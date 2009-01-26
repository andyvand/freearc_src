{-# OPTIONS_GHC -cpp #-}
---------------------------------------------------------------------------------------------------
---- ����������� ������/�������������� � ������ ��������� � ���. ----------------------------------
---------------------------------------------------------------------------------------------------
module Errors where

import Prelude hiding (catch)
import Control.Concurrent
import Control.Exception
import Control.Monad
import Data.Char
import Data.Maybe
import Data.IORef
import System.Exit
import System.IO
import System.IO.Unsafe
#if defined(FREEARC_WIN)
import GHC.ConsoleHandler
#else
import System.Posix.Signals
#endif

import CompressionLib   (compressionLib_cleanup)
import Utils
import Files
import Charsets

-- |���� �������� ���������
aEXIT_CODE_SUCCESS      = 0
aEXIT_CODE_WARNINGS     = 1
aEXIT_CODE_FATAL_ERROR  = 2
aEXIT_CODE_BAD_PASSWORD = 21
aEXIT_CODE_USER_BREAK   = 255

-- |��� ��������� ���� ������ � ��������������
data ErrorTypes = GENERAL_ERROR               String
                | CMDLINE_NO_COMMAND          [String]
                | CMDLINE_NO_ARCSPEC          [String]
                | CMDLINE_NO_FILENAMES        [String]
                | UNKNOWN_CMD                 String [String]
                | CMDLINE_UNKNOWN_OPTION      String
                | CMDLINE_AMBIGUOUS_OPTION    String [String]
                | CMDLINE_BAD_OPTION_FORMAT   String
                | INVALID_OPTION_VALUE        String String [String]
                | CMDLINE_GENERAL             String
                | CANT_READ_DIRECTORY         String
                | CANT_GET_FILEINFO           String
                | CANT_OPEN_FILE              String
                | BAD_CRC                     String
                | BAD_CFG_SECTION             String [String]
                | OP_TERMINATED
                | TERMINATED
                | NOFILES
                | SKIPPED_FAKE_FILES          Int
                | BROKEN_ARCHIVE              FilePath String
                | INTERNAL_ERROR              String
                | COMPRESSION_ERROR           String
                | BAD_PASSWORD                FilePath FilePath

--foreign import "&errCounter" :: Ptr Int
{-
data SqliteException = SqliteException Int String
  deriving (Typeable)

catchSqlite :: IO a -> (SqliteException -> IO a) -> IO a
catchSqlite = catchDyn

throwSqlite :: SqliteException -> a
throwSqlite = throwDyn
-}

---------------------------------------------------------------------------------------------------
---- ��������� Ctrl-Break, Close � �.�. ������� ������� -------------------------------------------
---------------------------------------------------------------------------------------------------

setCtrlBreakHandler action = do
  --myThread <- myThreadId
  -- ��� ������ ��� ������������� ���������� ����������� ���������� ���������� �������
#if defined(FREEARC_WIN)
  bracket (installHandler$ Catch onBreak) (installHandler) $  \oldHandler -> do
    action
#else
  let catchSignals a  =  installHandler sigINT (CatchOnce$ onBreak undefined) Nothing
  bracket (catchSignals (CatchOnce$ onBreak (error "onBreak"))) (catchSignals) $  \oldHandler -> do
    action
#endif

-- |������� fail, ���� ���������� ���� ���������� ���������� ���������
failOnTerminated = do
  whenM (val programTerminated) $ do
    -- unlessM (val fileManagerMode) $ do
      fail$ errormsg TERMINATED

-- |��������� Ctrl-Break �������� � ���������� ������������� �
-- ��������� ����. �����, ������� ����������� ����������, ����������� �� ��
onBreak event = terminateOperation
terminateOperation = do
  programTerminated =: True
  isFM <- val fileManagerMode
  registerError$ iif isFM OP_TERMINATED TERMINATED

shutdown msg_ exitCode_ = do
  programTerminated' <- val programTerminated
  let (msg, exitCode)  | programTerminated'  =  (errormsg TERMINATED, aEXIT_CODE_USER_BREAK)
                       | otherwise           =  (msg_, exitCode_)
  separator' =: ("","\n")
  log_separator' =: "\n"
  fin <- val finalizers
  mapM_ (ignoreErrors.snd) fin
  compressionLib_cleanup

  w <- val warnings
  case w of
    0 -> when (exitCode==aEXIT_CODE_SUCCESS) $ condPrintLineLn "k"$ "All OK"
    _ -> condPrintLineLn "n"$ "There were "++show w++" warning(s)"
  ignoreErrors (msg &&& condPrintLineLn "n" msg)
  condPrintLineLn "e" ""
#if !defined(FREEARC_WIN) && !defined(FREEARC_GUI)
  putStrLn ""  -- � Unix ����������� �������������� ������� ������ � ��������� �� ���������� ���������
#endif
  ignoreErrors$ closeLogFile
  ignoreErrors$ hFlush stdout
  ignoreErrors$ hFlush stderr
  --killThread myThread
  exit (exitCode  |||  (w &&& aEXIT_CODE_WARNINGS))
#if 0
  -- ����� ���������� ������ ���������� ���������, � ��������� arc.exe � ��� ������ ������
  exitWith$ case () of
   _ | exitCode>0 -> ExitFailure exitCode
     | w>0        -> ExitFailure aEXIT_CODE_WARNINGS
     | otherwise  -> ExitSuccess
#endif
  return undefined

-- |"bracket" � ����������� "close" ����� ��� ^Break
bracketCtrlBreak init close action = do
  id <- newId
  bracket (do x<-init; addFinalizer id (close x); return x)
          (\x -> do removeFinalizer id; close x)
          action

-- |bracketCtrlBreak, ����������� fail ��� �������� Nothing �� init
bracketCtrlBreakMaybe init fail close action = do
  bracketCtrlBreak (do x<-init; when (isNothing x) fail; return x)
                   (`whenJust_` close)
                   (`whenJust`  action)

-- |��������� close-�������� �� ���������� action
ensureCtrlBreak close action  =  bracketCtrlBreak (return ()) (\_->close) (\_->action)

-- |"handle" � ����������� "onException" ����� ��� ^Break
handleCtrlBreak onException action = do
  id <- newId
  handle (\e -> do onException; throwIO e) $ do
    bracket_ (addFinalizer id onException)
             (failOnTerminated >> removeFinalizer id)
             (action)

-- ��������/������� finalizer � ������
addFinalizer id action  =  finalizers .= ((id,action):)
removeFinalizer id      =  finalizers .= filter ((/=id).fst)
newId                   =  do curId+=1; id<-val curId; return id

-- |���������� �����
curId :: IORef Int
curId = unsafePerformIO (ref 0)
{-# NOINLINE curId #-}

-- |������ ��������, ������� ���� ��������� ����� ������� �� ^Break
finalizers :: IORef [(Int, IO ())]
finalizers = unsafePerformIO (ref [])
{-# NOINLINE finalizers #-}

-- |���� ���� ��������������� ����� ����, ��� ������������ ����� Ctrl-Break
programTerminated = unsafePerformIO (ref False)
{-# NOINLINE programTerminated #-}

-- |����� ������ ����-���������: ��� ���� terminateOperation �������������� ��-������� - �� ���������� ���������� ���� ������ �������� � ����������
fileManagerMode = unsafePerformIO (ref False)
{-# NOINLINE fileManagerMode #-}


---------------------------------------------------------------------------------------------------
---- ������ ��������� � ��������� ����� ������. ���������� ������ ��� �������������� --------------
---------------------------------------------------------------------------------------------------

errormsg (GENERAL_ERROR str) =
  str

errormsg (UNKNOWN_CMD cmd known_cmds) =
  "command "++quote cmd++" is unknown. Supported commands are:\n" ++ joinWith ", " known_cmds

errormsg (CMDLINE_UNKNOWN_OPTION option) =
  "unknown option " ++ quote option

errormsg (CMDLINE_GENERAL option) =
  option

errormsg (CMDLINE_AMBIGUOUS_OPTION option variants) =
  "ambiguous option " ++ quote option ++ ": is that "++enumerate "or" variants++"?"

errormsg (CMDLINE_BAD_OPTION_FORMAT option) =
  "option " ++ quote option ++ " have illegal format"

errormsg (INVALID_OPTION_VALUE fullname shortname valid_values) =
  fullname++" option must be one of: "++ enumerate "or" (map (('-':shortname)++) valid_values)

errormsg (CMDLINE_NO_COMMAND args) =
  "no command name in command: " ++ quote (unwords args)

errormsg (CMDLINE_NO_ARCSPEC args) =
  "no archive name in command: " ++ quote (unwords args)

errormsg (CMDLINE_NO_FILENAMES args) =
  "no filenames in command: " ++ quote (unwords args)

errormsg (CANT_READ_DIRECTORY dir) =
  "error while reading directory " ++ quote dir

errormsg (CANT_GET_FILEINFO filename) =
  "can't get info about file " ++ quote filename

errormsg (CANT_OPEN_FILE filename) =
  "can't open file " ++ quote filename

errormsg (BAD_CRC filename) =
  "CRC error in " ++ filename

errormsg (BAD_CFG_SECTION cfgfile section) =
  "Bad section " ++ head section ++ " in "++cfgfile

errormsg (OP_TERMINATED) =
  "Operation terminated!"

errormsg (TERMINATED) =
  "Program terminated!"

errormsg (NOFILES) =
  "No files, erasing empty archive"

errormsg (SKIPPED_FAKE_FILES n) =
  "skipped "++show n++" fake files"

errormsg (BROKEN_ARCHIVE arcname msg) =
  "Archive "++arcname++" corrupt: "++msg++
  ". Please recover it using 'r' command or use -tp- switch to ignore Recovery Record"

errormsg (INTERNAL_ERROR msg) =
  "FreeArc internal error: "++msg

errormsg (COMPRESSION_ERROR msg) = msg

errormsg (BAD_PASSWORD archive "")   = "Bad password for archive "++archive
errormsg (BAD_PASSWORD archive file) = "Bad password for "++file++" in archive "++archive


-- |����������� ������ ��������
enumerate s list  =  joinWith2 ", " (" "++s++" ") (map quote list)

{-# NOINLINE errormsg #-}


----------------------------------------------------------------------------------------------------
---- ���� ������ ��� ��������� ������ --------------------------------------------------------------
----------------------------------------------------------------------------------------------------

errcode BAD_PASSWORD{} = aEXIT_CODE_BAD_PASSWORD
errcode _              = aEXIT_CODE_FATAL_ERROR


----------------------------------------------------------------------------------------------------
---- ����/����� �� ����� � ���������, �������� ������ -sct -----------------------------------------
----------------------------------------------------------------------------------------------------

#ifdef FREEARC_GUI
myPutStr      = doNothing
myPutStrLn    = doNothing
myFlushStdout = doNothing0
#else
myGetLine     = getLine >>= terminal2str
myPutStr      = putStr   =<<. str2terminal
myPutStrLn    = putStrLn =<<. str2terminal
myFlushStdout = hFlush stdout
#endif


----------------------------------------------------------------------------------------------------
---- ������ � ��������� � ���������� ������� ������ �� ����� � ������������ � ������ --display -----
----------------------------------------------------------------------------------------------------

-- ���������� �������� ������, ������� � ��� ������������� �� ���������� �������/������������� ������
-- ����� ����, ������ ����� ���������� ������ ����������� � ������ �������,
-- ���� ��� ���������� ��������������� ����� ��������� ���������
printLine = printLineC ""
printLineC c str = do
  (oldc,separator) <- val separator'
  let makeLower (x:y:zs) | isLower y  =  toLower x:y:zs
      makeLower xs                    =  xs
  let handle "w" = stderr
      handle _   = stdout
#ifndef FREEARC_GUI
  hPutStr (handle oldc) =<< str2terminal separator
  hPutStr (handle c)    =<< str2terminal ((oldc=="h" &&& makeLower) str)
  hFlush  (handle c)
#endif
  separator' =: (c,"")

-- |���������� ������ � ������������ ����� ����� ��
printLineLn str = do
  printLine str
  printLineNeedSeparator "\n"

-- �������� ����������� ����� �������� �������. �� ������� ��� ������ �����,
-- ��������� �������� ������������ ������ ����� � �� ���� :)))
printLineNeedSeparator str = do
  separator' =: ("",str)

-- �������� ������ � �������.
-- ������� � �� ����� ��� �������, ��� � ����� �� �������� ������ --display
condPrintLine c line = do
  display_option <- val display_option'
  when (c/="$" || (display_option `contains` '#')) $ do
      printLog line
  when (display_option `contains_one_of` c) $ do
      printLineC c line

-- |���������� ������ � ������������ ����� ����� ��
condPrintLineLn c line = do
  condPrintLine c line
  condPrintLineNeedSeparator c "\n"

-- �������� ����������� ����� �������� ������� ��� ������� ���������� ������ ������ c
condPrintLineNeedSeparator c str = do
  display_option <- val display_option'
  when (c/="$" || (display_option `contains` '#')) $ do
      log_separator' =: str
  when (c=="" || (display_option `contains_one_of` c)) $ do
      separator' =: (c,str)

-- ������� �������
openLogFile logfilename = do
  closeLogFile  -- ������� ����������, ���� ���
  logfile <- case logfilename of
                 ""  -> return Nothing
                 log -> fileAppendText log >>== Just
  logfile' =: logfile

-- ������� ������ � �������
printLog line = do
  separator <- val log_separator'
  whenJustM_ (val logfile') $ \log -> do
      fileWrite log =<< str2logfile (separator ++ line); fileFlush log
      log_separator' =: ""

-- ������� �������
closeLogFile = do
  whenJustM_ (val logfile') fileClose
  logfile' =: Nothing

-- ����������, �������� Handle ��������
logfile'        = unsafePerformIO$ newIORef Nothing
-- ����������, ������������ ��� ��������� ������
separator'      = unsafePerformIO$ newIORef ("","") :: IORef (String,String)
log_separator'  = unsafePerformIO$ newIORef "\n"    :: IORef String
display_option' = unsafePerformIO$ newIORef$ error "undefined display_option"

{-# NOINLINE printLine #-}
{-# NOINLINE printLineNeedSeparator #-}
{-# NOINLINE condPrintLine #-}
{-# NOINLINE condPrintLineNeedSeparator #-}
{-# NOINLINE separator' #-}
{-# NOINLINE log_separator' #-}
{-# NOINLINE display_option' #-}

----------------------------------------------------------------------------------------------------
---- ������ ��������� �� ������� � ��������������
----------------------------------------------------------------------------------------------------

-- |������ ��������� �� ������ � ������� � ��������� ���������� ��������� � ���� ����������
registerError err = do
  let msg = errormsg err
  val errorHandlers >>= mapM_ ($msg)
  -- ���� �� � ������ ����-���������, �� ������� ����� ���������� ���� ������ ����������,
  -- ����� - ������ ��������� ��������� ����� �� ���������
  unlessM (val fileManagerMode) $ do
    shutdown ("ERROR: "++msg) (errcode err)
  return undefined

-- |������ �������������� � ������� � ����� ��� �� �����
registerWarning warn = do
  warnings += 1
  let msg = errormsg warn
  val warningHandlers >>= mapM_ ($msg)
  condPrintLineLn "w" ("WARNING: "++msg)

-- |��������� �������� � ���������� ���������� ��������� ��� ���� warning'��
count_warnings action = do
  w0 <- val warnings
  action
  w  <- val warnings
  return (w-w0)

-- |������� ������, ��������� � ���� ������ ���������
warnings = unsafePerformIO$ newIORef 0 :: IORef Int

-- ��������, ����������� ��� ��������� ������/�������������� (�������������� � ������ ������ ���������)
errorHandlers   = unsafePerformIO$ newIORef [] :: IORef [String -> IO ()]
warningHandlers = unsafePerformIO$ newIORef [] :: IORef [String -> IO ()]

{-# NOINLINE registerError #-}
{-# NOINLINE registerWarning #-}
{-# NOINLINE warnings #-}
{-# NOINLINE errorHandlers #-}
{-# NOINLINE warningHandlers #-}

----------------------------------------------------------------------------------------------------
---- ������ � �������
----------------------------------------------------------------------------------------------------

-- |���������� Nothing � ���������� ��������� �� ������, ���� ���� �� ������� �������
tryOpen filename = catchJust ioErrors
                     (fileOpen filename >>== Just)
                     (\e -> do registerWarning$ CANT_OPEN_FILE filename; return Nothing)

-- |����������� ����
fileCopy srcname dstname = do
  bracketCtrlBreak (fileOpen srcname) (fileClose) $ \srcfile -> do
    handleCtrlBreak (ignoreErrors$ fileRemove dstname) $ do
      bracketCtrlBreak (fileCreate dstname) (fileClose) $ \dstfile -> do
        size <- fileGetSize srcfile
        fileCopyBytes srcfile size dstfile


----------------------------------------------------------------------------------------------------
----- External functions ---------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |Stop program execution
foreign import ccall unsafe "stdlib.h exit"
  exit :: Int -> IO ()

