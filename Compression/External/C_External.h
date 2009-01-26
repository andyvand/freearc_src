#include "../Compression.h"

int external_compress   (char *packcmd, char *unpackcmd, char *datafile, char *packedfile, CALLBACK_FUNC *callback, void *auxdata);
int external_decompress (char *packcmd, char *unpackcmd, char *datafile, char *packedfile, CALLBACK_FUNC *callback, void *auxdata);

// �������� � ������� ������� ������ ��������� ������������� � arc.ini ������� ���������.
// params �������� �������� ���������� �� arc.ini. ���������� 1, ���� �������� ���������.
int AddExternalCompressor (char *params);

#ifdef __cplusplus

// ���������� ������������ ���������� ������� ������ COMPRESSION_METHOD
class EXTERNAL_METHOD : public COMPRESSION_METHOD
{
public:
  // ��������� ����� ������ ������
  char    *name;            // ��� ������ (pmm, ccm...)
  bool    can_set_mem;      // �������� ��������� ���������� � ������?
  MemSize cmem;             // ����� ������, ������������ ��� ������
  MemSize dmem;             // ����� ������, ������������ ��� ����������
  char    *datafile;        // ������������ ����� � �������������� �������
  char    *packedfile;      // ������������ ����� � ������������ �������
  char    *packcmd;         // ������� �������� ������ (datafile -> packedfile)
  char    *unpackcmd;       // ������� ���������� ������ (packedfile -> datafile)
  char    *options[MAX_PARAMETERS];             // ���. ��������� ������
  char     option_strings[MAX_METHOD_STRLEN];   // ��������� ����� ��� �������� ������ ����������
  char    *defaultopt;      // �������� ���������� �� ���������

  // ���������, ����������� ��� PPMonstr
  int     order;            // ������� ������ (�� �������� ��������� �������� ��������������� ���������)
  int     MRMethod;         // ��� ������, ����� ������, ���������� ��� �������� ������, ���������
  int     MinCompression;   // ����������� ������� ������. ���� �������� ������ ������, �� ������ ��� ����� �������� ������������ (��������) ������

  EXTERNAL_METHOD() {};
  // ������������� �����: ��� ������������� ����� �� ������� "external?"
  virtual int doit (char *what, int param, void *data, CALLBACK_FUNC *callback)
  {
      if (strequ (what,"external?"))  return 1;
      else return COMPRESSION_METHOD::doit (what, param, data, callback);
  }

  // ������� ���������� � ��������
  virtual int decompress (CALLBACK_FUNC *callback, void *auxdata);
#ifndef FREEARC_DECOMPRESS_ONLY
  virtual int compress   (CALLBACK_FUNC *callback, void *auxdata);

  // �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � parse_EXTERNAL)
  virtual void ShowCompressionMethod (char *buf);

  // ��������/���������� ����� ������, ������������ ��� ��������/����������, ������ ������� ��� ������ �����
  virtual MemSize GetCompressionMem     (void)          {return cmem;}
  virtual MemSize GetDecompressionMem   (void)          {return dmem;}
  virtual MemSize GetDictionary         (void)          {return 0;}
  virtual MemSize GetBlockSize          (void)          {return 0;}
  virtual void    SetCompressionMem     (MemSize _mem);
  virtual void    SetDecompressionMem   (MemSize _mem)  {SetCompressionMem(_mem);}
  virtual void    SetDictionary         (MemSize dict)  {}
  virtual void    SetBlockSize          (MemSize bs)    {}
#endif
};

// ��������� ������ ������������� EXTERNAL
COMPRESSION_METHOD* parse_EXTERNAL (char** parameters);

#endif  // __cplusplus
