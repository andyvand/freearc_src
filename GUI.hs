----------------------------------------------------------------------------------------------------
---- �������������� ������������ � ���� ���������� ��������� (CUI - Console User Interface).  ------
----------------------------------------------------------------------------------------------------
module GUI where

import Prelude    hiding (catch)
import Control.Monad
import Control.Concurrent
import Control.Exception
import Data.Char  hiding (Control)
import Data.IORef
import Data.List
import Data.Maybe
import Foreign
import Foreign.C
import Numeric           (showFFloat)
import System.CPUTime    (getCPUTime)
import System.IO
import System.Time

import Graphics.UI.Gtk
import Graphics.UI.Gtk.ModelView as New

import Utils
import Errors
import Files
import Charsets
import FileInfo
import Options
import UIBase

-- |���� �������� ���������
aINI_FILE = "freearc.ini"

-- ���� � INI-�����
aINITAG_LANGUAGE = "language"
aINITAG_PROGRESS = "ProgressWindowSize"

-- |������� �����������
aLANG_DIR = "arc.languages"

-- |��� ������-����� ��� �������� ��������������� ������� �������� �������
aHISTORY_FILE = "freearc.history"


----------------------------------------------------------------------------------------------------
---- ����������� ���������� ��������� --------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |�������������� Gtk � ������ ��������� ���� ���������
startGUI action = runInBoundThread $ do
  unsafeInitGUIForThreadedRTS
  action >>= widgetShowAll
  mainGUI

-- |������������� GUI-����� ���������
guiStartProgram = forkIO$ startGUI (fmap fst runIndicators)

-- |������ ���� ���������� ��������� � ��������� ���� ��� ��� �������������� ����������.
runIndicators = do
  -- INI-����
  inifile  <- findFile configFilePlaces aINI_FILE
  settings <- inifile  &&&  readConfigFile inifile >>== map (split2 '=')
  -- �����������.
  langDir  <- findDir configFilePlaces aLANG_DIR
  setLocale$ langDir </> (settings.$lookup aINITAG_LANGUAGE `defaultVal` aLANG_FILE)

  -- ���������� ���� ���������� ���������
  window <- windowNew
  vbox   <- vBoxNew False 10
  set window [windowWindowPosition := WinPosCenter,
              containerBorderWidth := 10, containerChild := vbox]

  -- ������ ���� ���������� ���������
  let sz = settings.$lookup aINITAG_PROGRESS `defaultVal` "350 200"
  let (w,h) = sz.$ split2 ' '
  windowResize window (readInt w) (readInt h)

  -- �������� ���� �� ���������
  (statsBox, updateStats, clearStats) <- createStats
  curFileLabel <- labelNew Nothing
  curFileBox   <- hBoxNew True 0
  boxPackStart curFileBox curFileLabel PackGrow 2
  widgetSetSizeRequest curFileLabel 30 (-1)
  progressBar  <- progressBarNew
  buttonBox    <- hBoxNew True 10
  boxPackStart vbox statsBox     PackNatural 0
  boxPackStart vbox curFileBox   PackNatural 0
  boxPackStart vbox progressBar  PackNatural 0
  boxPackEnd   vbox buttonBox    PackNatural 0
  miscSetAlignment curFileLabel 0 0    -- ��������� ����� ��� �������� �����
  progressBarSetText progressBar " "   -- ����� �������� ����� ����� ���������� ���������� ������ progressBar

  -- �������� �������� ������ ����� ����
  --buttonNew window stockClose ResponseClose
  backgroundButton <- buttonNewWithMnemonic       =<< i18n"0052   Background  "
  pauseButton      <- toggleButtonNewWithMnemonic =<< i18n"0053   Pause  "
  cancelButton     <- buttonNewWithMnemonic       =<< i18n"0055   Cancel  "
  boxPackStart buttonBox backgroundButton PackNatural 0
  boxPackStart buttonBox pauseButton      PackNatural 0
  boxPackEnd   buttonBox cancelButton     PackNatural 0

  -- ����������� ������� (�������� ����/������� ������)
  let askProgramClose = do
        active <- val pauseButton
        (if active then id else syncUI) $ do
          pauseTiming $ do
            whenM (askYesNo window "0251 Abort operation?") $ do
              ignoreErrors$ terminateOperation

  window `onDelete` \e -> do
    askProgramClose
    return True

  cancelButton `onClicked` do
    askProgramClose

  pauseButton `onToggled` do
    active <- val pauseButton
    if active then do takeMVar mvarSyncUI
                      pause_real_secs
                      buttonSetLabel pauseButton =<< i18n"0054   Continue  "
              else do putMVar mvarSyncUI "mvarSyncUI"
                      resume_real_secs
                      buttonSetLabel pauseButton =<< i18n"0053   Pause  "

  backgroundButton `onClicked` do
    windowIconify window

  -- ��������� ��������� ����, ���������� � ������� ���������� ��������� ��� � 0.5 �������
  i' <- ref 0   -- � ��� ��������� ��������� ��� � 0.1 �������
  indicatorThread 0.1 $ \indicator title b bytes total processed p -> postGUIAsync$ do
    i <- val i'; i' += 1; let once_a_halfsecond = (i `mod` 5 == 0)
    -- ��������� ����
    set window [windowTitle := title]                              `on` once_a_halfsecond
    -- ����������
    updateStats b processed                                        `on` once_a_halfsecond
    -- ��������-��� � ������� �� ��
    progressBarSetFraction progressBar processed                   `on` True
    progressBarSetText     progressBar p                           `on` once_a_halfsecond
  backgroundThread 0.5 $ postGUIAsync$ do
    -- ��� �������� ����� ��� ������ ���������� �������
    uiMessage' <- val uiMessage
    labelSetText curFileLabel uiMessage'

  -- ������� ��� ���� � ����������� � ������� ������
  let clearAll = do
        set window [windowTitle := " "]
        clearStats
        labelSetText curFileLabel ""
        progressBarSetFraction progressBar 0
        progressBarSetText     progressBar " "

  -- �������!
  widgetGrabFocus pauseButton
  return (window, clearAll)


-- |�������� ����� ��� ������ ����������
createStats = do
  textBox <- tableNew 4 6 False
  labels' <- ref []

  -- �������� ���� ��� ������ ������� ���������� � �������� ����� � ���
  let newLabel2 x y s = do label1 <- labelNewWithMnemonic =<< i18n s
                           tableAttach textBox label1 (x+0) (x+1) y (y+1) [Expand, Fill] [Expand, Fill] 0 0
                           --set label1 [labelWidthChars := 25]
                           miscSetAlignment label1 0 0

                           label2 <- labelNew Nothing
                           tableAttach textBox label2 (x+1) (x+2) y (y+1) [Expand, Fill] [Expand, Fill] 10 0
                           set label2 [labelSelectable := True]
                           miscSetAlignment label2 1 0
                           labels' ++= [label2]
                           return [label1,label2]
      -- ���������� ������ ���� ��������
      newLabel x y s  =    newLabel2 x y s >>== (!!1)

  newLabel 2 0 "     "        -- make space between left and right columns
  filesLabel      <- newLabel 0 0 "0056 Files"
  totalFilesLabel <- newLabel 3 0 "0057 Total files"
  bytesLabel      <- newLabel 0 1 "0058 Bytes"
  totalBytesLabel <- newLabel 3 1 "0059 Total bytes"
  ratioLabel      <- newLabel 0 3 "0060 Ratio"
  speedLabel      <- newLabel 3 3 "0061 Speed"
  timesLabel      <- newLabel 0 4 "0062 Time"
  totalTimesLabel <- newLabel 3 4 "0063 Total time"

  compressed      @ [_,      compressedLabel] <- newLabel2 0 2 "0252 Compressed"
  totalCompressed @ [_, totalCompressedLabel] <- newLabel2 3 2 "0253 Total compressed"
  last_cmd' <- ref ""

  -- ���������, ��������� ������� ����������
  let updateStats b (processed :: Double) = do
        UI_State { total_files = total_files
                 , total_bytes = total_bytes
                 , files       = files
                 , cbytes      = cbytes
                 }  <-  val ref_ui_state
        secs <- return_real_secs

        -- ��� ������ ���������� ��������� ������ � Compressed/Total compressed, ��� ��������� ��� ����������
        cmd <- val ref_command >>== cmd_name
        -- ��������/��������� ������� � ������ Compressed ���� ������� ����������
        last_cmd <- val last_cmd'
        last_cmd' =: cmd
        when (cmd /= last_cmd) $ do
          mapM_ (if cmdType cmd == ADD_CMD then widgetShow else widgetHide)
                (compressed++totalCompressed)

        labelSetMarkup filesLabel$      "<b>"++show3 files++"</b>"
        labelSetMarkup bytesLabel$      "<b>"++show3 b++"</b>"
        labelSetMarkup compressedLabel$ "<b>"++show3 cbytes++"</b>"
        labelSetMarkup totalFilesLabel$ "<b>"++show3 total_files++"</b>"
        labelSetMarkup totalBytesLabel$ "<b>"++show3 total_bytes++"</b>"
        labelSetMarkup timesLabel$      "<b>"++showHMS secs++"</b>"
        when (processed>0.001 && b>0) $ do
        labelSetMarkup totalCompressedLabel$ "<b>~"++show3 (total_bytes*cbytes `div` b)++"</b>"
        labelSetMarkup totalTimesLabel$      "<b>~"++showHMS (secs/processed)++"</b>"
        labelSetMarkup ratioLabel$           "<b>"++ratio2 cbytes b++"%</b>"
        labelSetMarkup speedLabel$           "<b>"++showSpeed b secs++"</b>"

  -- ���������, ��������� ������� ����������
  let clearStats  =  val labels' >>= mapM_ (`labelSetMarkup` "     ")
  --
  return (textBox, updateStats, clearStats)

{-# NOINLINE runIndicators #-}


-- |���������� � ������ ��������� �����
guiStartFile = doNothing0

-- |������������� ����� ���������� ��������� � ������� ��� �����
uiSuspendProgressIndicator = do
  aProgressIndicatorEnabled =: False

-- |����������� ����� ���������� ��������� � ������� ��� ������� ��������
uiResumeProgressIndicator = do
  aProgressIndicatorEnabled =: True

-- |������������� ��������� (���� �� �������) �� ����� ���������� ��������
uiPauseProgressIndicator action =
  bracket (do x <- val aProgressIndicatorEnabled
              aProgressIndicatorEnabled =: False
              return x)
          (\x -> aProgressIndicatorEnabled =: x)
          (\x -> action)

-- |Reset console title
resetConsoleTitle = return ()

-- |Pause progress indicator & timing while dialog runs
myDialogRun dialog  =  uiPauseProgressIndicator$ pauseTiming$ dialogRun dialog


----------------------------------------------------------------------------------------------------
---- ������� � ������������ ("������������ ����?" � �.�.) ------------------------------------------
----------------------------------------------------------------------------------------------------

{-# NOINLINE askOverwrite #-}
-- |������ � ���������� �����
askOverwrite filename diskFileSize diskFileTime arcfile ref_answer answer_on_u = do
  (title:file:question) <- i18ns ["0078 Confirm File Replace",
                                  "0165 %1\n%2 bytes\nmodified on %3",
                                  "0162 Destination folder already contains processed file.",
                                  "",
                                  "",
                                  "",
                                  "0163 Would you like to replace the existing file",
                                  "",
                                  "%1",
                                  "",
                                  "",
                                  "0164 with this one?",
                                  "",
                                  "%2"]
  let f1 = formatn file [filename,           show3$ diskFileSize,   formatDateTime$ diskFileTime]
      f2 = formatn file [storedName arcfile, show3$ fiSize arcfile, formatDateTime$ fiTime arcfile]
  ask (format title filename) (formatn (joinWith "\n" question) [f1,f2]) ref_answer answer_on_u

-- |����� �������� ��� ������ �������� � ������������
ask title question ref_answer answer_on_u =  do
  old_answer <- val ref_answer
  new_answer <- case old_answer of
                  "a" -> return old_answer
                  "u" -> return old_answer
                  "s" -> return old_answer
                  _   -> ask_user title question
  ref_answer =: new_answer
  case new_answer of
    "u" -> return answer_on_u
    _   -> return (new_answer `elem` ["y","a"])

-- |���������� ������� � ������������� ���������� �����
ask_user title question  =  gui $ do
  -- �������� ������
  bracketCtrlBreak (messageDialogNew Nothing [] MessageQuestion ButtonsNone question) widgetDestroy $ \dialog -> do
  set dialog [windowTitle          := title,
              windowWindowPosition := WinPosCenter]
{-
  -- ������ � ������������
  upbox <- dialogGetUpper dialog
  label <- labelNew$ Just$ question++"?"
  boxPackStart  upbox label PackGrow 0
  widgetShowAll upbox
-}
  -- ������ ��� ���� ��������� �������
  hbox <- dialogGetActionArea dialog
  buttonBox <- tableNew 3 3 True
  boxPackStart hbox buttonBox PackGrow 0
  id' <- ref 1
  for (zip [0..] buttons) $ \(y,line) -> do
    for (zip [0..] (split '/' line)) $ \(x,text) -> do
      when (text>"") $ do
      text <- i18n text
      button <- buttonNewWithMnemonic ("  "++text++"  ")
      tableAttachDefaults buttonBox button x (x+1) y (y+1)
      id <- val id'; id' += 1
      dialogAddActionWidget dialog button (ResponseUser id)
  widgetShowAll hbox

  -- �������� ����� � ���� �����: y/n/a/...
  (ResponseUser id) <- myDialogRun dialog
  let answer = (split '/' valid_answers) !! (id-1)
  when (answer=="q") $ do
    terminateOperation
  return answer


-- ������, ������������ ask_user, � ��������������� �� ������� �� �������, ���������
valid_answers = "y/n/q/a/s/u"
buttons       = ["0079 _Yes/0080 _No/0081 _Cancel"
                ,"0082 Yes to _All/0083 No to A_ll/0084 _Update all"]


----------------------------------------------------------------------------------------------------
---- ������ ������� --------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |������ ������ ��� ����������/������������. ������������ ��������� ����.
-- ��� ���������� ������ ���� ������ ������ - ��� ������ �� ������ ��� �����
ask_passwords = ( ask_password_dialog "0076 Enter encryption password" 2
                , ask_password_dialog "0077 Enter decryption password" 1
                , doNothing0   -- ���������� ��� ������������ ������
                )

-- |������ ������� ������.
ask_password_dialog title' amount opt_parseData = gui $ do
  -- �������� ������ �� ������������ �������� OK/Cancel
  bracketCtrlBreak dialogNew widgetDestroy $ \dialog -> do
  title <- i18n title'
  set dialog [windowTitle          := title,
              windowWindowPosition := WinPosCenter]
  okButton <- buttonNewFromStock stockOk
  hbox     <- dialogGetActionArea dialog
  boxPackEnd hbox okButton PackNatural 10
  --okButton <- dialogAddButton dialog stockOk ResponseOk
  dialogAddButton dialog stockCancel ResponseCancel

  -- ������ ������� � ������ ��� ����� ������ ��� ���� �������
  (pwdTable, [pwd1,pwd2]) <- pwdBox amount
  for [pwd1,pwd2] (`onEntryActivate` buttonClicked okButton)

  -- ������ OK ����������� ������ ���� ��� �������� ������ ���������
  onClicked okButton $ do
    p1 <- val pwd1
    p2 <- val pwd2
    when (p1>"" && p1==p2) $ do
      dialogResponse dialog ResponseOk

  -- ������� ������� ������ ������� � ����� � �� �����
  set pwdTable [containerBorderWidth := 10]
  upbox <- dialogGetUpper dialog
  boxPackStart  upbox pwdTable PackGrow 0
  widgetShowAll upbox

  choice <- myDialogRun dialog
  if choice==ResponseOk
    then val pwd1
    else terminateOperation >> return ""


{-# NOINLINE ask_passwords #-}

-- |������ ������� � ������ ��� ����� ������ ��� ���� �������
pwdBox amount = do
  pwdTable <- tableNew 2 amount False
  tableSetColSpacings pwdTable 0
  let newField y s = do -- ������� � ����� �������
                        label <- labelNewWithMnemonic =<< i18n s
                        tableAttach pwdTable label 0 1 (y-1) y [Fill] [Expand, Fill] 5 0
                        miscSetAlignment label 0 0.5
                        -- ���� ����� ������ � ������ �������
                        pwd <- entryNew
                        set pwd [entryVisibility := False, entryActivatesDefault := True]
                        tableAttach pwdTable pwd 1 2 (y-1) y [Expand, Shrink, Fill] [Expand, Fill] 5 0
                        return pwd
  pwd1 <- newField 1 "0074 Enter password:"
  pwd2 <- if amount==2  then newField 2 "0075 Reenter password:"  else return pwd1
  return (pwdTable, [pwd1,pwd2])


----------------------------------------------------------------------------------------------------
---- ����/����� ������������ � ������  -------------------------------------------------------------
----------------------------------------------------------------------------------------------------

{-# NOINLINE uiPrintArcComment #-}
uiPrintArcComment = doNothing

{-# NOINLINE uiInputArcComment #-}
uiInputArcComment old_comment = gui$ do
  bracketCtrlBreak dialogNew widgetDestroy $ \dialog -> do
  title <- i18n"0073 Enter archive comment"
  set dialog [windowTitle := title,
              windowDefaultHeight := 200, windowDefaultWidth := 400,
              windowWindowPosition := WinPosCenter]
  dialogAddButton dialog stockOk     ResponseOk
  dialogAddButton dialog stockCancel ResponseCancel

  commentTextView <- newTextViewWithText old_comment
  upbox <- dialogGetUpper dialog
  boxPackStart upbox commentTextView PackGrow 10
  widgetShowAll upbox

  choice <- myDialogRun dialog
  if choice==ResponseOk
    then textViewGetText commentTextView
    else terminateOperation >> return ""


----------------------------------------------------------------------------------------------------
---- ���������� ------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |��������� �������� � GUI-����� (���������� ���, ��� ������������ bound thread � ��� - �������)
gui action = do
  bound <- isCurrentThreadBound
  if bound  then action else do
  x <- ref Nothing
  y <- postGUISync (action `catch` (\e -> do x=:Just e; return undefined))
  whenJustM (val x) throwIO
  return y

-- |���������� ����������, �������� ������� ��������� �� ������� �����
tooltips :: IORef Tooltips = unsafePerformIO$ ref$ error "undefined GUI::tooltips"
tooltip w s = do s <- i18n s; t <- val tooltips; tooltipsSetTip t w s ""

-- |������� �������, ��� ��� �������������� ������� � ������
i18t title create = do
  (label, t) <- i18n' title
  control <- create label
  tooltip control t  `on`  t/=""
  return control

-- |This instance allows to get/set checkbox state using standard =:/val interface
instance Variable RadioButton Bool where
  new  = undefined
  val  = toggleButtonGetActive
  (=:) = toggleButtonSetActive

-- |This instance allows to get/set checkbox state using standard =:/val interface
instance Variable ToggleButton Bool where
  new  = undefined
  val  = toggleButtonGetActive
  (=:) = toggleButtonSetActive

-- |This instance allows to get/set checkbox state using standard =:/val interface
instance Variable CheckButton Bool where
  new  = undefined
  val  = toggleButtonGetActive
  (=:) = toggleButtonSetActive

-- |This instance allows to get/set entry state using standard =:/val interface
instance Variable Entry String where
  new  = undefined
  val  = entryGetText
  (=:) = entrySetText

-- |This instance allows to get/set expander state using standard =:/val interface
instance Variable Expander Bool where
  new  = undefined
  val  = expanderGetExpanded
  (=:) = expanderSetExpanded

-- |This instance allows to get/set value displayed by widget using standard =:/val interface
instance GtkWidgetClass w gw a => Variable w a where
  new  = undefined
  val  = getValue
  (=:) = setValue

-- |Universal interface to arbitrary GTK widget `w` which controls value of type `a`
class GtkWidgetClass w gw a | w->gw, w->a where
  widget      :: w -> gw                 -- ^The GTK widget by itself
  getTitle    :: w -> IO String          -- ^Read current widget's title
  setTitle    :: w -> String -> IO ()    -- ^Set current widget's title
  getValue    :: w -> IO a               -- ^Read current widget's value
  setValue    :: w -> a -> IO ()         -- ^Set current widget's value
  setOnUpdate :: w -> (IO ()) -> IO ()   -- ^Called when user changes widget's value
  onClick     :: w -> (IO ()) -> IO ()   -- ^Called when user clicks button

data GtkWidget gw a = GtkWidget
 {gwWidget      :: gw
 ,gwGetTitle    :: IO String
 ,gwSetTitle    :: String -> IO ()
 ,gwGetValue    :: IO a
 ,gwSetValue    :: a -> IO ()
 ,gwSetOnUpdate :: (IO ()) -> IO ()
 ,gwOnClick     :: (IO ()) -> IO ()
 }

instance GtkWidgetClass (GtkWidget gw a) gw a where
  widget      = gwWidget
  getTitle    = gwGetTitle
  setTitle    = gwSetTitle
  getValue    = gwGetValue
  setValue    = gwSetValue
  setOnUpdate = gwSetOnUpdate
  onClick     = gwOnClick

-- |������ GtkWidget
gtkWidget = GtkWidget { gwWidget      = undefined
                      , gwGetTitle    = undefined
                      , gwSetTitle    = undefined
                      , gwGetValue    = undefined
                      , gwSetValue    = undefined
                      , gwSetOnUpdate = undefined
                      , gwOnClick     = undefined
                      }

-- ������������ ������ Pango Markup ��� ����������� ������
bold text = "<b>"++text++"</b>"


-- |������ ����� ������ TextView � �������� �������
newTextViewWithText s = do
  textView <- textViewNew
  textViewSetText textView s
  return textView

-- |����� �����, ������������ � TextView
textViewSetText textView s = do
  buffer <- textViewGetBuffer textView
  textBufferSetText buffer s

-- |��������� �����, ������������ � TextView
textViewGetText textView = do
  buffer <- textViewGetBuffer      textView
  start  <- textBufferGetStartIter buffer
  end    <- textBufferGetEndIter   buffer
  textBufferGetText buffer start end False


{-# NOINLINE eventKey #-}
-- |���������� ������ ��� �������, �������� Alt-Ctrl-M
eventKey (Key {eventKeyName = name, eventModifier = modifier}) =
  let mshow Shift   = "Shift"
      mshow Control = "Ctrl"
      mshow Alt     = "Alt"
      mshow _       = "_"
  --
  in joinWith "-" ((sort$ map mshow modifier)++[mapHead toUpper name])

{-# NOINLINE debugMsg #-}
-- |������ � ���������� ����������
debugMsg msg = do
  bracketCtrlBreak (messageDialogNew (Nothing) [] MessageError ButtonsClose msg) widgetDestroy $ \dialog -> do
  dialogRun dialog
  return ()

{-# NOINLINE msgBox #-}
-- |������ � �������������� ����������
msgBox window dialogType msg = do
  imsg <- i18n msg
  bracketCtrlBreak (messageDialogNew (Just window) [] dialogType ButtonsClose imsg) widgetDestroy $ \dialog -> do
  dialogRun dialog
  return ()

-- |��������� � ������������ ������������� ��������
askOkCancel = askConfirmation ButtonsOkCancel ResponseOk
askYesNo    = askConfirmation ButtonsYesNo    ResponseYes
{-# NOINLINE askConfirmation #-}
askConfirmation buttons rightResponse window msg = do
  imsg <- i18n msg
  bracketCtrlBreak (messageDialogNew (Just window) [] MessageQuestion buttons imsg) widgetDestroy $ \dialog -> do
  dialogRun dialog >>== (==rightResponse)

{-# NOINLINE inputString #-}
-- |��������� � ������������ ������
inputString window msg = do
  -- �������� ������ �� ������������ �������� OK/Cancel
  bracketCtrlBreak dialogNew widgetDestroy $ \dialog -> do
    set dialog [windowTitle        := msg,
                windowTransientFor := window]
    dialogAddButton dialog stockOk     ResponseOk      >>= \okButton -> do
    dialogAddButton dialog stockCancel ResponseCancel

    --label    <- labelNew$ Just msg
    entry <- entryNew
    entry `onEntryActivate` buttonClicked okButton

    upbox <- dialogGetUpper dialog
    --boxPackStart  upbox label    PackGrow 0
    boxPackStart  upbox entry PackGrow 0
    widgetShowAll upbox

    choice <- dialogRun dialog
    case choice of
      ResponseOk -> val entry >>== Just
      _          -> return Nothing


{-# NOINLINE boxed #-}
-- |������� control � ��������� ��� � hbox
boxed makeControl title = do
  hbox    <- hBoxNew False 0
  control <- makeControl .$i18t title
  boxPackStart  hbox  control  PackNatural 5
  return (hbox, control)


{-# NOINLINE label #-}
-- |�����
label title   =  do (hbox, _) <- boxed labelNewWithMnemonic title
                    return gtkWidget {gwWidget = hbox}


{-# NOINLINE button #-}
-- |������
button title  =  do
  (hbox, control) <- boxed buttonNewWithMnemonic title
  return gtkWidget { gwWidget   = hbox
                   , gwOnClick  = \action -> onClicked control action >> return ()
                   , gwSetTitle = buttonSetLabel control
                   , gwGetTitle = buttonGetLabel control
                   }


{-# NOINLINE checkBox #-}
-- |�������
checkBox title = do
  (hbox, control) <- boxed checkButtonNewWithMnemonic title
  return gtkWidget { gwWidget      = hbox
                   , gwGetValue    = val control
                   , gwSetValue    = (control=:)
                   , gwSetOnUpdate = \action -> onToggled control action >> return ()
                   }


{-# NOINLINE comboBox #-}
-- |������ ���������, ���������� �������� ����� �����������
comboBox title labels = do
  hbox  <- hBoxNew False 0
  label <- labelNewWithMnemonic .$i18t title
  combo <- New.comboBoxNewText
  for labels (\l -> New.comboBoxAppendText combo =<< i18n l)
  boxPackStart  hbox  label  PackNatural 5
  boxPackStart  hbox  combo  PackNatural 5
  return gtkWidget { gwWidget      = hbox
                   , gwGetValue    = New.comboBoxGetActive combo >>== fromMaybe 0
                   , gwSetValue    = New.comboBoxSetActive combo
                   }


{-# NOINLINE simpleComboBox #-}
-- |������ ���������, ���������� �������� ����� �����������
simpleComboBox labels = do
  combo <- New.comboBoxNewText
  for labels (New.comboBoxAppendText combo)
  return combo

{-# NOINLINE makePopupMenu #-}
-- |������ popup menu
makePopupMenu action labels = do
  m <- menuNew
  mapM_ (mkitem m) labels
  return m
    where
        mkitem menu label =
            do i <- menuItemNewWithLabel label
               menuShellAppend menu i
               i `onActivateLeaf` (action label)



{-# NOINLINE radioFrame #-}
-- |������ �����, ���������� ����� ����������� � ���������� ���� �����
--  ���� ��������� ��� ������ ������� ��������� ������
radioFrame title (label1:labels) = do
  -- ������� �����-������, ��������� �� � ���� ������
  radio1 <- radioButtonNewWithMnemonic .$i18t label1
  radios <- mapM (\title -> radioButtonNewWithMnemonicFromWidget radio1 .$i18t title) labels
  let buttons = radio1:radios
  -- ��������� �� ����������� � ��������� ��������� �������, ����������� � ���������� onChanged
  vbox <- vBoxNew False 0
  onChanged <- ref doNothing0
  for buttons $ \button -> do boxPackStart vbox button PackNatural 0
                              button `onToggled` do
                                whenM (val button) $ do
                                  val onChanged >>= id
  -- ������� ������� ������ ������
  frame <- i18t title $ \title -> do
             frame <- frameNew
             set frame [frameLabel := title.$ deleteIf (=='_'), containerChild := vbox]
             return frame
  return gtkWidget { gwWidget      = frame
                   , gwGetValue    = foreach buttons val >>== fromJust.elemIndex True
                   , gwSetValue    = \i -> (buttons!!i) =: True
                   , gwSetOnUpdate = (onChanged=:)
                   }


{-# NOINLINE twoColumnTable #-}
-- |�������������� �������, ������������ �������� �����+������
twoColumnTable dataset = do
  (table, setLabels) <- emptyTwoColumnTable$ map fst dataset
  zipWithM_ ($) setLabels (map snd dataset)
  return table

{-# NOINLINE emptyTwoColumnTable #-}
-- |�������������� �������: ��������� ������ ����� ��� ����� �������
-- � ���������� ������ �������� setLabels ��� ��������� ������ �� ������ �������
emptyTwoColumnTable dataset = do
  table <- tableNew (length dataset) 2 False
  -- �������� ���� ��� ������ ������� ���������� � �������� ����� � ���
  setLabels <- foreach (zip [0..] dataset) $ \(y,s) -> do
      -- ������ �������
      label <- labelNewWithMnemonic =<< i18n s;  let x=0
      tableAttach table label (x+0) (x+1) y (y+1) [Expand, Fill] [Expand, Fill] 0 0
      miscSetAlignment label 0 0     --set label [labelWidthChars := 25]
      -- ������ �������
      label <- labelNew Nothing
      tableAttach table label (x+1) (x+2) y (y+1) [Expand, Fill] [Expand, Fill] 10 0
      set label [labelSelectable := True]
      miscSetAlignment label 1 0
      -- ��������� ��������, ��������������� ����� ������ ����� (��������������� ��� ������ ������)
      return$ \text -> labelSetMarkup label$ bold$ text
  return (table, setLabels)

