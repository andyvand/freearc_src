#include "../Compression.h"

int dict_compress   (MemSize BlockSize, int MinCompression, int MinWeakChars, int MinLargeCnt, int MinMediumCnt, int MinSmallCnt, int MinRatio, CALLBACK_FUNC *callback, void *auxdata);
int dict_decompress (MemSize BlockSize, int MinCompression, int MinWeakChars, int MinLargeCnt, int MinMediumCnt, int MinSmallCnt, int MinRatio, CALLBACK_FUNC *callback, void *auxdata);


#ifdef __cplusplus

// ���������� ������������ ���������� ������� ������ COMPRESSION_METHOD
class DICT_METHOD : public COMPRESSION_METHOD
{
public:
  // ��������� ����� ������ ������
  MemSize BlockSize;        // ������ ����� ������, ��������������� �� ���. ������ ���� �������� ���� ����������� �������
  int     MinCompression;   // ����������� ������� ������. ���� �������� ������ ������, �� ������ ��� ����� �������� ������������ (��������) ������
  int     MinWeakChars;     // ���������� ���������� ���������� weak chars. ���� ��� �������� ������ - ��������� ����� �� ������, ��������� ����� �������� weak chars ������ ��������������� � ���, ��� ��� �������� ����, ������� ����� ��������� ����� �� �������
  int     MinLargeCnt;      // ����������� "�������" �������
  int     MinMediumCnt;     // ����������� "�������" �������
  int     MinSmallCnt;      // ����������� "���������" �������
  int     MinRatio;         // ����������� "���������"

  // �����������, ������������� ���������� ������ ������ �������� �� ���������
  DICT_METHOD();

  // ������� ���������� � ��������
  virtual int decompress (CALLBACK_FUNC *callback, void *auxdata);
#ifndef FREEARC_DECOMPRESS_ONLY
  virtual int compress   (CALLBACK_FUNC *callback, void *auxdata);

  // �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � parse_DICT)
  virtual void ShowCompressionMethod (char *buf);

  // ��������/���������� ����� ������, ������������ ��� ��������/����������, ������ ������� ��� ������ �����
  virtual MemSize GetCompressionMem     (void)         {return BlockSize*2;}
  virtual MemSize GetDecompressionMem   (void)         {return 1*mb /*BlockSize*2*/;}
  virtual MemSize GetDictionary         (void)         {return BlockSize;}
  virtual MemSize GetBlockSize          (void)         {return BlockSize;}
  virtual void    SetCompressionMem     (MemSize mem)  {if (mem>0)   BlockSize = mem/2;}
  virtual void    SetDecompressionMem   (MemSize mem)  {if (mem>0)   BlockSize = mem/2;}
  virtual void    SetDictionary         (MemSize dict) {if (dict>0)  BlockSize = dict;}
  virtual void    SetBlockSize          (MemSize bs)   {if (bs>0)    BlockSize = bs;}
#endif
};

// ��������� ������ ������������� DICT
COMPRESSION_METHOD* parse_DICT (char** parameters);

#endif  // __cplusplus
