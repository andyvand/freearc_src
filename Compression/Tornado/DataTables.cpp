// (c) Bulat Ziganshin <Bulat.Ziganshin@gmail.com>
// GPL'ed code for data tables preprocessing (subtracting) which improves compression
#include "../Compression.h"

// Maximum size of one table row at compression
#define MAX_TABLE_ROW 64

// Maximum size of one table row at decompression
#define MAX_TABLE_ROW_AT_DECOMPRESSION 256

// Pad required before and after decompression output buffer to support undiffing
#define PAD_FOR_TABLES (MAX_TABLE_ROW_AT_DECOMPRESSION*2)


// Utility part ******************************************************************************

// Process data table subtracting from each N-byte element contents of previous one
// (bytewise with carries starting from lower address, i.e. in LSB aka Intel byte order)
static void diff_table (int N, BYTE *table_start, int table_len)
{
    for (BYTE *r = table_start + N*table_len; (r-=N) > table_start; )
        for (int i=0,carry=0,newcarry; i<N; i++)
            newcarry = r[i] < r[i-N]+carry,
            r[i] -= r[i-N]+carry,
            carry = newcarry;
}

// Process data table adding to each element contents of previous one
static void undiff_table (int N, BYTE *table_start, int table_len)
{
    for (BYTE *r = table_start + N; r < table_start + N*table_len; r+=N)
        for (int i=0,carry=0,temp; i<N; i++)
            temp = r[i]+r[i-N]+carry,
            r[i] = temp,
            carry = temp/256;
}


// Compression part ******************************************************************************

#ifndef FREEARC_DECOMPRESS_ONLY
// Check the following data for presence of table which will be better compressed
// after subtraction of subsequent elements
// ��������� ���������� �� ���������� �������� ����� ��������� ��������� ������ � match finders
static uint64 table_count=0, table_sumlen=0;     // Total stats for sucessfully processed tables
#define value16s(t)  ((int16) value16(t))
static bool check_for_data_table (int N, int &type, int &items, byte *p, byte *bufend, byte *&table_end, byte *buf, uint64 &offset, byte *(&last_checked)[MAX_TABLE_ROW][MAX_TABLE_ROW])
{
    CHECK (N<MAX_TABLE_ROW,  (s,"Fatal error: check_for_data_table() called with N=%d that is larger than maximum allowed %d", N, MAX_TABLE_ROW-1));
    byte *&last = last_checked[N][(p-buf)%N];
    if (last > p)    return FALSE;

    byte *t = p - 2, *lastpoint;
    //printf ("\nStarted  %x    ", p-buf+offset);
    int lensum=600, len=0, dir = value16s(t + N) - value16s(t) < 0? -1:1, lenminus=0;
    for (t = lastpoint = t + N; t + 2 <= bufend; t += N) {
        int diff = value16s(t) - value16s(t - N);
        double itemlb = logb(1 + abs(value16s(t)));
        double difflb = logb(1 + abs(diff));
             if (dir<0 && diff<0 && difflb < itemlb/1.1)  len++;
        else if (dir>0 && diff>0 && difflb < itemlb/1.1)  len++;
        else if (diff==0) lenminus++;
        else {
            if (len>3)  lastpoint=t;
            lensum-=lensum/8, lensum+=mymin(len,10)*30, dir=diff<0?-1:1, len=0;
            if (lensum<500) break;
        }
    }

    last = t;

    if (t-p > N*(40+lenminus) && lastpoint-p > mymax(N,20)) {
        type = N; items = (lastpoint-p)/type;
        diff_table (type, p, items);
        table_end = p+type*items;
        table_count++;  table_sumlen += type*items;
        stat (printf("%08x-%08x %d*%d\n", int(p-buf+offset), int(p-buf+offset+type*items), type, items));
        //stat (printf ("\n%d: Start %x, end %x, length %d      ", type, int(p-buf+offset), int(table_end-buf+offset), items));
        return TRUE;
    }

    return FALSE;
}
#endif


// Decompression part ******************************************************************************

// Info about one data table that should be undiffed
struct DataTableEntry {int table_type; BYTE *table_start; int table_len;};

// List of data tables that was not yet undiffed.
// The things become especially interesting for tables divided between two write chunks :D
struct DataTables
{
   DataTableEntry   *tables, *curtable, *tables_end;   // Pointers to the start, cuurent entry and end of allocated DataTableEntries table
   byte              base_data[MAX_TABLE_ROW_AT_DECOMPRESSION];  // Place for saving intermediate base element of table divided between two write chunks

   DataTables();
   ~DataTables()   {free(tables);}

   // Add description of one more datatable to the list
   void add (int _table_type, BYTE *_table_start, int _table_len);

   // Check that list is already filled so data should be written to outstream
   // (within frame of undiff/diff calls) prior to further processing
   bool filled();

   enum OPERATION {DO_DIFF, DO_UNDIFF};
   // Either diff or undiff all tables in list until buffer point marked by write_end pointer
   void process_tables (OPERATION op, BYTE *write_end);

   // Undiff contents of tables in current list, preparing data buffer to be saved to outstream
   void undiff_tables (BYTE *write_start, BYTE *write_end);

   // Called after data was written. It diffs tables again so that their contents
   // may be used in subsequent LZ decompression. It also clears list of datatables,
   // leaving only last table if this table continues after write_end pointer
   void diff_tables (BYTE *write_end);

   // Called when buffer shifts to new position relative to file -
   // list entries also need to be shifted
   void shift (BYTE *old_pos, BYTE *new_pos);
};


DataTables::DataTables()
{
    const int ENTRIES = 10000;   // Number of entries in the list. When list overflows, data in outbuf are processed and written to outstream
    tables     = (DataTableEntry *) malloc (sizeof(DataTableEntry) * ENTRIES);
    curtable   = tables;
    tables_end = tables + ENTRIES;
}

// Add description of one more datatable to the list
void DataTables::add (int _table_type, BYTE *_table_start, int _table_len)
{
    CHECK (curtable<tables_end,                       (s,"Fatal error: DataTables::add() called without prior filled() check"));
    CHECK (_table_type<=MAX_TABLE_ROW_AT_DECOMPRESSION,  (s,"Fatal error: DataTables::add() called with _table_type=%d that is larger than maximum allowed %d", _table_type, MAX_TABLE_ROW_AT_DECOMPRESSION));
    curtable->table_type  = _table_type;
    curtable->table_start = _table_start;
    curtable->table_len   = _table_len;
    curtable++;
}

// Check that list is already filled so data should be written to outstream
// (within frame of undiff/diff calls) prior to further processing
bool DataTables::filled()
{
    return curtable==tables_end;
}

enum OPERATION {DO_DIFF, DO_UNDIFF};
// Either diff or undiff all tables in list until buffer point marked by write_end pointer
void DataTables::process_tables (OPERATION op, BYTE *write_end)
{
    for (DataTableEntry *p=tables; p<curtable; p++) {
         //printf ("\n%d %x-%x, len=%d   ", p->table_type, table_start-outbuf, p->table_start-outbuf+p->table_len*p->table_type, p->table_len*p->table_type),
         // Truncate number of processed elements if table ends after output pointer
         int len = mymin (p->table_len, 1 + (write_end - p->table_start) / p->table_type);
         if (op==DO_DIFF)   diff_table (p->table_type, p->table_start, len);
         else             undiff_table (p->table_type, p->table_start, len);
    }
}

// Undiff contents of tables in current list, preparing data buffer to be saved to outstream
void DataTables::undiff_tables (BYTE *write_start, BYTE *write_end)
{
    // Check that first table in list continues from previous write chunk
    if (curtable>tables && tables[0].table_start < write_start)  {
        // Put correct base element (saved from previous write chunk) to the beginning of first table
        // for the duration of undiffing process but then restore original bytes
        byte original[MAX_TABLE_ROW_AT_DECOMPRESSION];
        int bytes = mymin (tables[0].table_type, write_start-tables[0].table_start);
        memcpy (original,               tables[0].table_start,  bytes);
        memcpy (tables[0].table_start,  base_data,              bytes);
        process_tables (DO_UNDIFF, write_end);
        memcpy (tables[0].table_start,  original,               bytes);
    } else {
        process_tables (DO_UNDIFF, write_end);
    }
}

// Called after data was written. It diffs tables again so that their contents
// may be used in subsequent LZ decompression. It also clears list of datatables,
// leaving only last table if this table continues after write_end pointer
void DataTables::diff_tables (BYTE *write_end)
{
    if (curtable > tables) {
        DataTableEntry p = curtable[-1];
        // Number of elements in last datatable that entirely belongs to current write chunk
        int processed = (write_end - p.table_start) / p.table_type;
        // If the datatable continues after the end of write chunk then we need to process rest of table data when writing next chunk
        if (processed < p.table_len) {
            // Keep two more elements - one as base for undiffing and another because it may be divided between two write chunks
            processed = mymax (processed-2, 0);
            // Make the table entry shorter by number of elements already processed
            p.table_start += processed * p.table_type;
            p.table_len   -= processed;
            // Save base element contents of the table before diffing
            memcpy (base_data, p.table_start, p.table_type);
            // Diff buffer data in order to return them to their original state and empty the list
            process_tables (DO_DIFF, write_end);
            curtable = tables;
            // Put unprocessed tail of last datatable into start of the list
            *curtable++ = p;
            return;
        }
    }
    // Default route - we don't need to keep tails, so just diff and empty the list
    process_tables (DO_DIFF, write_end);
    curtable = tables;
}

// Called when buffer shifts to new position relative to file -
// list entries also need to be shifted
void DataTables::shift (BYTE *old_pos, BYTE *new_pos)
{
    CHECK (old_pos > new_pos,    (s,"Fatal error: DataTables::shift() was called with reversed arguments order"));
    CHECK (curtable <= tables+1, (s,"Fatal error: DataTables::shift() called when list of tables contains more than one entry"));
    for (DataTableEntry *p=tables; p<curtable; p++) {
        BYTE *old = p->table_start;
        p->table_start -= old_pos-new_pos;
        // Copy a few first bytes of table that belongs to previous write chunk into place
        // *before* buffer beginning (and therefore before new write chunk) -
        // these bytes required for correct undiffing
        memcpy (p->table_start, old, new_pos - p->table_start);
    }
}

