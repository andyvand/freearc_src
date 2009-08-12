#include <stdio.h>
#include <string.h>
extern "C" {
#include "C_External.h"
}

int external_program (bool IsCompressing, CALLBACK_FUNC *callback, void *auxdata, char *infile_basename, char *outfile_basename, char *cmd, char *method, int MinCompression, double *addtime)
{
    MYDIR t;  if (!t.create_tempdir())    return FREEARC_ERRCODE_WRITE;
    MYFILE infile (t, infile_basename);
    MYFILE outfile(t, outfile_basename);

    BYTE* Buf = (BYTE*) malloc(LARGE_BUFFER_SIZE);    // �����, ������������ ��� ������/������ ������
    if (!Buf)  {return FREEARC_ERRCODE_NOT_ENOUGH_MEMORY;}
    int x;                                            // ���, ������������ ��������� ��������� ������/������
    int ExitCode = 0;                                 // ��� �������� ������� ���������
    bool useHeader = !strequ(method,"tempfile");      // TRUE, ���� � ������ ������� ������ ������������ 0/1 - ������ �������/�����

    // ��������� ������� ������ �� ��������� ����
    infile.remove();
    uint64 bytes = 0;
    BYTE runCmd = 1;
    if (!IsCompressing && useHeader)  checked_read (&runCmd, 1);
    while ( (x = callback ("read", Buf, LARGE_BUFFER_SIZE, auxdata)) > 0 )
    {
        if (!infile.isopen())  {// �� ��������� ���� ���� �� ������ ���� �������-������ ������ (��� ������� ������� � ������������ �����-������)
            if (!infile.tryOpen(WRITE_MODE))  {x=FREEARC_ERRCODE_WRITE; break;}
            registerTemporaryFile (infile);
        }
        if (runCmd!=0 && runCmd!=1) {            // ��� ������������� �� ������� �������� FreeArc, ������� �� ��������� 1 ����� ������� ������� (������ �� FreeArc 1.0!)
            outfile = "data7777";
            bytes += 1;
            if (write(infile.handle,&runCmd,1) != 1)   {x=FREEARC_ERRCODE_WRITE; break;}
            runCmd = 1;
        }
        bytes += x;
        if (write(infile.handle,Buf,x) != x)           {x=FREEARC_ERRCODE_WRITE; break;}
    }
    free(Buf);  Buf = NULL;
    unregisterTemporaryFile (infile);
    infile.close();
    if (x)  {infile.remove(); return x;}   // ���� ��� ������/������ ��������� ������ - �������

    // ���� cmd ����� - ���� ������������ ������ ��� ����������� ������ ����� ���������� �������.
    // ���� runCmd==0 - ������ ���� ����������� ��� ������
    outfile.remove();
    registerTemporaryFile (infile);
    registerTemporaryFile (outfile);
    if (*cmd && runCmd) {
    	char temp[30];
        printf ("\n%s %s bytes with %s\n", IsCompressing? "Compressing":"Unpacking", show3(bytes,temp), cmd);
        MYFILE _tcmd(cmd); // utf8->utf16 conversion
        double time0 = GetGlobalTime();
        ExitCode = RunCommand (_tcmd.filename, t.filename, TRUE);
        printf ("\nErrorlevel=%d\n", ExitCode);
        if (addtime)  *addtime += GetGlobalTime() - time0;
    } else {
        infile.rename (outfile);
    }

    // ������� �������� ����, ���� ������� ����������� ������� � ��� ����� �������
    if(ExitCode==0)    outfile.tryOpen (READ_MODE);
    if (outfile.isopen()) {
        registerTemporaryFile (outfile);
        unregisterTemporaryFile (infile);
        infile.remove();
        BYTE compressed[1] = {1};
        if (IsCompressing && useHeader)     checked_write(compressed,1);
    } else {
        unregisterTemporaryFile (outfile);
        unregisterTemporaryFile (infile);
        if (IsCompressing && !useHeader)    {infile.remove(); return FREEARC_ERRCODE_GENERAL;}
        outfile.remove();
        if (!IsCompressing)                 {infile.remove(); return FREEARC_ERRCODE_INVALID_COMPRESSOR;}
        infile.rename (outfile);
        if (!outfile.tryOpen (READ_MODE))   {infile.remove(); outfile.remove(); return FREEARC_ERRCODE_READ;}
        registerTemporaryFile (outfile);
        BYTE uncompressed[1] = {0};
        if (IsCompressing)                  checked_write(uncompressed,1);
    }

    // ��������� �������� ������ �� �����
    QUASIWRITE (outfile.size());
    Buf = (BYTE*) malloc(LARGE_BUFFER_SIZE);
    while ((x = read (outfile.handle, Buf, LARGE_BUFFER_SIZE)) > 0)
    {
        checked_write (Buf, x);
    }
finished:
    free(Buf);
    unregisterTemporaryFile (outfile);
    outfile.close();
    outfile.remove();
    unregisterTemporaryFile (t);
    return x;         // 0, ���� �� � �������, � ��� ������ �����
}


/*-------------------------------------------------*/
/* ���������� ������ EXTERNAL_METHOD               */
/*-------------------------------------------------*/

char *prepare_cmd (EXTERNAL_METHOD *p, char *cmd)
{
    // Replace "{options}" or "{-option }" in packcmd with string like "-m48 -r1 " (for "pmm:m48:r1" method string)
    char *OPTIONS_STR = "{options}",  *OPTION_STR = "option";
    char OPTIONS_START = '{',  OPTIONS_END = '}';

    // Params of option template in cmd line
    char before[MAX_METHOD_STRLEN] = "-";
    char after[MAX_METHOD_STRLEN]  =  " ";
    char *replaced = strstr (cmd, OPTIONS_STR);
    int  how_many  = strlen (OPTIONS_STR);

    // If there is no "{options}" in cmd - look for "{...option...}"
    if (!replaced)
    {
        // search for '{'
        for (char *p1 = cmd; *p1; p1++)
        {
            if (*p1 == OPTIONS_START)
            {
                // search for '}'
                char *p2 = p1, *p12 = NULL;
                for (; *p2; p2++)
                {
                    if (*p2 == OPTIONS_END)  break;
                    if (start_with(p2, OPTION_STR))  p12 = p2;
                }
                // if we have "option" inside of "{...}"
                if (*p2==OPTIONS_END && p12)
                {
                    // Save strings before and after "option" and how many chars in cmd to replace
                    strncopy (before, p1+1, p12-p1-1 + 1);
                    strncopy (after,  p12+strlen(OPTION_STR), p2-p12-strlen(OPTION_STR) + 1);
                    replaced = p1;
                    how_many = p2-p1+1;
                    break;
                }
            }
        }
    }

    // If we found any option template in cmd
    if (replaced)
    {
        // Collect in param_str options in cmd format
        char param_str[MAX_METHOD_STRLEN] = "";
        for (char **opt = p->options; *opt; opt++)
        {
            strcat (param_str, before);
            strcat (param_str, *opt);
            strcat (param_str, after);
        }
        // Finally replace template with collected or default options
        cmd = str_replace_n (cmd, replaced, how_many, *p->options? param_str : p->defaultopt);
    }

    return cmd;
}


// ������� ����������
int EXTERNAL_METHOD::decompress (CALLBACK_FUNC *callback, void *auxdata)
{
    char *cmd = prepare_cmd (this, unpackcmd);
    int result = external_program (FALSE, callback, auxdata, packedfile, datafile, cmd, name, 0, &addtime);
    if (cmd != unpackcmd)  delete cmd;
    return result;
}

#ifndef FREEARC_DECOMPRESS_ONLY

// ������� ��������
int EXTERNAL_METHOD::compress (CALLBACK_FUNC *callback, void *auxdata)
{
    char *cmd = prepare_cmd (this, packcmd);
    int result = external_program (TRUE, callback, auxdata, datafile, packedfile, cmd, name, 0, &addtime);
    if (cmd != packcmd)  delete cmd;
    return result;
}

// �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � parse_EXTERNAL)
void EXTERNAL_METHOD::ShowCompressionMethod (char *buf)
{
    if (strequ (name, "pmm")) {
        char MemStr[100];
        showMem (cmem, MemStr);
        sprintf (buf, "pmm:%d:%s%s", order, MemStr, MRMethod==2? ":r2": (MRMethod==0? ":r0":""));
    } else {
        strcpy (buf, name);
        for (char** opt=options; *opt; opt++)
        {
            strcat(buf, ":");
            strcat(buf, *opt);
        }
    }
}

// �������� ����������� � ������, ������ ������������ order
void EXTERNAL_METHOD::SetCompressionMem (MemSize _mem)
{
    if (can_set_mem && _mem>0) {
        order  +=  int (trunc (log(double(_mem)/cmem) / log(2) * 4));
        cmem=dmem=_mem;
    }
}

#endif  // !defined (FREEARC_DECOMPRESS_ONLY)


// ������������ ������ ���� EXTERNAL_METHOD/PPMonstr � ��������� ����������� ��������
// ��� ���������� NULL, ���� ��� ������ ����� ������ ��� �������� ������ � ����������
COMPRESSION_METHOD* parse_PPMONSTR (char** parameters)
{
  // ���� �������� ������ (������� ��������) - "pmm", �� ������� ��������� ���������
  if (strcmp (parameters[0], "pmm") == 0) {
    // ��������� �������� ���������� ��� ������ ������ PPMonstr
    EXTERNAL_METHOD *p = new EXTERNAL_METHOD;
    p->name           = "pmm";
    p->MinCompression = 100;
    p->can_set_mem    = TRUE;
    p->order          = 16;
    p->cmem           = 192*mb;
    p->dmem           = 192*mb;
    p->MRMethod       = 1;
    p->datafile       = "$$arcdatafile$$.tmp";
    p->packedfile     = "$$arcdatafile$$.pmm";

    int error = 0;  // ������� ����, ��� ��� ������� ���������� ��������� ������

    // �������� ��� ��������� ������ (��� ������ ������ ��� ������������� ������ ��� ������� ���������� ���������)
    while (*++parameters && !error)
    {
      char *param = *parameters;
      if (start_with (param, "mem")) {
        param+=2;  // ���������� "mem..." ��� "m..."
      }
      if (strlen(param)==1) switch (*param) {    // ������������� ���������
        case 'r':  p->MRMethod = 1; continue;
      }
      else switch (*param) {                    // ���������, ���������� ��������
        case 'm':  p->cmem = p->dmem = parseMem (param+1, &error); continue;
        case 'o':  p->order          = parseInt (param+1, &error); continue;
        case 'r':  p->MRMethod       = parseInt (param+1, &error); continue;
      }
      // ���� �� ��������, ���� � ��������� �� ������� ��� ��������
      // ���� ���� �������� ������� ��������� ��� ����� ����� (�.�. � �� - ������ �����),
      // �� �������� ��� �������� ���� order, ����� ��������� ��������� ��� ��� mem
      int n = parseInt (param, &error);
      if (!error) p->order = n;
      else        error=0, p->cmem = p->dmem = parseMem (param, &error);
    }
    if (error)  {delete p; return NULL;}  // ������ ��� �������� ���������� ������

    // ������ packcmd/unpackcmd ��� PPMonstr
    char cmd[100];
    sprintf (cmd, "ppmonstr e -o%d -m%d -r%d %s", p->order, p->cmem>>20, p->MRMethod, p->datafile);
    p->packcmd = strdup_msg(cmd);
    sprintf (cmd, "ppmonstr d %s", p->packedfile);
    p->unpackcmd = strdup_msg(cmd);

    return p;
  } else {
    return NULL;   // ��� �� ����� PPMONSTR
  }
}

static int PPMONSTR_x = AddCompressionMethod (parse_PPMONSTR);   // �������������� ������ ������ PPMONSTR




// ��������� ������������ ������� ����������� **********************************************************************

// ������������ ������ ���� EXTERNAL_METHOD � ��������� ����������� ��������
// ��� ���������� NULL, ���� ��� ������ ����� ������ ��� �������� ������ � ����������
COMPRESSION_METHOD* parse_EXTERNAL (char** parameters, void *method_template)
{
  if (strequ (parameters[0], ((EXTERNAL_METHOD*)method_template)->name)) {
    // ���� �������� ������ (������� ��������) ������������� �������� ������������ EXTERNAL ������, �� ������� ��������� ���������
    EXTERNAL_METHOD *p = new EXTERNAL_METHOD (*(EXTERNAL_METHOD*)method_template);

    // �������� ��������� ������ ������ ������ �������
    char **param = parameters+1, **opt = p->options, *place = p->option_strings;
    while (*param)
    {
      strcpy (place, *param++);
      *opt++ = place;
      place += strlen(place)+1;
    }
    *opt++ = NULL;

    return p;
  } else {
    return NULL;   // ��� �� ����� EXTERNAL
  }
}


// �������� � ������� ������� ������ ��������� ������������� � arc.ini ������� ���������.
// params �������� �������� ���������� �� arc.ini. ���������� 1, ���� �������� ���������.
// ������ ��������:
//   [External compressor: ccm123, ccmx123, ccm125, ccmx125]
//   mem = 276
//   packcmd   = {compressor} c $$arcdatafile$$.tmp $$arcpackedfile$$.tmp
//   unpackcmd = {compressor} d $$arcpackedfile$$.tmp $$arcdatafile$$.tmp
//   datafile   = $$arcdatafile$$.tmp
//   packedfile = $$arcpackedfile$$.tmp
//
int AddExternalCompressor (char *params)
{
    // �������� �������� ������ ������ �� ��������� ������, �������� ��� ��������� � ���������
    char  local_method [MAX_EXTERNAL_COMPRESSOR_SECTION_LENGTH];
    strncopy (local_method, params, MAX_METHOD_STRLEN);
    char* parameters [MAX_PARAMETERS];
    split (local_method, '\n', parameters, MAX_PARAMETERS);

    // ��������, ��� ������ ������ - ��������� ������ [External compressor]
    if (last_char(parameters[0])=='\r')  last_char(parameters[0]) = '\0';
    if (! (start_with (parameters[0], "[External compressor:")
           && end_with (parameters[0], "]")))
      return 0;

    // �������� �� ��������� ������ ����� ������ ���������
    char *versions_list = strdup_msg (strchr(parameters[0],':')+1);
    last_char(versions_list) = '\0';
    char* version_name [MAX_COMPRESSION_METHODS];
    int versions_count = split (versions_list, ',', version_name, MAX_COMPRESSION_METHODS);

    // ��� ������ ������ ������ ��������� ������ EXTERNAL_METHOD
    EXTERNAL_METHOD *version  =  new EXTERNAL_METHOD[versions_count];
    for (int i=0; i<versions_count; i++) {
        // �������������� ������ EXTERNAL_METHOD ������ ��������� ������ � ����������� �� ���������
        version[i].name           = trim_spaces(version_name[i]);
        version[i].MinCompression = 100;
        version[i].can_set_mem    = FALSE;
        version[i].cmem           = 0;
        version[i].dmem           = 0;
        version[i].datafile       = "$$arcdatafile$$.tmp";
        version[i].packedfile     = "$$arcpackedfile$$.tmp";
        version[i].packcmd        = "";
        version[i].unpackcmd      = "";
        version[i].defaultopt     = "";
        version[i].solid          = 1;
    }


    // ������ �������� ��� ������� �� �������� ����������, ���������������� �������������
    // (������� ��������/����������, ���������� � ������ � ��� �����).
    for (char **param=parameters;  *++param; ) {
        // ���������� ������ ��������, ������ � �� ����� ����� �� '='
        // c ��������� ��������� � ������ ����� � ��� ���������
        char *s = *param;
        if (last_char(s)=='\r')  last_char(s) = '\0';  // �� ������ ��������� ����� � '\r\n' �������������
        if (*s=='\0' || *s==';')  continue;  // ��������� ������� ������ ������ / ������ ������������
        while (*s && isspace(*s))  s++;   // ��������� ��������� ������� � ������
        char *left = s;                   // �������� ������ ����� ����� (�����) ���������
        while (*s && !isspace(*s) && *s!='=')  s++;   // ����� ����� �����
        if (*s=='\0')  return 0;
        if (*s!='=') {                         // ��������� ������� ����� �����, ���� �����
            *s++ = '\0';
            while (*s && isspace(*s))  s++;
            if (*s!='=')  return 0;
        }
        *s++ = '\0';                           // �������� '\0' ����� �����
        while (*s && isspace(*s))  s++;        // ��������� ������� � ������ ������ ����� (��������)
        if (*s=='\0')  return 0;
        char *right = s;                       // �������� ������ ��������

        // ������ left �������� ����� ����� ������ (�� '=') ��� ��������,
        // � right - ������ ����� ��� ��������� ��������.
        // �������� ��� ������ ����������� � ������� � ��� ��������������� ����
        for (int i=0; i<versions_count; i++) {
            int error = 0;  // ������� ����, ��� ��� ������� ���������� ��������� ������
                 if (strequ (left, "mem"))         version[i].cmem = version[i].dmem = parseInt (right,&error)*mb;
            else if (strequ (left, "cmem"))        version[i].cmem        = parseInt (right,&error)*mb;
            else if (strequ (left, "dmem"))        version[i].dmem        = parseInt (right,&error)*mb;
            else if (strequ (left, "packcmd"))     version[i].packcmd     = subst (strdup_msg(right), "{compressor}", version[i].name);
            else if (strequ (left, "unpackcmd"))   version[i].unpackcmd   = subst (strdup_msg(right), "{compressor}", version[i].name);
            else if (strequ (left, "datafile"))    version[i].datafile    = subst (strdup_msg(right), "{compressor}", version[i].name);
            else if (strequ (left, "packedfile"))  version[i].packedfile  = subst (strdup_msg(right), "{compressor}", version[i].name);
            else if (strequ (left, "default"))     version[i].defaultopt  = subst (strdup_msg(right), "{compressor}", version[i].name);
            else if (strequ (left, "solid"))       version[i].solid       = parseInt (right, &error);
            else                                   error=1;

            if (error)  return 0;
        }
    }


    // �������, �������������� ������ EXTERNAL ������ ������, ������������ ��� �������
    // ��� ������������� ����� ������� ������ � ��������� ���� ����������� ��������
    // � ���, ����� ������� ����� �������� ��� ��� ����������, ����� ����� �����
    // ���������� ������ � �.�.
    for (int i=0; i<versions_count; i++) {
        AddExternalCompressionMethod (parse_EXTERNAL, &version[i]);
    }
    return 1;
}

// ������-����� ������, ������������ ��� ���������� �� ������ � ����, � ����� ����������� ���.
// ������������� ����������� ����� ������� ����� ������ �����������, �������� REP � LZMA
static int TEMPFILE_x = AddExternalCompressor ("[External compressor:tempfile]");   // �������������� ������ ������ TEMPFILE

