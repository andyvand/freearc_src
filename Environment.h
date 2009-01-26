#include <time.h>
#include "Compression/Common.h"

#define PRESENT_INT32

#ifdef  __cplusplus
extern "C" {
#endif

#define INIT_CRC 0xffffffff

void SetFileDateTime (const CFILENAME Filename, time_t t); // ���������� �����/���� ����������� �����
void FormatDateTime (char *buf, int bufsize, time_t t);    // ��������������� �����/���� ��� ������� ��������
CFILENAME GetExeName (CFILENAME buf, int bufsize);         // ������� ��� ������������ ����� ���������
unsigned GetPhysicalMemory (void);                         // ����� ���������� ������ ����������
unsigned GetMaxMemToAlloc (void);                          // ����. ����� ������ ������� �� ����� �������� � �������� ������������ ������ ��������
unsigned GetAvailablePhysicalMemory (void);                // ����� ��������� ���������� ������ ����������
void TestMalloc (void);                                    // �������� ���������� ��������� ������
int GetProcessorsCount (void);                             // ����� ���������� ����������� (������, ���������� ����) � �������. ������������ ��� ����������� ����, ������� "������" �������������� ������� ������������� ��������� � ���������
uint UpdateCRC (void *Addr, uint Size, uint StartCRC);     // �������� CRC ���������� ����� ������
uint CalcCRC (void *Addr, uint Size);                      // ��������� CRC ����� ������
void memxor (char *dest, char *src, uint size);            // ��-xor-��� ��� ����� ������
int systemRandomData (char *rand_buf, int rand_size);
void BuildPathTo (CFILENAME name);                         // ������� �������� �� ���� � name

#ifdef  __cplusplus
}
#endif
