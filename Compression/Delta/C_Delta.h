#include "../Compression.h"

int delta_compress   (MemSize BlockSize, int ExtendedTables, CALLBACK_FUNC *callback, void *auxdata);
int delta_decompress (MemSize BlockSize, int ExtendedTables, CALLBACK_FUNC *callback, void *auxdata);


#ifdef __cplusplus

// ���������� ������������ ���������� ������� ������ COMPRESSION_METHOD
class DELTA_METHOD : public COMPRESSION_METHOD
{
public:
  // ��������� ����� ������ ������
  MemSize BlockSize;        // ������ ����� ������, �������������� �� ���� ���
  int     ExtendedTables;   // ������ ������� � �������� ��������, �������� �� 2/4

  // �����������, ������������� ���������� ������ ������ �������� �� ���������
  DELTA_METHOD();

  // ������� ���������� � ��������
  virtual int decompress (CALLBACK_FUNC *callback, void *auxdata);
#ifndef FREEARC_DECOMPRESS_ONLY
  virtual int compress   (CALLBACK_FUNC *callback, void *auxdata);

  // �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � parse_DELTA)
  virtual void ShowCompressionMethod (char *buf);

  // ��������/���������� ����� ������, ������������ ��� ��������/����������, ������ ������� ��� ������ �����
  virtual MemSize GetCompressionMem     (void)         {return BlockSize;}
  virtual MemSize GetDecompressionMem   (void)         {return BlockSize;}
  virtual MemSize GetDictionary         (void)         {return 0;}
  virtual MemSize GetBlockSize          (void)         {return 0;}
  virtual void    SetCompressionMem     (MemSize mem)  {if (mem>0)   BlockSize = mem;}
  virtual void    SetDecompressionMem   (MemSize mem)  {if (mem>0)   BlockSize = mem;}
  virtual void    SetDictionary         (MemSize dict) {}
  virtual void    SetBlockSize          (MemSize bs)   {}
#endif
};

// ��������� ������ ������ ������ DELTA
COMPRESSION_METHOD* parse_DELTA (char** parameters);

#endif  // __cplusplus
