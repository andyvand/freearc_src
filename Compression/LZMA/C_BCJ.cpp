extern "C" {
#include "C_BCJ.h"
}

#include "7zip/Compress/Branch/BranchX86.c"
#include "7zip/Compress/Branch/BranchCoder.cpp"
#include "7zip/Compress/Branch/x86.cpp"

template <class CBCJ_x86_Coder>
int bcj_x86_de_compress( CALLBACK_FUNC *callback, void *auxdata)
{
  CBCJ_x86_Coder c; c.Init();                    // �������/������� ��� BCJ-X86 �������������
  BYTE* Buf = (BYTE*)malloc(LARGE_BUFFER_SIZE);  // ����� ��� ������
  if (Buf==NULL)   return FREEARC_ERRCODE_NOT_ENOUGH_MEMORY;
  int RemainderSize=0;                           // ������� ������ � ����������� ����
  int x, InSize;                                 // ���������� ����������� ����
  while ( (InSize = x = callback ("read", Buf+RemainderSize, LARGE_BUFFER_SIZE-RemainderSize, auxdata)) >= 0 )
  {
    if ((InSize+=RemainderSize)==0)            goto Ok;  // ������ ������ ���
    int OutSize = InSize<=5? InSize : c.Filter(Buf, InSize);  // ������ 5 ���� ���� ������ �� ������������ :)
    if( (x=callback("write",Buf,OutSize,auxdata)) != OutSize )      goto Error;
    RemainderSize = InSize-OutSize;
    // �������� �������������� ������� ������ � ������ ������
    if (RemainderSize>0)                memmove(Buf,Buf+OutSize,RemainderSize);
  }
Error: delete Buf; return x;            // ��������� ������ ��� ������/������
Ok:    delete Buf; return FREEARC_OK;   // �� � �������
}


/*-------------------------------------------------*/
/* ���������� ������ BCJ_X86_METHOD                */
/*-------------------------------------------------*/
// ������� ����������
int BCJ_X86_METHOD::decompress (CALLBACK_FUNC *callback, void *auxdata)
{
  return bcj_x86_de_compress<CBCJ_x86_Decoder> (callback, auxdata);
}

#ifndef FREEARC_DECOMPRESS_ONLY

// ������� ��������
int BCJ_X86_METHOD::compress (CALLBACK_FUNC *callback, void *auxdata)
{
  return bcj_x86_de_compress<CBCJ_x86_Encoder> (callback, auxdata);
}

// �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ (�������, �������� � parse_BCJ_X86)
void BCJ_X86_METHOD::ShowCompressionMethod (char *buf)
{
  sprintf (buf, "exe");
}

#endif  // !defined (FREEARC_DECOMPRESS_ONLY)

// ������������ ������ ���� BCJ_X86_METHOD ��� ���������� NULL, ���� ��� ������ ����� ������
COMPRESSION_METHOD* parse_BCJ_X86 (char** parameters)
{
  if (strcmp (parameters[0], "exe") == 0
      &&  parameters[1]==NULL )
    // ���� �������� ������ - "exe" � ���������� � ���� ���, �� ��� ��� �����
    return new BCJ_X86_METHOD;
  else
    return NULL;   // ��� �� ����� bcj_x86
}

static int BCJ_X86_x = AddCompressionMethod (parse_BCJ_X86);   // �������������� ������ ������ BCJ_X86
