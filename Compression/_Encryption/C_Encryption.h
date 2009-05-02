#include "../Compression.h"

// ������������ ������ �����/iv/���� � ������
#define MAXKEYSIZE 64

enum TEncrypt {ENCRYPT, DECRYPT};
int docrypt (enum TEncrypt DoEncryption, int cipher, int mode, BYTE *key, int keysize, int rounds, BYTE *iv,
             CALLBACK_FUNC *callback, void *auxdata);


#ifdef __cplusplus

// ���������� ������������ ���������� ������� ������/���������� COMPRESSION_METHOD
class ENCRYPTION_METHOD : public COMPRESSION_METHOD
{
public:
  // ��������� ����� ������ ����������
  int  cipher;                   // �� ��������� ����������
  int  mode;                     // �� ������ ���������� (ctr, cfb...)
  char key [MAXKEYSIZE*2+1];     // ���� � base16 ������
  char iv  [MAXKEYSIZE*2+1];     // ������ ������������� � base16 ������
  char salt[MAXKEYSIZE*2+1];     // "����" � base16 ������
  char code[MAXKEYSIZE*2+1];     // ��� ������������ � base16 ������
  int  numIterations;            // ���������� �������� ��� ��������� ����� �� password+salt
  int  rounds;                   // ���������� ����� ��� ����������, ��� ������ - ��� ���������, �� �������. 0 - ������������ �������� �� ���������, ��������������� ����������� ���������
  int  keySize;                  // ����� ����� � ������ (0 - ������������ ������������ ���������)
  int  ivSize;                   // ����� IV � ������ (=������� ����� ��������� ����������)

  // �����������, ������������� ���������� ������ ���������� �������� �� ���������
  ENCRYPTION_METHOD();

  // ������������� �����, �������� �� ������� "encryption?", "KeySize" � "IVSize"
  virtual int doit (char *what, int param, void *data, CALLBACK_FUNC *callback);
  // ������� ���������� � ��������
  virtual int decompress (CALLBACK_FUNC *callback, void *auxdata);
#ifndef FREEARC_DECOMPRESS_ONLY
  virtual int compress   (CALLBACK_FUNC *callback, void *auxdata);

  // �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � parse_ENCRYPTION)
  virtual void ShowCompressionMethod (char *buf);

  // ��������/���������� ����� ������, ������������ ��� ��������/����������, ������ ������� ��� ������ �����
  virtual MemSize GetCompressionMem     (void)         {return 0;}
  virtual MemSize GetDictionary         (void)         {return 0;}
  virtual MemSize GetBlockSize          (void)         {return 0;}
  virtual void    SetCompressionMem     (MemSize mem)  {}
  virtual void    SetDecompressionMem   (MemSize mem)  {}
  virtual void    SetDictionary         (MemSize dict) {}
  virtual void    SetBlockSize          (MemSize bs)   {}
#endif
  virtual MemSize GetDecompressionMem   (void)         {return 0;}
};

// ��������� ������ ������ ����������
COMPRESSION_METHOD* parse_ENCRYPTION (char** parameters);

#endif  // __cplusplus
