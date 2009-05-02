#include "../Compression.h"
#include "../_CLS/cls.h"


#ifdef __cplusplus

// ���������� ������������ ���������� ������� ������ COMPRESSION_METHOD
class CLS_METHOD : public COMPRESSION_METHOD
{
public:
  // ��������� ����� ������ ������
  char     name[100];            // ��� ������ (pmm, ccm...)        ////
  char     params[100];          // ���. ��������� ������           ////
  CLS_MAIN *ClsMain;
  CALLBACK_FUNC *callback;
  void *auxdata;

  CLS_METHOD(char *_name, CLS_MAIN *_ClsMain)
    { strcpy(name, _name); ClsMain = _ClsMain; strcpy(params, ""); }

  // ������� ���������� � ��������
  virtual int decompress (CALLBACK_FUNC *callback, void *auxdata);
#ifndef FREEARC_DECOMPRESS_ONLY
  virtual int compress   (CALLBACK_FUNC *callback, void *auxdata);

  // �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � parse_CLS)
  virtual void ShowCompressionMethod (char *buf);

  // ��������/���������� ����� ������, ������������ ��� ��������/����������, ������ ������� ��� ������ �����
  virtual MemSize GetCompressionMem     (void)          {return 0;}
  virtual MemSize GetDictionary         (void)          {return 0;}
  virtual MemSize GetBlockSize          (void)          {return 0;}
  virtual void    SetCompressionMem     (MemSize)  {}
  virtual void    SetDecompressionMem   (MemSize)  {}
  virtual void    SetDictionary         (MemSize)  {}
  virtual void    SetBlockSize          (MemSize)  {}
#endif
  virtual MemSize GetDecompressionMem   (void)          {return 0;}
};

// ��������� ������ ������������� CLS
COMPRESSION_METHOD* parse_CLS (char** parameters);

#endif  // __cplusplus
