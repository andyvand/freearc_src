#include "../Compression.h"

#ifndef FREEARC_DECOMPRESS_ONLY
int bcj_x86_compress   (CALLBACK_FUNC *callback, void *auxdata);
#endif
int bcj_x86_decompress (CALLBACK_FUNC *callback, void *auxdata);


#ifdef __cplusplus

// ���������� ������������ ���������� ������� ������ COMPRESSION_METHOD
class BCJ_X86_METHOD : public COMPRESSION_METHOD
{
public:
  // ������� ���������� � ��������
  virtual int decompress (CALLBACK_FUNC *callback, void *auxdata);
#ifndef FREEARC_DECOMPRESS_ONLY
  virtual int compress   (CALLBACK_FUNC *callback, void *auxdata);

  // �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ (�������, �������� � parse_BCJ_X86)
  virtual void ShowCompressionMethod (char *buf);

  // ��������/���������� ����� ������, ������������ ��� ��������/����������, ������ ������� ��� ������ �����
  virtual MemSize GetCompressionMem     (void)         {return LARGE_BUFFER_SIZE;}
  virtual MemSize GetDecompressionMem   (void)         {return LARGE_BUFFER_SIZE;}
  virtual MemSize GetDictionary         (void)         {return 0;}
  virtual MemSize GetBlockSize          (void)         {return 0;}
  virtual void    SetCompressionMem     (MemSize mem)  {}
  virtual void    SetDecompressionMem   (MemSize mem)  {}
  virtual void    SetDictionary         (MemSize dict) {}
  virtual void    SetBlockSize          (MemSize bs)   {}
#endif
};

// ��������� ������ ������ ������ BCJ_X86
COMPRESSION_METHOD* parse_BCJ_X86 (char** parameters);

#endif  // __cplusplus
