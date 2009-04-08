/* Delta: binary tables preprocessor v1.0  (c) Bulat.Ziganshin@gmail.com  2008-03-13

This algorithm preprocess data improving their further compression. It detects tables
of binary records and 1) substracts sucessive values in columns, 2) reorder columns
trying to maximize results of further compression.

Algorithm includes 3 phases:

1) Preliminary table detection. It finds 6+ repetitions of the same byte at the same distance,
   i.e. anything like a...a...a...a...a...a where '.' denotes any byte except for 'a'.
   This is done in delta_compress

2) Candidates detected at first phase are then checked by FAST_CHECK_FOR_DATA_TABLE looking for
   monotonic sequence of bytes with fixed distance. Most candidates found at first stage are
   filtered out here

3) Remaining candidates are tested by slow_check_for_data_table() that finds exact table boundaries
   and detects columns that should and that shouldn't be substracted. Only if table is large enough
   it will be finally processed

The algorithm processes 20 mb/sec on 1GHz CPU, but i'm sure that the speed may be 3-fold increased

*/



/* To-do list:
+1. �������� ����������� ������� � �������� �� �������� � ������ ������� (��� ���������)
      ��������� ���������� ����� � ������� 4 ������!
2. �������� �������� ���������� ������������� � ��������������� ��������
3. ���������� ��������� �������� �������:
     +��������� ������� � �������� ��������� � ��������� ������ ����� (sqrt(N)*rows >= X)
     +��������� ���������� �� ���������� ������� ��� ����������� ��������� ������ ������
     �������� ������ ��� �������� � ������������� �������� ����� ���������� (���� 8,16,24,32...)
4. �������� ������� �������, �������� ���������� ����������� �����/������ � �������� ������� �������,
     ��� ���� ����� ������ ����� ���� SLOW �������� ��� ������� ���������� ����� ��������
     (������ ���������� ����� �������� ����� ����� ��������)
5. ��������� LINE �� 64, �������� �������� count[i]>5, ������� hash1 � �������� ��� 1-2 ������� ������
     LINE=64; hash1 only; ������ �������� ��� N=1,2 ��� �������� ���������� �����
+6. ������������� 4 5 6 1 2 3 ��� ���� "����� �����������" ������ ���� (��������� ���� ��������� ��������)
7. ���������� last_checked?
8. ��������� DELTA=4
9. MAXELEM=64+hash1 �������� �� 35�� ������ mdb, �������� �� 12-14�� ������ skype/wwlib/ruby
   MAXELEM=32+hash1 �������� �� 20�� ������ ruby

skype - ����������� �������:
58602 17
587e0 14
cdc0ce 2

table5: table20070921181100.rar
FULL  Compression: 0.911 seconds, speed 21.394 mb/sec
-SLOW Compression: 0.480 seconds, speed 40.605 mb/sec
-FAST Compression: 0.320 seconds, speed 60.907 mb/sec

fast+slow checks by N:
total    727111
1 283578 682737
2 132068
4 162505
3 104586


Old list:
+1. ��������� ������� �� ��������� (������ C � GX)
+2. ����� ���������� ����� ����� ������������� �������� ���������� �������� ������� �� � ����� ���������
3. �� ���� ��������� ��������� ������� � ���, ���������� �� ��� ������� ������
4. ����������������? �������� ������� � ������ ��������� (���������� ����������� ������)
-5. hash *p/16 -> /8 ��� /32?
+6. �������� �� 64�� �� ������ ������� � �������������� ����������� ��� �������������
+7. ��� �������� ��������� ������� ���������� ��� �������, ��� ������ ��������� ��� ptr=table_end-32 � ������
-8. ������� ���������� ���������� ����� (� �������� ������� �������) �� � ����� ���������/xor
9. ����������, �������� ������� �������, �������� ���������� ����������� ����� � �������� ������� �������
+10. else carry = 0;
+11. if (*(int32*)ptr != *(int32*)(ptr+3))   //  a little speed optimization

�������� �������:
+1. 0C,04,FC... - ��� �������� ����� 0 �������� ������ ����� ��������,
      ������� ���� ������ difflb<itemlb/1.1? len++:omit++
+2. ���� ����� �� last_table_end ��� ��������� LINE �� 64 (�������� �������� count[i]>5)
+3. ������������ ��� ���������� ������� ����� ����� �� ��������, ��� � ��� ���������� �����?
+4. ��������� ������� � �������� ��������� � ��������� ������ ����� (sqrt(N)*rows >= X ?)
+5. CHECK_FOR_DATA_TABLE: ����������� p[-1]+p[N-1] != p[2*N-1]+p[3*N-1] ����� �� ��������
      ��-�� ���������� ���������� � ���� �������� ��������� �������
+6. DELTA=8 (����. ������� ����� ��������� ���������� � ����� �������, ������� ��������������� ��� ������� �� �������)
-7. 29-������� ������� ����������, ������ ��-�� *p/16 (�������� �� /8?)
8. �������� ������ ��� �������� � ������������� �������� ����� ���������� (���� 8,16,24,32...)
-9. �������� �������� ������� ����� ������� �� ����� ������ ����� ������� (500->400?)

���������� ���������:
+1. ���������� �����, ������� ��������
+2. ������ last_checked?
3. ������ � 64 ����� � ��� �������� (+0, +32) ��� 1-�������� ������
4. �������� ��������� ����������� ���� ��������� lines (count[i]/=2 ?)
5. �������� ���������� 1-2-������� ���������; �������� ��� ������ �� 32-� �����, unicode-�������
6. ������������ 4 ���� �� 32 �����, �������� ����� ������ ������ ������ �� 1-4-������� �������
7. ������� ������� CHECK_FOR_DATA_TABLE ��� 1, 2 � 3+ ������� ������


340ms   592 ns/line  18.5 ns/b = ������ ���������� count
470ms   634 ns/line  24.3 ns/b + ���� �� count
610ms                          + �������� ������ 1-4 �������� ������
750ms 1.230 ns/line  38.4 ns/b + �������� ���������� ������
*/

// ALGORITHM PARAMETERS ************************************************************************

// Maximum size of one table element (31 max. with current `type` encoding scheme)
#define MAX_ELEMENT_SIZE 30

// ������ ������ �����, � ������� ������ ���������� ���������
const int LINE=32;

// ������������ ���������� �� ����������� �������� � ��� �� �������,
// ������� �� ��������� ��� ����� ������� �� �������� �������
// � FAST_CHECK_FOR_DATA_TABLE
#define DELTA 8


// C HEADERS **************************************************************************************
#include "../Compression.h"


// OPTIONS FOR STANDALONE EXECUTABLE **************************************************************
#ifndef DELTA_LIBRARY
// ����� ����������, ���������� �� stdout
//   0   ������ ������
//   1   ����� ����������
//   2   ��������� ���������� � ��������
static int verbose = 0;

// �������� ����� ���������� ������� ���� ���������
static int print_timings = 1;

// Total stats for sucessfully processed tables
static uint64 table_count=0, table_sumlen=0, table_diffed=0; static double table_skipBits=0;
// Count of FAST_CHECK_FOR_DATA_TABLE and slow_check_for_data_table calls
static uint64 fast_checks=0, slow_checks=0;
#endif


// MEMORY BUFFER **********************************************************************************

// �����, ������������ ��� ����������� ���������� ����������� ������� ������
// � ���������. ����� ����� ���������� � ���� 8/16/32-��������� ����� � �����������
// ��� �������������. ������� ���������� ������ ������������ � �������� �����.
// ������������� ����� ������������ ������ ����� ���������� � ���� ������.
// ����� ���������� ����� ������ - ��� max(p,end), ��� p - ������� ���������,
// � end - ������������ ������� ����� ���������� ������.
struct Buffer
{
    byte*  buf;              // ����� ����������� ������
    byte*  p;                // ������� ��������� ������/������ ������ ����� ������
    byte*  end;              // ����� ����� ����� �����������/���������� ������
    byte*  bufend;           // ����� ������ ������
    Buffer (uint size=64*kb) { buf=p=end= (byte*) malloc(size); bufend = buf+size; }
    ~Buffer()                { free(); }
    int    len()             { return mymax(p,end)-buf; }
    void   reset()           { p=buf; }
    void   empty()           { p=end=buf; }
    void   free ()           { ::free(buf); buf=p=end=NULL; }
    void   put8 (uint x)     { reserve(sizeof(uint8 )); *(uint8 *)p=x; p+=sizeof(uint8 ); }
    void   put16(uint x)     { reserve(sizeof(uint16)); *(uint16*)p=x; p+=sizeof(uint16); }
    void   put32(uint x)     { reserve(sizeof(uint32)); *(uint32*)p=x; p+=sizeof(uint32); }
    void   reserve(uint n)   {
                               if (p+n > bufend) {
                                 uint newsize = mymax(p+n-buf, (bufend-buf)*2);
                                 byte* newbuf = (byte*) realloc (buf, newsize);
                                 bufend = newbuf + newsize;
                                 p   += newbuf-buf;
                                 end += newbuf-buf;
                                 buf  = newbuf;
                               }
                             }
// ��� ������ ������
    void   rewind()          { end=mymax(p,end); p=buf; }
    uint   get8 ()           { uint x = *(uint8 *)p; p+=sizeof(uint8 ); return x; }
    uint   get16()           { uint x = *(uint16*)p; p+=sizeof(uint16); return x; }
    uint   get32()           { uint x = *(uint32*)p; p+=sizeof(uint32); return x; }
    bool   eof()             { return p>=end; }
};

// �������� 32-������ ����� � �������� �����
#define Put32(x)                                           \
{                                                          \
    Buffer header(sizeof(int32));                          \
    header.put32 (x);                                      \
    WRITE (header.buf, header.len());                      \
    header.free();                                         \
}


// UTILITY FUNCTIONS ******************************************************************************

// type �������� ������ �������. ����� �������� �������������� ���� - � ������,
// ��������� ����=1 ���� ��������������� ������� �� ����� ��������

// Encode `type` word from N, doDiff[] and immutable[] values.
inline static uint32 encode_type (int N, bool doDiff[], bool immutable[])
{
    uint32 type = 1<<N;
    for (int i=0; i<N; i++) {
        type += immutable[i] << i;
    }
    return type;
}

// Decode `type` word into N, doDiff[] and immutable[] values
static void decode_type (uint32 type, int &N, bool doDiff[], bool immutable[])
{
    int i;
    for (i=0; type>1; i++, type>>=1) {
        immutable[i] = type&1;
        doDiff[i]    = !immutable[i];
    }
    N=i;
}

// Process data table subtracting from each N-byte element contents of previous one
// (bytewise with carries starting from lower address, i.e. in LSB aka Intel byte order).
// bool doDiff[0..N-1] marks columns what should be diffed,
// other columns are left untouched. Carry saved only over adjancent diffed columns
inline static void diff_table (int N, BYTE *table_start, int table_len, bool doDiff[])
{
    for (BYTE *r = table_start + N*table_len; (r-=N) > table_start; )
        for (int i=0,carry=0; i<N; i++)
            if (doDiff[i]) {
                int newcarry = r[i] < r[i-N]+carry;
                r[i]        -= r[i-N]+carry;
                carry        = newcarry; }
            else carry = 0;
}

// Process data table adding to each element contents of previous one
static void undiff_table (int N, BYTE *table_start, int table_len, bool doDiff[])
{
    for (BYTE *r = table_start + N; r < table_start + N*table_len; r+=N)
        for (int i=0,carry=0; i<N; i++)
            if (doDiff[i]) {
                int sum = r[i]+r[i-N]+carry;
                r[i]    = sum;
                carry   = sum/256; }
            else carry = 0;

}

// Reorder table so that all immutable columns are placed before all mutable ones.
// bool immutable[0..N-1] marks immutable columns
static inline void reorder_table (int N, BYTE *table_start, int table_len, bool immutable[], Buffer &tempbuf)
{
    // First, copy all the data into temporary area
    tempbuf.reserve (N*table_len);
    memcpy (tempbuf.buf, table_start, N*table_len);

    // Then, copy contents of immutable columns into the table beginning
    BYTE *p=table_start, *q=tempbuf.buf;
    for (int i=0; i<table_len; i++)
        for (int k=0; k<N; k++, q++)
            if (immutable[k])
                *p++ = *q;

    // And last, copy rest of data to the table end
    q=tempbuf.buf;
    for (int i=0; i<table_len; i++)
        for (int k=0; k<N; k++, q++)
            if (!immutable[k])
                *p++ = *q;
}

// Undo effect of reorder_table()
static void unreorder_table (int N, BYTE *table_start, int table_len, bool immutable[], Buffer &tempbuf)
{
    // Count number of immutable columns. Exit if reordering isn't required
    int imm_columns=0; iterate_var(i,N) imm_columns+=immutable[i];
    if (imm_columns==0 || imm_columns==N)  return;

    // First, copy all data into temporary area
    tempbuf.reserve (N*table_len);
    memcpy (tempbuf.buf, table_start, N*table_len);

    // Gather immutable and mutable columns together
    BYTE *p=table_start, *q=tempbuf.buf, *q1 = tempbuf.buf+imm_columns*table_len;
    for (int i=0; i<table_len; i++)
        for (int k=0; k<N; k++)
            *p++ = immutable[k]? *q++ : *q1++;
}


#ifndef FREEARC_DECOMPRESS_ONLY
// TABLE COLUMNS ANALYSIS *********************************************************************

// Analyze which table colums need to be diffed and which ones are (almost) immutable
static void analyze_table (int N, BYTE *table_start, int table_len, bool doDiff[], bool immutable[])
{
    // �������� ������ ������� ��������
    for (int k=0; k<N; k++) {
        // ��� ������� �� ����� �� 4 ���������:
        //   (�����) �����������
        //   (�����) ����������� ����� ���������
        //   ���������� (�������� ����������� ����� ���������)
        //   ���������� "���������" ������
        // (����� ��� �������� ��� xor-���������)
        // ���� ��� �������� �� ���������� ������ ����������� �������,
        //   � ��� ��������� ������� �����������

        BYTE *p = table_start+k; int neq=0;
        for (int i=1; i<table_len; i++, p+=N) {
            neq  +=  p[N]!=p[0];
        }

        // �������� ������������ �������: ����������(p[i]!=p[i+1]) < 1/4 �� ����� ���������
        immutable[k] = neq*4 < table_len  && N!=2 && N!=4 && N!=8;
        if (immutable[k]) {
            stat (verbose>0 && printf (" %d", k));
        }
        // � ��������� ������ ���� ������� ������ �������� �� ���������
        doDiff[k] = !immutable[k];
        if (doDiff[k]) {
            stat (table_diffed += table_len);
        }
    }
}


// DISCOVERING TABLE BOUNDARIES *********************************************************************
// Check the following data for presence of table which will be better compressed
// after subtraction of subsequent elements and find it's exact boundaries

// ��������� ������� �������, �������������� � ��� ������, ����� ������� ������������ ���������� ������� ���� (�����<4)
static BYTE* search_for_table_boundary (int N, BYTE *t, byte *bufstart, byte *bufend, int &_useless)
{
    int dir = (*(int16*)(t+N) - *(int16*)t < 0)? -1:1,  len=0, omit=0, useless=_useless=0, bad=0;
    BYTE* lastpoint=t;  bool first_time=TRUE;
    for (t+=N; bufstart<=t+N && t+N+sizeof(int16)<=bufend; t+=N) {
        int diff = *(int16*)t - *(int16*)(t-N);
        uint itemlb = lb(1 + abs(*(int16*)t));
        uint difflb = lb(1 + abs(diff));
        itemlb -= itemlb > 10;  // itemlb /= 1.1 (0 <= itemlb < 20)
             if (dir<0 && diff<0) difflb < itemlb? len++,omit=0 : useless++,omit++;
        else if (dir>0 && diff>0) difflb < itemlb? len++,omit=0 : useless++,omit++;
        else if (diff==0) useless++;
        else {
            if (len>=4 || first_time)  bad=0, lastpoint = t-N*omit,  _useless=useless,  first_time = FALSE;
            else {bad++; if (bad>=2) break;}  // �����, ���� ��� ������ ������ ������� ������������ � ������ <4
            dir = (*(int16*)(t+N) - *(int16*)t < 0)? -1:1;  len=0, omit=0;
            if (dir*diff>0)  t-=N;   // ������ ������� ������������ ����� � �������� ��������, ���� ������� ����� ��� V (�����-������), � �� ����������, ���� �� ����� ��� N (������-������-������)
        }
    }
    return lastpoint;
}

// ���������, ����� �� ������� �������� ����� � ������� p � ������� ��������� N
static bool slow_check_for_data_table (int N, byte *p, uint32 &type, BYTE *&table_start, BYTE *&table_end, byte *bufstart, byte *bufend, byte *buf, uint64 &offset, Buffer &ReorderingBuffer)
{
    // ������� ��������� �����, ������� � p, � ������� ������ �������
    int useless;
    table_start = search_for_table_boundary (-N, p,           bufstart, bufend, useless);
    // ����� ��������� �����, ������� � table_start, � ������� ����� �������
    table_end   = search_for_table_boundary (N,  table_start, bufstart, bufend, useless);

    // +��������� ������� � �������� ��������� � ��������� ������ ����� (sqrt(N)*rows >= X)
    // +��������� ���������� �� ���������� ������� ��� ����������� ��������� ������ ������
    // �������� ������ ��� �������� � ������������� �������� ����� ���������� (���� 8,16,24,32...)
    // ������� ���������� ������, �������� ������� ����������� �� ��������� [��� ������� �� ��� ����]

    // ������ ��������, ���������� �� ������ ��� ������� ��� ����, ����� � ������ ������������
    int rows   = (table_end-table_start)/N;
    int useful = rows - useless;  // ���������� �������� ����� �������
    double skipBits = logb(mymax(table_start-bufstart,1));  // ������� ��� ������� ��������� �� ����������� ���� skip
    stat ((slow_checks++, verbose>1 && printf ("Slow check  %08x-%08x (%d*%d+%d)\n", int(table_start-buf+offset), int(table_end-buf+offset), N, useful, useless)));
    if (useful*sqrt((double)N) > 30+4*skipBits) {
        stat ((table_count++,  table_sumlen += N*rows, table_skipBits+=skipBits));
        stat (verbose>0 && printf("%08x-%08x %d*%d   ", int(table_start-buf+offset), int(table_end-buf+offset), N, rows));

        // ���������� ����� ������� ����� �������, � ����� �������� ��������������.
        // ������� ���������� � ������� ������������� ������� � ������ ������� (��� �������� ������ lz77)
        bool doDiff[MAX_ELEMENT_SIZE], immutable[MAX_ELEMENT_SIZE];
        analyze_table (N, table_start, rows, doDiff, immutable);
        diff_table    (N, table_start, rows, doDiff);
        reorder_table (N, table_start, rows, immutable, ReorderingBuffer);
        type = encode_type (N, doDiff, immutable);
        stat (verbose>0 && printf("\n"));
        return TRUE;
    }

    return FALSE;
}


// MAIN ALGORITHM *********************************************************************************

// Check for data table at p with N-byte elements
#define FAST_CHECK_FOR_DATA_TABLE(N,p)                                                          \
{                                                                                               \
    /* Make a quick-and-dirty check and if it's successful - call the slow check */             \
    if (uint(p[    1] - p[  N+1] + DELTA) <= 2*DELTA                                            \
    &&  uint(p[  N+1] - p[2*N+1] + DELTA) <= 2*DELTA                                            \
    &&  uint(p[2*N+1] - p[3*N+1] + DELTA) <= 2*DELTA                                            \
    &&  *(int16*)(p) + *(int16*)(p+N)  !=  *(int16*)(p+2*N) + *(int16*)(p+3*N))                 \
    {                                                                                           \
        BYTE *table_start, *table_end;  uint32 type;                                            \
        if (slow_check_for_data_table (N, p, type, table_start, table_end, last_table_end, bufend, buf, offset, ReorderingBuffer)) {  \
            encode_table (table_start-last_table_end, type, (table_end-table_start)/N);         \
            last_table_end = table_end;                                                         \
            goto found;                                                                         \
        }                                                                                       \
    }                                                                                           \
}

#define encode_table(skip, type, rows)   \
{                                        \
    TSkip.put32 (skip);                  \
    TType.put32 (type);                  \
    TRows.put32 (rows);                  \
}


int delta_compress (MemSize BlockSize, int ExtendedTables, CALLBACK_FUNC *callback, void *auxdata)
{
    int errcode = FREEARC_OK;
    byte *buf = (byte*) BigAlloc(BlockSize);  // Buffer for one block of input data (typically, 8mb long)
    if (buf==NULL)  return FREEARC_ERRCODE_NOT_ENOUGH_MEMORY;   // Error: not enough memory
    uint64 offset = 0;  // Current offset of buf[] contents relative to file (increased after each input block processd)
    Buffer TSkip, TType, TRows;    // Buffers for storing info about each table filtered
    Buffer ReorderingBuffer;       // Buffer used in reorder_table

    // Each iteration of this cycle reads, process and encodes one block of data
    for (;;)
    {
        // Read input block
        int Size;  READ_LEN_OR_EOF (Size, buf, BlockSize);

        BYTE *bufend = buf + Size;     // End of data in buf[]
        BYTE *last_table_end = buf;    // End of last table found so far
        BYTE *hash[256], *hash1[256];
        iterate_var(i,256)  hash[i] = hash1[i] = buf-1;

        for (byte *ptr=buf+LINE; ptr+MAX_ELEMENT_SIZE*4 < bufend; )
        {
if (*(int32*)ptr != *(int32*)(ptr+3))   //  a little speed optimization, mainly to skip blocks of all zeroes
{
            // ��������� ���������� ���������� ���������� ��� ������� ���� �� ������ ����������
            BYTE count[MAX_ELEMENT_SIZE]; zeroArray(count);
            BYTE *p = ptr; iterate_var(i,LINE)
            {
                int n = p - hash[*p/16];   // detecting repeated data by 4 higher bits
                hash[*p/16] = p;
                if (n<=MAX_ELEMENT_SIZE)  count[n-1]++;
#if 0
                // Detecting repeating data by all 8 bits - useful for tables with longer rows
                int n1 = p - hash1[*p];
                hash1[*p] = p;
                if (n!=n1 && n1<=MAX_ELEMENT_SIZE)  count[n1-1]++;
#endif
                p++;
            }

            // ������ ������ �� ���������, �� ������� ���� ������ 5 ���������� -
            // ��� ��������� �� ������ ������ �������
            iterate_var(i, MAX_ELEMENT_SIZE)  if (count[i] > 5)
            {
                int N = i+1;
                stat ((fast_checks+=N, verbose>1 && printf ("Fast check  %08x (%d*%d)\n", int(ptr-buf+offset), N, count[i])));

                BYTE *p = ptr;
                for (int j=0; j<N; j++, p++)  FAST_CHECK_FOR_DATA_TABLE(N,p);
            }
}
            ptr += LINE;
            continue;

            // ���� �� �������� ����� ����, ��� ������� � ������������ �������.
            // ��������� � ����������
            found:  ptr = mymax (ptr+LINE, last_table_end);
        }

        // Now the whole input block is processed and we can output the resulting data
        QUASIWRITE (sizeof(int32)*2 + TType.len()*3 + Size);
        Put32 (Size);                        // output the input block size
        Put32 (TType.len());                 // output the buffer size
        WRITE (TSkip.buf, TSkip.len());      // output the TSkip buffer contents
        WRITE (TType.buf, TType.len());      // ..
        WRITE (TRows.buf, TRows.len());      // ..
        TSkip.empty(), TType.empty(), TRows.empty();
        WRITE (buf, Size);                   // output the preprocessed data
        offset += Size;
    }

 finished:
    stat (printf("\rTables %.0lf * %.0lf = %.0lf (%.0lf) bytes (%.0lf/%.0lf probes) %.1lf skipbits\n", double(table_count), double(table_sumlen/mymax(table_count,1)), double(table_sumlen), double(table_diffed), double(slow_checks), double(fast_checks), double(table_skipBits/mymax(table_count,1))));
    BigFree(buf); return errcode;
}
#endif


// Decompression which undiffs all data tables which was diffed by table_compress()
int delta_decompress (MemSize BlockSize, int ExtendedTables, CALLBACK_FUNC *callback, void *auxdata)
{
    int errcode = FREEARC_OK;   // Error code returned by last operation or FREEARC_OK
    uint64 offset = 0;   // Current offset of buf[] contents relative to file (increased after each input block processd)
    Buffer Data, TSkip, TType, TRows,
           ReorderingBuffer;           // Buffer used in reorder_table

    // ����, ������ �������� �������� ������������ ���� ���� ������ ������
    for (;;)
    {
        // ��������� ���� ���� ������ � �������� ����������� � �� ������
        int DataSize;              READ4_OR_EOF(DataSize);       // Size of data block
        int TableSize;             READ4(TableSize);             // Size of each table describing data tables
        TSkip.reserve(TableSize);  READ (TSkip.buf, TableSize);  // Read table descriptions (see below)
        TType.reserve(TableSize);  READ (TType.buf, TableSize);
        TRows.reserve(TableSize);  READ (TRows.buf, TableSize);
        Data .reserve(DataSize);   READ (Data.buf,  DataSize);   // Finally, read block contents itself

        // Undiff all data tables in this block
        BYTE *p = Data.buf;
        for (int i=TableSize/sizeof(int32); i; i--)
        {
            int skip = TSkip.get32();   // How many bytes to skip after previous data table
            int type = TType.get32();   // Type of data table (actually, just number of bytes in each element)
            int rows = TRows.get32();   // Number of rows in table

            int N; bool doDiff[MAX_ELEMENT_SIZE], immutable[MAX_ELEMENT_SIZE];
            decode_type (type, N, doDiff, immutable);
            p += skip;
            stat (verbose>0 && printf("%08x-%08x %d*%d\n", int(p-Data.buf+offset), int(p-Data.buf+N*rows+offset), N, rows));
            unreorder_table (N, p, rows, immutable, ReorderingBuffer);
            undiff_table    (N, p, rows, doDiff);
            p += N*rows;
        }
        TSkip.empty(), TType.empty(), TRows.empty();

        // And finally write undiffed data
        WRITE (Data.buf, DataSize);  Data.empty();
        offset += DataSize;
    }
finished:
    return errcode;
}


// FUNCTIONS FOR STANDALONE EXECUTABLE ************************************************************

#ifndef DELTA_LIBRARY
#include "../Common.cpp"

// Structure for recording compression statistics and zero record of this type
struct Results {
  char *msg;                 // Mode: compression/decompression
  FILE *fin, *fout;          // Input and output files
  uint64 filesize;           // Size of input file
  uint64 insize, outsize;    // How many bytes was already read/written
  double time;               // How many time was spent in (de)compression routines
} r0;

int ReadWriteCallback (const char *what, void *buf, int size, void *r_)
{
  Results &r = *(Results*)r_;        // Accumulator for compression statistics

  if (strequ(what,"init")) {
    r.filesize = get_flen(r.fin);
    r.time -= GetGlobalTime();

  } else if (strequ(what,"read")) {
    r.time += GetGlobalTime();
    int n = file_read (r.fin, buf, size);
    r.insize += n;
    r.time -= GetGlobalTime();
    return n;

  } else if (strequ(what,"write")) {
    r.time += GetGlobalTime();
    if (r.fout)  file_write (r.fout, buf, size);
    r.outsize += size;
    if (!verbose)
    {
      char percents[10] = "";
      if (r.filesize)    sprintf (percents, "%2d%%: ", int(double(r.insize)*100/r.filesize));
      double insizeMB = double(r.insize)/1000/1000;
      if (r.time > 0.01)  printf( "\r%sprocessed %.0lf mb, %.3lf seconds, speed %.3lf mb/sec",
                                    percents, insizeMB, r.time, insizeMB/r.time);
      //    4096.00 KiB ->     1230.92 KiB (ratio  30.05%, speed  299 KiB/s)
    }
    r.time -= GetGlobalTime();
    return size;

  } else if (strequ(what,"done")) {
    r.time += GetGlobalTime();
    if (!verbose)
    {
      double insizeMB = double(r.insize)/1000/1000;
      if (r.time > 0.01)  printf( "\r%s: %.0lf mb, %.3lf seconds, speed %.3lf mb/sec     ",
                                    r.msg, insizeMB, r.time, insizeMB/r.time);
    }

  } else {
    return FREEARC_ERRCODE_NOT_IMPLEMENTED;
  }
}

// ������ ��������� ������ � ����� delta_compress/delta_decompress � ���������������� �����������
int main (int argc, char **argv)
{
    // ���������� ������ ��������?
    int unpack = 0;

    int BlockSize=8*mb, ExtendedTables=0;

    while (argv[1] && argv[1][0] == '-') {
        switch( tolower(argv[1][1]) ) {
            case 'v':   verbose++;                           break;
            case 't':   print_timings++;                     break;
            case 'd':   unpack++;                            break;
            case 'x':   ExtendedTables++;                    break;
            case 'b':   BlockSize = atoi(argv[1]+2)*(1<<20); break;
            default :   printf( "\n Unknown option '%s'\n", argv[1]);
                        exit(1);
        }
        argv++, argc--;
    }

    // ����� �����, � ��������� ������ ������ ���� ����� 1 ��� 2 ���������
    // (������� � ����������� �������� �����)
    if (argc != 2  &&  argc != 3) {
        printf( "Delta: binary tables preprocessor v1.0  (c) Bulat.Ziganshin@gmail.com  2008-03-13");
        printf( "\n" );
        printf( "\n Usage: delta [options] original-file [packed-file]");
        printf( "\n   -bN --  process data in N mb blocks");
        //printf( "\n   -x  --  enable extended tables (with 32..64-byte elements)");
        printf( "\n   -v  --  increment verbosity level (0 - default, 2 - maximum)");
        printf( "\n" );
        printf( "\n For decompress: delta -d [-v] packed-file [unpacked-file]");
        printf( "\n" );
        exit(2);
    }

    Results r = r0;

    // ������� ������� ����
    r.fin = fopen (argv[1], "rb");
    if (r.fin == NULL) {
        printf( "Can't open %s for read\n", argv[1]);
        exit(3);
    }

    // ������� �������� ����, ���� �� ����� � ��������� ������
    if (argc == 3) {
        r.fout = fopen (argv[2], "wb");
        if (r.fout == NULL) {
            printf( "Can't open %s for write\n", argv[2]);
            exit(4);
        }
    } else {
        r.fout = NULL;
    }

    // (De)compress
    ReadWriteCallback ("init", NULL, 0, (void*)&r);
    if (!unpack) {
        r.msg = "Compression";
        delta_compress   (BlockSize, ExtendedTables, ReadWriteCallback, &r);
    } else {
        r.msg = "Decompression";
        delta_decompress (BlockSize, ExtendedTables, ReadWriteCallback, &r);
    }
    ReadWriteCallback ("done", NULL, 0, (void*)&r);

    fclose(r.fin);  if (r.fout)  fclose(r.fout);
    return 0;
}

#endif

