#define TORNADO_LIBRARY
#include "Tornado.cpp"
extern "C" {
#include "C_Tornado.h"
}

/*-------------------------------------------------*/
/* ���������� ������ TORNADO_METHOD                */
/*-------------------------------------------------*/

// �����������, ������������� ���������� ������ ������ �������� �� ���������
TORNADO_METHOD::TORNADO_METHOD()
{
  m = std_Tornado_method [default_Tornado_method];
}

// ������� ����������
int TORNADO_METHOD::decompress (CALLBACK_FUNC *callback, void *auxdata)
{
  return tor_decompress (callback, auxdata);
}

#ifndef FREEARC_DECOMPRESS_ONLY

// ������� ��������
int TORNADO_METHOD::compress (CALLBACK_FUNC *callback, void *auxdata)
{
  return tor_compress (m, callback, auxdata);
}

// ���������� ������ ������� � ���������������� ������ ����
void TORNADO_METHOD::SetDictionary (MemSize dict)
{
  if (dict>0) {
    if (dict < m.buffer)
      // ��� ���������� �������: ��������� ������ ����, ���� �� ������� ����� ��� ������ ���������� �����
      m.hashsize  =  sizeof(PtrVal)  *  mymin (m.hashsize/sizeof(PtrVal), roundup_to_power_of(dict,2));
    else
      // ��� ���������� �������: ��������������� ��������� ������ ����
      if (m.hashsize > 1*mb)
      {
        if (m.hashsize<8*mb && m.hashsize<m.buffer/2)   m.hashsize = m.buffer/2;  // ��-������, �������� ������ ����, ���� �� ��� �������� ��� ��� Core2
        uint h  =  mymin (uint64(dict) / (m.buffer/64) * (m.hashsize/64),  2*gb);  // ��������� ������ ������ ����
        m.hashsize = mymin (round_to_nearest_power_of(h / m.hash_row_width, 2) * m.hash_row_width,  2*gb);  // �������� ������ ���� � ������ row_width
      }
    m.buffer = dict;
  }
}

// �������� � buf[MAX_METHOD_STRLEN] ������, ����������� ����� ������ � ��� ��������� (�������, �������� � parse_TORNADO)
void TORNADO_METHOD::ShowCompressionMethod (char *buf)
{
    struct PackMethod defaults = std_Tornado_method[m.number];  char NumStr[100], BufferStr[100], HashSizeStr[100], TempHashSizeStr[100], RowStr[100], EncStr[100], ParserStr[100], StepStr[100], TableStr[100];
    showMem (m.buffer,   BufferStr);
    showMem (m.hashsize, TempHashSizeStr);
    sprintf (NumStr,      m.number  !=default_Tornado_method? ":%d"  : "", m.number);
    sprintf (HashSizeStr, m.hashsize!=defaults.hashsize     ? ":h%s" : "", TempHashSizeStr);
    sprintf (RowStr,      m.hash_row_width  !=defaults.hash_row_width?  ":l%d"  : "", m.hash_row_width);
    sprintf (EncStr,      m.encoding_method !=defaults.encoding_method? ":c%d"  : "", m.encoding_method);
    sprintf (ParserStr,   m.match_parser    !=defaults.match_parser?    ":p%d"  : "", m.match_parser);
    sprintf (StepStr,     m.update_step     !=defaults.update_step?     ":u%d"  : "", m.update_step);
    sprintf (TableStr,    m.find_tables     !=defaults.find_tables?     ":t%d"  : "", m.find_tables);
    sprintf (buf, "tor%s:%s%s%s%s%s%s%s", NumStr, BufferStr, HashSizeStr, RowStr, EncStr, ParserStr, StepStr, TableStr);
}

#endif  // !defined (FREEARC_DECOMPRESS_ONLY)

// ������������ ������ ���� TORNADO_METHOD � ��������� ����������� ��������
// ��� ���������� NULL, ���� ��� ������ ����� ������ ��� �������� ������ � ����������
COMPRESSION_METHOD* parse_TORNADO (char** parameters)
{
  if (strcmp (parameters[0], "tor") == 0) {
    // ���� �������� ������ (������� ��������) - "tor", �� ������� ��������� ���������

    TORNADO_METHOD *p = new TORNADO_METHOD;
    int error = 0;  // ������� ����, ��� ��� ������� ���������� ��������� ������

    // �������� ��� ��������� ������ (��� ������ ������ ��� ������������� ������ ��� ������� ���������� ���������)
    while (*++parameters && !error)
    {
      char* param = *parameters;
      switch (*param) {                    // ���������, ���������� ��������
        case 'b': p->m.buffer          = parseMem (param+1, &error); continue;
        case 'h': p->m.hashsize        = parseMem (param+1, &error); continue;
        case 'l': p->m.hash_row_width  = parseInt (param+1, &error); continue;
        case 'c': p->m.encoding_method = parseInt (param+1, &error); continue;
        case 'p': p->m.match_parser    = parseInt (param+1, &error); continue;
        case 'u': p->m.update_step     = parseInt (param+1, &error); continue;
        case 't': p->m.find_tables     = parseInt (param+1, &error); continue;
      }
      // ���� �� ��������, ���� � ��������� �� ������� ��� ��������
      // ���� ���� �������� ������� ��������� ��� ����� ����� (�.�. � �� - ������ �����),
      // �� ����� �������, ��� ��� ����� �������, ����� ��������� ��������� ��� ��� buffer
      int n = parseInt (param, &error);
      if (!error)  p->m = std_Tornado_method[n];
      else         error=0, p->m.buffer = parseMem (param, &error);
    }

    if (error)  {delete p; return NULL;}  // ������ ��� �������� ���������� ������
    return p;
  } else
    return NULL;   // ��� �� ����� TORNADO
}

static int TORNADO_x = AddCompressionMethod (parse_TORNADO);   // �������������� ������ ������ TORNADO
