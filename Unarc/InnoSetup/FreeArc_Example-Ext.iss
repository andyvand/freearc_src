;[English]
;Extended example of using unarc.dll for decompression of FreeArc archives with displaying of progress indicator in Inno Setup window.
;The script requires Inno Setup QuickStart Pack 5.2.3 and above! (http://files.jrsoftware.org)

;[Russian]
;����������� ������ ���������� FreeArc ������ ��� ������ unarc.dll, � ������������ ��������� ���������� � ���� Inno Setup.

; miniFAQ
;   - ���������� �������: �������� ������ � �������� � ������ [Files], ���������� ����� external dontcopy, ���� ����, ������� ����������/������.
;       ����� ���� ����� �������� �������: {#SourceToProgress}, ���������� ��� �� ����� ssPostInstall �� Source: � DestDir: (� ������ �����������/�����).
;   - ���� ����� ����� ����� � ������������, ���� �� ����� ������ �� ����� 2��, ����� "copy /b setup.exe+xxx.arc newsetup.exe", ������� � [Files] "{srcexe}"
;   - ��� ���������� �������, ������ � ����������� precomp, �������� � ����������� ������ ������� �� PowerPack � ���� arc.ini. (��� ������� � #define precomp ������� ����� Max, �� ������ ����� ������������, �.�. ���������� ��������� ���� PowerPack, � ��� ����� 8 ��!)
;   - ���� ��� ������ ������� ��������� �� ������ � ������ [_ISToolPreCompile], �� �������������� �����������, ������� ������: Install Inno Setup Preprocessor
;   - ������ ������������ �� ������� Inno Setup 5.2.3, 5.2.3.e7 �� ResTools, 5.2.4, 5.3.2 beta, 5.3.2-beta-Unicode.
; ����������: ����������� �������, ���������� � ������ �����, �������� �����������/�����, ���������� � ���������� ������ precomp, ���������� ������ �������, ����� ����� � ������ ������...
;
; ������ 3.3 ext �� Victor_Dobrov, 13-09-2009
;   - arc.ini ������ � c:\
;   - ���������� ������ ���������� ��������� ��� ������������� ������� �������������
;   - ��������� ������ ���������� �����������/������������� ������
;
; ������ 3.3 �� Bulat Ziganshin, 13-09-2009
;   - ��������� ���������� �� 10%
;   - FreeArcExtract() ������������ ����� '-wPATH' ��� ������� �������� ��� ��������� ������
;   - ��� ���������� ���������� ������� ��������� �����
;   - ���������� ������ � unarc.dll - �������� ��� ���������� � �������������� ��������� ������
;
; ������ 3.2 ext �� Victor_Dobrov, 31-07-2009
;   - ����� ������� ������ ���������� �������
;   - ���������� ������� � ������ �����
;   - ���������� ��� � ������ ��������� �����������/�����
;   - ��������� � ����������� ����� � precomp-���������
;   - ������� ������� � ���������� ������ ������� � ������ (����� ���������!)
;   - miniFAQ � ������ ������...
;
; ������ 3.2 �� Bulat Ziganshin, 31-07-2009
;   - ���������� unarc.dll - ������ ��� �� �������� �� ������� �������

; ������ 3.1 �� Bulat Ziganshin, 29-07-2009
;   - ����� ������� ��������� ��������� (������ �� LZMA ������� ������� �� 8 �� ������ dictsize)
;   - ������ �� �������� ������ ����� facompress.dll �� PATH
;
; ������ 3.0 �� Bulat Ziganshin, 29-07-2009
;   - ������� ArchiveOrigSize ���������� ����� ������ � ������
;   - ������������ �������� �������� �� read � write (���� progress � written)
;
; ������ 2.1 �� Bulat Ziganshin, 10-07-2009
;   - � unarc.dll ���������� ������, �������� �������������� ���������� ��� ���������� ��������� �������

; ��������� �� Victor_Dobrov, 09-07-2009
;   - ������� � PeekMessage 0 �� WizardForm.Handle, ����� ���� ������ ��� ��������� � �����
;   - ������� �������� �� ������������� ��� ������ ��-�� ������ FreeArc
;   - ��������� ����������� ������ ������ ������������ (� ����� ������� Escape)
;   - ����� �������� ������ �� ������������ - ����� ������� ������������ � WizardForm.FileNameLabel
;   - ������ ������������ � �������� ���������� ������� ���������� �������� ����� � ����� �� ��� ����������
;   - ����������� ���������� ������� ��� ��� ���������� ������ �������������, ��� � ��� ���������� �������
;   - �� ����� ���������� ������ ��� ������ ������� ����� ������ � ������ ����������� �������
;   - �� ����� ���������� ������ ���������� ������� ������, ������������� ������ � ����������� �������
;   - ��� ������ ������������ ��� ������ (������� ��� Corona Skin, ��� ������ ��������� ������������� ��� ���������)
;   - � ������� FreeArcCallback �������� ������� ����, ���������� �������������� ��������, �.�. ����� � ��� ������ ������
;   - ����������� ��� Unicode-������: ����� ������������ ������� ������� ��� �������� � ����������� �������
;   - (!) ��� ���������� ����������� ������ ������� ������������� ������ �� ����� �������������

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

; ��������� �� CTACKo & SotM'�. 01-07-2009
;   - ��������� ��������� �����, ���� � ���� ��������� ����������� ������� �����
;   - ��� ���������� ������������ ������������� PAnsiChar/PChar. ����� ������������ ��� ������� ��� � UNICODE ������ � ������������� ��������������

; ��������� �� SotM'�. 23-06-2009
;   - ������� ����� ������ ������ ��������� ������������.
;   - ��� ������� "������" ��� ���������� ������ ���������� ������ �� ������������� ������.

; ��������� �� Victor_Dobrov, 15-06-2009
;   - ����������� � ����������� �������, ����� ��������� ������ �������, ����� ��������-���, ��� ��������� ���������� ����������� ����� (�������������) � ������������ ����� ������.

; Bulat Ziganshin, 13-06-2009
;   - �������� ���������� unarc.dll � ������� ���������� freearc_example.iss.

;#define precomp GetEnv("ProgramFiles") + "\FreeArc\PowerPack\Max\*"  ;���� ������ ������� � PRECOMP, ���������������� ������ � ������� ����� � ������������ ��� ���������� ������� (� ����� ������ ��� precomp04.exe, PPMonstr.exe, ecm.exe, unecm.exe, packjpg_dll.dll)

[Setup]
AppName=FreeArc Example
AppVerName=FreeArc Example 3.2 Extreme
DefaultDirName={pf}\FreeArc Example
DirExistsWarning=no
;DisableReadyPage=true
ShowLanguageDialog=auto
OutputBaseFilename=FreeArc_Example-Ext
OutputDir=.
VersionInfoCopyright=Bulat Ziganshin, Victor Dobrov, SotM, CTACKo

[Components]
Name: Russian; Description: ����������� ��������� � �������
Name: English; Description: �������� ������� �����; Types: compact full

[UninstallDelete]
Type: filesandordirs; Name: {app}

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
eng.ArcInfo=archive: %1 �� %2, size %3 of %5, %4%% processed
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
;rus.PassFail=�������� ������!
rus.ArcFail=���������� �� ���������!
rus.ArcTitle=���������� FreeArc-�������...
;rus.Szip=���������� 7zip-�������...
rus.StatusInfo=������: %1%2, %3%% ���������, �������� ����� %4
rus.ArcInfo=����� %1 �� %2, ����� %3 �� %5, %4%% ����������
rus.ArcFinish=����������� �������: %1, �������� ������: %2 [%3]
eng.taskbar=%1%%, %2 remains
rus.taskbar=%1%%, ��� %2
rus.ending=����������
rus.hour=�����
rus.min=���
rus.sec=���

[_ISToolPreCompile]
#sub ShowErr
  #pragma error Str(void)
#endsub
#define Break(any S = "Empty") void = S, ShowErr
#ifndef Archives
    #define Archives ""
#endif
#define LastLine
#define Current AddBackslash(GetEnv("TEMP")) + GetDateTimeString('dd/mm-hh:nn', '-', '-') +'.iss'
#sub GetLastLine
 #expr SaveToFile(Current)
  #for {faAnyFile = FileOpen(Current); !FileEof(faAnyFile); LastLine = FileRead(faAnyFile)} NULL
 #expr FileClose(faAnyFile)
#endsub
#define TrimEx(str S = "", str T = " ") \
    Pos(T,S) == 1 ? S = Copy(S,2,Len(S)) : S, Copy(S,Len(S)) == T ? S = Copy(S,1,Len(S)-1) : S, Pos(T,S) == 1 || Copy(S,Len(S)) == T ? TrimEx(S,T) : S
#define SkipText(str S = "", str T = ";", int F = 1) \
    Local[0] = Pos(T, S), Local[0] > 0 ? (F == 0 ? Copy(S, Local[0]) : (F < 0 ? Copy(S,,Local[0] -1) : Copy(S, Local[0] + Len(T)))) : S
#define Find2Cut(str S, str B, str E = ";") \
    S = LowerCase(S), B = LowerCase(B), \
    (Local[0] = Pos(B, S)) > 0 ? (Local[1] = Copy(S, Local[0]+Len(B)), (Local[0] = Pos(E, Local[1])) > 0 ? (Copy(Local[1],, Local[0]-1)) : Local[1]) : ""
#define SourceToProgress() GetLastLine, \
    Local[0] = Find2Cut(LastLine,"UnArc(",")"), Local[0] == "" ? Local[0] = Find2Cut(LastLine,"UnZip(",")") : void, Local[0] != "" && Pos("dontcopy", Find2Cut(LastLine,"Flags:")) == 0 ? Local[5] = "?" : void, \
    Local[1] = TrimEx(TrimEx(SkipText(Local[0],"',",-1)),"'"), Local[2] = TrimEx(TrimEx(SkipText(Local[0],"',")),"'"), Local[1] == "" ? Local[1] = TrimEx(Find2Cut(LastLine,"Source:")) : void, Local[2] == "" ? Local[2] = TrimEx(Find2Cut(LastLine,"DestDir:")) : void, \
    Local[3] = TrimEx(Find2Cut(LastLine,"Components:")), Local[3] == "" ? void : (Local[3] = "<"+ Local[3], void), Local[4] = TrimEx(Find2Cut(LastLine,"Tasks:")), Local[4] == "" ? void : (Local[4] = ">"+ Local[4], void), \
    Local[1] == "" ? Break('Previous line must be in [Files] section') : (Local[0] = Local[1] +"/"+ Local[2] + Local[3] + Local[4] + Local[5]), TrimEx(Archives) == "" ? Archives = Local[0] : (Archives = Archives +"|"+ Local[0]), void
#define isFalse(any S)  (S = LowerCase(Str(S))) == "no" || S == "false" || S == "off" ? "true" : "false"

[Files]
Source: unarc.dll; DestDir: {tmp}; Flags: dontcopy
Source: compiler:InnoCallback.dll; DestDir: {tmp}; Flags: dontcopy
#ifdef precomp
;���� �������, ��� ������ ������� � PRECOMP, � ����������� ���������� ����������� ��� ���������� �����
Source: {#precomp}; DestDir: {sys}; Flags: deleteafterinstall
Source: {#GetEnv("ProgramFiles")}\FreeArc\bin\arc.ini; DestDir: c:\; Flags: deleteafterinstall
#endif
;��� ������ ������������� ����� �������� � ������� ���������� ��� ������� ���������� ������
Source: {win}\help\*.hlp; DestDir: {app}\Files; Flags: external
;������ ���������� �������
Source: {src}\*.arc; DestDir: {app}\ArcFiles; Flags: external dontcopy
{#SourceToProgress}

[Code]
type
#ifdef UNICODE
    #define A "W"
#else
    #define A "A"  ;// ����� ����� � SetWindowText, {#A} �������� �� A ��� W � ����������� �� ������
    PAnsiChar = PChar;  // Required for Inno Setup 5.3.0 and lower. (��������� ��� Inno Setup ������ 5.3.0 � ����)
#endif
#if Ver < 84018176
    AnsiString = String; // There is no need for this line in Inno Setup 5.2.4 and above (��� Inno Setup ������ 5.2.4 � ���� ��� ������ �� �����)
#endif

    TMessage = record hWnd: HWND; msg, wParam: Word; lParam: LongWord; Time: TFileTime; pt: TPoint; end;
    TFreeArcCallback = function (what: PAnsiChar; int1, int2: Integer; str: PAnsiChar): Integer;
    TArc = record Path, Dest, comp, task: string; allMb, Files: Integer; Size: Extended; end;
    TBarInfo = record stage, name: string; size, allsize: Extended; count, perc, pos, mb, time: Integer; end;
    TCWPSTRUCT = record lParam: LongWord; wParam: Word; Msg: LongWord; hwnd: HWnd; end;
    TCWPSTRUCTProc = procedure(Code: Integer; wParam: Word; lParam: TCWPSTRUCT);
    TTimerProc = procedure(HandleW, Msg, idEvent, TimeSys: LongWord);
var
    StatusLabel, FileNameLabel, ExtractFile, StatusInfo: TLabel;
    ProgressBar: TNewProgressBar;
    CancelCode, n, ArcInd, UnPackError, StartInstall, LastTimerEvent, lastMb, baseMb: Integer;
    FreeMB, TotalMB: Cardinal;
    WndHookID, TimerID: LongWord;
    Arcs, Records: array of TArc;
    msgError: string;
    Status: TBarInfo;
    FreezeTimer: Boolean;
    totalUncompressedSize, origsize: Integer;             // total uncompressed size of archive data in mb
    Texture2, Texture: TBitmapImage;
const
    PM_REMOVE = 1;
    CP_ACP = 0; CP_UTF8 = 65001;
    oneMB=1024*1024;
    Period = 250; // ������� ���������� ������ �������� � ������ �������
    BackColor = $fcfbfb; EndColor = $d8e9ec; // ����� ��������� ��� ���� ����
    VK_ESCAPE = 27;
    HC_ACTION = 0;
    WH_CALLWNDPROC = 4;
    WM_PAINT = $F;
    CancelDuringInstall = {#isFalse(SetupSetting("AllowCancelDuringInstall"))};

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
function GetCurrentThreadID: LongWord; external 'GetCurrentThreadId@kernel32 stdcall delayload';
function MulDiv(Number, Numerator, Denominator: Integer): Integer; external 'MulDiv@kernel32 stdcall delayload';

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

Function FreeArcCmd(callback: longword; cmd1,cmd2,cmd3,cmd4,cmd5,cmd6,cmd7,cmd8,cmd9,cmd10: PAnsiChar): integer;
Begin
    CancelCode:= 0; AppProcessMessage;
    try
        Result:= FreeArcExtract(callback, cmd1,cmd2,cmd3,cmd4,cmd5,cmd6,cmd7,cmd8,cmd9,cmd10);    // Pass the specified arguments to 'unarc.dll'
        if CancelCode < 0 then Result:= CancelCode;
    except
        Result:= -63;  //    ArcFail
    end;
End;

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

Function StringToArray(Text, Cut: String): array of String; var i, k: Integer;  // ��������� ������ ������ � �������� ������. ������ �������� ����� ����� ���� �����. ������ � ������/����� ������ ������������
Begin
    SetArrayLength(Result, 0);    if Cut = '' then Cut:= #1310;   //���� ������ ����, ������� �������� �����
  Repeat    k:= Pos(Cut,Text);
    if k = 1 then begin Delete(Text, 1, Length(Cut)); CONTINUE
    end;
    SetArrayLength(Result, GetArrayLength(Result) +1); i:= GetArrayLength(Result) -1;
    if k = 0 then
        Result[i]:=Text
    else begin
        Result[i]:= Copy(Text, 1, k -1); Delete(Text, 1, Length(Result[i]) + Length(Cut));
    end;
  Until Length(Text) * k = 0;
End;

Function CreateLabel(Parent: TWinControl; AutoSize, WordWrap, Transparent: Boolean; FontName: String; FontStyle: TFontStyles; FontColor: TColor; Left, Top, Width, Height: Integer; Prefs: TObject): TLabel;
Begin
  Result:=TLabel.Create(Parent); Result.parent:= Parent;
  if Prefs <> Nil then begin
    Top:= TWinControl(Prefs).Top; Left:= TWinControl(Prefs).Left; Width:= TWinControl(Prefs).Width; Height:= TWinControl(Prefs).Height;
  end;
    if Top > 0 then result.Top:=Top; if Left > 0 then result.Left:= Left; if Width > 0 then result.Width:= Width; if Height > 0 then result.Height:= Height;
    if FontName <> '' then result.Font.Name:= FontName; if FontColor > 0 then result.Font.Color:= FontColor; if FontStyle <> [] then result.Font.Style:= FontStyle;
    result.AutoSize:= AutoSize; result.WordWrap:= WordWrap; result.Transparent:=Transparent; result.ShowHint:= true;
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

Function ExpandENV(string: String): String; var n: UINT; Begin // ExpandConstant + ������������ DOS-���������� ���� %SystemRoot%
if Pos('{',string) * Pos('}',string) = 0 then Result:= String else Result:= ExpandConstant(String); n:= Pos('%',result); if n = 0 then Exit;
    Delete(result, n,1); Result:= Copy(Result,1, n-1) + ExpandConstant('{%'+Copy(Result, n, Pos('%',result) -n) +'}') + Copy(Result, Pos('%',result) +1, Length(result))
End;

Function cm(Message: String): String; Begin Result:= ExpandConstant('{cm:'+ Message +'}') End;
Function LoWord(lw: LongWord): LongWord; Begin Result:= lw shr 16; End;

Function Size64(Hi, Lo: Integer): Extended;
Begin
        Result:= Lo;
    if Lo<0 then Result:= Result + $7FFFFFFF + $7FFFFFFF + 2;
    for Hi:= Hi-1 Downto 0 do
        Result:= Result + $7FFFFFFF + $7FFFFFFF + 2;
End;

Function RGB(r, g, b: Longint): Longint; Begin Result:= (r or (g shl 8) or (b shl 16)) End;
Function GetBValue(rgb: DWord): Byte; Begin Result:= Byte(rgb shr 16) End;
Function GetGValue(rgb: DWord): Byte; Begin Result:= Byte(rgb shr 8) End;
Function GetRValue(rgb: DWord): Byte; Begin Result:= Byte(rgb) End;

Procedure GradientFill(WorkBmp: TBitmapImage; BeginColor, FinishColor: Integer);    var ColorBand: TRect; StartColor, i: Integer; Begin    {���� BeginColor < 0, �� �������� ��������������}
    WorkBmp.Bitmap.Width:= WorkBmp.Width; WorkBmp.Bitmap.Height:= WorkBmp.Height; StartColor:= trunc(Abs(BeginColor))
    if BeginColor < 0 then n:= WorkBmp.Width else n:= WorkBmp.Height;
    for i:=0 to n do begin if BeginColor < 0 then begin
        ColorBand.Top:= 0; ColorBand.Bottom:= WorkBmp.Height;
        ColorBand.Left:= MulDiv(i, WorkBmp.Width, n); ColorBand.Right:= MulDiv(i+1, WorkBmp.Width, n);
    end else begin
        ColorBand.Top:= MulDiv(i, WorkBmp.Height, n); ColorBand.Bottom:= MulDiv(i+1, WorkBmp.Height, n);
        ColorBand.Left:= 0; ColorBand.Right:= WorkBmp.Width; end;
    WorkBmp.Bitmap.Canvas.Brush.Color:= RGB(GetRValue(StartColor) + MulDiv(I, GetRValue(FinishColor) - GetRValue(StartColor), n-1), GetGValue(StartColor) + MulDiv(I, GetGValue(FinishColor) - GetGValue(StartColor), n-1), GetBValue(StartColor) + MulDiv(I, GetBValue(FinishColor) - GetBValue(StartColor), n-1));
    WorkBmp.Bitmap.Canvas.FillRect(ColorBand); end;
End;

// Converts OEM encoded string into ANSI    (����������� OEM ������ � ANSI ���������)
function OemToAnsiStr(strSource: AnsiString): AnsiString;
var
    nRet : longint;
begin
    SetLength(Result, Length(strSource));
    nRet:= OemToChar(strSource, Result);
end;

// Converts ANSI encoded string into UTF-8 (����������� ������ �� ANSI � UTF-8 ���������)
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

// ArcInd - ������� �����, ���� � 0
// baseMb - �������� �� ����. ������ �� ����
// lastMb - ��������� �� ���. ������ �� ����
// Status.mb - ������� � ������� ������
// Status.allsize - ����� ���� �������
// Status.size - ����� ��������� �� �� ������� ������
// totalUncompressedSize - ������ ����� ������ � �������
// ����� �������� ��������� �� ���� ������ ������ �� ������ �� ���� (����� 'write')
// �������� ������� ��������� � ������������ � �������� � ������� ������ (����� 'read')

Procedure UpdateStatus(Flags: Integer);   // ����������� � ��������������, �������� ���������� Period
var
    Remaining: Integer; i, t, s: string;
Begin
  if Flags and $1 > 0 then FreezeTimer:= Flags and $2 = 0; //  bit 0 = 1 change start/stop, bit 1 = 0 stop, bit 1 = 1 start
  if (Flags and $4 > 0) or (Status.size <> baseMb+lastMb) then LastTimerEvent:= 0; // bit 2 = 1 UpdateNow // �������� �� ����� ��� ������ �� ������ �� ����
  if FreezeTimer or (GetTickCount - LastTimerEvent <= Period) then Exit else LastTimerEvent:= GetTickCount;
  Status.size := baseMb+lastMb; // ��������� �� ������� ������
  if totalUncompressedSize > 0 then with WizardForm.ProgressGauge do begin    //    �������� �������� �������� �� ���� ������ ������ �� ����
      Position:= round(Max * Status.size/totalUncompressedSize)
  end;
  with WizardForm.ProgressGauge do begin    // ���������� �����
#ifndef precomp
    // � ���������, ���� ��� ������ ����� �� ����� ������� �������, ��������� � �������������� ������� �����������
    if position > 0 then Remaining:= trunc((GetTickCount - StartInstall) * Abs((max - position)/position)) else
#endif
      Remaining:= 0;
    t:= cm('ending'); i:= t;
    if Remaining > 0 then begin
      t:= FmtMessage(cm('taskbar'), [IntToStr(Status.perc/10), TicksToTime(Remaining, 'h', 'm', 's', false)])
      i:= TicksToTime(Remaining, cm('hour'), cm('min'), cm('sec'), false)
    end;
  end;
  SetTaskBarTitle(t); // �������� � ���������� ����� �� ������ ������������
  if Status.size > 0 then
    s:= ' ['+ ByteOrTB(Status.size*oneMB, true) +']';   // ���� ������� ������� ������� ����� {app} ����� CalcDirSize, �� ��� ������ ��������� ����� �������� ������ ��� ����� ��������� ������
  StatusInfo.Caption:= FmtMessage(cm('StatusInfo'), [IntToStr(Status.count +ord(Status.count < 0)), s, Format('%.1n', [Abs(Status.perc/10)]), i]);
  // ������ ����������� �������� �� ���� ���������� �������� ������
  if (Status.stage = cm('ArcTitle')) and (GetArrayLength(Arcs) > 0) then begin
    ExtractFile.Caption:= FmtMessage(cm('ArcInfo'), [IntToStr(ArcInd+1), IntToStr(GetArrayLength(Arcs)), ByteOrTB(Arcs[ArcInd].Size, true), Format('%.0n', [Status.mb/(Arcs[ArcInd].Size/oneMB)*100]), ByteOrTB(Status.allsize, true)])
    ProgressBar.Position:= round(ProgressBar.Max * Status.mb/trunc(Arcs[ArcInd].Size/oneMB))
  end;
End;

Procedure MyTimerProc(h, msg, idevent, dwTime: Longword);
Begin
    if WizardForm.CurPageID = wpInstalling then UpdateStatus(0);
End;

Procedure OnWndHook(Code: Integer; wParam: Word; lParam: TCWPSTRUCT);
Begin
  if (Code = HC_ACTION) and (LoWord(lParam.msg) = WM_PAINT) then begin  // ���������� ������ ��� ������������ ����������� �� �������
    if (Status.name <> WizardForm.FileNameLabel.Caption) and (WizardForm.FileNameLabel.Caption <> '') then begin // ��� �����, �������� ������ � ������
        FileNameLabel.Caption:= WizardForm.FileNameLabel.Caption;
        Status.name:= WizardForm.FileNameLabel.Caption;    // ������ ���������� ��� ���������� ���������� �����
        Case Status.stage of
            SetupMessage(msgStatusExtractFiles): // ���� ���������� ������ �������������
                Status.count:= Status.count +1;    // ���-�� ������
        End;
    end;
    if (Status.stage <> WizardForm.StatusLabel.Caption) and (WizardForm.StatusLabel.Caption <> '') then begin
        StatusLabel.Caption:= WizardForm.StatusLabel.Caption;
        Status.stage:= WizardForm.StatusLabel.Caption;  // ������� ���� ���������
        if Status.stage = SetupMessage(msgStatusRollback) then begin
            WizardForm.StatusLabel.Hide; WizardForm.FileNameLabel.Hide; StatusInfo.Hide; ExtractFile.Hide; ProgressBar.Hide;
        end;
    end;
    with WizardForm.ProgressGauge do begin
        n:= (Max - Min)/1000
        if n > 0 then Status.perc:= (Position-Min)/n;   // 1000 ���������
    end;
    UpdateStatus(0);
  end;
    CallNextWNDPROC(WndHookID, Code, wParam, lParam)    {������������ �������}
End;

// compsize:    � Mb ����� ������
// total_files: � int2 ? ����� ������ � ������
// origsize:    � Mb ����� ����� ������ � ������
// write:    � Mb ����� ���������� (������������� �� ������) �� ���� ��������
// read:    � Mb ����� ������������ ��������, � int2 ������ �������� ������
// filename:    ���������� ����� ���������� ������� �����

// The main callback function for unpacking FreeArc archives
function FreeArcCallback(what: PAnsiChar; Mb, int2: Integer; str: PAnsiChar): Integer; // ���������� �� ����� 100 ��� � �������, ��� �������� ����� �� �������
begin
  case string(what) of
    'origsize': origsize:= Mb;  // ������ � ���. ������ (��� ���������� �� ����������)
    'total_files': Null;
    'filename':  begin   // Update FileName label
        WizardForm.FileNameLabel.Caption:= OemToAnsiStr(str); // ����������� ����, �� ����� ������� � ������ ���������
        FileNameLabel.Caption:= OemToAnsiStr(str); // ����������� ����, �� ����� ������� � ������ ���������
        Status.count:= Status.count + 1;    // ���-�� ������, ���� ����������
    end;
    'read': // ������� � ������� ������
        Status.mb:= Mb;
    'write':  // Assign to Mb *total* amount of data extracted to the moment from all archives
        lastMb:= Mb;   // ��������� �� �������� ������
  end;
    if WizardForm.CurPageID = wpInstalling then UpdateStatus(0);    // �������� �������� ���������, �� ��������� ������
    if (GetKeyState(VK_ESCAPE) < 0) and not CancelDuringInstall then
        WizardForm.Close;   // ���������� Cancel (���� ��������� ������ ���������)
    AppProcessMessage;
    Result:= CancelCode;
end;

Function ArcDecode(Line: string): array of TArc;   // ������ ������ Archives
    var tmp, cut: array of String; n, i: integer;
Begin
    SetArrayLength(result,0); if Line <> '' then tmp:= StringToArray(Line,'|') else Exit;
    for n:= 0 to GetArrayLength(tmp) - 1 do begin
        if tmp[n][Length(tmp[n])] = '?' then Continue; // ��� ������ �������������� � AfterInstall: UnArc(...)
        SetArrayLength(result, GetArrayLength(result) +1); i:= GetArrayLength(result) -1;
        cut:= StringToArray(tmp[n],'>')    // ������, ������ or and not �������� �� ����� ��������
            if GetArrayLength(cut) > 1 then result[i].task:= cut[1];
        cut:= StringToArray(cut[0],'<')    // ����������
            if GetArrayLength(cut) > 1 then result[i].comp:= cut[1];
        cut:= StringToArray(cut[0],'/')    // ����� ����������
            if GetArrayLength(cut) > 1 then result[i].Dest:= cut[1] else result[i].Dest:= '{app}';    // ��-���������
        if (ExtractFileDrive(ExpandENV(cut[0])) = '') and (ExpandENV(cut[0]) = cut[0]) then    // ������ ���� Rus\*.arc
            result[i].Path:= '{src}\'+ cut[0] else result[i].Path:= cut[0];    // ������� �� �������� ������
        result[i].Dest:= ExpandENV(result[i].Dest); result[i].Path:= ExpandENV(result[i].Path);
    end;
End;

// Scans the specified folders for archives and add them to list
function AddArcs(files, target: string): Integer; // ���������� ������� � ����� ������ � ������� ������ ������������� ������
    var FSR: TFindRec; i: integer;
Begin
    Result:= 0; if FindFirst(ExpandENV(files), FSR) then
        try
            repeat
                // Skip everything but the folders
                if FSR.Attributes and FILE_ATTRIBUTE_DIRECTORY > 0 then CONTINUE;
                // Expand the folder list
                i:= GetArrayLength(Arcs); SetArrayLength(Arcs, i +1);
                Arcs[i].Dest:= target;  // ���� ���������� ��� ��������� �� ����� �������
                Arcs[i].Path:= ExtractFilePath(ExpandENV(files)) + FSR.Name;
                Arcs[i].Size:= Size64(FSR.SizeHigh, FSR.SizeLow);
                Status.allsize:= Status.allsize + Arcs[i].Size; // ��������������� ��� �������� ��������� ���������� 7-zip ������� (is7z.dll)
                Arcs[i].allMb:= FreeArcCmd(WrapFreeArcCallback(@FreeArcCallback,4),'l','--',AnsiToUtf8(Arcs[i].Path),'','','','','','','');  // ��� ������
                if Arcs[i].allMb >= 0 then begin
                    Arcs[i].allMb:= origsize; result:= result + Arcs[i].allMb; // ������ ������������� ������ ������� ������
                end;
            until not FindNext(FSR);
        finally
            FindClose(FSR);
        end;
End;

function UnPackArchive(Source, Destination: string; allMb, Mode: Integer): Integer;
var
    callback: longword;
Begin
    // ���� ������ ��������� ���������, ������ Cancel ������ ��������
    WizardForm.CancelButton.Enabled:= not CancelDuringInstall;
    callback:= WrapFreeArcCallback(@FreeArcCallback,4);   //FreeArcCallback has 4 arguments
    Result:= FreeArcCmd(callback,'x','-o+','-dp'+AnsiToUtf8(Destination),'--',AnsiToUtf8(Source),'','','','','');  // ��� ������
    // Error occured
    if Result = 0 then Exit;
        msgError:= FmtMessage(cm('ArcError'), [IntToStr(Result)]);
        WizardForm.StatusLabel.Caption:= msgError;
        WizardForm.FileNameLabel.Caption:= ExtractFileName(Source);
        GetSpaceOnDisk(ExtractFileDrive(Destination), True, FreeMB, TotalMB);
        case Result of
        -1:   if FreeMB < allMb {�� �� �����} then msgError:= SetupMessage(msgDiskSpaceWarningTitle)
               else msgError:= msgError + #13#10 + FmtMessage(cm('ArcBroken'), [ExtractFileName(Source)]);
        -127: msgError:= cm('ArcBreak');    //Cancel button
        -63:  msgError:= cm('ArcFail');
        end;
    Log(msgError);  // ���������� ������ � ���, � ����� ���������� � ����� �� �������� ����������
End;

// Extracts all found archives
function UnPack(Archives: string): Integer;
begin
//    UpdateStatus(1); // ���������� ������
    Records:= ArcDecode(Archives); SetArrayLength(Arcs,0); Status.allsize:= 0; {����� �����}
    for n:= 0 to GetArrayLength(Records) -1 do  // Get the size of all archives
        if (not IsTaskSelected(Records[n].task) and (Records[n].task <>'')) and (not IsComponentSelected(Records[n].comp) and (Records[n].comp <>'')) then Continue // ���������� � ������ �� �������
        else totalUncompressedSize:= totalUncompressedSize + AddArcs(Records[n].Path, Records[n].Dest); // ������ ������ �������
    // Other initializations
    WizardForm.StatusLabel.Caption:= cm('ArcTitle');    // ������ ����a ����������
    ExtractFile.Show; ProgressBar.Show;
    baseMb:= 0; lastMb:= 0; Status.mb:= 0; // �������� ���������� ���������, ���� ����� ���� ������� ������ ������ ������������
    Status.count:= 0;   // �� ��������� �����, ����������� �������������
    UpdateStatus(7);  // ���������� �������� ������ �������
  for ArcInd:= 0 to GetArrayLength(Arcs) -1 do begin    // ������ � ������� �����, ��������� �������� � ArcDecode
    Result:= UnPackArchive(Arcs[ArcInd].Path, Arcs[ArcInd].Dest, Arcs[ArcInd].allMb, 0);  // ��� ������
    if Result <> 0 then Break;    // �������� ���� ����������
    baseMb:= baseMb + lastMb; lastMb:= 0; Status.mb:= 0; // ����� ����� ������������� ������
    // ������������ ����� ������������� ���������, ���� ��������� � ����� {app} ��� {tmp}
    if (Pos(AnsiLowercase(ExpandConstant('{app}')), AnsiLowercase(Arcs[ArcInd].Path)) > 0) or (Pos(AnsiLowercase(ExpandConstant('{tmp}')), AnsiLowercase(Arcs[ArcInd].Path)) > 0) then
        DeleteFile(Arcs[ArcInd].Path);
  end;
    if Result = 0 then WizardForm.StatusLabel.Caption:= FmtMessage(cm('ArcFinish'), [IntToStr(GetArrayLength(Arcs)), IntToStr(Status.count), ByteOrTB(Status.size*oneMB, true)]);
    StatusInfo.Hide; ExtractFile.Hide; ProgressBar.Hide;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
    if CurStep = ssInstall then begin
        StartInstall:= GetTickCount    {����� ������ ���������� ������}
        WndHookID:= SetWindowsHookEx(WH_CALLWNDPROC, WrapCWPSTRUCTProc(@OnWndHook, 3), 0, GetCurrentThreadID);    {��������� SendMessage ����}
        TimerID:= SetTimer(0, 0, 500 {����������}, WrapTimerProc(@MyTimerProc, 4));    {��������� �������}
        if not {#isFalse(SetupSetting("Uninstallable"))} then Status.count:= -1; // �� ������� ���� unins000.exe
    end;
    if CurStep = ssPostInstall then
    begin
        StartInstall:= GetTickCount    {����� ������ ����������}
        UnPackError:= UnPack('{#Archives}')
        if UnPackError <> 0 then begin // Error occured, uninstall it then
            if not {#isFalse(SetupSetting("Uninstallable"))} then  // ������������� ���������
                Exec(ExpandConstant('{uninstallexe}'), '/SILENT','', sw_Hide, ewWaitUntilTerminated, n);    // ����� ��������� ��-�� ������ unarc.dll
            WizardForm.caption:= SetupMessage(msgErrorTitle) +' - '+ cm('ArcBreak')
            SetTaskBarTitle(SetupMessage(msgErrorTitle))
        end else
            SetTaskBarTitle(SetupMessage(msgSetupAppTitle));
    end;
end;

Procedure SetTexture(CurPageID: Integer);    // �� ������ �������� ���� ��������
Begin
    WizardForm.Bevel1.Visible:= (WizardForm.CurPageID <> wpWelcome) and (WizardForm.CurPageID <> wpFinished);
        WizardForm.Bevel1.Parent:= WizardForm.OuterNotebook.ActivePage
    Texture.Parent:= WizardForm.InnerNotebook.ActivePage; Texture.SendToBack;
    Texture.Visible:= CurPageID = wpInstalling; Texture2.Visible:= Texture.Visible;
End;

Procedure CurPageChanged(CurPageID: Integer);
Begin
    SetTexture(CurPageID)
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
        MainForm.Close; // ����������� ������� ������ �������� ����, ������ ��� Escape.
End;

Procedure InitializeWizard();
Begin
// Create controls to show extended info
    StatusLabel:= CreateLabel(WizardForm.InstallingPage,false,false,true,'',[],0,0,0,0,0, WizardForm.StatusLabel);
    FileNameLabel:= CreateLabel(WizardForm.InstallingPage,false,false,true,'',[],0,0,0,0,0, WizardForm.FileNameLabel);
    WizardForm.StatusLabel.Top:= WizardForm.ProgressGauge.Top; WizardForm.FileNameLabel.Top:= WizardForm.ProgressGauge.Top;    // ������ ��� �����������, ����� ��� ������� WM_PAINT ���������������
    with WizardForm.ProgressGauge do begin
    StatusInfo:= CreateLabel(WizardForm.InstallingPage, false, true, true, '', [], 0, 0, Top + ScaleY(32), Width, 0, Nil);
    ProgressBar := TNewProgressBar.Create(WizardForm);
        ProgressBar.SetBounds(Left, StatusInfo.Top + StatusInfo.Height + ScaleY(16), Width, Height);
        ProgressBar.Parent := WizardForm.InstallingPage;
        ProgressBar.max := 65536;
        ProgressBar.Hide;   // ����� ������� ��� ��������� ���������� �������
    ExtractFile:= CreateLabel(WizardForm.InstallingPage, false, true, true, '', [], 0, 0, ProgressBar.Top + ScaleY(32), Width, 0, Nil);
    end;
    WizardForm.OnClose:= @WizardClose   // ��������� �������� ���������� ������� ������������ ���������
// ������� �������
 Texture:= TBitmapImage.Create(WizardForm);
    Texture.SetBounds(-WizardForm.InnerNotebook.Left, -WizardForm.InnerNotebook.Top, WizardForm.ClientWidth, WizardForm.ClientHeight);
    GradientFill(Texture, BackColor, EndColor);    // ������ ��������� ����� ��������� ��������
 Texture2:= TBitmapImage.Create(WizardForm);
    Texture2.SetBounds(0, 0, WizardForm.ClientWidth, WizardForm.ClientHeight);
    Texture2.Parent:= WizardForm.InnerPage;
    Texture2.Bitmap:= Texture.Bitmap;
End;

Procedure DeInitializeSetup;
Begin
    KillTimer(0, TimerID)        {�������� �������}
    UnhookWindowsHookEx(WndHookID)    {�������� SendMessage ����}
End;
