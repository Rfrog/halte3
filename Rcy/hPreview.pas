unit hPreview;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls,
  StdCtrls,
  Buttons, ExtCtrls, OKCANCL1, jpeg, pngimage, CustomStream,
  Dialogs;

type

  TFileType = (clImage, clText, clSound, clNone);

  TPreviewDialog = class(TOKBottomDlg)
    Edit1: TEdit;
    procedure OKBtnClick(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FPanelCreated: Boolean;
    Encoding: TEncoding;
    function GetType(Buffer: TStream; Name: string): TFileType;
    procedure Resize(sHeight, sWidth: Integer); overload;
  public
    procedure Preview(Buffer: TStream; Name: string);
  end;

var
  PreviewDialog: TPreviewDialog;

implementation

{$R *.dfm}

uses hMain, libZPlay;

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
  Panel: TControl;
  Player: ZPlay;
  MusicType: TStreamFormat;

procedure TPreviewDialog.Resize(sHeight, sWidth: Integer);
begin
  ClientWidth := sWidth;
  ClientHeight := sHeight + okBtn.Height + Edit1.Height + 10;
  Bevel1.Height := sHeight;
  if (Self.Top < 0) or (Self.Top >= Screen.Height) then
    Self.Top := MainForm.Top;
  if (Self.Left < 0) or (Self.Left >= Screen.Width) then
    Self.Left := MainForm.Left;
  Self.Position := poOwnerFormCenter;
end;

procedure TPreviewDialog.FormCreate(Sender: TObject);
begin
  inherited;
  FPanelCreated := False;
  Player := ZPlay.Create;
  Encoding := TEncoding.GetEncoding(932);
end;

procedure TPreviewDialog.FormDestroy(Sender: TObject);
begin
  inherited;
  Player.Free;
  Encoding.Free;
end;

procedure TPreviewDialog.FormHide(Sender: TObject);
begin
  inherited;
  Panel.Free;
  FPanelCreated := False;
  Player.StopPlayback;
  Encoding.Free;
  Encoding := TEncoding.GetEncoding
    (StrToIntDef(Edit1.Text, 932));
end;

procedure TPreviewDialog.FormKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_DOWN:
      begin
        MainForm.ListView1.ItemIndex :=
          MainForm.ListView1.ItemIndex + 1;
        MainForm.PreviewRes(MainForm.ListView1.ItemIndex);
      end;
    VK_UP:
      begin
        MainForm.ListView1.ItemIndex :=
          MainForm.ListView1.ItemIndex - 1;
        MainForm.PreviewRes(MainForm.ListView1.ItemIndex);
      end;
  end;
  inherited;
end;

procedure TPreviewDialog.FormShow(Sender: TObject);
begin
  inherited;
  Edit1.Text := IntToStr(Encoding.CodePage);
end;

function TPreviewDialog.GetType;
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
    MusicType := sfWav;
    Exit;
  end;
  if CompareMem(@head[0], Pbyte(OGGMagic), 4) then
  begin
    Result := clSound;
    MusicType := sfOgg;
    Exit;
  end;
  if SameText(Mp3Ext, ExtractFileExt(Name)) then
  begin
    Result := clSound;
    MusicType := sfMp3;
    Exit;
  end;
end;

procedure TPreviewDialog.OKBtnClick(Sender: TObject);
begin
  inherited;
  Hide;
end;

procedure TPreviewDialog.Preview(Buffer: TStream; Name: string);
var
  Graph: TGraphic;
  SoundInfo: TStreamInfoW;
  ID3Info: TID3InfoW;
begin
  case GetType(Buffer, Name) of
    clImage:
      begin
        Edit1.Enabled := False;
        if FPanelCreated then
          Panel.Free;
        Panel := TImage.Create(Self);
        FPanelCreated := True;
        try
          Panel.Left := Bevel1.Left;
          Panel.Top := Bevel1.Top;
          Panel.Height := Bevel1.Height;
          Panel.Width := Bevel1.Width;
          (Panel as TImage).AutoSize := False;
          Panel.Parent := Self;
          (Panel as TImage).Stretch := True;
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
                raise Exception.Create('Unsupported Image.');
              end;
            end;
          end;
          if Graph.Height > Graph.Width then
          begin
            Panel.Height := cWidth *
              Graph.Height div Graph.Width;
            Panel.Width := cWidth;
          end
          else
          begin
            Panel.Height := cHeight;
            Panel.Width := cHeight *
              Graph.Width div Graph.Height;
          end;
          Resize(Panel.Height, Panel.Width);
          (Panel as TImage).Picture.Assign(Graph);
          Graph.Free;
        finally

        end;
      end;
    clText:
      begin
        Edit1.Enabled := True;
        Buffer.Seek(0, soFromBeginning);
        if FPanelCreated then
          Panel.Free;
        Panel := TMemo.Create(Self);
        FPanelCreated := True;
        try
          Panel.Left := Bevel1.Left;
          Panel.Top := Bevel1.Top;
          Panel.Height := Bevel1.Height;
          Panel.Width := Bevel1.Width;
          Panel.Parent := Self;
          (Panel as TMemo).ScrollBars := ssVertical;
          (Panel as TMemo).Lines.LoadFromStream(Buffer,Encoding);
          (Panel as TMemo).ReadOnly := True;
        finally

        end;
      end;
    clSound:
      begin
        Edit1.Enabled := False;
        if not(Buffer is TMemoryStream) then
          raise Exception.Create
            ('Need MemoryStream to Play sound.');
        Buffer.Seek(0, soFromBeginning);
        if FPanelCreated then
          Panel.Free;
        Panel := TMemo.Create(Self);
        FPanelCreated := True;
        try
          Panel.Left := Bevel1.Left;
          Panel.Top := Bevel1.Top;
          Panel.Height := Bevel1.Height;
          Panel.Width := Bevel1.Width;
          Panel.Parent := Self;
          (Panel as TMemo).ScrollBars := ssVertical;
          (Panel as TMemo).ReadOnly := True;
          Player.StopPlayback;
          Player.OpenStream(1, 1, (Buffer as TMemoryStream)
            .Memory, Buffer.Size, MusicType);
          SetLength(SoundInfo.Description, 100);
          Player.GetStreamInfoW(SoundInfo);
          Player.LoadID3W(id3Version1, ID3Info);
          with (Panel as TMemo).Lines do
          begin
            Add('Halte3 Sound Info. Preview');
            Add('++++++++++++++++++++++++++');
            Add('File Info. :');
            Add(format('File: %s', [Name]));
            case MusicType of
              sfOgg:
                Add(format('FileType: %s', ['Ogg Vobis']));
              sfMp3:
                Add(format('FileType: %s',
                  ['MP3(MPEG Audio Layer3)']));
              sfWav:
                Add(format('FileType: %s', ['WAVE Audio']));
            end;
            Add(format('Sampling Rate: %d Hz',
              [SoundInfo.SamplingRate]));
            Add(format('Channel: %d',
              [SoundInfo.ChannelNumber]));
            Add(format('Bitrate: %d KBps', [SoundInfo.Bitrate]));
            Add(format('Length: %d hour: %d min: %d sec. %d ms',
              [SoundInfo.Length.hms.hour,
              SoundInfo.Length.hms.minute,
              SoundInfo.Length.hms.second,
              SoundInfo.Length.hms.millisecond]));
            Add('++++++++++++++++++++++++++');
            Add('ID3 Tag Info. :');
            Add(format('Title: %s', [ID3Info.Title]));
            Add(format('Artist: %s', [ID3Info.Artist]));
            Add(format('Album: %s', [ID3Info.Album]));
            Add(format('Year: %s', [ID3Info.Year]));
            Add(format('Comment: %s', [ID3Info.Comment]));
            Add(format('Track: %s', [ID3Info.Track]));
            Add(format('Genre: %s', [ID3Info.Genre]));
            Add('++++++++++++++++++++++++++');
          end;
          Player.StartPlayback;
        finally

        end;
      end;
  else
    raise Exception.Create('Can not preview this type.');
  end;
end;

end.
