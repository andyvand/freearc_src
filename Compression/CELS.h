#ifndef FREEARC_COMPRESSION_H
#define FREEARC_COMPRESSION_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <math.h>
#include <time.h>

#include "Common.h"
#include "_TABI\tabi.h"


#ifdef __cplusplus
extern "C" {
#endif

// ****************************************************************************************************************************
// ����������� �������� *******************************************************************************************************
// ****************************************************************************************************************************

//���� ������
#define FREEARC_OK                               0     /* ALL RIGHT */
#define FREEARC_ERRCODE_GENERAL                  (-1)  /* Some error when (de)compressing */
#define FREEARC_ERRCODE_INVALID_COMPRESSOR       (-2)  /* Invalid compression method or parameters */
#define FREEARC_ERRCODE_ONLY_DECOMPRESS          (-3)  /* Program builded with FREEARC_DECOMPRESS_ONLY, so don't try to use compress */
#define FREEARC_ERRCODE_OUTBLOCK_TOO_SMALL       (-4)  /* Output block size in (de)compressMem is not enough for all output data */
#define FREEARC_ERRCODE_NOT_ENOUGH_MEMORY        (-5)  /* Can't allocate memory needed for (de)compression */
#define FREEARC_ERRCODE_IO                       (-6)  /* Error when reading or writing data */
#define FREEARC_ERRCODE_BAD_COMPRESSED_DATA      (-7)  /* Data can't be decompressed */
#define FREEARC_ERRCODE_NOT_IMPLEMENTED          (-8)  /* Requested feature isn't supported */
#define FREEARC_ERRCODE_NO_MORE_DATA_REQUIRED    (-9)  /* Required part of data was already decompressed */


// ��������� ��� ������� ������ ������� ������
#define b_ (1u)
#define kb (1024*b_)
#define mb (1024*kb)
#define gb (1024*mb)

// ���������� ����, ������� ������ ��������/������������ �� ���� ��� �� ���� �����������
#define BUFFER_SIZE (64*kb)

// ���������� ����, ������� ������ ��������/������������ �� ���� ��� � ������� ������� � ��� ���������� ������������� ����������
#define LARGE_BUFFER_SIZE (256*kb)

// ���������� ����, ������� ������ ��������/������������ �� ���� ��� � ����� ������� ������� (storing, tornado � ���� ��������)
// ���� ����� ������������ ������ �� disk seek operations - ��� �������, ��� ������������ �� ���������� �/� � ������ ������ ;)
#define HUGE_BUFFER_SIZE (8*mb)

// �������������� ����������� ��� �������� �������� �������� ����� ������� ������
#define COMPRESSION_METHODS_DELIMITER            '+'   /* ����������� ���������� ������ � ��������� �������� ����������� */
#define COMPRESSION_METHOD_PARAMETERS_DELIMITER  ':'   /* ����������� ���������� � ��������� �������� ������ ������ */
#define MAX_COMPRESSION_METHODS    1000        /* ������ ���� �� ������ ����� ������� ������, �������������� � ������� AddCompressionMethod */
#define MAX_PARAMETERS             200         /* ������ ���� �� ������ ������������� ���-�� ���������� (���������� �����������), ������� ����� ����� ����� ������ */
#define MAX_METHOD_STRLEN          2048        /* ������������ ����� ������, ����������� ����� ������ */
#define MAX_METHODS_IN_COMPRESSOR  100         /* ������������ ����� ������� � ����� ����������� */
#define MAX_EXTERNAL_COMPRESSOR_SECTION_LENGTH 2048  /* ������������ ����� ������ [External compressor] */


// ****************************************************************************************************************************
// �����, ����������� ��������� � ������ ������ *******************************************************************************
// ****************************************************************************************************************************

typedef TABI_FUNCTION CALLBACK_FUNC;

namespace CELS
{

struct COMPRESSION_METHOD
{
  TABI_MAP p;      // Call parameters
  double addtime;  // �������������� �����, ����������� �� ������ (�� ������� ����������, �������������� threads � �.�.)

  // Methods
  COMPRESSION_METHOD (TABI_ELEMENT* params) : p(params) {addtime=0;};
  virtual ~COMPRESSION_METHOD() {}
  virtual void parse_method() = 0;
  virtual int  server();

  // ������� ���������� � ��������
  virtual int decompress (CALLBACK_FUNC *callback, void *auxdata) = 0;
#ifndef FREEARC_DECOMPRESS_ONLY
  virtual int compress   (CALLBACK_FUNC *callback, void *auxdata) = 0;

  // �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � ParseCompressionMethod)
  virtual void ShowCompressionMethod (char *buf) = 0;

  // ���������� � ������, ����������� ��� ��������/����������,
  // ������� ������� (�� ���� ��������� ������ ����������� �������� � ������ ������� ������ - ��� lz/bs ����),
  // � ������� ����� (�� ���� ������� �������� ������ ����� ����� �������� � ���� �����-���� - ��� bs ���� � lzp)
  virtual MemSize GetCompressionMem   (void)         = 0;
  virtual MemSize GetDictionary       (void)         = 0;
  virtual MemSize GetBlockSize        (void)         {return 0;}
  // ��������� ����� ������ �� ������������� ��������� ���-�� ������, ������� ��� ������� �����
  virtual void    SetCompressionMem   (MemSize mem)  = 0;
  virtual void    SetDecompressionMem (MemSize mem)  = 0;
  virtual void    SetDictionary       (MemSize dict) = 0;
  virtual void    SetBlockSize        (MemSize bs)   {return;}
  // ���������� ������������ ��� ��������/���������� ������, ��� ������� / ������ �����
  void LimitCompressionMem   (MemSize mem)  {if (GetCompressionMem()   > mem)   SetCompressionMem(mem);}
  void LimitDecompressionMem (MemSize mem)  {if (GetDecompressionMem() > mem)   SetDecompressionMem(mem);}
  void LimitDictionary       (MemSize dict) {if (GetDictionary()       > dict)  SetDictionary(dict);}
  void LimitBlockSize        (MemSize bs)   {if (GetBlockSize()        > bs)    SetBlockSize(bs);}
#endif
  virtual MemSize GetDecompressionMem (void) = 0;
};

}

// Compression method registration
int CELS_Register (TABI_FUNCTION *method);
// Central CELS function that provides all CELS services
int CELS_Call (TABI_ELEMENT* params);


// ****************************************************************************************************************************
// ������� ������/������ ������ � ������� ������ ******************************************************************************
// ****************************************************************************************************************************

// Auxiliary code to read/write data blocks and 4-byte headers
#define INIT() callback (TABI_DYNAMAP("request","init"))
#define DONE() callback (TABI_DYNAMAP("request","done"))

#define MALLOC(type, ptr, size)                                            \
{                                                                          \
    (ptr) = (type*) malloc ((size) * sizeof(type));                        \
    if ((ptr) == NULL) {                                                   \
        errcode = FREEARC_ERRCODE_NOT_ENOUGH_MEMORY;                       \
        goto finished;                                                     \
    }                                                                      \
}

#define BIGALLOC(type, ptr, size)                                          \
{                                                                          \
    (ptr) = (type*) BigAlloc ((size) * sizeof(type));                      \
    if ((ptr) == NULL) {                                                   \
        errcode = FREEARC_ERRCODE_NOT_ENOUGH_MEMORY;                       \
        goto finished;                                                     \
    }                                                                      \
}

#define READ(buf, size)                                                    \
{                                                                          \
    void *localBuf = (buf);                                                \
    int localSize  = (size);                                               \
    if (localSize  &&  (errcode=callback(TABI_DYNAMAP("request","read") ("buf",localBuf) ("size",localSize))) != localSize) { \
        if (errcode>=0) errcode=FREEARC_ERRCODE_IO;                        \
        goto finished;                                                     \
    }                                                                      \
}

#define READ_LEN(len, buf, size)                                           \
{                                                                          \
    if ((errcode=(len)=callback(TABI_DYNAMAP("request","read") ("buf",(void*)(buf)) ("size",size))) < 0) {            \
        goto finished;                                                     \
    }                                                                      \
}

#define READ_LEN_OR_EOF(len, buf, size)                                    \
{                                                                          \
    if ((errcode=(len)=callback(TABI_DYNAMAP("request","read") ("buf",(void*)(buf)) ("size",size))) <= 0) {            \
        goto finished;                                                     \
    }                                                                      \
}

#define WRITE(buf, size)                                                   \
{                                                                          \
    void *localBuf = (buf);                                                \
    int localSize  = (size);                                               \
    /* "write" callback on success guarantees to write all the data and may return 0 */ \
    if (localSize && (errcode=callback(TABI_DYNAMAP("request","write") ("buf",localBuf) ("size",localSize)))<0)  \
        goto finished;                                                     \
}

#define READ4(var)                                                         \
{                                                                          \
    unsigned char localHeader[4];                                          \
    READ (localHeader, 4);                                                 \
    (var) = value32 (localHeader);                                         \
}

#define READ4_OR_EOF(var)                                                  \
{                                                                          \
    int localHeaderSize;                                                   \
    unsigned char localHeader[4];                                          \
    READ_LEN_OR_EOF (localHeaderSize, localHeader, 4);                     \
    if (localHeaderSize!=4)  {errcode=FREEARC_ERRCODE_IO; goto finished;}  \
    (var) = value32 (localHeader);                                         \
}

#define WRITE4(value)                                                      \
{                                                                          \
    unsigned char localHeader[4];                                          \
    setvalue32 (localHeader, value);                                       \
    WRITE (localHeader, 4);                                                \
}

#define QUASIWRITE(size)                                                   \
{                                                                          \
    callback(TABI_DYNAMAP("request","quasiwrite") ("bytes",size));         \
}

#define ReturnErrorCode(x)                                                 \
{                                                                          \
    errcode = (x);                                                         \
    goto finished;                                                         \
}                                                                          \


// Buffered data output
#ifndef FREEARC_STANDALONE_TORNADO
#define FOPEN()   Buffer fbuffer(BUFFER_SIZE)
#define FWRITE(buf, size)                                                  \
{                                                                          \
    void *flocalBuf = (buf);                                               \
    int flocalSize = (size);                                               \
    int rem = fbuffer.remainingSpace();                                    \
    if (flocalSize>=4096) {                                                \
        FFLUSH();                                                          \
        WRITE(flocalBuf, flocalSize);                                      \
    } else if (flocalSize < rem) {                                         \
        fbuffer.put (flocalBuf, flocalSize);                               \
    } else {                                                               \
        fbuffer.put (flocalBuf, rem);                                      \
        FFLUSH();                                                          \
        fbuffer.put ((byte*)flocalBuf+rem, flocalSize-rem);                \
    }                                                                      \
}
#define FFLUSH()  { WRITE (fbuffer.buf, fbuffer.len());  fbuffer.empty(); }
#define FCLOSE()  { FFLUSH();  fbuffer.free(); }
#endif // !FREEARC_STANDALONE_TORNADO


// ****************************************************************************************************************************
// ENCRYPTION ROUTINES *****************************************************************************************************
// ****************************************************************************************************************************

// Generates key based on password and salt using given number of hashing iterations
void Pbkdf2Hmac (const BYTE *pwd, int pwdSize, const BYTE *salt, int saltSize,
                 int numIterations, BYTE *key, int keySize);

int fortuna_size (void);


#ifdef __cplusplus
}       // extern "C"
#endif

#endif  // FREEARC_COMPRESSION_H
