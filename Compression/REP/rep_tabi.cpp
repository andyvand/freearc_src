#include "../NewCompression.h"

#include "rep.cpp"

// ��������� �⠭���⭮�� ����䥩� ��⮤�� ᦠ�� COMPRESSION_METHOD
struct REP_METHOD : COMPRESSION_METHOD
{
  // ��ࠬ���� �⮣� ��⮤� ᦠ��
  MemSize BlockSize;        // ������ ����. ���������� ������ ⮫쪮 � �।���� �⮩ ���⠭樨. ���室 ����� - BlockSize+BlockSize/4
  int     MinCompression;   // ��������� ��業� ᦠ��. �᫨ ��室�� ����� �����, � ����� ��� ���� ����ᠭ� �ਣ������ (��ᦠ��) �����
  int     MinMatchLen;      // �������쭠� ����� ��ப�, �� ���ன ��� �㤥� ���������� ��뫪�� �� �।��饥 �宦�����
  int     Barrier;          // �࠭��, ��᫥ ���ன ����᪠���� �ᯮ�짮���� ᮢ������� ����襣� ࠧ��� (��᪮��� lzma/ppmd ��� ࠢ�� �ய���� ��)
  int     SmallestLen;      // ��� ����訩 ࠧ���
  int     HashSizeLog;      // ������ ࠧ��� �� (� 4-���⮢�� ᫮���). ����訥 ���祭�� 㢥��稢��� ᦠ⨥, �� ��������� ���. �� �㫥��� ���祭�� ��⨬���� ࠧ��� �������� ��⮬���᪨
  int     Amplifier;        // �����樥�� "�ᨫ����" ���᪠

  // ���������, ��ᢠ����騩 ��ࠬ��ࠬ ��⮤� ᦠ�� ���祭�� �� 㬮�砭��
  REP_METHOD();
//  rep_method (TABI_ELEMENT* params) : p(params) {};

  // �㭪樨 �ᯠ����� � 㯠�����
  virtual int decompress (CALLBACK_FUNC *callback, void *auxdata);
#ifndef FREEARC_DECOMPRESS_ONLY
  virtual int compress   (CALLBACK_FUNC *callback, void *auxdata);

  // ������� � buf[MAX_METHOD_STRLEN] ��ப�, ����뢠���� ��⮤ ᦠ�� � ��� ��ࠬ���� (�㭪��, ���⭠� � parse_REP)
  virtual void ShowCompressionMethod (char *buf);

  // �������/��⠭����� ���� �����, �ᯮ��㥬�� �� 㯠�����/�ᯠ�����, ࠧ��� ᫮���� ��� ࠧ��� �����
  virtual void    SetCompressionMem     (MemSize mem);
  virtual MemSize GetCompressionMem     (void);
  virtual void    SetDictionary         (MemSize dict) {BlockSize = dict;}
  virtual MemSize GetDictionary         (void)         {return BlockSize;}
  virtual void    SetDecompressionMem   (MemSize mem)  {BlockSize = mem;}
#endif
  virtual MemSize GetDecompressionMem   (void)         {return BlockSize;}
};

// ������騪 ��ப� ��⮤� ᦠ�� REP
COMPRESSION_METHOD* parse_REP (char** parameters);



int rep_server (char *service, TABI_ELEMENT* params)
{
  return rep_method(params).server(service);
}

int rep_register = RegisterCompressionMethod(rep_server);

