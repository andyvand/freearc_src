;������ ���������� 7zip ������, � ������������ �������� ���� � ���� Inno Setup ��� ������ is7z.dll v1.01
;����� ������� � is7z.dll ������ ������� (aka ExpeditoR)
;������ ���� ��� dimon-na-domu@mail.ru
;���� ��� ����������� ������ ����������, �� ��������� �� ��� ���� http://mp3runner.narod.ru/
;� ���������� ������ ��� ������ mp3runner.
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
var
 ProgressBar: TNewProgressBar;
 ExtractFile: TNewStaticText;
 Button1:     TButton;

type
 FreeArcCallback = function (what: PChar; int1, int2: Integer; str: PChar): Integer;

function WrapFreeArcCallback (callback:FreeArcCallback; paramcount:integer):longword;
  external 'wrapcallback@files:innocallback.dll stdcall';

function FreeArcExtract (callback: longword; cmd1,cmd2,cmd3,cmd4,cmd5,cmd6,cmd7,cmd8,cmd9,cmd10: PChar): integer; external 'FreeArcExtract@files:unarc.dll cdecl';

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
      ProgressBar.max := 100;
      ProgressBar.Position := 0;
      ExtractFile.parent:=WizardForm.InstallingPage;
      ExtractFile.autosize:=false;
      ExtractFile.Width := Width;
      ExtractFile.top:=Top + ScaleX(35);
      ExtractFile.caption:='���������� ������ 7zip';
    end;
end;

procedure Button1OnClick(Sender: TObject);
begin
// CancelExtract;
end;

procedure CurStepChanged(CurStep: TSetupStep);
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
    callback:=WrapCallback(@WrapFreeArcCallback,4); //Our proc has 4 arguments
    try
     FreeArcExtract (callback, 'x', '-dp'+ExpandConstant('{app}'), ExpandConstant('{tmp}') + '\1.arc', '', '', '', '', '', '', '');
     Button1.visible:=false;
    except
     MsgBox('�������� ������!', mbInformation, MB_OK);
     Button1.visible:=false;
    end;
   end;
end;
