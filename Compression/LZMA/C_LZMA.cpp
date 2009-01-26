// C_LZMA.cpp - ��������� FreeArc � ��������� ������ LZMA

#ifdef WIN32
#include <windows.h>
#include <initguid.h>
#else
#define INITGUID
#endif

// Enable multithreading support
#define COMPRESS_MF_MT

extern "C" {
#include "C_LZMA.h"
}

enum
{
  kBT2,
  kBT3,
  kBT4,
  kHC4,
  kHT4
};

static const char *kMatchFinderIDs[] =
{
  "BT2",
  "BT3",
  "BT4",
  "HC4",
  "HT4"
};

static int FindMatchFinder(const char *s)
{
  for (int m = 0; m < (int)(sizeof(kMatchFinderIDs) / sizeof(kMatchFinderIDs[0])); m++)
    if (!strcasecmp(kMatchFinderIDs[m], s))
      return m;
  return -1;
}

// ������� � ���� .o ���� ��� ����������� ������������
// #include "Common/Alloc.cpp"
#include "7zip/Common/InBuffer.cpp"
#include "7zip/Compress/LZ/LZOutWindow.cpp"
#include "7zip/Compress/LZMA/LZMADecoder.cpp"
#include "7zip/Common/OutBuffer.cpp"
#ifndef FREEARC_DECOMPRESS_ONLY
#include "Common/CRC.cpp"
#include "7zip/Compress/LZ/LZInWindow.cpp"
#ifdef COMPRESS_MF_MT
// #include "Windows/Synchronization.cpp"  -- moved to CompressionLibrary.cpp which should be linked into every program that uses Compression Library
#include "7zip/Compress/LZ/MT/MT.cpp"
#endif
#include "7zip/Compress/RangeCoder/RangeCoderBit.cpp"
#include "7zip/Compress/LZMA/LZMAEncoder.cpp"
#endif  // !defined (FREEARC_DECOMPRESS_ONLY)

using namespace NCompress::NLZMA;


class CallbackInStream:
  public ISequentialInStream,
  public CMyUnknownImp
{
  CALLBACK_FUNC *callback;
  void     *auxdata;
  bool          first_read;
public:
  int errcode;
  STDMETHOD_(ULONG, AddRef)()  { return 1; }
  STDMETHOD_(ULONG, Release)() { return 1; }
  STDMETHOD(QueryInterface)(REFGUID, void **) { return E_NOINTERFACE; }

  CallbackInStream(CALLBACK_FUNC *_callback, void *_auxdata) : callback(_callback), auxdata(_auxdata), errcode(0) {first_read=TRUE;}
  virtual ~CallbackInStream() {}
  STDMETHOD(Read)(void *data, UInt32 size, UInt32 *processedSize);
  STDMETHOD(ReadPart)(void *data, UInt32 size, UInt32 *processedSize);
};

STDMETHODIMP CallbackInStream::Read(void *data, UInt32 size, UInt32 *processedSize)
{
  if(processedSize != NULL)
    *processedSize = 0;
  ssize_t res;
  if (compress_all_at_once) {
    // Read whole buffer at the first call
    res  =  first_read? callback ("read", data, (size_t) size, auxdata)
                      : 0;
  } else {
    // Read data in the BUFFER_SIZE chunks
    res  =  callback ("read", data, mymin((size_t) size, BUFFER_SIZE), auxdata);
  }
  first_read = FALSE;
  if (res < 0) {
    errcode = res;
    return E_FAIL;
  }
  if(processedSize != NULL)
    *processedSize = (UInt32)res;
  return S_OK;
}

STDMETHODIMP CallbackInStream::ReadPart(void *data, UInt32 size, UInt32 *processedSize)
{
  return Read(data, size, processedSize);
}



class CallbackOutStream:
  public ISequentialOutStream,
  public CMyUnknownImp
{
  CALLBACK_FUNC *callback;
  void     *auxdata;
public:
  int errcode;
  STDMETHOD_(ULONG, AddRef)()  { return 1; }
  STDMETHOD_(ULONG, Release)() { return 1; }
  STDMETHOD(QueryInterface)(REFGUID, void **) { return E_NOINTERFACE; }

  CallbackOutStream(CALLBACK_FUNC *_callback, void *_auxdata) : callback(_callback), auxdata(_auxdata), errcode(0) {}
  virtual ~CallbackOutStream() {}
  STDMETHOD(Write)(const void *data, UInt32 size, UInt32 *processedSize);
  STDMETHOD(WritePart)(const void *data, UInt32 size, UInt32 *processedSize);
};

STDMETHODIMP CallbackOutStream::Write(const void *data, UInt32 size, UInt32 *processedSize)
{
  if(processedSize != NULL)
    *processedSize = 0;
  ssize_t res = callback ("write", (void*)data, (size_t)size, auxdata);
  if (res < 0) {
    errcode = res;
    return E_FAIL;
  }
  if(processedSize != NULL)
    *processedSize = (UInt32)size;
  return S_OK;
}

STDMETHODIMP CallbackOutStream::WritePart(const void *data, UInt32 size, UInt32 *processedSize)
{
  return Write(data, size, processedSize);
}


#ifndef FREEARC_DECOMPRESS_ONLY

int lzma_compress  ( int dictionarySize,
                     int hashSize,
                     int algorithm,
                     int numFastBytes,
                     int matchFinder,
                     int matchFinderCycles,
                     int posStateBits,
                     int litContextBits,
                     int litPosBits,
                     CALLBACK_FUNC *callback,
                     void *auxdata )
{
  CallbackInStream  inStream  (callback, auxdata);
  CallbackOutStream outStream (callback, auxdata);
  NCompress::NLZMA::CEncoder* encoder = new NCompress::NLZMA::CEncoder;

  bool eos = (1==1);  // use End-Of-Stream marker because we don't know filesize apriori

  if (encoder->SetupProperties (dictionarySize,
                                hashSize,
                                posStateBits,
                                litContextBits,
                                litPosBits,
                                algorithm,
                                numFastBytes,
                                matchFinder,
                                matchFinderCycles,
                                GetCompressionThreads() > 1,
                                eos) != S_OK)
  {
    delete encoder;
    return FREEARC_ERRCODE_INVALID_COMPRESSOR;
  }

  HRESULT result = encoder->Code (&inStream, &outStream, 0, 0, 0);
  delete encoder;
  if (inStream.errcode)
    return inStream.errcode;
  if (outStream.errcode)
    return outStream.errcode;
  if (result == E_OUTOFMEMORY)
  {
    return FREEARC_ERRCODE_NOT_ENOUGH_MEMORY;
  }
  else if (result != S_OK)
  {
    //fprintf(stderr, "\nEncoder error = %X\n", (unsigned int)result);
    return FREEARC_ERRCODE_GENERAL;
  }
  return 0;
}

#endif  // !defined (FREEARC_DECOMPRESS_ONLY)

int lzma_decompress( int dictionarySize,
                     int hashSize,
                     int algorithm,
                     int numFastBytes,
                     int matchFinder,
                     int matchFinderCycles,
                     int posStateBits,
                     int litContextBits,
                     int litPosBits,
                     CALLBACK_FUNC *callback,
                     void *auxdata )
{
  CallbackInStream  inStream  (callback, auxdata);
  CallbackOutStream outStream (callback, auxdata);
  NCompress::NLZMA::CDecoder* decoder = new NCompress::NLZMA::CDecoder;

  if (decoder->SetupProperties(dictionarySize, posStateBits, litContextBits, litPosBits) != S_OK)
  {
    delete decoder;
    return 1;
  }

  UInt64 fileSize = (UInt64)-1;

  HRESULT result = decoder->Code(&inStream, &outStream, 0, &fileSize, 0);
  delete decoder;
  if (inStream.errcode)
    return inStream.errcode;
  if (outStream.errcode)
    return outStream.errcode;
  if (result == E_OUTOFMEMORY)
  {
    return FREEARC_ERRCODE_NOT_ENOUGH_MEMORY;
  }
  if (result != S_OK)
  {
    //fprintf(stderr, "\nDecoder error = %X\n", (unsigned int)result);
    return FREEARC_ERRCODE_GENERAL;
  }
  return 0;
}



/*-------------------------------------------------*/
/* ���������� ������ LZMA_METHOD                  */
/*-------------------------------------------------*/

// ���� ������ str ���������� �� start, �� ���������� ����� �������, ����� - NULL
char* start_from (char* str, char* start)
{
  while (*start && *str==*start)  str++, start++;
  return *start? NULL : str;
}

// �����������, ������������� ���������� ������ ������ �������� �� ���������
LZMA_METHOD::LZMA_METHOD()
{
  dictionarySize    = 64*mb;
  hashSize          = 0;
  algorithm         = 1;
  numFastBytes      = 32;
  matchFinder       = kHT4;
  matchFinderCycles = 0;    // ���������� LZMA ��������� ���������� ������ �������������, ������ �� matchFinder � numFastBytes
  posStateBits      = 2;
  litContextBits    = 3;
  litPosBits        = 0;
}

// ������� ����������
int LZMA_METHOD::decompress (CALLBACK_FUNC *callback, void *auxdata)
{
  return lzma_decompress (dictionarySize,
                          hashSize,
                          algorithm,
                          numFastBytes,
                          matchFinder,
                          matchFinderCycles,
                          posStateBits,
                          litContextBits,
                          litPosBits,
                          callback,
                          auxdata);
}

#ifndef FREEARC_DECOMPRESS_ONLY

// ������� ��������
int LZMA_METHOD::compress (CALLBACK_FUNC *callback, void *auxdata)
{
  SetDictionary (dictionarySize);   // ��������� ������ ������� ����� ������ ������� � 4�� ������ :)
  // ���� LZMA ����� ������������ multithreading matchfinder,
  // �� ��� ������ ������� ����� ������ �� ��������� ����� - ������ �����
  // ������� ������������ wall clock time ����� �������� ��������
  if ((algorithm || matchFinder!=kHC4) && GetCompressionThreads()>1)
      addtime = -1;   // ��� ������ �� ������������� wall clock time
  return lzma_compress   (dictionarySize,
                          hashSize,
                          algorithm,
                          numFastBytes,
                          matchFinder,
                          matchFinderCycles,
                          posStateBits,
                          litContextBits,
                          litPosBits,
                          callback,
                          auxdata);
}


// �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � parse_LZMA)
void LZMA_METHOD::ShowCompressionMethod (char *buf)
{
  char DictionaryStr[100], HashStr[100], fcStr[100], pbStr[100], lcStr[100], lpStr[100], algStr[100];
  showMem (dictionarySize, DictionaryStr);
  showMem (hashSize, HashStr);
  LZMA_METHOD defaults;
  sprintf (fcStr, matchFinderCycles!=defaults.matchFinderCycles? ":mc%d" : "", matchFinderCycles);
  sprintf (pbStr, posStateBits     !=defaults.posStateBits     ? ":pb%d" : "", posStateBits);
  sprintf (lcStr, litContextBits   !=defaults.litContextBits   ? ":lc%d" : "", litContextBits);
  sprintf (lpStr, litPosBits       !=defaults.litPosBits       ? ":lp%d" : "", litPosBits);
  matchFinder==kHT4? (algorithm==2? sprintf (algStr, "a%d", algorithm)
                                  : sprintf (algStr, algorithm==0? "fast" : "normal"))
                   : sprintf (algStr, "%s:%s", algorithm==0? "fast": algorithm==1? "normal": "max", kMatchFinderIDs [matchFinder]);
  for (char *p=algStr; *p; p++)   *p = tolower(*p);  // strlwr(algStr);
  sprintf (buf, "lzma:%s%s%s:%s:%d%s%s%s%s",
                      DictionaryStr,
                      hashSize? ":h" : "",
                      hashSize? HashStr : "",
                      algStr,
                      numFastBytes,
                      fcStr,
                      pbStr,
                      lcStr,
                      lpStr);
  //printf("\n%s\n",buf);
}

// ���������, ������� ������ ��������� ��� �������� �������� �������
MemSize LZMA_METHOD::GetCompressionMem (void)
{
  SetDictionary (dictionarySize);   // ��������� ������ ������� ����� ������ ������� � 4�� ������ :)
  switch (matchFinder) {
    case kBT2:    return NBT2::CalcHashSize(dictionarySize,hashSize)*sizeof(NBT2::CIndex) + dictionarySize*9 + NBT2::ReservedAreaSize(dictionarySize) + 256*kb + RangeEncoderBufferSize(dictionarySize);
    case kBT3:    return NBT3::CalcHashSize(dictionarySize,hashSize)*sizeof(NBT3::CIndex) + dictionarySize*9 + NBT3::ReservedAreaSize(dictionarySize) + 256*kb + RangeEncoderBufferSize(dictionarySize);
    case kBT4:    return NBT4::CalcHashSize(dictionarySize,hashSize)*sizeof(NBT4::CIndex) + dictionarySize*9 + NBT4::ReservedAreaSize(dictionarySize) + 256*kb + RangeEncoderBufferSize(dictionarySize);
    case kHC4:    return NHC4::CalcHashSize(dictionarySize,hashSize)*sizeof(NHC4::CIndex) + dictionarySize*5 + NHC4::ReservedAreaSize(dictionarySize) + 256*kb + RangeEncoderBufferSize(dictionarySize);
    case kHT4:    return NHT4::CalcHashSize(dictionarySize,hashSize)*sizeof(NHT4::CIndex) + dictionarySize   + NHT4::ReservedAreaSize(dictionarySize) + 256*kb + RangeEncoderBufferSize(dictionarySize);
    default:      CHECK (FALSE, (s,"lzma::calcDictSize - unknown matchFinder %d", matchFinder));
  }
}

MemSize LZMA_METHOD::GetDecompressionMem (void)
{
  return dictionarySize + RangeDecoderBufferSize(dictionarySize);
}

MemSize calcDictSize (LZMA_METHOD *p, MemSize mem)
{
  double mem4 = mymax (double(mem)-256*kb, 0);
  switch (p->matchFinder) {
    case kBT2:    return (MemSize)floor(mem4/9.5);
    case kBT3:    return (MemSize)floor(mem4/11.5);
    case kBT4:    return (MemSize)floor(mem4/11.5);
    case kHC4:    return (MemSize)floor(mem4/7.5);
    case kHT4:    return (MemSize)floor(mem4/1.75);
    default:      CHECK (FALSE, (s,"lzma::calcDictSize - unknown matchFinder %d", p->matchFinder));
  }
}

// ���������� ������������� ������ ��� ��������
void LZMA_METHOD::SetCompressionMem (MemSize mem)
{
  if (mem<=0)  return;
  hashSize       = 0;
  dictionarySize = calcDictSize (this, mem);

  if (dictionarySize<32*kb) {

  // ���� ������� ��������� ������� ��������� - ������������ �� ����� ������� �������� ������.
  //   (�� ��������� ������, ��� ���������� ������������� ����������� � ������
  //     � ���� ���������� ����������, ��� �� ����� �������� ������):
  //  if (matchFinder!=HC4)
  //    matchFinder = HC4,  SetCompressionMem (mem);
  //  else
      dictionarySize = 32*kb;
  }
  // �������� ������� ���� �� 32 kb, 48 kb, 64 kb...
  uint t = 1 << lb(dictionarySize);
  if (t/2*3 <= dictionarySize)
        dictionarySize = t/2*3;
  else  dictionarySize = t;
}

// ���������� ������������� ������ ��� ����������
void LZMA_METHOD::SetDecompressionMem (MemSize mem)
{
  if (mem<=0)  return;
  dictionarySize = mem;
  // �������� ������� ���� �� 32 kb, 48 kb, 64 kb...
  uint t = 1 << lb(dictionarySize);
  if (t/2*3 <= dictionarySize)
        dictionarySize = t/2*3;
  else  dictionarySize = t;
}

// ���������� ������ �������.
void LZMA_METHOD::SetDictionary (MemSize mem)
{
  if (mem<=0)  return;
  dictionarySize = mymin (mem, roundDown (calcDictSize (this, UINT_MAX), mb));
}

#endif  // !defined (FREEARC_DECOMPRESS_ONLY)

// ������������ ������ ���� LZMA_METHOD � ��������� ����������� ��������
// ��� ���������� NULL, ���� ��� ������ ����� ������ ��� �������� ������ � ����������
COMPRESSION_METHOD* parse_LZMA (char** parameters)
{
  if (strcmp (parameters[0], "lzma") == 0) {
    // ���� �������� ������ (������� ��������) - "lzma", �� ������� ��������� ���������

    LZMA_METHOD *p = new LZMA_METHOD;
    p->matchFinder = INT_MAX;
    int error = 0;  // ������� ����, ��� ��� ������� ���������� ��������� ������

    // �������� ��� ��������� ������ (��� ������ ������ ��� ������������� ������ ��� ������� ���������� ���������)
    while (*++parameters) {
      char *param = *parameters;  bool optional = param[0]=='*';  optional && param++;
           if (start_from (param, "d"))    p->dictionarySize    = parseMem (param+1, &error);
      else if (start_from (param, "h"))   {MemSize h            = parseMem (param+1, &error);
                                           if (error)  goto unnamed;  else p->hashSize = h;}
      else if (start_from (param, "a"))    p->algorithm         = parseInt (param+1, &error);
      else if (start_from (param, "fb"))   p->numFastBytes      = parseInt (param+2, &error);
      else if (start_from (param, "mc"))   p->matchFinderCycles = parseInt (param+2, &error);
      else if (start_from (param, "lc"))   p->litContextBits    = parseInt (param+2, &error);
      else if (start_from (param, "lp"))   p->litPosBits        = parseInt (param+2, &error);
      else if (start_from (param, "pb"))   p->posStateBits      = parseInt (param+2, &error);
      else if (start_from (param, "mf"))   p->matchFinder       = FindMatchFinder (param[2]=='='? param+3 : param+2);
      else if (strequ (param, "fastest"))  p->algorithm = 0,  p->matchFinder==INT_MAX && (p->matchFinder = kHT4),  p->numFastBytes = 32,   p->matchFinderCycles = 1;
      else if (strequ (param, "fast"))     p->algorithm = 0,  p->matchFinder==INT_MAX && (p->matchFinder = kHT4),  p->numFastBytes = 32,   p->matchFinderCycles = 0;
      else if (strequ (param, "normal"))   p->algorithm = 1,  p->matchFinder==INT_MAX && (p->matchFinder = kHT4),  p->numFastBytes = 32,   p->matchFinderCycles = 0;
      else if (strequ (param, "max"))      p->algorithm = 2,  p->matchFinder==INT_MAX && (p->matchFinder = kBT4),  p->numFastBytes = 128,  p->matchFinderCycles = 0;
      else if (strequ (param, "ultra"))    p->algorithm = 2,  p->matchFinder==INT_MAX && (p->matchFinder = kBT4),  p->numFastBytes = 128,  p->matchFinderCycles = 128;
      else {
unnamed:// ���� �� ��������, ���� � ��������� ������� ��� ������������
        // ��� ����� ���� ������ - ��� MatchFinder'�, ����� ����� - �������� numFastBytes,
        // ��� ����������� ������ - �������� dictionarySize
        error = 0;
        int n = FindMatchFinder (param);
        if (n>=0)
          p->matchFinder = n;
        else {
          n = parseInt (param, &error);
          if (!error)  p->numFastBytes = n;
          else         {error=0; MemSize n = parseMem (param, &error);
                        if (!error)  p->dictionarySize = n;}
        }
      }
      if (!optional)
        if (error || p->matchFinder<0)  {delete p; return NULL;}  // ������ ��� �������� ���������� ������
    }
    if (p->matchFinder == INT_MAX)
      p->matchFinder = kHT4;   // default match finder
    return p;
  } else
    return NULL;   // ��� �� ����� lzma
}

static int LZMA_x = AddCompressionMethod (parse_LZMA);   // �������������� ������ ������ LZMA
