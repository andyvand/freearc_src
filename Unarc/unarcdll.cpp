// ��������� ����� ��� ���������� ������
#undef  ON_CHECK_FAIL
#define ON_CHECK_FAIL()   UnarcQuit()
void UnarcQuit();

// ������ � ��������� ������
#include "ArcStructure.h"

#include "../Compression/MultiThreading.h"
#include "unarcdll.h"

// ������ � �������� ��������� ������ � ���������� �������� ��� �������
#include "ArcCommand.h"
#include "ArcProcess.h"

// ���������� ����� �� ��������� � ������ ������
void UnarcQuit()
{
  CurrentProcess->quit();
}


/******************************************************************************
** �������� ���������� � ����������, ������������ DLL *************************
******************************************************************************/
class DLLUI : public BASEUI
{
private:
  char outdir[MY_FILENAME_MAX*4];  //unicode: utf-8 encoding
  uint64 totalBytes;
public:
  Mutex mutex;
  Event DoEvent, EventDone;

  char *what; int int1, int2, result; char *str;
  bool event (char *_what, int _int1, int _int2, char *_str);

  bool AllowProcessing (char cmd, int silent, FILENAME arcname, char* comment, int cmtsize, FILENAME outdir);
  FILENAME GetOutDir ();
  void BeginProgress (uint64 totalBytes);
  bool ProgressRead  (uint64 readBytes);
  bool ProgressWrite (uint64 writtenBytes);
  bool ProgressFile  (bool isdir, const char *operation, FILENAME filename, uint64 filesize);
  char AskOverwrite  (FILENAME filename, uint64 size, time_t modified);
  void Abort         (COMMAND *cmd);
} UI;


/******************************************************************************
** ���������� ���������� � ����������, ������������ DLL ***********************
******************************************************************************/
bool DLLUI::event (char *_what, int _int1, int _int2, char *_str)
{
  Lock _(mutex);
  what = _what;
  int1 = _int1;
  int2 = _int2;
  str  = _str;

  DoEvent.Signal();
  EventDone.Lock();
  return result>=0;
}

void DLLUI::BeginProgress (uint64 totalBytes)
{
  this->totalBytes = totalBytes;
}

bool DLLUI::ProgressRead (uint64 readBytes)
{
  return event ("progress", readBytes>>20, totalBytes>>20, "");
}

bool DLLUI::ProgressWrite (uint64 writtenBytes)
{
  return event ("written", writtenBytes>>20, 0, "");
}

bool DLLUI::ProgressFile (bool isdir, const char *operation, FILENAME filename, uint64 filesize)
{
  return event ("filename", 0, 0, filename);
}

FILENAME DLLUI::GetOutDir()
{
  return outdir;
}

bool DLLUI::AllowProcessing (char cmd, int silent, FILENAME arcname, char* comment, int cmtsize, FILENAME _outdir)
{
  strcpy (outdir, _outdir);
  return TRUE;
}

char DLLUI::AskOverwrite (FILENAME filename, uint64 size, time_t modified)
{
  return 'n';
}

void DLLUI::Abort (COMMAND *cmd)
{
  event ("quit", 0, 0, "");
}


/******************************************************************************
** ���������� ����������� DLL *************************************************
******************************************************************************/
static DWORD WINAPI timer_thread (void *)
{
  for(;;)
  {
    Sleep(10);
    UI.event ("timer", 0, 0, "");
  }
}

static DWORD WINAPI decompress_thread (void *paramPtr)
{
  COMMAND *command = (COMMAND*) paramPtr;
  PROCESS (*command, UI);      //   ��������� ����������� �������
  UI.what = "quit";
  UI.DoEvent.Signal();
  return 0;
}

int __cdecl FreeArcExtract (cbtype *callback, ...)
{
  va_list argptr;
  va_start(argptr, callback);

  int argc=0;
  char *argv[1000] = {"c:\\unarc.dll"};  //// ����� ����� �������� arc.ini!

  for (int i=1; i<1000; i++)
  {
    argc = i;
    argv[i] = va_arg(argptr, char*);
    if (argv[i]==NULL || argv[i][0]==0)
      {argv[i]=NULL; break;}
  }
  va_end(argptr);




  COMMAND command (argc, argv);    // ���������� �������
  if (command.ok) {                // ���� ������� ��� ������ � ����� ��������� �������
    CThread thread;
    thread.Create (timer_thread,      &command);   //   ����. ����, ���������� callback 100 ��� � �������
    thread.Create (decompress_thread, &command);   //   ��������� ����������� �������

    for(;;)
    {
      UI.DoEvent.Lock();
      if (strequ (UI.what, "quit"))
        {return command.ok? FREEARC_OK : FREEARC_ERRCODE_GENERAL;}
      UI.result = callback (UI.what, UI.int1, UI.int2, UI.str);
      UI.EventDone.Signal();
    }
    thread.Wait();
  }
  return command.ok? FREEARC_OK : FREEARC_ERRCODE_GENERAL;
}

