extern "C" {
#include "C_Delta.h"
}


#define DELTA_LIBRARY
#include "Delta.cpp"

/*-------------------------------------------------*/
/* ���������� ������ DELTA_METHOD                    */
/*-------------------------------------------------*/

// �����������, ������������� ���������� ������ ������ �������� �� ���������
DELTA_METHOD::DELTA_METHOD()
{
  BlockSize      = 8*mb;
  ExtendedTables = 0;
}

// ������� ����������
int DELTA_METHOD::decompress (CALLBACK_FUNC *callback, void *auxdata)
{
  return delta_decompress (BlockSize, ExtendedTables, callback, auxdata);
}

#ifndef FREEARC_DECOMPRESS_ONLY

// ������� ��������
int DELTA_METHOD::compress (CALLBACK_FUNC *callback, void *auxdata)
{
  return delta_compress (BlockSize, ExtendedTables, callback, auxdata);
}

// �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � parse_DELTA)
void DELTA_METHOD::ShowCompressionMethod (char *buf)
{
    DELTA_METHOD defaults; char BlockSizeStr[100]=":";
    showMem (BlockSize, BlockSizeStr+1);
    sprintf (buf, "delta%s%s", BlockSize!=defaults.BlockSize? BlockSizeStr:"", ExtendedTables? ":x":"");
}

#endif  // !defined (FREEARC_DECOMPRESS_ONLY)

// ������������ ������ ���� DELTA_METHOD � ��������� ����������� ��������
// ��� ���������� NULL, ���� ��� ������ ����� ������ ��� �������� ������ � ����������
COMPRESSION_METHOD* parse_DELTA (char** parameters)
{
  if (strcmp (parameters[0], "delta") == 0) {
    // ���� �������� ������ (������� ��������) - "delta", �� ������� ��������� ���������

    DELTA_METHOD *p = new DELTA_METHOD;
    int error = 0;  // ������� ����, ��� ��� ������� ���������� ��������� ������

    // �������� ��� ��������� ������ (��� ������ ������ ��� ������������� ������ ��� ������� ���������� ���������)
    while (*++parameters && !error)
    {
      char* param = *parameters;
      if (strlen(param)==1) switch (*param) {    // ������������� ���������
        case 'x':  p->ExtendedTables = 1; continue;
      }
      switch (*param) {                    // ���������, ���������� ��������
        case 'b':  p->BlockSize = parseMem (param+1, &error); continue;
      }
      // ���� �� ��������, ���� � ��������� �� ������� ��� ��������
      // ���� ���� �������� ������� ��������� ��� ����� ������,
      // �� �������� ��� �������� ���� BlockSize
      p->BlockSize = parseMem (param, &error);
    }
    if (error)  {delete p; return NULL;}  // ������ ��� �������� ���������� ������
    return p;
  } else
    return NULL;   // ��� �� ����� DELTA
}

static int DELTA_x = AddCompressionMethod (parse_DELTA);   // �������������� ������ ������ DELTA

