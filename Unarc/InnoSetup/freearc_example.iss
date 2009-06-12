;������ ���������� FreeArc ������, � ������������ �������� ���� � ���� Inno Setup ��� ������ unarc.dll
[Setup]
AppName=My Program
AppVerName=My Program version 1.5
DefaultDirName={pf}\My Program
DefaultGroupName=My Program
Compression=zip

[Languages]
Name: rus; MessagesFile: compiler:Languages\Russian.isl

[Files]
Source: 1.arc; DestDir: {tmp}; Flags: ignoreversion recursesubdirs createallsubdirs
Source: ..\unarc.dll; DestDir: {tmp}; Flags: dontcopy
Source: InnoCallback.dll; DestDir: {tmp}; Flags: dontcopy

[Icons]
Name: {group}\�������; IconFilename: {app}\unins000.exe; Filename: {app}\unins000.exe

[Code]
type
  TMsg = record
    hwnd: HWND;
    message: UINT;
    wParam: Longint;
    lParam: Longint;
    time: DWORD;
    pt: TPoint;
  end;

const
  PM_REMOVE      = 1;

function PeekMessage(var lpMsg: TMsg; hWnd: HWND; wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): BOOL; external 'PeekMessageA@user32.dll stdcall';
function TranslateMessage(const lpMsg: TMsg): BOOL; external 'TranslateMessage@user32.dll stdcall';
function DispatchMessage(const lpMsg: TMsg): Longint; external 'DispatchMessageA@user32.dll stdcall';

procedure AppProcessMessage;
var
  Msg: TMsg;
begin
  while PeekMessage(Msg, WizardForm.Handle, 0, 0, PM_REMOVE) do begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
end;



type
  TFreeArcCallback = function (what: PChar; int1, int2: Integer; str: PChar): Integer;

function WrapFreeArcCallback (callback: TFreeArcCallback; paramcount: integer):longword;
  external 'wrapcallback@files:innocallback.dll stdcall';

function FreeArcExtract (callback: longword; cmd1,cmd2,cmd3,cmd4,cmd5,cmd6,cmd7,cmd8,cmd9,cmd10: PChar): integer; external 'FreeArcExtract@files:unarc.dll cdecl';



var
 ProgressBar: TNewProgressBar;
 ExtractFile: TNewStaticText;
 Button1:     TButton;
 Cancel:      Integer;

procedure InitializeWizard();
begin
  ProgressBar := TNewProgressBar.Create(WizardForm);
  ExtractFile:=TNewStaticText.Create(WizardForm);
  with WizardForm.ProgressGauge do
    begin
      ProgressBar.Left := Left;
      ProgressBar.Top := Top + ScaleX(55);
      ProgressBar.Width := Width;
      ProgressBar.Height := Height;
      ProgressBar.Parent := WizardForm.InstallingPage;
      ProgressBar.max := 1000;
      ProgressBar.Position := 0;
      ExtractFile.parent:=WizardForm.InstallingPage;
      ExtractFile.autosize:=false;
      ExtractFile.Width := Width;
      ExtractFile.top:=Top + ScaleX(35);
      ExtractFile.caption:='���������� ������ FreeArc';
    end;
end;

procedure Button1OnClick(Sender: TObject);
begin
  Cancel := -1;
end;

function FreeArcCallback (what: PChar; int1, int2: Integer; str: PChar): Integer;
var percents: Integer;
begin
  if string(what)='filename' then
      //ExtractFile.Caption:=str
  else if (string(what)='progress') and (int2>0) then begin
      percents := (int1*1000) div int2;
      ProgressBar.Position := percents;
      ExtractFile.Caption:='����������� '+IntToStr(int1)+' �� '+IntToStr(int2)+' �� ('+FloatToStr(percents/10)+'%)';
  end;
  AppProcessMessage;
  Result := Cancel;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var callback: longword;
begin
  If CurStep=ssPostInstall then
   begin
    Button1:=TButton.create(WizardForm);
    Button1.parent:=WizardForm;
    Button1.width:=135;
    Button1.caption:='�������� ����������';
    Button1.left:=260;
    Button1.top:=WizardForm.cancelbutton.top;
    Button1.OnClick:=@Button1OnClick;
    callback:=WrapFreeArcCallback(@FreeArcCallback,4);   //FreeArcCallback has 4 arguments
    Cancel := 0;
    try
     AppProcessMessage;
     FreeArcExtract (callback, 'x', '-o+', '-dp'+ExpandConstant('{app}'), ExpandConstant('{tmp}') + '\1.arc', '', '', '', '', '', '');
     Button1.visible:=false;
     if cancel<0 then
       MsgBox('��������� ��������!', mbInformation, MB_OK);
    except
     MsgBox('�������� ������!', mbInformation, MB_OK);
     Button1.visible:=false;
    end;
   end;
end;
