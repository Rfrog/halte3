unit hPreview;

interface

uses Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Forms,
  Vcl.Controls, Vcl.StdCtrls, Vcl.Buttons, Vcl.ExtCtrls, Vcl.Imaging.pngimage,
  jpeg, Vcl.Dialogs;

type
  TFileType = (clImage, clText, clSound, clNone);

  TPreviewDialog = class(TForm)
    OKBtn: TButton;
    Bevel1: TBevel;
    Image1: TImage;
    Memo1: TMemo;
    Edit1: TEdit;
    Button1: TButton;
    procedure OKBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    FData: TMemoryStream;
    function GetType(Buffer: TStream; Name: string): TFileType;
  public
    Encode: TEncoding;
    procedure Preview(Buffer: TStream; Name: string);
  end;

var
  PreviewDialog: TPreviewDialog;

implementation

{$R *.dfm}

uses bass;

const
  PNGMagic: AnsiString = #$89'PNG';
  BMPMagic: AnsiString = 'BM';
  JpegExt = '.jpg';
  TGAExt = '.TGA';

  TxtExt = '.txt';
  KSExt = '.ks';
  LUAExt = '.Lua';
  XMLExt = '.xml';
  CSVExt = '.csv';
  INIExt = '.ini';

  WAVMagic: AnsiString = 'RIFF';
  OGGMagic: AnsiString = 'OggS';
  Mp3Ext = '.mp3';

  cWidth = 400;
  cHeight = 300;

var
  SineStream: HSTREAM;

function TPreviewDialog.GetType(Buffer: TStream; Name: string): TFileType;
var
  head: array [0 .. 3] of Byte;
begin
  Result := clNone;
  Buffer.Seek(0, soFromBeginning);
  Buffer.Read(head[0], 4);
  if CompareMem(@head[0], Pbyte(PNGMagic), 4) then
  begin
    Result := clImage;
    Exit;
  end;
  if CompareMem(@head[0], Pbyte(BMPMagic), 2) then
  begin
    Result := clImage;
    Exit;
  end;
  if SameText(JpegExt, ExtractFileExt(Name)) then
  begin
    Result := clImage;
    Exit;
  end;
  if SameText(TxtExt, ExtractFileExt(Name)) then
  begin
    Result := clText;
    Exit;
  end;
  if SameText(KSExt, ExtractFileExt(Name)) then
  begin
    Result := clText;
    Exit;
  end;
  if SameText(LUAExt, ExtractFileExt(Name)) then
  begin
    Result := clText;
    Exit;
  end;
  if SameText(XMLExt, ExtractFileExt(Name)) then
  begin
    Result := clText;
    Exit;
  end;
  if SameText(CSVExt, ExtractFileExt(Name)) then
  begin
    Result := clText;
    Exit;
  end;
  if SameText(INIExt, ExtractFileExt(Name)) then
  begin
    Result := clText;
    Exit;
  end;
  if CompareMem(@head[0], Pbyte(WAVMagic), 4) then
  begin
    Result := clSound;
    Exit;
  end;
  if CompareMem(@head[0], Pbyte(OGGMagic), 4) then
  begin
    Result := clSound;
    Exit;
  end;
  if SameText(Mp3Ext, ExtractFileExt(Name)) then
  begin
    Result := clSound;
    Exit;
  end;
end;

procedure TPreviewDialog.Button1Click(Sender: TObject);
begin
  Encode.Free;
  Encode := TEncoding.GetEncoding(StrToIntDef(Edit1.Text, 932));
end;

procedure TPreviewDialog.FormCreate(Sender: TObject);
begin
  // Initialize audio - default device, 44100hz, stereo, 16 bits
  if not BASS_Init(-1, 44100, 0, Handle, nil) then
  begin
    showmessage('Error initializing audio!');
    Halt;
  end;
  FData := TMemoryStream.Create;
  Encode := TEncoding.GetEncoding(932);
end;

procedure TPreviewDialog.FormDestroy(Sender: TObject);
begin
  // Close BASS
  BASS_Free();

  Encode.Free;
  FData.Free;
end;

procedure TPreviewDialog.OKBtnClick(Sender: TObject);
begin
  BASS_StreamFree(SineStream);
  FData.Clear;
  Self.Hide;
end;

procedure TPreviewDialog.Preview(Buffer: TStream; Name: string);
var
  Graph: TGraphic;
  U16: array [1 .. $40] of Cardinal;
  i: Integer;
  Texts: TStringList;
begin
  Edit1.Text := IntToStr(Encode.CodePage);
  Memo1.Clear;
  Show;
  Memo1.Lines.Add('-------------------');
  Memo1.Lines.Add('Preview by Halte3');
  Memo1.Lines.Add('HatsuneTakumi');
  Memo1.Lines.Add('CopyRight2011-2012');
  Memo1.Lines.Add('-------------------');
  Memo1.Lines.Add('Loading resource,pls wait.');
  Memo1.Lines.Add('-------------------');
  Memo1.Lines.Add('FileName: ' + Name);
  Memo1.Lines.Add('FileSize: ' + IntToStr(Buffer.Size));
  case GetType(Buffer, Name) of
    clImage:
      begin
        Graph := TBitmap.Create;
        try
          Buffer.Seek(0, soFromBeginning);
          Graph.LoadFromStream(Buffer);
        except
          Graph.Free;
          Graph := TPngImage.Create;
          try
            Buffer.Seek(0, soFromBeginning);
            Graph.LoadFromStream(Buffer);
          except
            Graph.Free;
            Graph := TJPEGImage.Create;
            try
              Buffer.Seek(0, soFromBeginning);
              Graph.LoadFromStream(Buffer);
            except
              Graph.Free;
              Hide;
              raise Exception.Create('Unsupported Image.');
            end;
          end;
        end;
        Image1.Picture.Assign(Graph);
        Memo1.Lines.Add('FileType: Picture');
        Memo1.Lines.Add(Format('Size: %d * %d', [Graph.Width, Graph.Height]));
        Memo1.Lines.Add('-------------------');
        Graph.Free;
      end;
    clText:
      begin
        Texts := TStringList.Create;
        try
          Memo1.Lines.Add('FileType: Text');
          Memo1.Lines.Add('-------------------');
          Texts.LoadFromStream(Buffer, Encode);
          Memo1.Lines.AddStrings(Texts);
        finally
          Texts.Free;
        end;
      end;
    clSound:
      begin
        BASS_StreamFree(SineStream);
        Buffer.Seek(0, soFromBeginning);
        FData.Clear;
        FData.CopyFrom(Buffer, Buffer.Size);
        SineStream := BASS_StreamCreateFile(True, FData.Memory, 0, FData.Size,
          BASS_SAMPLE_LOOP);
        if SineStream < BASS_ERROR_ENDED then
          raise Exception.Create('Open stream error.');
        BASS_ChannelPlay(SineStream, True);
        Memo1.Lines.Add('FileType: Sound');
        Memo1.Lines.Add('Length: ' +
          floattostr(BASS_ChannelBytes2Seconds(SineStream,
          BASS_ChannelGetLength(SineStream, BASS_POS_BYTE))) + ' s');
        Memo1.Lines.Add('-------------------');
      end;
  else
    begin
      Buffer.Seek(0, soFromBeginning);
      Memo1.Lines.Add('FileType: Unknow');
      Memo1.Lines.Add('Memory dump: ');
      Memo1.Lines.Add('-------------------');
      Buffer.Read(U16[1], $100);
      for i := 1 to $10 do
        Memo1.Lines.Add(Format('%.2x: %.8x %.8x %.8x %.8x',
          [i, U16[i + 0], U16[i + 1], U16[i + 2], U16[i + 3]]));
      Memo1.Lines.Add('-------------------');
    end;
  end;
end;

initialization

if (HIWORD(BASS_GetVersion) <> BASSVERSION) then
begin
  MessageBox(0, 'An incorrect version of BASS.DLL was loaded', nil,
    MB_ICONERROR);
  Halt;
end;

finalization

end.
