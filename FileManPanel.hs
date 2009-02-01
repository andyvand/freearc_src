----------------------------------------------------------------------------------------------------
---- FreeArc archive manager: file manager panel                                              ------
----------------------------------------------------------------------------------------------------
module FileManPanel where

import Prelude hiding (catch)
import Control.Concurrent
import Control.Exception
import Control.Monad
import Data.Char
import Data.IORef
import Data.List
import Data.Maybe
import System.IO.Unsafe

import Graphics.UI.Gtk
import Graphics.UI.Gtk.ModelView as New

import Utils
import Errors
import Files
import FileInfo
import Charsets
import Options
import Cmdline
import UIBase
import UI
import ArhiveDirectory
import ArcExtract
import FileManUtils


-- |������ ���������� � �����������
encryptionPassword  =  unsafePerformIO$ newIORef$ ""
decryptionPassword  =  unsafePerformIO$ newIORef$ ""

----------------------------------------------------------------------------------------------------
---- �������� ����-��������� -----------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |������� ���������� ��� �������� ��������� ����-���������
newFM window view model selection statusLabel messageCombo = do
  historyFile <- io$ findOrCreateFile configFilePlaces aHISTORY_FILE
  curdir <- io$ getCurrentDirectory
  counterCombo <- ref 0  -- number of last message + 1 in combobox
  fm' <- mvar FM_State { fm_window       = window
                       , fm_view         = view
                       , fm_model        = model
                       , fm_selection    = selection
                       , fm_statusLabel  = statusLabel
                       , fm_messageCombo = (messageCombo, counterCombo)
                       , fm_filelist     = error "undefined FM_State::fm_filelist"
                       , fm_history_file = historyFile
                       , fm_history      = Nothing
                       , fm_onChdir      = []
                       , fm_sort_order   = ""
                       , subfm           = FM_Directory {subfm_dir=curdir}}
  selection `New.onSelectionChanged` fmStatusBarTotals fm'
  return fm'

-- |������� ����� � ���������� ��� ��� ������ ��������� ����-���������
newFMArc fm' arcname arcdir = do
  xpwd'     <- val decryptionPassword
  xkeyfile' <- fmGetHistory1 fm' "keyfile" ""
  [command] <- io$ parseCmdline$ ["l", arcname]++(xpwd' &&& ["-op"++xpwd'])
                                               ++(xkeyfile' &&& ["--OldKeyfile="++xkeyfile'])
  command <- (command.$ opt_cook_passwords) command ask_passwords  -- ����������� ������ � ������� � �������������
  archive <- io$ archiveReadInfo command "" "" (const True) doNothing2 arcname
  let filetree = buildTree$ map (fiToFileData.cfFileInfo)$ arcDirectory archive
  io$ arcClose archive
  return$ FM_Archive archive arcname arcdir filetree

-- |������� ���� ������ ����� ������ �������� ������ �������������� ���
closeFMArc fm' = do
  return ()
  --fm <- val fm'
  --io$ arcClose (fm_archive fm)
  --fm' .= \fm -> fm {subfm = (subfm fm) {subfm_archive = phantomArc}}

-- ������� � �����/������� filename
chdir fm' filename' = do
  fm <- val fm'
  filename <- fmCanonicalizePath fm' filename'
  res <- splitArcPath fm' filename
  msg <- i18n"0071 %1: no such file or directory!"
  if res==Not_Exists  then fmErrorMsg fm' (format msg filename)  else do
  (files, sub) <- case res of
    -- ������ ������ � �������� �� �����
    DiskPath dir -> do filelist <- io$ dir_list dir
                       return (map fiToFileData filelist, FM_Directory dir)
    -- ������ ������ � ������
    ArcPath arcname arcdir -> do
                       arc <- if isFM_Archive fm && arcname==fm_arcname fm
                              then return ((fm.$subfm) {subfm_arcdir=arcdir})
                              else newFMArc fm' arcname arcdir
                       return (arc.$subfm_filetree.$ftFilesIn arcdir fdArtificialDir, arc)
  -- ������� ������� �������/����� � fm � ������� �� ����� ����� ������ ������
  fm' =: fm {subfm = sub}
  fmSetFilelist fm' (files.$ sortOnColumn (fm_sort_order fm))
  -- ������� ��������� � �������� ��� ��������� ������������������� ��������.
  --fmStatusBarTotals fm'
  sequence_ (fm_onChdir fm)
  widgetGrabFocus (fm_view fm)
  -- ������� ������� �������/����� � ��������� ����
  fm <- val fm'
  let title | isFM_Archive fm  =  takeFileName (fm_arcname fm) </> fm_arcdir fm
            | otherwise        =  takeFileName (fm_dir fm)  |||  fm_dir fm
  set (fm_window fm) [windowTitle := title++" - FreeArc"]


-- |�������� action � ������ ��������, ����������� ��� �������� � ������ �������/�����
fmOnChdir fm' action = do
  fm' .= \fm -> fm {fm_onChdir = action : fm_onChdir fm}

-- |������� � ������ ��������� ���������� �� ����� ������ ������ � ������� �� ��� �������
fmStatusBarTotals fm' = do
  fm <- val fm'
  selected <- getSelectionFileInfo fm'
  [sel,total] <- i18ns ["0022 Selected %1 bytes in %2 file(s)", "0023 Total %1 bytes in %2 file(s)"]
  let format msg files  =  formatn msg [show3$ sum$ map fdSize files,  show3$ length files]
  fmStatusBarMsg fm' $ (selected &&& (format sel   selected++"     "))
                                 ++   format total (fm_filelist fm)

-- |������� ��������� � ������ ���������
fmStatusBarMsg fm' msg = do
  fm <- val fm'
  labelSetText (fm_statusLabel fm) msg
  return ()

-- |�������� ��������� � pop-up ������ ���������
fmStackMsg fm' msg = do
  fm <- val fm'
  let (box,n')  =  fm_messageCombo fm
  n <- val n';  n' += 1
  New.comboBoxAppendText box msg
  New.comboBoxSetActive  box n
  return ()

-- |��� �����, ������������ �� ��������� ����
fmFilenameAt fm' path = do
  fm <- val fm'
  let fullList = fm_filelist fm
  return$ fmname(fullList!!head path)

-- |���������� ���� ��� ��������
fmGetCursor fm' = do
  fm <- val fm'
  let fullList  = fm_filelist  fm
  (cursor,_) <- New.treeViewGetCursor (fm_view fm)
  case cursor of
    [i] -> return (fdBasename$ fullList!!i)
    _   -> return ""

-- |���������� ������ �� �������� ����
fmSetCursor fm' filename = do
  fm <- val fm'
  whenJustM_ (fmFindCursor fm' filename)
             (\cursor -> New.treeViewSetCursor (fm_view fm) cursor Nothing)

-- |���������� ������ ��� ����� � �������� ������
fmFindCursor fm' filename = do
  fm <- val fm'
  let fullList  =  fm_filelist  fm
  return (fmap (:[])$  findIndex ((filename==).fmname) fullList)

-- |��������/����������� �����, ��������������� ��������� ���������
fmSelectFilenames   = fmSelUnselFilenames New.treeSelectionSelectPath
fmUnselectFilenames = fmSelUnselFilenames New.treeSelectionUnselectPath
fmSelUnselFilenames selectOrUnselect fm' filter_p = do
  fm <- val fm'
  let fullList  = fm_filelist  fm
  let selection = fm_selection fm
  for (findIndices filter_p fullList)
      (selectOrUnselect selection.(:[]))

-- |������ ��� ��������� ������ + ��� ��������� � ����������� mapDirName
getSelection fm' mapDirName = do
  let mapFilenames fd | fdIsDir fd = mapDirName$ fmname fd
                      | otherwise  = [fmname fd]
  getSelectionFileInfo fm' >>== concatMap mapFilenames

-- |������ FileInfo ��������� ������
getSelectionFileInfo fm' = do
  fm <- val fm'
  let fullList = fm_filelist fm
  getSelectionRows fm' >>== map (fullList!!)

-- |������ ������� ��������� ������
getSelectionRows fm' = do
  fm <- val fm'
  let selection = fm_selection fm
  New.treeSelectionGetSelectedRows selection >>== map head

-- |������� �� ������ ��������� �����
fmDeleteSelected fm' = do
  rows <- getSelectionRows fm'
  fm <- val fm'
  fmSetFilelist fm' (fm_filelist fm `deleteElems` rows)

-- |������� �� ����� ����� ������ ������
fmSetFilelist fm' files = do
  fm <- val fm'
  fm' =: fm {fm_filelist = files}
  changeList (fm_model fm) files

-- |������� ��������� �� ������
fmErrorMsg fm' msg = do
  fm <- val fm'
  msgBox (fm_window fm) MessageError =<< i18n msg


----------------------------------------------------------------------------------------------------
---- ���������� ������ ������ ----------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |���������� ������� ������� ����������
fmGetSortOrder fm'  =  fm_sort_order `fmap` val fm'
-- |���������� ������� ����������
fmSetSortOrder fm' showSortOrder  =  fmModifySortOrder fm' showSortOrder . const
-- |�������������� ������� ���������� � fm' � �������� ��������� ���������� ��� ��������������� ��������
fmModifySortOrder fm' showSortOrder f_order = do
  fm <- val fm'
  let sort_order = f_order (fm_sort_order fm)
  fm' =: fm {fm_sort_order = sort_order}
  -- ������������ ��������� ����������
  let (column, order)  =  break1 isUpper sort_order
  showSortOrder column (if order == "Asc"  then SortDescending  else SortAscending)  -- Gtk ����� ��� ������ � ���, ��� �������� ��������� ;)

-- |��������� ������� ���������� � �������
fmSaveSortOrder    fm'  =  fmReplaceHistory fm' "SortOrder"
-- |������������ ������� ���������� �� �������
fmRestoreSortOrder fm'  =  fmGetHistory1    fm' "SortOrder" "NameAsc"

-- | (ClickedColumnName, OldSortOrder) -> NewSortOrder
calcNewSortOrder "Name"     "NameAsc"      = "NameDesc"
calcNewSortOrder "Name"     _              = "NameAsc"
calcNewSortOrder "Size"     "SizeDesc"     = "SizeAsc"
calcNewSortOrder "Size"     _              = "SizeDesc"
calcNewSortOrder "Modified" "ModifiedDesc" = "ModifiedAsc"
calcNewSortOrder "Modified" _              = "ModifiedDesc"

-- |����� ������� ���������� �� ����� �������
sortOnColumn "NameAsc"       =  sortOn (\fd -> (not$ fdIsDir fd, strLower$ fmname fd))
sortOnColumn "NameDesc"      =  sortOn (\fd -> (     fdIsDir fd, strLower$ fmname fd))  >>> reverse
--
sortOnColumn "SizeAsc"       =  sortOn (\fd -> if fdIsDir fd  then -1             else  fdSize fd)
sortOnColumn "SizeDesc"      =  sortOn (\fd -> if fdIsDir fd  then aFILESIZE_MIN  else -fdSize fd)
--
sortOnColumn "ModifiedAsc"   =  sortOn (\fd -> (not$ fdIsDir fd,  fdTime fd))
sortOnColumn "ModifiedDesc"  =  sortOn (\fd -> (not$ fdIsDir fd, -fdTime fd))
--
sortOnColumn _               =  id


----------------------------------------------------------------------------------------------------
---- �������� � ������ ������� ---------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |�������� �������� � ������ �������
fmAddHistory fm' tags text = ignoreErrors $ do
  fm <- val fm'
  -- ������ ����� ������� � ������ ������ � ��������� �� ����������� ��������
  let newItem  =  join2 "=" (head (split '/' tags), text)
  modifyConfigFile (fm_history_file fm) ((newItem:) . deleteIf (==newItem))

-- |todo: �������� �������� � ������ �������
fmReplaceHistory = fmAddHistory

-- |������� ������ ������� �� ��������� ����/�����
fmGetHistory1 fm' tags deflt = do x <- fmGetHistory fm' tags; return (head (x++[deflt]))
fmGetHistory  fm' tags       = handle (\_ -> return []) $ do
  fm <- val fm'
  hist <- fmGetConfigFile fm'
  hist.$ map (split2 '=')                           -- ������� ������ ������ �� ���+��������
      .$ filter ((split '/' tags `contains`).fst)   -- �������� ������ � ����� �� ������ tags
      .$ map snd                                    -- �������� ������ ��������.
      .$ map (splitCmt "")                          -- ������� ������ �������� �� ��������+�����
      .$ mapM (\x -> case x of                      -- ������������ �������� � ����� �� �������
                       ("",b) -> return b
                       (a ,b) -> do a <- i18n a; return$ join2 ": " (a,b))

-- |�������� ���������� ����� �������
fmGetConfigFile fm' = do
  fm <- val fm'
  case fm_history fm of
    Nothing      -> readConfigFile (fm_history_file fm)
    Just history -> return history

-- |�� ����� ���������� ���� ������ ���������� ����� ������� �������� �� ���� fm_history
fmCacheConfigFile fm' =
  bracket_ (do fm <- val fm'
               history <- readConfigFile (fm_history_file fm)
               fm' =: fm {fm_history = Just history})
           (fm' .= \fm -> fm {fm_history = Nothing})


----------------------------------------------------------------------------------------------------
---- ��������������� ����������� -------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- �������� ���� �� ���������� ��������� �� �������
opt `select` variants  =  words$ split ',' variants !! opt
-- ����������� ����� ��������� � ������ �����, �������������� ������ ����������� � � ������
cvt1 opt  =  map (opt++) . words . clear
-- �� �� �����, ������ ��� ����� ����������� ������ � ������, �� ������������ � "-"
cvt  opt  =  map (\w -> (w!~"-*" &&& opt)++w) . words . clear
-- ������� ����������� ���� "*: " � ������ ������
clear     =  trim . snd . splitCmt ""
-- |��������� �������� �� ��������+�����
splitCmt xs ""           = ("", reverse xs)
splitCmt xs ":"          = (reverse xs, "")
splitCmt xs (':':' ':ws) = (reverse xs, ws)
splitCmt xs (w:ws)       = splitCmt (w:xs) ws


----------------------------------------------------------------------------------------------------
---- GUI controls, ����������������� � FM ----------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |��������������� ������, �������������� ������ ����� � ����������� ��������
data EntryWithHistory = EntryWithHistory
  { ehGtkWidget   :: GtkWidget ComboBoxEntry String
  , entry         :: Entry
  , saveHistory   :: IO ()
  , rereadHistory :: IO ()
  }

instance GtkWidgetClass EntryWithHistory ComboBoxEntry String where
  widget      = widget      . ehGtkWidget
  getTitle    = getTitle    . ehGtkWidget
  setTitle    = setTitle    . ehGtkWidget
  getValue    = getValue    . ehGtkWidget
  setValue    = setValue    . ehGtkWidget
  setOnUpdate = setOnUpdate . ehGtkWidget
  onClick     = onClick     . ehGtkWidget


{-# NOINLINE fmEntryWithHistory #-}
-- |������� �����-���� � �������� ��� ����� tag;
-- ����� ������������ � ������� ���������� �������� ����� ����� �������� process
fmEntryWithHistory fm' tag filter_p process = do
  comboBox <- New.comboBoxEntryNewText
  Just entry <- binGetChild comboBox >>== fmap castToEntry
  historySize <- mvar 0
  let rereadHistory = do
        historySize .<- \hs -> do
        replicateM_ (hs+1) (New.comboBoxRemoveText comboBox 0)
        history <- fmGetHistory fm' tag >>= Utils.filterM filter_p
        for history (New.comboBoxAppendText comboBox)
        return (length history)
  let getText = do
        New.comboBoxGetActiveText comboBox >>= process.fromJust
  let setText text = do
        entry =: text
  let saveHistory = do
        text <- getText
        New.comboBoxPrependText comboBox text
        fmAddHistory fm' tag text
  rereadHistory
  hs <- val historySize
  when (hs>0) $ New.comboBoxSetActive comboBox 0
  return EntryWithHistory
           {                           entry         = entry
           ,                           saveHistory   = saveHistory
           ,                           rereadHistory = rereadHistory
           , ehGtkWidget = gtkWidget { gwWidget      = comboBox
                                     , gwGetValue    = getText
                                     , gwSetValue    = setText
                                     , gwSetOnUpdate = \action -> New.onChanged comboBox action >> return ()
                                     }
           }


{-# NOINLINE fmLabeledEntryWithHistory #-}
-- |���� ������ � �������� ��� ����� tag � ������ �����
fmLabeledEntryWithHistory fm' tag title = do
  hbox  <- hBoxNew False 0
  title <- label title
  inputStr <- fmEntryWithHistory fm' tag (const$ return True) (return)
  set (entry inputStr) [entryActivatesDefault := True]
  boxPackStart  hbox  (widget title)     PackNatural 0
  boxPackStart  hbox  (widget inputStr)  PackGrow    5
  return (hbox, inputStr)


{-# NOINLINE fmCheckedEntryWithHistory #-}
-- |���� ������ � �������� ��� ����� tag � ��������� �����
fmCheckedEntryWithHistory fm' tag title = do
  hbox  <- hBoxNew False 0
  checkBox <- checkBox title
  inputStr <- fmEntryWithHistory fm' tag (const$ return True) (return)
  set (entry inputStr) [entryActivatesDefault := True]
  boxPackStart  hbox  (widget checkBox)  PackNatural 0
  boxPackStart  hbox  (widget inputStr)  PackGrow    5
  --checkBox `onToggled` do
  --  on <- val checkBox
  --  (if on then widgetShow else widgetHide) (widget inputStr)
  return (hbox, checkBox, inputStr)


{-# NOINLINE fmFileBox #-}
-- |���� ����� �����/�������� � �������� ��� ����� tag � ������� �� ����� ����� ���������� ������
fmFileBox fm' dialog tag dialogType makeControl dialogTitle filter_p process = do
  hbox    <- hBoxNew False 0
  control <- makeControl
  dir'    <- fmEntryWithHistory fm' tag filter_p process
  set (entry dir') [entryActivatesDefault := True]
  chooserButton <- button "0999 ..."
  chooserButton `onClick` do
    title <- i18n dialogTitle
    bracketCtrlBreak (fileChooserDialogNew (Just title) (Just$ castToWindow dialog) dialogType [("Select",ResponseOk), ("Cancel",ResponseCancel)]) widgetDestroy $ \chooserDialog -> do
      fileChooserSetFilename    chooserDialog =<< (val dir' >>== unicode2utf8)
      fileChooserSetCurrentName chooserDialog =<< (val dir' >>== takeFileName)
      fileChooserSetFilename    chooserDialog =<< (val dir' >>== unicode2utf8)
      choice <- dialogRun chooserDialog
      when (choice==ResponseOk) $ do
        whenJustM_ (fileChooserGetFilename chooserDialog) $ \dir -> do
          dir' =: utf8_to_unicode dir
  boxPackStart  hbox  (widget control)        PackNatural 0
  boxPackStart  hbox  (widget dir')           PackGrow    5
  boxPackStart  hbox  (widget chooserButton)  PackNatural 0
  return (hbox, control, dir')


{-# NOINLINE fmInputString #-}
-- |��������� � ������������ ������ (� �������� �����)
fmInputString fm' tag title filter_p process = do
  fm <- val fm'
  -- �������� ������ �� ������������ �������� OK/Cancel
  fmDialog fm' title $ \(dialog,okButton) -> do
    x <- fmEntryWithHistory fm' tag filter_p process
    set (entry x) [entryActivatesDefault := True]

    upbox <- dialogGetUpper dialog
    --boxPackStart  upbox label    PackGrow 0
    boxPackStart  upbox (widget x) PackGrow 0
    widgetShowAll upbox

    choice <- dialogRun dialog
    case choice of
      ResponseOk -> do saveHistory x; val x >>== Just
      _          -> return Nothing


{-# NOINLINE fmDialog #-}
-- ������ �� ������������ �������� OK/Cancel
fmDialog fm' title action = do
  fm <- val fm'
  title <- i18n title
  bracketCtrlBreak dialogNew widgetDestroy $ \dialog -> do
    set dialog [windowTitle          := title,
                windowTransientFor   := fm_window fm,
                containerBorderWidth := 0]
    dialogAddButton dialog stockOk     ResponseOk      >>= \okButton -> do
    dialogAddButton dialog stockCancel ResponseCancel
    dialogSetDefaultResponse dialog ResponseOk
    tooltips =:: tooltipsNew
    action (dialog,okButton)


----------------------------------------------------------------------------------------------------
---- ������ ������ � ������ ------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

createFilePanel = do
  -- Scrolled window where this list will be put
  scrwin <- scrolledWindowNew Nothing Nothing
  scrolledWindowSetPolicy scrwin PolicyAutomatic PolicyAutomatic
  -- Create a new ListView
  view  <- New.treeViewNew
  set view [ {-New.treeViewSearchColumn := 0, -} New.treeViewRulesHint := True]
  New.treeViewSetHeadersVisible view True
  -- ������ � ������������� ������
  model <- New.listStoreNew []
  set view [New.treeViewModel := model]
  -- ������ ������� ��� � �����������.
  let columnTitles = ["0015 Name", "0016 Size", "0017 Modified", "0018 DIRECTORY"]
      n = map (drop 5) columnTitles
  s <- i18ns columnTitles
  onColumnTitleClicked <- ref doNothing
  columns <- sequence [
     addColumn view model onColumnTitleClicked (n!!0) (s!!0) fmname                                                       []
    ,addColumn view model onColumnTitleClicked (n!!1) (s!!1) (\fd -> if (fdIsDir fd) then (s!!3) else (show3$ fdSize fd)) [cellXAlign := 1]
    ,addColumn view model onColumnTitleClicked (n!!2) (s!!2) (formatDateTime.fdTime)                                      [] ]
  -- �������� ����� �� ������ �������
  -- treeViewSetSearchColumn treeViewSetSearchEqualFunc treeViewSetEnableSearch
  -- Enable multiple selection
  selection <- New.treeViewGetSelection view
  set selection [New.treeSelectionMode := SelectionMultiple]
  -- Pack list into scrolled window and return window
  containerAdd scrwin view
  return (scrwin, view, model, selection, showOrder columns, onColumnTitleClicked)

-- |������ ����� ������ ������������ ������
changeList model filelist = do
  -- ������� ������ ������ �� ������ � ��������� � ������
  New.listStoreClear model
  for filelist (New.listStoreAppend model)

-- |�������� �� view �������, ������������ field, � ���������� title
addColumn view model onColumnTitleClicked colname title field attrs = do
  col1 <- New.treeViewColumnNew
  New.treeViewColumnSetTitle col1 title
  renderer1 <- New.cellRendererTextNew
  New.cellLayoutPackStart col1 renderer1 True
  -- ������� ������� ���� ����� ������������� ��������������� ��� ���������� ���� ���������
  -- (bool New.cellLayoutPackStart New.cellLayoutPackEnd expand) col1 renderer1 expand
  -- set col1 [New.treeViewColumnSizing := TreeViewColumnAutosize] `on` expand
  -- set col1 [New.treeViewColumnSizing := TreeViewColumnFixed] `on` not expand
  set col1 [ New.treeViewColumnResizable   := True
           , New.treeViewColumnClickable   := True
           , New.treeViewColumnReorderable := True]
  -- ��� ������� �� ��������� ������� ������� ������
  col1 `New.onColClicked` do
    val onColumnTitleClicked >>= ($colname)
  New.cellLayoutSetAttributes col1 renderer1 model $ \row -> [New.cellText := field row] ++ attrs
  New.treeViewAppendColumn view col1
  return (colname,col1)

-- |�������� ��������� ���������� ��� �������� colname � ����������� order
showOrder columns colname order = do
  for (map snd columns) (`New.treeViewColumnSetSortIndicator` False)
  let Just col1  =  colname `lookup` columns
  New.treeViewColumnSetSortIndicator col1 True
  New.treeViewColumnSetSortOrder     col1 order

