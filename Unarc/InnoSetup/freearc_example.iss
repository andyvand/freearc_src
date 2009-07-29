;[English]
;Example of using unarc.dll for decompression of FreeArc archives with displaying of progress indicator in Inno Setup window.
;YOU NEED TO PROVIDE CORRECT VALUE FOR totalSize BELOW!
;
;[Russian]
;������ ���������� FreeArc ������ ��� ������ unarc.dll, � ������������ ��������� ���������� � ���� Inno Setup.
;���������� ���������� ���������� �������� totalSize ����!
;
;���� ����� ����� ����� � ������������, ���� �� ����� ������ �� ����� 2��, ����� "copy /b setup.exe+xxx.arc newsetup.exe" � ������� � ���� Archives = '{srcexe}'
;
; ��������� �� Bulat Ziganshin, 10-07-2009
;   - ������ '������ ���������' ������ �� ������������, ������� � ������� ����� ��������� ����������� ������ ������
;   - � unarc.dll ���������� ������, �������� �������������� ���������� ��� ���������� ��������� �������
;
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
; ��������� �� Victor_Dobrov, 02-07-2009
;   - ������ ������������ � ������ ����� ���������� ����� �� ���������� ��������� ���� ������� � ����� ������� ����������.
;   - � Unicode-������� ������������ ��������� ������������ ����� ������.
;
; ��������� �� CTACKo & SotM'�. 01-07-2009
;   - ��������� ��������� �����, ���� � ���� ��������� ����������� ������� �����
;   - ��� ���������� ������������ ������������� PAnsiChar/PChar. ����� ������������ ��� ������� ��� � UNICODE ������ � ������������� ��������������.
;
; ��������� �� SotM'�. 23-06-2009
;   - ������ �������� ��� ������� ����-���� ����, ����� ���� ����� ��� ���������������� �����.
;   - ������� ����� ������ ������ ��������� ������������.
;   - ��� ������� "������" ��� ���������� ������ ���������� ������ �� ������������� ������.
;   - ������������ ��������� ����������, ����� �� ����� ����� ������ ����������.
;   - ������� ���������������� ��� �������� ��� ��� ����� �������� � ��������� ������.
;   - �������� ���� ��������� �� ���������� �����.

; ��������� �� Victor_Dobrov, 15-06-2009
;   - ����������� � ����������� �������, ����� ��������� ������ �������, ����� ��������-���, ��� ��������� ���������� ����������� ����� (�������������) � ������������ ����� ������.

; Bulat Ziganshin, 13-06-2009
;   - �������� ���������� unarc.dll � ������� ���������� freearc_example.iss.

[Setup]
AppName=FreeArc Example
AppVerName=FreeArc Example 2.0
DefaultDirName={pf}\FreeArc Example
UsePreviousAppDir=false
DirExistsWarning=no
ShowLanguageDialog=auto
OutputBaseFilename=FreeArcExample
OutputDir=.
VersionInfoCopyright=Bulat Ziganshin, Victor Dobrov, SotM, CTACKo

[Languages]
Name: eng; MessagesFile: compiler:Default.isl
Name: rus; MessagesFile: compiler:Languages\Russian.isl

[CustomMessages]
eng.ArcBreak=Installation cancelled!
eng.ExtractedInfo=Extracted %1 Mb of %2 Mb
eng.ArcInfo=Archive: %1 of %2
eng.ArcTitle=Extracting FreeArc archive
eng.ArcError=Decompression failed with error code %1
eng.ArcFail=Decompression failed!
eng.AllProgress=Overall extraction progress: %1%%
eng.ArcBroken=Archive %1 is damaged%nor not enough free space.
eng.Extracting=Extracting: %1
eng.taskbar=%1%%, %2 remains
eng.remains=Remaining time: %1
eng.LongTime=at no time
eng.ending=ending
eng.hour= hours
eng.min= mins
eng.sec= secs

rus.ArcBreak=��������� ��������!
rus.ExtractedInfo=����������� %1 �� �� %2 ��
rus.ArcInfo=�����: %1 �� %2
rus.ArcTitle=���������� ������� FreeArc
rus.ArcError=����������� FreeArc ������ ��� ������: %1
rus.ArcFail=���������� �� ���������!
rus.AllProgress=����� �������� ����������: %1%%
rus.ArcBroken=��������, ����� %1 ��������%n��� ������������ ����� �� ����� ����������.
rus.Extracting=���������������: %1
rus.taskbar=%1%%, ��� %2
rus.remains=�������� ����� %1
rus.LongTime=�����
rus.ending=����������
rus.hour= �����
rus.min= ���
rus.sec= ���

[Files]
;Source: *.arc; DestDir: {app}; Flags: nocompression
Source: arc.ini; DestDir: {tmp}; Flags: dontcopy
Source: unarc.dll; DestDir: {tmp}; Flags: dontcopy deleteafterinstall
Source: compiler:InnoCallback.dll; DestDir: {tmp}; Flags: dontcopy

[UninstallDelete]
Type: filesandordirs; Name: {app}

[Code]
const
    Archives = '{src}\*.arc';    // ������� ������������ ������� FreeArc; ��� ������� ������ ������ � [Files] ��������� �������������

    PM_REMOVE = 1;
    CP_ACP = 0; CP_UTF8 = 65001;
    oneMb = 1048576;

type
#ifdef UNICODE  ; ���� � ��� ������ �� ���� ������, �� ���������� ������������ ��� ��������� ������ ��� ����� ������ Inno Setup
    #define A "W"
#else
    #define A "A"  ; ����� ����� � SetWindowText, {#A} �������� �� A ��� W � ����������� �� ������
    PAnsiChar = PChar;  // Required for Inno Setup 5.3.0 and higher. (��������� ��� Inno Setup ������ 5.3.0 � ����)
#endif
#if Ver < 84018176
    AnsiString = String; // There is no need for this line in Inno Setup 5.2.4 and above (��� Inno Setup ������ 5.2.4 � ���� ��� ������ �� �����)
#endif

    TMyMsg = record
        hwnd: HWND;
        message: UINT;
        wParam: Longint;
        lParam: Longint;
        time: DWORD;
        pt: TPoint;
    end;

    TFreeArcCallback = function (what: PAnsiChar; int1, int2: Integer; str: PAnsiChar): Integer;
    TArc = record Path: string; OrigSize: Integer; Size: Extended; end;

var
    ExtractFile: TLabel;
    lblExtractFileName: TLabel;
    btnCancelUnpacking: TButton;
    CancelCode, n, UnPackError, StartInstall: Integer;
    Arcs: array of TArc;
    msgError: string;
    lastMb: Integer;
    baseMb: Integer;
    totalUncompressedSize: Integer;             // total uncompressed size of archive data in mb
    LastTimerEvent: DWORD;

Function MultiByteToWideChar(CodePage: UINT; dwFlags: DWORD; lpMultiByteStr: string; cbMultiByte: integer; lpWideCharStr: string; cchWideChar: integer): longint; external 'MultiByteToWideChar@kernel32.dll stdcall';
Function WideCharToMultiByte(CodePage: UINT; dwFlags: DWORD; lpWideCharStr: string; cchWideChar: integer; lpMultiByteStr: string; cbMultiByte: integer; lpDefaultChar: integer; lpUsedDefaultChar: integer): longint; external 'WideCharToMultiByte@kernel32.dll stdcall';

function PeekMessage(var lpMsg: TMyMsg; hWnd: HWND; wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): BOOL; external 'PeekMessageA@user32.dll stdcall';
function TranslateMessage(const lpMsg: TMyMsg): BOOL; external 'TranslateMessage@user32.dll stdcall';
function DispatchMessage(const lpMsg: TMyMsg): Longint; external 'DispatchMessageA@user32.dll stdcall';

Function OemToChar(lpszSrc, lpszDst: AnsiString): longint; external 'OemToCharA@user32.dll stdcall';
function GetWindowLong(hWnd, nIndex: Integer): Longint; external 'GetWindowLongA@user32 stdcall delayload';
function SetWindowText(hWnd: Longint; lpString: String): Longint; external 'SetWindowText{#A}@user32 stdcall delayload';

function GetTickCount: DWord; external 'GetTickCount@kernel32';
function WrapFreeArcCallback (callback: TFreeArcCallback; paramcount: integer):longword; external 'wrapcallback@files:innocallback.dll stdcall';
function FreeArcExtract (callback: longword; cmd1,cmd2,cmd3,cmd4,cmd5,cmd6,cmd7,cmd8,cmd9,cmd10: PAnsiChar): integer; external 'FreeArcExtract@files:unarc.dll cdecl';

procedure AppProcessMessage;
var
    Msg: TMyMsg;
begin
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
    end;
end;

// ������� ����� � ������ � ��������� 3 ����� (%.3n) � ����������� ������� �����, ���� ��� ����
Function NumToStr(Float: Extended): String;
Begin
    Result:= Format('%.3n', [Float]); StringChange(Result, ',', '.');
    while ((Result[Length(Result)] = '0') or (Result[Length(Result)] = '.')) and (Length(Result) > 1) do
        SetLength(Result, Length(Result)-1);
End;

function cm(Message: String): String; Begin Result:= ExpandConstant('{cm:'+ Message +'}') End;

Function Size64(Hi, Lo: Integer): Extended;
Begin
    Result:= Lo;
    if Lo<0 then Result:= Result + $7FFFFFFF + $7FFFFFFF + 2;
    for Hi:= Hi-1 Downto 0 do
        Result:= Result + $7FFFFFFF + $7FFFFFFF + 2;
End;

// Converts OEM encoded string into ANSI
// ����������� OEM ������ � ANSI ���������
function OemToAnsiStr( strSource: AnsiString): AnsiString;
var
    nRet : longint;
begin
    SetLength( Result, Length( strSource ) );
    nRet:= OemToChar( strSource, Result );
end;

// Converts ANSI encoded string into UTF-8
// ����������� ������ �� ANSI � UTF-8 ���������
function AnsiToUtf8( strSource: string ): string;
var
    nRet : integer;
    WideCharBuf: string;
    MultiByteBuf: string;
begin
    strSource:= strSource + chr(0);
    SetLength( WideCharBuf, Length( strSource ) * 2 );
    SetLength( MultiByteBuf, Length( strSource ) * 2 );

    nRet:= MultiByteToWideChar( CP_ACP, 0, strSource, -1, WideCharBuf, Length(WideCharBuf) );
    nRet:= WideCharToMultiByte( CP_UTF8, 0, WideCharBuf, -1, MultiByteBuf, Length(MultiByteBuf), 0, 0);

    Result:= MultiByteBuf;
end;

// OnClick event function for btnCancel
procedure btnCancelUnpackingOnClick(Sender: TObject);
begin
    if MsgBox( SetupMessage( msgExitSetupMessage ), mbInformation, MB_YESNO ) = IDYES then
        CancelCode:= -127;
end;

var origsize: Integer;
// The callback function for getting info about FreeArc archive
function FreeArcInfoCallback (what: PAnsiChar; Mb, sizeArc: Integer; str: PAnsiChar): Integer;
begin
    if string(what)='origsize'    then origsize := Mb else
    if string(what)='compsize'    then                else
    if string(what)='total_files' then                else
    Result:= CancelCode;
end;

// Returns decompressed size of files in archive
function ArchiveOrigSize(arcname: string): Integer;
var
    callback: longword;
Begin
    callback:= WrapFreeArcCallback(@FreeArcInfoCallback,4);   //FreeArcInfoCallback has 4 arguments
    CancelCode:= 0;
    AppProcessMessage;
    try
        // Pass the specified arguments to 'unarc.dll'
        Result:= FreeArcExtract (callback, 'l', '--', AnsiToUtf8(arcname), '', '', '', '', '', '', '');
        if CancelCode < 0 then Result:= CancelCode;
        if Result >= 0 then Result:= origsize;
    except
        Result:= -63;  //    ArcFail
    end;
end;

// Scans the specified folders for archives and add them to list
function FindArcs(dir: string): Extended;
var
    FSR: TFindRec;
Begin
    Result:= 0;
    if FindFirst(ExpandConstant(dir), FSR) then begin
        try
            repeat
                // Skip everything but the folders
                if FSR.Attributes and FILE_ATTRIBUTE_DIRECTORY > 0 then CONTINUE;
                n:= GetArrayLength(Arcs);
                // Expand the folder list
                SetArrayLength(Arcs, n +1);
                Arcs[n].Path:= ExtractFilePath(ExpandConstant(dir)) + FSR.Name;
                Arcs[n].Size:= Size64(FSR.SizeHigh, FSR.SizeLow);
                Result:= Result + Arcs[n].Size;
                Arcs[n].OrigSize := ArchiveOrigSize(Arcs[n].Path)
                totalUncompressedSize := totalUncompressedSize + Arcs[n].OrigSize
            until not FindNext(FSR);
        finally
            FindClose(FSR);
        end;
    end;
End;

// Sets the TaskBar title
Procedure SetTaskBarTitle(Title: String); var h: Integer;
Begin
    h:= GetWindowLong(MainForm.Handle, -8); if h <> 0 then SetWindowText(h, Title);
End;

// Converts milliseconds to human-readable time
// ������������ ����������� � ��������-�������� ����������� �������
Function TicksToTime(Ticks: DWord; h,m,s: String; detail: Boolean): String;
Begin
    if detail                               {hh:mm:ss format} then
        Result:= PADZ(IntToStr(Ticks/3600000), 2) +':'+ PADZ(IntToStr((Ticks/1000 - Ticks/1000/3600*3600)/60), 2) +':'+ PADZ(IntToStr(Ticks/1000 - Ticks/1000/60*60), 2)
    else if Ticks/3600 >= 1000              {more than hour}  then
        Result:= IntToStr(Ticks/3600000) +h+' '+ PADZ(IntToStr((Ticks/1000 - Ticks/1000/3600*3600)/60), 2) +m
    else if Ticks/60 >= 1000                {1..60 minutes}   then
        Result:= IntToStr(Ticks/60000) +m+' '+ PADZ(IntToStr(Ticks/1000 - Ticks/1000/60*60), 2) +s
   else Result:= IntToStr(Ticks/1000) +s    {less than one minute}
End;

// The main callback function for unpacking FreeArc archives
function FreeArcCallback (what: PAnsiChar; Mb, sizeArc: Integer; str: PAnsiChar): Integer;
var
    percents, Remaining: Integer;
    s: String;
begin
    if GetTickCount - LastTimerEvent > 1000 then begin
        // This code will be executed once each 1000 ms (���� ��� ����� ����������� ��� � 1000 �����������)
        //  ....
        // End of code executed by timer
        LastTimerEvent := LastTimerEvent+1000;
    end;
    
    if string(what)='filename' then begin
        // Update FileName label
        lblExtractFileName.Caption:= FmtMessage( cm( 'Extracting' ), [OemToAnsiStr( str )] )
    end else if (string(what)='write') and (totalUncompressedSize>0) and (Mb>lastMb) then begin
        // Assign to Mb *total* amount of data extracted to the moment from all archives
        lastMb := Mb;
        Mb := baseMb+Mb;
    
        // Update progress bar
        WizardForm.ProgressGauge.Position:= Mb;

        // Show how much megabytes/archives were processed up to the moment
        percents:= (Mb*1000) div totalUncompressedSize;
        s := FmtMessage(cm('ExtractedInfo'), [IntToStr(Mb), IntToStr(totalUncompressedSize)]);
        if GetArrayLength(Arcs)>1 then
            s := s + '. '+FmtMessage(cm('ArcInfo'), [IntToStr(n+1), IntToStr(GetArrayLength(Arcs))])
        ExtractFile.Caption := s

        // Calculate and show current percents
        percents:= (Mb*1000) div totalUncompressedSize;
        s:= FmtMessage(cm('AllProgress'), [Format('%.1n', [Abs(percents/10)])]);
        if Mb > 0 then Remaining:= trunc((GetTickCount - StartInstall) * Abs((totalUncompressedSize - Mb)/Mb)) else Remaining:= 0;
        if Remaining = 0 then SetTaskBarTitle(cm('ending')) else begin
            s:= s + '.  '+FmtMessage(cm('remains'), [TicksToTime(Remaining, cm('hour'), cm('min'), cm('sec'), false)])
            SetTaskBarTitle(FmtMessage(cm('taskbar'), [IntToStr(percents/10), TicksToTime(Remaining, 'h', 'm', 's', false)]))
        end;
        WizardForm.FileNameLabel.Caption := s
    end;
    AppProcessMessage;
    Result:= CancelCode;
end;

// Extracts all found archives
function UnPack(Archives: string): Integer;
var
    totalCompressedSize: Extended;
    callback: longword;
    FreeMB, TotalMB: Cardinal;
begin
    // Display 'Extracting FreeArc archive'
    lblExtractFileName.Caption:= '';
    lblExtractFileName.Show;
    ExtractFile.caption:= cm('ArcTitle');
    ExtractFile.Show;
    // Show the 'Cancel unpacking' button and set it as default button
    btnCancelUnpacking.Caption:= WizardForm.CancelButton.Caption;
    btnCancelUnpacking.Show;
    WizardForm.ActiveControl:= btnCancelUnpacking;
    WizardForm.ProgressGauge.Position:= 0;
    // Get the size of all archives
    totalUncompressedSize := 0;
    totalCompressedSize := FindArcs(Archives);
    WizardForm.ProgressGauge.Max:= totalUncompressedSize;
    // Other initializations
    callback:= WrapFreeArcCallback(@FreeArcCallback,4);   //FreeArcCallback has 4 arguments
    StartInstall:= GetTickCount;    {����� ������ ����������}
    LastTimerEvent:= GetTickCount;
    baseMb:= 0

    for n:= 0 to GetArrayLength(Arcs) -1 do
    begin
        lastMb := 0
        CancelCode:= 0;
        AppProcessMessage;
        try
            // Pass the specified arguments to 'unarc.dll'
            Result:= FreeArcExtract (callback, 'x', '-o+', '-dp' + AnsiToUtf8( ExpandConstant('{app}') ), '--', AnsiToUtf8(Arcs[n].Path), '', '', '', '', '');
            if CancelCode < 0 then Result:= CancelCode;
        except
            Result:= -63;  //    ArcFail
        end;
        baseMb:= baseMb+lastMb

        // Error occured
        if Result <> 0 then
        begin
            msgError:= FmtMessage(cm('ArcError'), [IntToStr(Result)]);
            GetSpaceOnDisk(ExtractFileDrive(ExpandConstant('{app}')), True, FreeMB, TotalMB);
            case Result of
                -1: if FreeMB < 32 {�� �� �����} then msgError:= SetupMessage(msgDiskSpaceWarningTitle)
                    else msgError:= msgError + #13#10 + FmtMessage(cm('ArcBroken'), [ExtractFileName(Arcs[n].Path)]);
                -127:   msgError:= cm('ArcBreak');    //Cancel button
                -63:    msgError:= cm('ArcFail');
            end;
//          MsgBox(msgError, mbInformation, MB_OK);    //��������� ������������ �� �������� ����������
            Log(msgError);
            Break;    //�������� ���� ����������
        end;
    end;
    // Hide labels and button
    WizardForm.FileNameLabel.Caption:= '';
    lblExtractFileName.Hide;
    ExtractFile.Hide;
    btnCancelUnpacking.Hide;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
    if CurStep = ssPostInstall then
    begin
        UnPackError:= UnPack(Archives)
        if UnPackError = 0 then
            SetTaskBarTitle(SetupMessage(msgSetupAppTitle))
        else
        begin
            // Error occured, uninstall it then
            Exec(ExpandConstant('{uninstallexe}'), '/SILENT','', sw_Hide, ewWaitUntilTerminated, n);    //����� ��������� ��-�� ������ unarc.dll
            SetTaskBarTitle(SetupMessage(msgErrorTitle))
            WizardForm.Caption:= SetupMessage(msgErrorTitle) +' - '+ cm('ArcBreak')
        end;
    end;
end;

//    ����������� ������ ������ (�� ����� CurPageChanged), �� ������ ��������������� �� ���������� ������ ������������
//    if CurStep = ssInstall then
//      if UnPack(Archives) <> 0 then Abort;

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

procedure InitializeWizard();
begin
    with WizardForm.ProgressGauge do
    begin
        // Create a label to show current FileName being extracted
        lblExtractFileName:= TLabel.Create(WizardForm);
        lblExtractFileName.parent:=WizardForm.InstallingPage;
        lblExtractFileName.autosize:=false;
        lblExtractFileName.Width:= Width;
        lblExtractFileName.top:=Top + ScaleY(35);
        lblExtractFileName.Caption:= '';
        lblExtractFileName.Hide;

        // Create a label to show percentage
        ExtractFile:= TLabel.Create(WizardForm);
        ExtractFile.parent:=WizardForm.InstallingPage;
        ExtractFile.autosize:=false;
        ExtractFile.Width:= Width;
        ExtractFile.top:=lblExtractFileName.Top + ScaleY(16);
        ExtractFile.caption:= '';
        ExtractFile.Hide;
    end;

    // Create a 'Cancel unpacking' button and hide it for now.
    btnCancelUnpacking:=TButton.create(WizardForm);
    btnCancelUnpacking.Parent:= WizardForm;
    btnCancelUnpacking.SetBounds(WizardForm.CancelButton.Left, WizardForm.CancelButton.top, WizardForm.CancelButton.Width, WizardForm.CancelButton.Height);
    btnCancelUnpacking.OnClick:= @btnCancelUnpackingOnClick;
    btnCancelUnpacking.Hide;
end;
