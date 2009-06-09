// to do: ����� ������ �� ������ ("name" ��� "dir/name"),
//        ������������ ������/���������
//        ���������� ".arc", listfiles/-ap/-kb
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#include <wchar.h>

// SFX module is just unarc.cpp compiled with FREEARC_SFX defined
#ifdef FREEARC_SFX
#define NAME           "SFX"
#else
#define NAME           "unpacker"
#endif

#define HEADER1        "FreeArc 0.52 "
#define HEADER2        "  http://freearc.org  2009-05-31\n"

// ������ � ��������� ������
#include "ArcStructure.h"

// External compressors support
extern "C" {
#include "../Compression/External/C_External.h"
}

// ���� ������ � ������������� ������ � ������� �������, ���������� �����
#ifdef FREEARC_GUI
#include "gui\gui.h"
#include "gui\gui.cpp"
#elif defined(FREEARC_LIBRARY)
#include "LibUI.h"
#else
#include "CUI.h"
#endif
UI UI;


#ifdef FREEARC_INSTALLER
// Wipes entire directory with all its subdirs
void wipedir(TCHAR *dir)
{
    // List all entries in this directory
    CFILENAME dirstar  = (TCHAR*) malloc (MY_FILENAME_MAX * sizeof(TCHAR));
    CFILENAME fullname = (TCHAR*) malloc (MY_FILENAME_MAX * sizeof(TCHAR));
    _stprintf (dirstar, _T("%s%s*"), dir, _T(STR_PATH_DELIMITER));
    WIN32_FIND_DATA FindData[1];
    HANDLE h = FindFirstFileW (dirstar, FindData);
    if (h) do {
        // For every entry except for "." and ".., remove entire subdir (if it's a directory) or remove just file itself
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

// Register external compressors declared in arc.ini
void RegisterExternalCompressors (char *progname)
{
#ifndef FREEARC_TINY
  // Open config file arc.ini found in the same dir as sfx/unarc
  char *cfgfile = "arc.ini";
  char *name = (char*) malloc (strlen(progname) + strlen(cfgfile));
                                                 if (!name)  return;
  strcpy(name, progname);
  strcpy(drop_dirname(name), cfgfile);
  MYFILE f(name);
  if (!f.tryOpen(READ_MODE))                     return;

  // Read config file into memory
  FILESIZE size = f.size();                      if (!size)  return;
  char *contents = (char*) malloc(size+2);       if (!contents)  return;
  *contents = '\n';
  size = f.tryRead(contents+1, size);            if (size<0)  return;
  contents[size] = '\0';

  // Register each external compressor found in config file
  char *ANY_HEADING = "\n[", *EXT_HEADING = "[External compressor:";
  ClearExternalCompressorsTable();
  for (char *p, *section = strstr(contents, ANY_HEADING);  section != NULL;  section = p)
  {
    section++;
    p = strstr(section, ANY_HEADING);
    if (p)  *p = '\0';
    if (start_with(section,EXT_HEADING)  &&  AddExternalCompressor(section) != 1)
    {
      //printf("Error in config file %s section:\n%s\n", cfgfile, section);
    }
  }

  free(contents);
  f.close();
#endif
}

/******************************************************************************
** ���������� � ����������� ������������� ������� *****************************
******************************************************************************/
class COMMAND
{
public:
  char cmd;             // ����������� �������
  FILENAME arcname;     // ��� ��������������� �������� ������
  FILENAME *filenames;  // ����� �������������� �������� ������ �� ������
  FILENAME outpath;     // ����� -dp
  FILENAME runme;       // ����, ����������� ����� ����������
  BOOL wipeoutdir;      // ������� ����� �� outpath ����� ���������� ������ runme?
  BOOL tempdir;         // �� ��������� ����� �� ��������� �������?
  BOOL ok;              // ������� ����������� �������?
  int  silent;          // ����� -s
  BOOL yes;             // ����� -o+
  BOOL no;              // ����� -o-
  BOOL noarcext;        // ����� --noarcext
  BOOL nooptions;       // ����� --

  bool list_cmd()  {return cmd=='l' || cmd=='v';}   // True, ���� ��� ������� ��������� �������� ������

  // ������ ��������� ������
  COMMAND (int argc, char *argv[])
  {
#if defined(FREEARC_WIN) && !defined(FREEARC_LIBRARY)
    // Instead of those ANSI-codepage encoded argv[] strings provide true UTF-8 data!
    WCHAR **argv_w = CommandLineToArgvW (GetCommandLineW(), &argc);
    argv_w[0] = (WCHAR*) malloc (MY_FILENAME_MAX * 4);
    GetExeName (argv_w[0], MY_FILENAME_MAX * 2);

    argv = (char**) malloc ((argc+1) * sizeof(*argv));
    for (int i=0; i<argc; i++)
    {
      argv[i] = (char*) malloc (_tcslen (argv_w[i]) * 4 + 1);
      utf16_to_utf8 (argv_w[i], argv[i]);
      argv[i] = (char*) realloc (argv[i], strlen(argv[i]) + 1);
    }
    argv[argc] = NULL;
    free (argv_w[0]);
#endif
    // Register external compressors using arc.ini in the same dir as argv[0]
    RegisterExternalCompressors(argv[0]);

    // Default options
    noarcext  = FALSE;
    nooptions = FALSE;
    outpath = "";
    runme = NULL;
    wipeoutdir = FALSE;
    tempdir = FALSE;
    yes = FALSE;
    no  = FALSE;
    silent = 0;
#ifdef FREEARC_SFX
    arcname = argv[0];
    cmd     = 'x';

#ifdef FREEARC_INSTALLER
    // Installer by default extracts itself into some temp directory, runs setup.exe and then remove directory's contents
    if (argv[1] == NULL)
    {
        silent = 2;

        // Get TEMP path and convert it into UTF-8
        CFILENAME TempPathW = (TCHAR*)   malloc (MY_FILENAME_MAX * 4);
         FILENAME TempPath  = (FILENAME) malloc (MY_FILENAME_MAX * 4);
        GetTempPathW(MY_FILENAME_MAX, TempPathW);
        utf16_to_utf8 (TempPathW, TempPath);

        // Create unique tempdir
        tempdir = TRUE;
        outpath = (FILENAME) malloc (MY_FILENAME_MAX * 4);
        for (unsigned i = (unsigned) GetTickCount(), cnt=0; ; cnt++)
        {
            i = i*54322457 + 137;
            sprintf (outpath, "%s%s%u", TempPath, "installer", i);
            utf8_to_utf16 (outpath, TempPathW);
            if (_wmkdir(TempPathW) == 0)   break;  // Break on success

            if (cnt>1000) {
#ifdef FREEARC_GUI
              MessageBoxW (NULL, _T("Error creating temporary directory"), _T("Extraction impossible"), MB_OK | MB_ICONERROR);
#else
              printf("Error creating temporary directory");
#endif
              ok = false;
              return;
            }
        }
        free(TempPathW);

        // Run setup.exe from this dir
        runme   = (FILENAME) malloc (MY_FILENAME_MAX * 4);
        sprintf (runme, "%s%s%s", outpath, STR_PATH_DELIMITER, "setup.exe");

        // Delete extracted files afterwards
        wipeoutdir = TRUE;
    }
#endif

    // Parse options
    for (ok=TRUE; ok && *++argv; )
    {
      if (argv[0][0]=='-' || strequ(argv[0],"/?") || strequ(argv[0],"/help"))
      {
             if (strequ(argv[0],"-l"))       cmd = 'l', silent = silent || 2;
        else if (strequ(argv[0],"-v"))       cmd = 'v', silent = silent || 2;
        else if (strequ(argv[0],"-e"))       cmd = 'e', silent = silent || 2;
        else if (strequ(argv[0],"-x"))       cmd = 'x', silent = silent || 2;
        else if (strequ(argv[0],"-t"))       cmd = 't', silent = silent || 2;
        else if (strequ(argv[0],"-y"))       yes = TRUE;
        else if (strequ(argv[0],"-n"))       no  = TRUE;
        else if (start_with(argv[0],"-d"))   outpath = argv[0]+2;
        else if (strequ(argv[0],"-s"))       silent = 1;
        else if (strequ(argv[0],"-s0"))      silent = 0;
        else if (strequ(argv[0],"-s1"))      silent = 1;
        else if (strequ(argv[0],"-s2"))      silent = 2;
        else if (strequ(argv[0],"--"))       nooptions=TRUE;
        else ok=FALSE;
      }
      else break;
    }

    filenames = argv;            // the rest of arguments are filenames
    if (ok)  return;

    // Display help
    char *helpMsg = (char*) malloc(1000+strlen(arcname));
    sprintf (helpMsg,
#ifdef FREEARC_GUI
           HEADER1 NAME HEADER2
#else
           HEADER2
#endif
           "Usage: %s [options] [filenames...]\n"
           "Available options:\n"
#ifndef FREEARC_GUI
           "  -l       - display archive listing\n"
           "  -v       - display verbose archive listing\n"
#endif
           "  -x       - extract files\n"
           "  -e       - extract files without pathnames\n"
           "  -t       - test archive integrity\n"
           "  -d{Path} - set destination path\n"
           "  -y       - answer Yes on all overwrite queries\n"
           "  -n       - answer No  on all overwrite queries\n"
           "  -s[1,2]  - silent mode\n"
           "  --       - no more options\n"
           , drop_dirname(arcname));
#ifdef FREEARC_GUI
    MessageBoxW (NULL, MYFILE(helpMsg).displayname(), _T("Command-line help"), MB_OK | MB_ICONERROR);
#else
    printf("%s", MYFILE(helpMsg).displayname());
#endif

#else
    cmd     = ' ';
    arcname = NULL;
    for (ok=TRUE; ok && *++argv; )
    {
      if (argv[0][0]=='-')
      {
        if (strequ(argv[0],"--noarcext"))    noarcext =TRUE;
        else if (strequ(argv[0],"-o+"))      yes      =TRUE;
        else if (strequ(argv[0],"-o-"))      no       =TRUE;
        else if (start_with(argv[0],"-dp"))  outpath = argv[0]+3;
        else if (strequ(argv[0],"--"))       nooptions=TRUE;
        else ok=FALSE;
      }
      else if (cmd==' ')   cmd = argv[0][0], ok = ok && strlen(argv[0])==1;
      else if (!arcname)   arcname = argv[0];
      else break;
    }

    filenames = argv;            // the rest of arguments are filenames
    ok = ok && strchr("lvtex",cmd) && arcname;
    if (ok)  return;
    printf(HEADER2
           "Usage: unarc command [options] archive[.arc] [filenames...]\n"
           "Available commands:\n"
           "  l - display archive listing\n"
           "  v - display verbose archive listing\n"
           "  e - extract files into current directory\n"
           "  x - extract files with pathnames\n"
           "  t - test archive integrity\n"
           "Available options:\n"
           "  -dp{Path}   - set destination path\n"
           "  -o+         - overwrite existing files\n"
           "  -o-         - don't overwrite existing files\n"
           "  --noarcext  - don't add default extension to archive name\n"
           "  --          - no more options\n");
#endif
  }

  // TRUE, ���� i-� ���� �������� dirblock ������� �������� � ���������
  BOOL accept_file (DIRECTORY_BLOCK *dirblock, int i)
  {
    if (!*filenames)  return TRUE;            // � ��������� ������ �� ������� �� ������ ����� ����� - ������, ����� ������������ ����� ����
    for (FILENAME *f=filenames; *f; f++) {
      if (strequ (dirblock->name[i], *f))
        return TRUE;                          // �! �������!
    }
    return FALSE;                             // ������������ ����� �� �������
  }
};


/******************************************************************************
** ���������� ������� ��������� �������� ������ *******************************
******************************************************************************/
#ifdef FREEARC_GUI
void ListHeader (COMMAND &) {}
void ListFooter (COMMAND &) {}
void ListFiles (DIRECTORY_BLOCK *, COMMAND &) {}
#else

uint64 total_files, total_bytes, total_packed;

void ListHeader (COMMAND &command)
{
  if (command.cmd=='l')
      printf ("Date/time                  Size Filename\n"
              "----------------------------------------\n");
  else
      printf ("Date/time              Attr            Size          Packed      CRC Filename\n"
              "-----------------------------------------------------------------------------\n");
  total_files=total_bytes=total_packed=0;
}

void ListFooter (COMMAND &command)
{
  if (command.cmd=='l')
      printf ("----------------------------------------\n");
  else
      printf ("-----------------------------------------------------------------------------\n");
  printf ("%.0lf files, %.0lf bytes, %.0lf compressed", double(total_files), double(total_bytes), double(total_packed));
}

void ListFiles (DIRECTORY_BLOCK *dirblock, COMMAND &command)
{
  int  b=0;                // current_data_block
  bool Encrypted = FALSE;  // ������� �����-���� ����������?
  uint64 packed=0;
  iterate_var (i, dirblock->total_files) {
    // �������� ����� �����-����� ���� �� ����� �� ��������� ������������� ��� ����
    if (i >= dirblock->block_end(b))
      b++;
    // ���� ��� ������ ���� � �����-����� - ������ block-related ����������
    if (i == dirblock->block_start(b))
    { // ������� �� ������ ���� � ����� ���� ��� ����������� ������
      packed = dirblock->data_block[b].compsize;
      // �������� ���������� � �����-����� ��� ������������� � �� ����� ������� �� ����� �����-�����
      char *c = dirblock->data_block[b].compressor;
      Encrypted = strstr (c, "+aes-")!=NULL || strstr (c, "+serpent-")!=NULL || strstr (c, "+blowfish-")!=NULL || strstr (c, "+twofish-")!=NULL;
    }


    if (command.accept_file (dirblock, i)) { //   ���� ���� ���� ��������� ����������
      unsigned long long filesize = dirblock->size[i];
      char timestr[100];  FormatDateTime (timestr, 100, dirblock->time[i]);

      if (command.cmd=='l')
          printf (dirblock->isdir[i]? "%s       -dir-" : "%s %11.0lf", timestr, double(filesize));
      else
          printf ("%s %s %15.0lf %15.0lf %08x", timestr, dirblock->isdir[i]? ".D.....":".......", double(filesize), double(packed), dirblock->crc[i]);
      printf ("%c", Encrypted? '*':' ');

      // Print filename using console encoding
      static char filename[MY_FILENAME_MAX*4];
      dirblock->fullname (i, filename);
      static MYFILE file;  file.setname (filename);
      printf ("%s\n", file.displayname());

      total_files++;
      total_bytes  += filesize;
      total_packed += packed;    packed = 0;
    }
  }
}
#endif

/******************************************************************************
** ���������� ������ ���������� � ������������ ������� ************************
******************************************************************************/

// ����������, ���������� ��������� �������� ������ ������� ������
MYFILE *infile;          // ���� ������, �� �������� ��� ������
FILESIZE bytes_left;     // ���-�� ����, ������� �������� ��������� �� ���������� ����������� ������ ����� �����-�����

// ����������, ���������� ��������� �������� ������ ������������� ������
COMMAND *cmd;             // ����������� �������
DIRECTORY_BLOCK *dir;     // �������, �������� ����������� ��������������� �����
int curfile;              //   ����� � �������� �������� ���������������� �����
BOOL included;            //   ������� ���� ������� � ��������� ��� �� ������ ���������� ���?
int extractUntil;         //   ����� ���������� �����, ������� ����� ������� �� ����� �����-�����
MYFILE outfile;           // ����, ����������� �� ������
char fullname[MY_FILENAME_MAX*4]; // ������ ��� ���������������� ������ �����
FILESIZE bytes_to_write;  // ������� ���� � ������� ����� �������� ��������
FILESIZE writtenBytes;    // ������� ���� ����� ���� ����������� � ������� ������
FILESIZE archive_pos;     // ������� ������� � ������
CRC crc;                  // CRC ������, ���������� � ����
enum PASS {FIRST_PASS, SECOND_PASS};  // ������/������ ������ �� �����-����� (������ - ���������� ��������� � ������ ������, ������ - ���� ���������)

// ��������� ����������� ������
void quit(void)   {if (outfile.isopen())  outfile.close(), delete_file(outfile.filename);
#ifdef FREEARC_INSTALLER
                   // Wipe temporary outdir on unsuccesful extraction
                   if (cmd->tempdir)
                   {
                       CFILENAME tmp  =  (TCHAR*) malloc (MY_FILENAME_MAX * 4);
                       wipedir (utf8_to_utf16 (cmd->outpath, tmp));
                       free(tmp);
                   }
#endif
                   exit (FREEARC_EXIT_ERROR);}

// �������� ��� ������ � CHECK()
#undef  ON_CHECK_FAIL
#define ON_CHECK_FAIL()   quit()

// * ������������� ��������� ������������� ����������� �������� ������ � ������� �������� ������,
// * ������� ����� ������, ��� �������� ������ e/x/t, �������� ����� ���������� � �������,
// * � ��, ��� ����� ������ ����� ���� ��������� �� ���������

// ������� ��������� �������� ���� � ���������� ��������� � ��� ����������
void outfile_open (PASS pass)
{
  crc = INIT_CRC;
  bytes_to_write = dir->size[curfile];
  if (pass==SECOND_PASS && bytes_to_write==0)
    return;  // Directories and empty files were extracted in first pass
  included = cmd->accept_file (dir, curfile);
  char *xname = cmd->cmd=='e'? dir->name[curfile]
                             : dir->fullname (curfile, fullname);
  outfile.setname (xname);

  if (included && cmd->cmd!='t')
    if (dir->isdir[curfile])
      {if (cmd->cmd!='e')  BuildPathTo (outfile.filename), create_dir (outfile.filename);}
    else
      {if (outfile.exists())
       {
         if (cmd->no)  included = FALSE;
         else if (!cmd->yes)
         {
           char answer = UI.AskOverwrite (outfile.displayname(), dir->size[curfile], dir->time[curfile]);
           switch (answer)
           {
             case 'y': break;
             case 'n': included = FALSE;  break;
             case 'a': cmd->yes = TRUE;   break;
             case 's': cmd->no  = TRUE;   included = FALSE;  break;
             case 'q': quit();
           }
         }
       }
       if (included)  outfile.open (WRITE_MODE);}

  if (pass==FIRST_PASS || dir->size[curfile]>0)   // �� ������ �������� � ���������� ���������/������ ������
    if (!(dir->isdir[curfile] && cmd->cmd!='x'))  // �� �������� � ������������ ��������� ;)
      if (!UI.ProgressFile (dir->isdir[curfile], included? (cmd->cmd=='t'? "Testing":"Extracting"):"Skipping", MYFILE(xname).displayname(), bytes_to_write))
        quit();
}

// �������� ������ � �������� ����
void outfile_write (void *buf, int size)
{
  crc = UpdateCRC (buf, size, crc);
  if (included && cmd->cmd!='t' && size)
    outfile.write(buf,size);
  if (!UI.ProgressWrite (writtenBytes += size))  quit();
}

// ������� �������� ����
void outfile_close()
{
  if (included)
  {
    CHECK ((crc^INIT_CRC) == dir->crc[curfile], (s,"ERROR: file %s failed CRC check", outfile.utf8name));
    if (cmd->cmd!='t' && !dir->isdir[curfile])
      outfile.close();
      outfile.SetFileDateTime (dir->time[curfile]);
  }
  included = FALSE;
}

// Callback-������� ������/������ ��� ������������
int callback_func (const char *what, void *buf, int size, void *auxdata)
{
  if (strequ (what, "read")) {
    int read_bytes = mymin (bytes_left, size);
    if (read_bytes==0)  return 0;
    if (!UI.ProgressRead (archive_pos))  quit();
    int len = infile->tryRead (buf, read_bytes);
    if (len>0)  bytes_left -= len,  archive_pos += len;
    return len;

  } else if (strequ (what, "write")) {
    int origsize = size;
    if (curfile > extractUntil)  return FREEARC_ERRCODE_NO_MORE_DATA_REQUIRED;   // ��� ������� ����� �����������, �� ��������� ��������� ���������� �� ���������� :(
    while (size>0) {
      int n = mymin (bytes_to_write, size);   // ���������� ������� �������� �� ����� ����� ���
      outfile_write (buf,n);                  // ������� �������� ������ � ������ - ������ ��� ������
      bytes_to_write -= n;
      if (bytes_to_write==0) {                // ���� ���� ������� �� ����� - ������� � ����������
        outfile_close();
        if (++curfile > extractUntil)  return FREEARC_ERRCODE_NO_MORE_DATA_REQUIRED;   // ���� ��� �����, ������� �� ������ ����������� �� ����� �����, ��� ���������, �� ��������� ����������� ��������� ����������
        outfile_open(SECOND_PASS);
      }
      buf=(uint8*)buf+n; size-=n;
    }
    return origsize;     // ��������������� �������� ������ � ��������� ���������� ����������

  } else return FREEARC_ERRCODE_NOT_IMPLEMENTED;
}

// Add "tempfile" to compressors chain if required
char *AddTempfile (char *compressor)
{
  char *buffering = "tempfile";
  char PLUS[] = {COMPRESSION_METHODS_DELIMITER, '\0'};

  char *c = (char*) malloc (strlen(compressor)+1);
  if (!c)  return NULL;
  strcpy(c, compressor);
  compressor = c;

  // �������� ���������� �� ��������� ��������� � ��������� ������ ������
  CMETHOD  cm[MAX_METHODS_IN_COMPRESSOR];
  uint64 memi[MAX_METHODS_IN_COMPRESSOR];
  int N = split (compressor, COMPRESSION_METHODS_DELIMITER, cm, MAX_METHODS_IN_COMPRESSOR);
  uint64 mem = 0;
  for (int i=0; i<N; i++)
    mem += memi[i] = GetDecompressionMem(cm[i]);

  // Maximum memory allowed to use
  uint64 maxmem = mymin (GetPhysicalMemory()/4*3, GetMaxMemToAlloc());

  // If memreqs are too large - add "tempfile" between methods
  if (mem > maxmem)
  {
    char *c2 = (char*) malloc (strlen(compressor)+strlen(buffering)+2);
    if (!c2)  return NULL;
    compressor = c2;

    strcpy(compressor, cm[0]);
    mem=memi[0];

    for (int i=1; i<N; i++)
    {
      // If total memreqs of methods after last tempfile >maxmem - add one more tempfile occurence
      if (mem>0 && mem+memi[i]>maxmem)
      {
        strcat (compressor, PLUS);
        strcat (compressor, buffering);
        mem = 0;
      }
      strcat (compressor, PLUS);
      strcat (compressor, cm[i]);
      mem += memi[i];
    }
    free(c);  // we can't free c earlier since its space used by cm[i]
    return compressor;
  }

  free(c);
  return NULL;
}

// ����������� ��� �������������� ����� �� �����-����� � ������� block_num �������� dirblock
void ExtractFiles (DIRECTORY_BLOCK *dirblock, int block_num, COMMAND &command)
{
  cmd = &command;
  dir = dirblock;
  BLOCK& data_block (dirblock->data_block [block_num]);
  extractUntil = -1;                        // � ��� ���������� ����� ������� ����� ���������� ����� � �����-�����, ������� ����� ����������
  // �������� ��� ����� � ���� �����
  for (curfile = dirblock->block_start(block_num); curfile < dirblock->block_end(block_num); curfile++) {
    if (command.accept_file (dirblock, curfile))           // ���� ���� ���� ��������� ����������
    {
      if (dir->size[curfile]==0) {   // �� ���� ��� ������� ��� ������ ���� - ������� ��� �����
        outfile_open (FIRST_PASS);
        outfile_close(); }
      else
        extractUntil = curfile;      // � ����� - ��������, ��� ����� ����������� ���� ��� ������� �� ����� �����
    }
  }
  if (extractUntil >= 0) {                       // ���� � ���� ����� ������� ��� ������������� - ������, ���������! :)
    infile = &dirblock->arcfile;                 //   �������� ����
    infile->seek (archive_pos = data_block.pos); //   ������ ������ �����-����� � ������
    bytes_left = data_block.compsize;            //   ������ ����������� ������ � �����-�����
    curfile = dirblock->block_start (block_num); // ����� ������� ����� � ���� �����-�����
    outfile_open (SECOND_PASS);                  // ������� ������ �������� ����
    char *compressor = AddTempfile (data_block.compressor);  // ������� "tempfile" ����� ������������� ���� �� ������� ������ ��� ����������
    int result = MultiDecompress (compressor? compressor : data_block.compressor, callback_func, NULL);
    CHECK (result!=FREEARC_ERRCODE_INVALID_COMPRESSOR, (s,"ERROR: unsupported compression method %s", data_block.compressor));
    CHECK (result>=0 || result==FREEARC_ERRCODE_NO_MORE_DATA_REQUIRED, (s,"ERROR: archive data corrupted (decompression fails)"));
    free (compressor);
    outfile_close();                             // ������� ��������� �������� ����
  }
}


/******************************************************************************
** �������� ��������� *********************************************************
******************************************************************************/

// ������ ��������� ������ � �������� � ����������� �� ����������� �������
// ListFiles ��� ������� ����� �������� ��� ExtractFiles ��� ������� �����-�����
void ProcessArchive (COMMAND &command)
{
  static ARCHIVE arcinfo (command.arcname);
  arcinfo.read_structure();                                           // ��������� ��������� ������
  // ������� ��������� �������� �� ����� � �������� � ������������ ���������� �� ���������� SFX
  if (!UI.AllowProcessing (command.cmd, command.silent, MYFILE(command.arcname).displayname(), &arcinfo.arcComment[0], arcinfo.arcComment.size, command.outpath)) {
    command.ok = FALSE;  return;
  }
  if (command.cmd!='t')  outfile.SetBaseDir (UI.GetOutDir());

  writtenBytes = 0;
  if (command.list_cmd())  ListHeader (command);
  else                     UI.BeginProgress (arcinfo.arcfile.size());
  iterate_array (i, arcinfo.control_blocks_descriptors) {             // �������� ��� ��������� ����� � ������...
    BLOCK& block_descriptor = arcinfo.control_blocks_descriptors[i];
    if (block_descriptor.type == DIR_BLOCK) {                         // ... � ������ �� ��� ����� ��������
      DIRECTORY_BLOCK dirblock (arcinfo, block_descriptor);           // ��������� ���� ��������
      if (command.list_cmd())                                         // ���� ��� ������� ��������� ��������
        ListFiles (&dirblock, command);                               //   �� �������� �
      else
        iterate_array (i, dirblock.data_block)                        //   ����� - �������� ��� �����-����� � ��������
          ExtractFiles (&dirblock, i, command);                       //     � ��� ������� �� ��� �������� ��������� ������������/����������
    }
  }
  if (command.list_cmd())  ListFooter (command);
  else                     UI.EndProgress();

#ifdef FREEARC_INSTALLER
  // Run setup.exe after unpacking
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

#ifdef FREEARC_LIBRARY
extern "C" {
int __cdecl FreeArcExtract (HANDLE hWnd, HANDLE hpb, HANDLE hst, ...)
{
  //UI.callback = callback;
  UI.hWnd=hWnd, UI.hpb=hpb, UI.hst=hst;

  va_list argptr;
  va_start(argptr, hst);

  int argc=0;
  char *argv[100] = {"c:\\x.dll"};

  for (int i=1; i<100; i++)
  {
    argc = i;
    argv[i] = va_arg(argptr, char*);
    if (argv[i]==NULL || argv[i][0]==0)
      {argv[i]=NULL; break;}
  }
  va_end(argptr);


  SetCompressionThreads (GetProcessorsCount());
  COMMAND command (argc, argv);    // ���������� �������
  if (command.ok)                  // ���� ������� ��� ������ � ����� ��������� �������
    ProcessArchive (command);      //   ��������� ����������� �������
  return command.ok? FREEARC_OK : FREEARC_ERRCODE_GENERAL;
}
}
#else // non-library mode
int main (int argc, char *argv[])
{
  SetCompressionThreads (GetProcessorsCount());
  UI.DisplayHeader (HEADER1 NAME);
  COMMAND command (argc, argv);    // ���������� �������
  if (command.ok)                  // ���� ������� ��� ������ � ����� ��������� �������
    ProcessArchive (command);      //   ��������� ����������� �������
  printf ("\n");
  return command.ok? EXIT_SUCCESS : FREEARC_EXIT_ERROR;
}
#endif

