program Halte3;

uses
  FastMM4 in 'FastMM\FastMM4.pas',
  Forms,
  hMain in 'hMain.pas' {MainForm} ,
  hTypes in 'hTypes.pas',
  AppInfo in 'Core\AppInfo.pas',
  AssistantConst in 'Core\AssistantConst.pas',
  CRC in 'Core\CRC.pas',
  CustoManager in 'Core\CustoManager.pas',
  CustomStream in 'Core\CustomStream.pas',
  PluginFunc in 'Core\PluginFunc.pas',
  FastMM4Messages in 'FastMM\FastMM4Messages.pas',
  hPlugin in 'hPlugin.pas' {PluginDialog} ,
  hABOUT in 'hABOUT.pas' {AboutBox} ,
  hSearch in 'hSearch.pas' {Search} ,
  hOption in 'hOption.pas' {OptionForm} ,
  hHelp in 'hHelp.pas' {HelpForm} ,
  hDocumentTypes in 'hDocumentTypes.pas',
  hAutoDetect in 'hAutoDetect.pas' {frmAutoDetect} ,
  hCPtypes in 'hCPtypes.pas',
  hParam in 'hParam.pas',
  SysUtils,
  Classes,
  Dialogs,
  hPreview in 'hPreview.pas' {PreviewDialog} ,
  bass in 'SoundSupport\bass.pas',
  hBrowser in 'hBrowser.pas';

{$R *.res}

const
  PluginPath = '\GP\';

function GetAppPath: string;
begin
  Result := ExtractFilePath(Application.ExeName);
end;

function GetTime: string;
begin
  Result := DateToStr(Date) + ' ' + TimeToStr(Time) + '  ';
end;

begin
  IsMultiThread := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Halte3';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TPluginDialog, PluginDialog);
  Application.CreateForm(TAboutBox, AboutBox);
  Application.CreateForm(TSearch, Search);
  Application.CreateForm(TOptionForm, OptionForm);
  Application.CreateForm(THelpForm, HelpForm);
  Application.CreateForm(TfrmAutoDetect, frmAutoDetect);
  Application.CreateForm(TPreviewDialog, PreviewDialog);
  Application.Run;

end.
