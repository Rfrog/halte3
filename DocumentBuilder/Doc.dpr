program Doc;

uses
  Forms,
  DocBuilder in 'DocBuilder.pas' {Form6},
  hDocumentTypes in '..\hDocumentTypes.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm6, Form6);
  Application.Run;
end.
