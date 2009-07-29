;[English]
;Example of using unarc.dll for decompression of FreeArc archives with displaying of progress indicator in Inno Setup window.
;
;[Russian]
;������ ���������� FreeArc ������ ��� ������ unarc.dll, � ������������ ��������� ���������� � ���� Inno Setup.
;
;���������: ��������� � ��������� Archives ������ [Code] ���� � ����� � �������� FreeArc, �������� ���� �� ���� � ������ [Files].
;����� Archives ������ ���� �������� �� ����������� ����� ���������, ��� ������� ������ ������ � [Files] ��������� �������������.
;���� ����� ����� ����� � ������������, ���� �� ����� ������ �� ����� 2��, ����� "copy /b setup.exe+xxx.arc newsetup.exe" � ������� � ���� Archives = '{srcexe}';
;������ ������������ �� ������� Inno Setup 5.2.3, 5.2.3.e7 �� ResTools, 5.2.4, 5.3.2 beta, 5.3.2-beta-Unicode.
;
; ��������� �� Bulat Ziganshin, 10-07-2009
;   - � unarc.dll ���������� ������, �������� �������������� ���������� ��� ���������� ��������� �������
;
; ��������� �� Victor_Dobrov, 09-07-2009
;   - ������� � PeekMessage 0 �� WizardForm.Handle, ����� ���� ������ ��� ��������� � �����
;   - ������� �������� �� ������������� ��� ������ ��-�� ������ FreeArc
;   - ��������� ����������� ������ ������ ������������ (� ����� ������� Escape)
;   - �� ��������� ����������� � ������ ����� ������ ������������� ������ (����� totalsize)
;   - ����� �������� ������ �� ������������ - ����� ������� ������������ � WizardForm.FileNameLabel
;   - ������ ������������ � �������� ���������� ������� ���������� �������� ����� � ����� �� ��� ����������
;   - ����������� ���������� ������� ��� ��� ���������� ������ �������������, ��� � ��� ���������� �������
;   - ��� ��������� ����� ������ ������ ������������ ��������� ����������� � �������� � ������� ������
;   - �� ����� ���������� ������ ��� ������ ������� ����� ������ � ������ ����������� �������
;   - �� ����� ���������� ������ ���������� ������� ������, ������������� ������ � ����������� �������
;   - ��� ������ ������������ ��� ������ (������� ��� Corona Skin, ��� ������ ��������� ������������� ��� ���������)
;   - � ������� FreeArcCallback �������� ������� ����, ���������� �������������� ��������, �.�. ����� � ��� ������ ������
;   - ����������� ��� Unicode-������: ����� ������������ ������� ������� ��� �������� � ����������� �������
;   - (!) ��� ���������� ����������� ������ ������� ������������� ������ �� ����� �������������
;   - ������ ����� ���� � ������ ������, � ���� ������ ��� ���������� ������ | ������: #define Archives "{app}\Data\*.tmp|{src}\Archives\*.arc"

; ��������� �� Bulat Ziganshin, 08-07-2009
;   - ��������� ���������� ����� ����� ��������� � ������� ������ ��� �����������
;   - ��������� ��������� ������ ������� �� ������ ������������� � ���������� �� ���� ������
;   - ������������� ������������ ������� �������� �������
;   - FreeArcCallback ���������� �� ����� 100 ��� � �������, ��� �������� ����� �� �������
;   - �������� placeholder ��� ������������ ������������ ���� (� ������ ��������� FreeArcCallback)
;   - ���������� �������� � ��������� ���������� �������������� ����� ��� ������ ����������
;   - ���������� �������� � �������� �������/������ ��������������� �������
;   - ������ '�������� ����������' �������������� � ����������� �� �������� �����
;   - ���������� ���������� ����������� ������� (������ ������ ���������� � ������ ������ ����������)
;   - �� ��������� �������� ���������� ��� ������ ������� ��������� � ������
;
; ��������� �� CTACKo & SotM'�. 01-07-2009
;   - ��������� ��������� �����, ���� � ���� ��������� ����������� ������� �����
;   - ��� ���������� ������������ ������������� PAnsiChar/PChar. ����� ������������ ��� ������� ��� � UNICODE ������ � ������������� ��������������.
;
; ��������� �� SotM'�. 23-06-2009
;   - ������� ����� ������ ������ ��������� ������������.
;   - ��� ������� "������" ��� ���������� ������ ���������� ������ �� ������������� ������.

; ��������� �� Victor_Dobrov, 15-06-2009
;   - ����������� � ����������� �������, ����� ��������� ������ �������, ����� ��������-���, ��� ��������� ���������� ����������� ����� (�������������) � ������������ ����� ������.

; Bulat Ziganshin, 13-06-2009
;   - �������� ���������� unarc.dll � ������� ���������� freearc_example.iss.

#define Archives "{src}\*.arc"; ' ������� ���� ��� ��������� �����, � ������� ��������� ����� � ���������� ������� FreeArc.������� ����� � {app} ������������� ��������� ����� ����������� ����������.
; ����������� | � �������� �����������. ��� ������ � ����� ����� ���� ����� ��� �������, ��� ��� ������. ��� ������� ������� ������ � [Files] ��������� �������������.

[Setup]
AppName=FreeArc Example
AppVerName=FreeArc Example 2.2b
DefaultDirName={pf}\FreeArc Example
DirExistsWarning=no
ShowLanguageDialog=auto
OutputBaseFilename=FreeArc_Example
OutputDir=.
VersionInfoCopyright=Bulat Ziganshin, Victor Dobrov, SotM, CTACKo

[Languages]
Name: eng; MessagesFile: compiler:Default.isl
Name: rus; MessagesFile: compiler:Languages\Russian.isl

[CustomMessages]
eng.ArcBreak=Installation cancelled!
eng.ArcError=Decompression failed with error code %1
eng.ArcBroken=Archive <%1> is damaged or not enough free space.
eng.ArcFail=Decompression failed!
eng.ArcTitle=Extracting FreeArc archive...
eng.StatusInfo=Files: %1%2, progress %3%%, remaining time %4
eng.ArcInfo=archive: %1 �� %2, size %3 of %5, %4%% extracted
eng.ArcFinish=Unpacked archives: %1, received files: %2 [%3]
eng.taskbar=%1%%, %2 remains
eng.ending=ending
eng.hour=hours
eng.min=mins
eng.sec=secs
;
rus.ArcBreak=��������� ��������!
rus.ArcError=����������� FreeArc ������ ��� ������: %1
rus.ArcBroken=��������, ����� <%1> �������� ��� ������������ ����� �� ����� ����������.
rus.ArcFail=���������� �� ���������!
rus.ArcTitle=���������� FreeArc-������...
rus.StatusInfo=������: %1%2, %3%% ���������, �������� ����� %4
rus.ArcInfo=����� %1 �� %2, ����� %3 �� %5, %4%% �����������
rus.ArcFinish=����������� �������: %1, �������� ������: %2 [%3]
rus.taskbar=%1%%, ��� %2
rus.ending=����������
rus.hour=�����
rus.min=���
rus.sec=���

[Files]
;Source: *.arc; DestDir: {app}; Flags: nocompression
Source: unarc.dll; DestDir: {tmp}; Flags: dontcopy deleteafterinstall
Source: compiler:InnoCallback.dll; DestDir: {tmp}; Flags: dontcopy
;��� ������ ������������� ����� �������� � ������� ���������� ��� ������� ���������� ������
Source: {win}\inf\*; DestDir: {app}\files; Flags: external

[UninstallDelete]
Type: filesandordirs; Name: {app}

[Code]
var Debug: TForm; Dl: TMemo; cDebug: boolean; Procedure D(S: string); Begin if not cDebug then begin Debug:= CreateCustomForm; Debug.SetBounds(8, 4, 380, 580) Debug.Show Dl:=TMemo.Create(Debug) Dl.Align:= alClient; Dl.ScrollBars:= ssVertical; Dl.WantReturns:= False; Dl.Parent:= Debug; cDebug:= true end; if Dl.Lines.Text = '' then Dl.Lines.Text:= S else Dl.Lines.Insert(Dl.Lines.Count, S) End; Procedure Df(S: Extended); begin D(FloatToStr(S)) End;
const
    Archives = '{#Archives}';   // ������ ����� � ������� (� �������), ���������� ������ |
    PM_REMOVE = 1;
    CP_ACP = 0; CP_UTF8 = 65001;
    oneMB=1024*1024;
    Period = 250; // ������� ���������� ������ �������� � ������ �������
    HC_ACTION = 0;
    VK_ESCAPE = 27;
    WM_PAINT = $F;
    WH_CALLWNDPROC = 4;

type
#ifdef UNICODE  ;// ���� � ��� ������ �� ���� ������, �� ���������� ������������ ��� ��������� ������ ��� ����� ������ Inno Setup
    #define A "W"
#else
    #define A "A"  ;// ����� ����� � SetWindowText, {#A} �������� �� A ��� W � ����������� �� ������
    PAnsiChar = PChar;  // Required for Inno Setup 5.3.0 and higher. (��������� ��� Inno Setup ������ 5.3.0 � ����)
#endif
#if Ver < 84018176
    AnsiString = String; // There is no need for this line in Inno Setup 5.2.4 and above (��� Inno Setup ������ 5.2.4 � ���� ��� ������ �� �����)
#endif
#define isFalse(any S)  (S = LowerCase(Str(S))) == "no" || S == "false" || S == "off" ? "true" : "false"

    TMessage = record hWnd: HWND; msg, wParam: Word; lParam: LongWord; Time: TFileTime; pt: TPoint; end;
    TFreeArcCallback = function (what: PAnsiChar; int1, int2: Integer; str: PAnsiChar): Integer;
    TArc = record Path: string; Size: Extended; end;
    TBarInfo = record stage, name: string; size: Extended; count, perc, pos, time: Integer; end;
    TCWPSTRUCT = record lParam: LongWord; wParam: Word; Msg: LongWord; hwnd: HWnd; end;
    TCWPSTRUCTProc = procedure(Code: Integer; wParam: Word; lParam: TCWPSTRUCT);
    TTimerProc = procedure(HandleW, Msg, idEvent, TimeSys: LongWord);

var
    ExtractFile, StatusInfo: TLabel;
    ProgressBar: TNewProgressBar;
    CancelCode, n, ArcInd, UnPackError, StartInstall: Integer;
    Arcs: array of TArc;
    msgError: string;
    lastMb, baseMb: Integer;
    LastTimerEvent: DWORD;
    WndHookID, TimerID: LongWord;
    allSize: Extended;
    Status: TBarInfo;

function WrapFreeArcCallback (callback: TFreeArcCallback; paramcount: integer):longword; external 'wrapcallback@files:innocallback.dll stdcall';
function FreeArcExtract (callback: longword; cmd1,cmd2,cmd3,cmd4,cmd5,cmd6,cmd7,cmd8,cmd9,cmd10: PAnsiChar): integer; external 'FreeArcExtract@files:unarc.dll cdecl';

Function OemToChar(lpszSrc, lpszDst: AnsiString): longint; external 'OemToCharA@user32.dll stdcall';
Function MultiByteToWideChar(CodePage: UINT; dwFlags: DWORD; lpMultiByteStr: PAnsiChar; cbMultiByte: integer; lpWideCharStr: PAnsiChar; cchWideChar: integer): longint; external 'MultiByteToWideChar@kernel32.dll stdcall';
Function WideCharToMultiByte(CodePage: UINT; dwFlags: DWORD; lpWideCharStr: PAnsiChar; cchWideChar: integer; lpMultiByteStr: PAnsiChar; cbMultiByte: integer; lpDefaultChar: integer; lpUsedDefaultChar: integer): longint; external 'WideCharToMultiByte@kernel32.dll stdcall';

function PeekMessage(var lpMsg: TMessage; hWnd: HWND; wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): BOOL; external 'PeekMessageA@user32.dll stdcall';
function TranslateMessage(const lpMsg: TMessage): BOOL; external 'TranslateMessage@user32.dll stdcall';
function DispatchMessage(const lpMsg: TMessage): Longint; external 'DispatchMessageA@user32.dll stdcall';

function GetTickCount: DWord; external 'GetTickCount@kernel32';
function GetWindowLong(hWnd, nIndex: Integer): Longint; external 'GetWindowLongA@user32 stdcall delayload';
function SetWindowText(hWnd: Longint; lpString: String): Longint; external 'SetWindowText{#A}@user32 stdcall delayload';
function GetKeyState(nVirtKey: Integer): ShortInt; external 'GetKeyState@user32 stdcall delayload';
function GetCurrentThreadId: LongWord; external 'GetCurrentThreadId@kernel32 stdcall delayload';

function CallNextWNDPROC(idHook: LongWord; Code: Integer; wParam: Word; lParam: TCWPSTRUCT): LongWord; external 'CallNextHookEx@user32 stdcall delayload';
function SetWindowsHookEx(idHook: LongWord; callback: LongWord; hMod: LongWord; dwThreadID: HWND): LongWord; external 'SetWindowsHookExW@user32 stdcall delayload';
function UnhookWindowsHookEx(idHook: LongWord): LongWord; external 'UnhookWindowsHookEx@user32 stdcall delayload';
function WrapCWPSTRUCTProc(callback:TCWPSTRUCTProc; paramcount:integer): longword; external 'wrapcallback@files:innocallback.dll';
function WrapTimerProc(callback: TTimerProc; Paramcount: Integer): longword; external 'wrapcallback@files:innocallback.dll stdcall';
function SetTimer(hWnd, nIDEvent, uElapse, lpTimerFunc: LongWord): longword; external 'SetTimer@user32';
function KillTimer(hWnd, nIDEvent: LongWord): LongWord; external 'KillTimer@user32 stdcall delayload';

procedure AppProcessMessage;
var
    Msg: TMessage;
begin
    if not PeekMessage(Msg, {WizardForm.Handle} 0, 0, 0, PM_REMOVE) then Exit;
    TranslateMessage(Msg); DispatchMessage(Msg);
end;

// Sets the TaskBar title
Procedure SetTaskBarTitle(Title: String); var h: Integer;
Begin
    h:= GetWindowLong(MainForm.Handle, -8); if h <> 0 then SetWindowText(h, Title);
End;

// ������� ����� � ������ � ��������� 2 ����� (%.2n) � ����������� ������� �����, ���� ��� ����
Function NumToStr(Float: Extended): String;
Begin
    Result:= Format('%.2n', [Float]); StringChange(Result, ',', '.');
    while ((Result[Length(Result)] = '0') or (Result[Length(Result)] = '.')) and (Pos('.', Result) > 0) do
        SetLength(Result, Length(Result)-1);
End;

Function ByteOrTB(Bytes: Extended; noMB: Boolean): String; {������� ����� � �������� ��/��/��/��/�� (�� 2� ������ ����� �������)}
    Begin
        if not noMB then Result:= NumToStr(Int(Bytes)) +' Mb' else
            if Bytes < 1024 then if Bytes = 0 then Result:= '0' else Result:= NumToStr(Int(Bytes)) +' Bt' else
                if Bytes/1024 < 1024 then Result:= NumToStr(round((Bytes/1024)*10)/10) +' Kb' else
                    If Bytes/oneMB < 1024 then Result:= NumToStr(round(Bytes/oneMB*100)/100) +' Mb' else
                        If Bytes/oneMB/1000 < 1024 then Result:= NumToStr(round(Bytes/oneMB/1024*1000)/1000) +' Gb' else
                            Result:= NumToStr(round(Bytes/oneMB/oneMB*1000)/1000) +' Tb';
    End;

// Converts milliseconds to human-readable time
// ������������ ����������� � ��������-�������� ����������� �������
Function TicksToTime(Ticks: DWord; h,m,s: String; detail: Boolean): String;
Begin
    if detail then            {hh:mm:ss format}
        Result:= PADZ(IntToStr(Ticks/3600000), 2) +':'+ PADZ(IntToStr((Ticks/1000 - Ticks/1000/3600*3600)/60), 2) +':'+ PADZ(IntToStr(Ticks/1000 - Ticks/1000/60*60), 2)
    else if Ticks/3600 >= 1000 then    {more than hour}
        Result:= IntToStr(Ticks/3600000) +h+' '+ PADZ(IntToStr((Ticks/1000 - Ticks/1000/3600*3600)/60), 2) +m
    else if Ticks/60 >= 1000 then    {1..60 minutes}
        Result:= IntToStr(Ticks/60000) +m+' '+ IntToStr(Ticks/1000 - Ticks/1000/60*60) +s
    else Result:= Format('%.1n', [Abs(Ticks/1000)]) +s    {less than one minute}
End;

function cm(Message: String): String; Begin Result:= ExpandConstant('{cm:'+ Message +'}') End;

Function LoWord(lw: LongWord): LongWord; Begin Result:= lw shr 16; End;

Function Size64(Hi, Lo: Integer): Extended;
Begin
    Result:= Lo;
    if Lo<0 then Result:= Result + $7FFFFFFF + $7FFFFFFF + 2;
    for Hi:= Hi-1 Downto 0 do
        Result:= Result + $7FFFFFFF + $7FFFFFFF + 2;
End;

// Converts OEM encoded string into ANSI
// ����������� OEM ������ � ANSI ���������
function OemToAnsiStr(strSource: AnsiString): AnsiString;
var
    nRet : longint;
begin
    SetLength(Result, Length(strSource));
    nRet:= OemToChar(strSource, Result);
end;

// Converts ANSI encoded string into UTF-8
// ����������� ������ �� ANSI � UTF-8 ���������
function AnsiToUtf8(strSource: string): string;
var
    nRet, nRet2: integer; WideCharBuf, MultiByteBuf: AnsiString;
begin
    SetLength(WideCharBuf, Length(strSource) * 2);
    SetLength(MultiByteBuf, Length(strSource) * 2);
    nRet:= MultiByteToWideChar(CP_ACP, 0, strSource, -1, WideCharBuf, Length(WideCharBuf));
    nRet2:= WideCharToMultiByte(CP_UTF8, 0, WideCharBuf, -1, MultiByteBuf, Length(MultiByteBuf), 0, 0);
    if nRet * nRet2 = 0 then Result:= strSource else Result:= MultiByteBuf;
end;

// Scans the specified folders for archives and add them to list
function FindArcs(files: string): Extended; // ��� ������ ������ ������������ ������ �������������
    var FSR: TFindRec;
Begin
    if FindFirst(ExpandConstant(files), FSR) then
        try
            repeat
                // Skip everything but the folders
                if FSR.Attributes and FILE_ATTRIBUTE_DIRECTORY > 0 then CONTINUE;
                n:= GetArrayLength(Arcs);
                // Expand the folder list
                SetArrayLength(Arcs, n +1);
                Arcs[n].Path:= ExtractFilePath(ExpandConstant(files)) + FSR.Name;
                Arcs[n].Size:= Size64(FSR.SizeHigh, FSR.SizeLow);
                Result:= Result + Arcs[n].Size;
            until not FindNext(FSR);
        finally
            FindClose(FSR);
        end;
End;

    var FreezeTimer: Boolean;
Procedure UpdateStatus(Flags: Integer);   // ����������� � ��������������, �������� ���������� Period
var
    Remaining: Integer; i, t, s: string;
Begin
    if Flags and $1 > 0 then FreezeTimer:= Flags and $2 = 0; //  bit 0 = 1 change start/stop, bit 1 = 0 stop, bit 1 = 1 start
    if Flags and $4 > 0 then LastTimerEvent:= 0; // bit 2 = 1 reset Timer
    if FreezeTimer or (GetTickCount - LastTimerEvent <= Period) then Exit else LastTimerEvent:= GetTickCount;
  with WizardForm.ProgressGauge do begin
    if position > 0 then Remaining:= trunc((GetTickCount - StartInstall) * Abs((max - position)/position)) else Remaining:= 0;
        t:= cm('ending'); i:= t;
        if Remaining > 0 then begin
            t:= FmtMessage(cm('taskbar'), [IntToStr(Status.perc/10), TicksToTime(Remaining, 'h', 'm', 's', false)])
            i:= TicksToTime(Remaining, cm('hour'), cm('min'), cm('sec'), false)
        end;
  end;
    SetTaskBarTitle(t); // �������� � ���������� ����� �� ������ ������������
    if Status.size > 0 then
        s:= ' ['+ ByteOrTB(Status.size*oneMB, true) +']';   // ����� ������� ������� ������� ����� {app} ����� CalcDirSize, �� ��� ����� ��������� ������
    StatusInfo.Caption:= FmtMessage(cm('StatusInfo'), [IntToStr(Status.count +ord(Status.count < 0)), s, Format('%.1n', [Abs(Status.perc/10)]), i]);
// �������� ����������� � �������� �������� � ������������� ������ ��� ��������� ���������� ������� �� ����� ����������
    if (Status.stage = cm('ArcTitle')) and (GetArrayLength(Arcs) > 1) then begin
        ExtractFile.Caption:= FmtMessage(cm('ArcInfo'), [IntToStr(ArcInd+1), IntToStr(GetArrayLength(Arcs)), ByteOrTB(Arcs[ArcInd].Size, true), Format('%.0n', [Status.pos/(Arcs[ArcInd].Size/oneMB)*100]), ByteOrTB(allSize, true)])
        ProgressBar.Position:= round(ProgressBar.Max * Status.pos/(Arcs[ArcInd].Size/oneMB))
    end;
End;

Procedure MyTimerProc(h, msg, idevent, dwTime: Longword);
Begin
    if WizardForm.CurPageID = wpInstalling then UpdateStatus(0);
End;

Procedure OnWndHook(Code: Integer; wParam: Word; lParam: TCWPSTRUCT);
Begin
  if (Code = HC_ACTION) and (LoWord(lParam.msg) = WM_PAINT) then begin  // ���������� ������ ��� ������������ ����������� �� �������
    if (Status.stage <> WizardForm.StatusLabel.Caption) and (WizardForm.StatusLabel.Caption <> '') then begin
        Status.stage:= WizardForm.StatusLabel.Caption;  // ������� ���� ���������
        if Status.stage = SetupMessage(msgStatusRollback) then begin
            StatusInfo.Hide; ExtractFile.Hide; ProgressBar.Hide;
        end;
    end;
    if (Status.name <> WizardForm.FileNameLabel.Caption) and (WizardForm.FileNameLabel.Caption <> '') then begin // ��� �����, �������� ������ � ������
        Status.name := WizardForm.FileNameLabel.Caption;    // ������ ���������� ��� ���������� ���������� �����
        Case Status.stage of
            SetupMessage(msgStatusExtractFiles), cm('ArcTitle'): // ����� ���������� ������ � ���������� �������
                Status.count:= Status.count + 1;    // ���-�� ������
        End;
    end;
    with WizardForm.ProgressGauge do begin
        n:= (Max - Min)/1000
        if n > 0 then Status.perc:= (Position-Min)/n;   // 1000 ���������
    end;
    UpdateStatus(0);
  end;
    CallNextWNDPROC(WndHookID, Code, wParam, lParam)    {������������ �������}
End;

// The main callback function for unpacking FreeArc archives
function FreeArcCallback (what: PAnsiChar; Mb, sizeArc: Integer; str: PAnsiChar): Integer;
    var Elapsed: Extended;
begin
//    if GetTickCount - LastTimerEvent > 1000 then begin
        // This code will be executed once each 1000 ms (���� ��� ����� ����������� ��� � 1000 �����������)
        UpdateStatus(0);
        if GetKeyState(VK_ESCAPE) < 0 then
            if WizardForm.CancelButton.Enabled then WizardForm.Close;   // �� �����
//        LastTimerEvent := LastTimerEvent+1000;
//    end;
  Case string(what) of
    'filename': begin   // Update FileName label
        WizardForm.FileNameLabel.Caption:= OemToAnsiStr(str); // ����������� ����
    end;
    'progress': if Mb >= 1 then with WizardForm.ProgressGauge do begin
        for n:= 0 to ArcInd-1 do Elapsed:= Elapsed + Arcs[n].Size; Elapsed:= Elapsed/oneMB + Mb; // ���������� M���� (��� ���������� ������ �������� ��������)
        Position:= round(Max * Elapsed/(allSize/oneMB))
        Status.pos := Mb;   // ������� � ������� ������
    end;
    'written': begin // Assign to Mb *total* amount of data extracted to the moment from all archives
        lastMb := Mb;   // ��������� �� �������� ������
        Status.size := baseMb+Mb; // ���������� ����� �����, ����� ������� ������ �� �������
    end;
  End;
    AppProcessMessage;
    Result:= CancelCode;
end;

// Extracts all found archives
function UnPack(Archives: string): Integer;
var
    callback: longword;
    FreeMB, TotalMB: Cardinal;
begin
    // ���� ������ ��������� ���������, ������ Cancel ������ ��������
    WizardForm.CancelButton.Enabled:= not {#isFalse(SetupSetting("AllowCancelDuringInstall"))}
    // Get the size of all archives
  Repeat
    if Pos('|',Archives) > 0 then begin
        allSize:= FindArcs(Copy(Archives, 1, Pos('|',Archives) -1)); // ��������� ��������� �����
        Delete(Archives, 1, Pos('|',Archives)); // ������ �����
    end;
        allSize:= FindArcs(Archives);   // ��������� (��� ������������) ����� � ��������
  Until Pos('|',Archives) = 0;
    // Other initializations
    callback:= WrapFreeArcCallback(@FreeArcCallback,4);   //FreeArcCallback has 4 arguments
    WizardForm.StatusLabel.Caption:= cm('ArcTitle');    // ������ ����a ����������
    ExtractFile.Show; ProgressBar.Show;
    baseMb:= 0;  // �������� ���������� ���������, ���� ����� ���� ������� ������ ������ ������������
    Status.count:= 0;   // �� ��������� �����, ����������� �������������
    UpdateStatus(7);  // ���������� �������� ������ �������

  for ArcInd:= 0 to GetArrayLength(Arcs) -1 do begin    // ������ � ������� �����
        CancelCode:= 0;
        AppProcessMessage;
        try
            // Pass the specified arguments to 'unarc.dll'
            Result:= FreeArcExtract (callback, 'x', '-o+', '-dp'+ AnsiToUtf8(ExpandConstant('{app}')), '--', AnsiToUtf8(Arcs[ArcInd].Path), '', '', '', '', '');
            if CancelCode < 0 then Result:= CancelCode;
        except
            Result:= -63;  //    ArcFail
        end;
        baseMb:= baseMb + lastMb    // ����� ����� ������������� ������
    // Error occured
        if Result <> 0 then begin
            msgError:= FmtMessage(cm('ArcError'), [IntToStr(Result)]);
            WizardForm.StatusLabel.Caption:= msgError;
            WizardForm.FileNameLabel.Caption:= ExtractFileName(Arcs[ArcInd].Path);
            GetSpaceOnDisk(ExtractFileDrive(ExpandConstant('{app}')), True, FreeMB, TotalMB);
            case Result of
            -1:   if FreeMB < 32 {�� �� �����} then msgError:= SetupMessage(msgDiskSpaceWarningTitle)
                        else msgError:= msgError + #13#10 + FmtMessage(cm('ArcBroken'), [ExtractFileName(Arcs[ArcInd].Path)]);
            -127: msgError:= cm('ArcBreak');    //Cancel button
            -63:  msgError:= cm('ArcFail');
            end;
            Log(msgError);  // ���������� ������ � ���, � ����� ���������� � ����� �� �������� ����������
            Break;    // �������� ���� ����������
        end;
    // ������� ������� ����� �� ����� ���������� ����� ����������� ������ �� ���������� ������
        if Pos(AnsiLowercase(ExpandConstant('{app}')), AnsiLowercase(Arcs[ArcInd].Path)) > 0 then DeleteFile(Arcs[ArcInd].Path);
  end;
    if Result = 0 then WizardForm.StatusLabel.Caption:= FmtMessage(cm('ArcFinish'), [IntToStr(GetArrayLength(Arcs)), IntToStr(Status.count), ByteOrTB(Status.size*oneMB, true)]);
    StatusInfo.Hide; ExtractFile.Hide; ProgressBar.Hide;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
    if CurStep = ssInstall then begin
        StartInstall:= GetTickCount    {����� ������ ���������� ������}
        WndHookID:= SetWindowsHookEx(WH_CALLWNDPROC, WrapCWPSTRUCTProc(@OnWndHook, 3), 0, GetCurrentThreadId);    {��������� SendMessage ����}
        TimerID:= SetTimer(0, 0, 500 {����������}, WrapTimerProc(@MyTimerProc, 4));    {��������� �������}
        if not {#isFalse(SetupSetting("Uninstallable"))} then Status.count:= -1; // �� ������� ���� unins000.exe
    end;
    if CurStep = ssPostInstall then
    begin
        StartInstall:= GetTickCount    {����� ������ ����������}
        UnPackError:= UnPack(Archives)
        if UnPackError = 0 then
            SetTaskBarTitle(SetupMessage(msgSetupAppTitle)) else
        begin
            // Error occured, uninstall it then
            if not {#isFalse(SetupSetting("Uninstallable"))} then  // ������������� ���������
                Exec(ExpandConstant('{uninstallexe}'), '/SILENT','', sw_Hide, ewWaitUntilTerminated, n);    // ����� ��������� ��-�� ������ unarc.dll
            SetTaskBarTitle(SetupMessage(msgErrorTitle))
            WizardForm.Caption:= SetupMessage(msgErrorTitle) +' - '+ cm('ArcBreak')
        end;
    end;
end;

Procedure CurPageChanged(CurPageID: Integer);
Begin
    if (CurPageID = wpFinished) and (UnPackError <> 0) then
    begin // Extraction was unsuccessful (����������� ������ ������)
        // Show error message
        WizardForm.FinishedLabel.Font.Color:= $0000C0;    // red (�������)
        WizardForm.FinishedLabel.Height:= WizardForm.FinishedLabel.Height * 2;
        WizardForm.FinishedLabel.Caption:= SetupMessage(msgSetupAborted) + #13#10#13#10 + msgError;
    end;
End;

procedure WizardClose(Sender: TObject; var Action: TCloseAction);
Begin
  Action:= caNone;    // ��� ����
    if Status.stage = cm('ArcTitle') then begin // ���������� �� ����� ssPostInstall
        UpdateStatus(1); // ���������� ������
        if MsgBox(SetupMessage(msgExitSetupMessage), mbInformation, MB_YESNO) = IDYES then
            CancelCode:= -127;  // �������� ����������
        UpdateStatus(7); // �������� ����������
    end else
        MainForm.Close; // ����������� ������� ������ �������� ���� ��� ������.
End;

procedure InitializeWizard();
begin
    with WizardForm.ProgressGauge do begin
// Create controls to show extended info
    StatusInfo:= TLabel.Create(WizardForm);
        StatusInfo.parent:=WizardForm.InstallingPage;
        StatusInfo.Autosize:= false;
        StatusInfo.Top:= Top + ScaleY(32);
        StatusInfo.Width:= Width;
    ProgressBar := TNewProgressBar.Create(WizardForm);
        ProgressBar.SetBounds(Left, StatusInfo.Top + StatusInfo.Height + ScaleY(16), Width, Height);
        ProgressBar.Parent := WizardForm.InstallingPage;
        ProgressBar.max := 65536;
        ProgressBar.Hide;   // ����� ������� ��� ��������� ���������� �������
    ExtractFile:= TLabel.Create(WizardForm);
        ExtractFile.parent:=WizardForm.InstallingPage;
        ExtractFile.Autosize:= false;
        ExtractFile.Top:= ProgressBar.Top + ScaleY(32);
        ExtractFile.Width:= Width;
    end;
    WizardForm.OnClose:= @WizardClose   // ��������� �������� ���������� ������� ������������ ���������
end;

Procedure DeInitializeSetup;
Begin
    KillTimer(0, TimerID)        {�������� �������}
    UnhookWindowsHookEx(WndHookID)    {�������� SendMessage ����}
End;