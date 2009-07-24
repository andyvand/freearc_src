#include "../NewCompression.h"

#define REP_LIBRARY
#include "rep.cpp"

// ��������� �⠭���⭮�� ����䥩� ��⮤�� ᦠ�� COMPRESSION_METHOD
struct REP_METHOD : COMPRESSION_METHOD
{
  // ��ࠬ���� �⮣� ��⮤� ᦠ��
  MemSize BlockSize;        // ������ ����. ���������� ������ ⮫쪮 � �।���� �⮩ ���⠭樨. ���室 ����� - BlockSize+BlockSize/4
  int     MinCompression;   // ��������� ��業� ᦠ��. �᫨ ��室�� ����� �����, � ����� ��� ���� ����ᠭ� �ਣ������ (��ᦠ��) �����
  int     MinMatchLen;      // �������쭠� ����� ��ப�, �� ���ன ��� �㤥� ���������� ��뫪�� �� �।��饥 �宦�����
  int     Barrier;          // �࠭��, ��᫥ ���ன ����᪠���� �ᯮ�짮���� ᮢ������� ����襣� ࠧ��� (��᪮��� lzma/ppmd ��� ࠢ�� �ய���� ��)
  int     SmallestLen;      // ��� ����訩 ࠧ���
  int     HashSizeLog;      // ������ ࠧ��� �� (� 4-���⮢�� ᫮���). ����訥 ���祭�� 㢥��稢��� ᦠ⨥, �� ��������� ���. �� �㫥��� ���祭�� ��⨬���� ࠧ��� �������� ��⮬���᪨
  int     Amplifier;        // �����樥�� "�ᨫ����" ���᪠

  // ���������, ��ᢠ����騩 ��ࠬ��ࠬ ��⮤� ���祭�� �� 㬮�砭��
  REP_METHOD (TABI_ELEMENT* params) : COMPRESSION_METHOD(params)
  {
    BlockSize      = 64*mb;
    MinCompression = 100;
    MinMatchLen    = 512;
    Barrier        = INT_MAX;
    SmallestLen    = 512;
    HashSizeLog    = 0;
    Amplifier      = 1;
  }

  // �㭪�� �ᯠ�����
  virtual int decompress (CALLBACK_FUNC *callback, void *auxdata)
  {
    return rep_decompress (BlockSize, MinCompression, MinMatchLen, Barrier, SmallestLen, HashSizeLog, Amplifier, callback, auxdata);
  }

#ifndef FREEARC_DECOMPRESS_ONLY
  // �㭪�� 㯠�����
  virtual int compress (CALLBACK_FUNC *callback, void *auxdata)
  {
    return rep_compress (BlockSize, MinCompression, MinMatchLen, Barrier, SmallestLen, HashSizeLog, Amplifier, callback, auxdata);
  }

  // �����ࠥ� ��ப� � ��ࠬ��ࠬ� ��⮤�
  virtual void parse_method()
  {
    // �ॢ�⨬ ��ப� ��⮤� ᦠ�� � ���ᨢ ��ப `parameters`, �࠭�騩 ��� �������� � ��ࠬ����
    char* method = p._str("method");
    char* params [MAX_PARAMETERS], **parameters = params;
    char  local_method [MAX_METHOD_STRLEN];
    strncopy (local_method, method, sizeof (local_method));
    split (local_method, COMPRESSION_METHOD_PARAMETERS_DELIMITER, parameters, MAX_PARAMETERS);
    if (!strequ (parameters[0], "rep"))  throw "rep:parse_method";

    // �᫨ �������� ��⮤� (�㫥��� ��ࠬ���) - "rep", � ࠧ���� ��⠫�� ��ࠬ����
    int error = 0;  // �ਧ��� ⮣�, �� �� ࠧ��� ��ࠬ��஢ �ந��諠 �訡��

    // ��ॡ��� �� ��ࠬ���� ��⮤� (��� �멤�� ࠭�� �� ������������� �訡�� �� ࠧ��� ��।���� ��ࠬ���)
    while (*++parameters && !error)
    {
      char* param = *parameters;
      switch (*param) {                    // ��ࠬ����, ᮤ�ঠ騥 ���祭��
        case 'b':  BlockSize   = parseMem (param+1, &error); continue;
        case 'l':  MinMatchLen = parseInt (param+1, &error); continue;
        case 'd':  Barrier     = parseMem (param+1, &error); continue;
        case 's':  SmallestLen = parseInt (param+1, &error); continue;
        case 'h':  HashSizeLog = parseInt (param+1, &error); continue;
        case 'a':  Amplifier   = parseInt (param+1, &error); continue;
      }
      // �᫨ ��ࠬ��� �����稢����� ������ ��業�. � ���஡㥬 �ᯠ���� ��� ��� "N%"
      if (last_char(param) == '%') {
        char str[100]; strcpy(str,param); last_char(str) = '\0';
        int n = parseInt (str, &error);
        if (!error) { MinCompression = n; continue; }
        error=0;
      }
      // � �� ��������, �᫨ � ��ࠬ��� �� 㪠���� ��� ��������
      // �᫨ ��� ��ࠬ��� 㤠���� ࠧ����� ��� 楫�� �᫮ (�.�. � �� - ⮫쪮 ����),
      // � ��᢮�� ��� ���祭�� ���� MinMatchLen, ���� ���஡㥬 ࠧ����� ��� ��� BlockSize
      int n = parseInt (param, &error);
      if (!error) MinMatchLen = n;
      else        error=0, BlockSize = parseMem (param, &error);
    }
    if (error)  throw "rep:parse_method";  // �訡�� �� ���ᨭ�� ��ࠬ��஢ ��⮤�
  }

  // ������� � buf[MAX_METHOD_STRLEN] ��ப�, ����뢠���� ��⮤ ᦠ�� � ��� ��ࠬ���� (�㭪��, ���⭠� � parse_method)
  virtual void ShowCompressionMethod (char *buf)
  {
    REP_METHOD defaults(NULL); char BlockSizeStr[100], MinCompressionStr[100], BarrierTempStr[100], BarrierStr[100], SmallestLenStr[100], HashSizeLogStr[100], AmplifierStr[100], MinMatchLenStr[100];
    showMem (BlockSize, BlockSizeStr);
    showMem (Barrier,   BarrierTempStr);
    sprintf (MinCompressionStr, MinCompression!=defaults.MinCompression? ":%d%%" : "", MinCompression);
    sprintf (BarrierStr,     Barrier    !=defaults.Barrier    ? ":d%s" : "", BarrierTempStr);
    sprintf (SmallestLenStr, SmallestLen!=defaults.SmallestLen? ":s%d" : "", SmallestLen);
    sprintf (AmplifierStr,   Amplifier  !=defaults.Amplifier  ? ":a%d" : "", Amplifier);
    sprintf (HashSizeLogStr, HashSizeLog!=defaults.HashSizeLog? ":h%d" : "", HashSizeLog);
    sprintf (MinMatchLenStr, MinMatchLen!=defaults.MinMatchLen? ":%d"  : "", MinMatchLen);
    sprintf (buf, "rep:%s%s%s%s%s%s%s", BlockSizeStr, MinCompressionStr, MinMatchLenStr, BarrierStr, SmallestLenStr, HashSizeLogStr, AmplifierStr);
  }

  // ����ந�� ��⮤ ᦠ�� �� �ᯮ�짮����� ��������� ���� �����
  virtual void SetCompressionMem (MemSize mem)
  {
    if (mem>0)
    {
      // �����஢��� �� rep_compress
      int L = roundup_to_power_of (mymin(SmallestLen,MinMatchLen)/2, 2);  // ������ ������, �� ������ �������� � ��
      int k = sqrtb(L*2);
      int HashSize = CalcHashSize (HashSizeLog, mem/5*4, k);

      BlockSize = mem - HashSize*sizeof(int);
    }
  }

  // �������, ᪮�쪮 ����� �ॡ���� ��� 㯠����� ������� ��⮤��
  virtual MemSize GetCompressionMem()
  {
    // �����஢��� �� rep_compress
    int L = roundup_to_power_of (mymin(SmallestLen,MinMatchLen)/2, 2);  // ������ ������, �� ������ �������� � ��
    int k = sqrtb(L*2);
    int HashSize = CalcHashSize (HashSizeLog, BlockSize, k);

    return BlockSize + HashSize*sizeof(int);
  }

  // �������/��⠭����� ���� �����, �ᯮ��㥬�� �� 㯠�����/�ᯠ�����, ࠧ��� ᫮���� ��� ࠧ��� �����
  virtual void    SetDictionary       (MemSize dict) {BlockSize = dict;}
  virtual MemSize GetDictionary       (void)         {return BlockSize;}
  virtual void    SetDecompressionMem (MemSize mem)  {BlockSize = mem;}
#endif
  virtual MemSize GetDecompressionMem (void)         {return BlockSize;}
};

// Function that represents REP compression method
int rep_server (TABI_ELEMENT* params)
{
  return REP_METHOD(params).server();
}

// Register REP method in dispatcher table
int rep_register = RegisterCompressionMethod(rep_server);

