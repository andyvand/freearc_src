// to do: ����� ������ �� ������ ("name" ��� "dir/name"),
//        ������������ ������/���������
//        ���������� ".arc", listfiles/-ap/-kb

// ������ � ��������� ������, �������� ��������� ������ � ���������� �������� ��� �������
#include "ArcStructure.h"
#include "ArcCommand.h"
#include "ArcProcess.h"

// ���� ������ � ������������� ������ � ������� �������, ���������� �����
#ifdef FREEARC_GUI
#include "gui\gui.h"
#include "gui\gui.cpp"
GUI UI;
#else
#include "CUI.h"
#endif


/******************************************************************************
** �������� ��������� *********************************************************
******************************************************************************/

#ifdef FREEARC_INSTALLER
// Wipes entire directory with all its subdirs
void wipedir(TCHAR *dir)
{
    // List all entries in this directory
    CFILENAME dirstar  = (TCHAR*) malloc (MY_FILENAME_MAX * sizeof(TCHAR));
    CFILENAME fullname = (TCHAR*) malloc (MY_FILENAME_MAX * sizeof(TCHAR));
    _stprintf (dirstar, _T("%s%s*"), dir, _T(STR_PATH_DELIMITER));
    WIN32_FIND_DATA FindData[1];
    HANDLE h = FindFirstFile (dirstar, FindData);
    if (h) do {
        // For every entry except for "." and "..", remove entire subdir (if it's a directory) or remove just file itself
        if (_tcscmp(FindData->cFileName,_T("."))  &&  _tcscmp(FindData->cFileName,_T("..")))
        {
            _stprintf (fullname, _T("%s%s%s"), dir, _T(STR_PATH_DELIMITER), FindData->cFileName);
            if (FindData->dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
                wipedir (fullname);
            else
                DeleteFile (fullname);
        }
    } while (FindNextFile(h,FindData));
    FindClose(h);
    RemoveDirectory (dir);
    free(fullname); free(dirstar);
}
#endif

// Run setup.exe after unpacking
void RunSetup (COMMAND &command)
{
#ifdef FREEARC_INSTALLER
  if (command.runme)
  {
      CFILENAME tmp  = (TCHAR*) malloc (MY_FILENAME_MAX * 4);
      CFILENAME tmp2 = (TCHAR*) malloc (MY_FILENAME_MAX * 4);

      // Execute command.runme in the directory command.outpath
      RunProgram (utf8_to_utf16 (command.runme, tmp), utf8_to_utf16 (command.outpath, tmp2), command.wipeoutdir);

      // Wipe outdir after installation was completed
      if (command.wipeoutdir)
          wipedir (utf8_to_utf16 (command.outpath, tmp));

      free(tmp); free(tmp2);
  }
#endif
}

int main (int argc, char *argv[])
{
  UI.DisplayHeader (HEADER1 NAME);
  COMMAND command (argc, argv);    // ���������� �������
  if (command.ok)                  // ���� ������� ��� ������ � ����� ��������� �������
    PROCESS (command, UI),         //   ��������� ����������� �������
    RunSetup (command);            //   ��������� setup.exe ��� �����������
  printf ("\n");
  return command.ok? EXIT_SUCCESS : FREEARC_EXIT_ERROR;
}

