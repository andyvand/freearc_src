#include <stdio.h>
#include <sys/stat.h>
#include <utime.h>
#include <limits.h>
#include <memory.h>
#include "Environment.h"
#include "Compression/Compression.h"

#ifdef FREEARC_WIN

#include <shlobj.h>
#include <commdlg.h>

static int CALLBACK BrowseCallbackProc(HWND hwnd, UINT uMsg, LPARAM lParam, LPARAM lpData)
{
  if(uMsg == BFFM_INITIALIZED)
    PostMessage(hwnd, BFFM_SETSELECTION, TRUE, lpData);

  return 0;
}

// ���� ������������ ������� �������
int BrowseForFolder(TCHAR *prompt, TCHAR *in_filename, TCHAR *out_filename)
{
  BROWSEINFO bi;
  bi.hwndOwner = GetActiveWindow();
  bi.lParam = (LONG)in_filename;
  bi.lpszTitle = prompt;
  bi.lpfn = BrowseCallbackProc;
  bi.pidlRoot = NULL;
  bi.pszDisplayName = out_filename;
  bi.ulFlags = BIF_RETURNONLYFSDIRS;

  LPITEMIDLIST pItemIdList = SHBrowseForFolder(&bi);

  int result = 0;
  if(pItemIdList != NULL)
  {
    if (SHGetPathFromIDList(pItemIdList, out_filename))
      result = 1;

    IMalloc *iMalloc = 0;
    if(SUCCEEDED(SHGetMalloc(&iMalloc)))
    {
      iMalloc->Free(pItemIdList);
      iMalloc->Release();
    }
  }
  return result;
}


// ���� ������������ ������� ����
int BrowseForFile(TCHAR *prompt, TCHAR *in_filename, TCHAR *out_filename)
{
  OPENFILENAME ofn;
  ZeroMemory (&ofn, sizeof(ofn));
  ofn.lStructSize = sizeof(ofn);
  ofn.hwndOwner   = GetActiveWindow();
  ofn.lpstrFile   = out_filename;
  ofn.nMaxFile    = MY_FILENAME_MAX;

  _tcscpy (out_filename, in_filename);

  return GetOpenFileName(&ofn)? 1 : 0;
}

// ���������� �����/���� ����� � ������ � ������������ � ����������� locale ��� ��������� ��������� ������� � ����
void GuiFormatDateTime (time_t t, char *buf, int bufsize, char *date_format, char *time_format)
{
  if (t==-1)  t=0;  // ����� ������� ����� :(

  FILETIME ft1, ft2;
  UnixTimeToFileTime (t, &ft1);
  FileTimeToLocalFileTime (&ft1, &ft2);
  SYSTEMTIME datetime;
  FileTimeToSystemTime (&ft2, &datetime);

  GetDateFormatA(LOCALE_USER_DEFAULT, 0, &datetime, date_format, buf, bufsize);
  char *p = str_end(buf);
  *p++ = ' ';
  GetTimeFormatA(LOCALE_USER_DEFAULT, 0, &datetime, time_format, p, bufsize - (p-buf));
}

#endif // Windows/Unix

