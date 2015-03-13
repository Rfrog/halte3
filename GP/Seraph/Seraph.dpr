library Seraph;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils, Vcl.Dialogs, CodeSiteLogging;

{$E GP}
{$R *.res}

Type
  Pack_Head = Packed Record
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    FileOffset: Cardinal;
  End;

  Voice_Head = packed record
    indexs: Word;
  end;

  Voice_Entries = packed record
    Flag: Cardinal;
    Start_Offset: Cardinal;
    Length: Cardinal;
  end;

  // Arc用的是树形结构，无文件名
  Arc_Head = packed record
    Dirs: Cardinal;
    Indexs: Cardinal;  //*12 = len?
  end;

  // 最大应该只有1层,与will类似
  Arc_Dir_Entry = packed record
    Base_Offset: Cardinal;
    indexs: Cardinal;
  end;

  //indexs倒序排列
  Arc_File_Entry = packed record
    Offset: Cardinal;
  end;

function EndianSwap(const a: integer): integer;
asm
  bswap eax
end;

procedure RleDecompress(Input, Output: TStream);
var
  DecompressLen, cdword, tmpDword: Cardinal;
  tmpByte2: Byte;
  tmpByte, tmpByte3: PByte;
  tmpWord: PWORD;
  Position: int64;
begin
  Output.Size := 0;
  cdword := 0;
  tmpDword := 0;
  tmpByte2 := 0;
  Input.Read(DecompressLen, 4);
  if DecompressLen = 0 then
  begin
    Output.CopyFrom(Input, Input.Size - Input.Position);
    Exit;
  end;
  tmpByte := @Byte(cdword);
  tmpWord := @Word(cdword);
  tmpByte3 := @Byte(tmpDword);
  repeat
    Input.Read(tmpByte^, 1);
    if tmpByte^ < $80 then
    begin
      tmpByte^ := tmpByte^ and $7F;
      tmpWord^ := ShortInt(tmpByte^);
      cdword := cdword and $0FFFF;
      cdword := cdword + 1;
      DecompressLen := DecompressLen - cdword;
      Output.CopyFrom(Input, cdword);
    end
    else
    begin
      Input.Read(tmpByte2, 1);
      tmpWord^ := ShortInt(tmpByte^);
      cdword := cdword shl $08;
      cdword := cdword + tmpByte2;
      tmpByte3^ := Byte(cdword);
      cdword := (cdword shr $05) and $3FF;
      tmpDword := tmpDword and $1F;
      cdword := cdword + 1;
      tmpDword := tmpDword and $0FFFF;
      cdword := cdword and $0FFFF;
      tmpDword := tmpDword + 1;
      Position := Output.Position - cdword;
      DecompressLen := DecompressLen - tmpDword;
      repeat
        Output.Seek(Position, soFromBeginning);
        Position := Position + 1;
        Output.Read(tmpByte2, 1);
        Output.Seek(0, soFromEnd);
        Output.Write(tmpByte2, 1);
        tmpDword := tmpDword - 1;
      until tmpDword <= 0;
    end;
  until integer(DecompressLen) <= 0;
end;

type
  TPackage = (pSCNPac = 0, pVoice = 1, pArchPac = 2, pEnv = 3,
    pNone = $FF);

function TestName(Filename: string): TPackage;
begin
  Result := pNone;
  if SameText(ExtractFileName(Filename), 'ArchPac.Dat') then
  begin
    Result := pArchPac;
    Exit;
  end;
  if SameText(ExtractFileName(Filename), 'env.dat') then
  begin
    Result := pEnv;
    Exit;
  end;
  if SameText(ExtractFileName(Filename), 'ScnPac.Dat') then
  begin
    Result := pSCNPac;
    Exit;
  end;
  if SameText(ExtractFileName(Filename), 'Voice0.Dat') then
  begin
    Result := pVoice;
    Exit;
  end;
end;

const
  ZlibMagic: AnsiString = #$78#$9C;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  head: Pack_Head;
  indexs: array of Pack_Entries;
  VoiceHead: Voice_Head;
  VIndexs: array of Voice_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    case TestName(FileBuffer.Filename) of
      pSCNPac:
        begin
          FileBuffer.Read(head.indexs, SizeOf(Pack_Head));
          SetLength(indexs, head.indexs + 1);
          FileBuffer.Read(indexs[0].FileOffset,
            SizeOf(Pack_Entries) * (head.indexs + 1));
          if (indexs[head.indexs].FileOffset = FileBuffer.Size)
            and (head.indexs < FileBuffer.Size) and
            (indexs[0].FileOffset < FileBuffer.Size) then
          begin
            Result := dsUnknown;
            Exit;
          end;
        end;
      pVoice:
        begin
          FileBuffer.Read(VoiceHead.indexs, SizeOf(Voice_Head));
          SetLength(VIndexs, VoiceHead.indexs + 1);
          FileBuffer.Read(VIndexs[0].Flag, SizeOf(Voice_Entries)
            * (VoiceHead.indexs + 1));
          if (VoiceHead.indexs < FileBuffer.Size) and
            ((VIndexs[VoiceHead.indexs - 1].Start_Offset +
            VIndexs[VoiceHead.indexs - 1].Length) <=
            FileBuffer.Size) and
            (VIndexs[VoiceHead.indexs].Flag = $CDCDCDCD) then
          begin
            Result := dsUnknown;
            Exit;
          end;
        end;
      pArchPac:
        begin
          FileBuffer.Read(VoiceHead.indexs, SizeOf(Voice_Head));
          if CompareMem(@VoiceHead.indexs,
            PByte(ZlibMagic), 2) then
            Result := dsUnknown;
        end;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Seraph', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  indexs: array of Pack_Entries;
  VoiceHead: Voice_Head;
  VIndexs: array of Voice_Entries;
  Offset: Cardinal;
  ArcHead: Arc_Head;
  Dirs: array of Arc_Dir_Entry;
  Files: Arc_File_Entry;
  i, j: integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    case TestName(FileBuffer.Filename) of
      pSCNPac:
        begin
          FileBuffer.Read(head.indexs, SizeOf(Pack_Head));
          SetLength(indexs, head.indexs + 1);
          FileBuffer.Read(indexs[0].FileOffset,
            SizeOf(Pack_Entries) * (head.indexs + 1));
          for i := 0 to head.indexs - 1 do
          begin
            Rlentry := TRlEntry.Create;
            Rlentry.AName := Format('%.8d', [i]);
            Rlentry.AOffset := indexs[i].FileOffset;
            Rlentry.AOrigin := soFromBeginning;
            Rlentry.AStoreLength := indexs[i + 1].FileOffset -
              indexs[i].FileOffset;
            Rlentry.ARLength := Rlentry.AStoreLength * 10;
            Rlentry.AKey := i;
            Rlentry.AKey2 := 0;
            IndexStream.ADD(Rlentry);
          end;
        end;
      pVoice:
        begin
          FileBuffer.Read(VoiceHead.indexs, SizeOf(Voice_Head));
          SetLength(VIndexs, VoiceHead.indexs + 1);
          FileBuffer.Read(VIndexs[0].Flag, SizeOf(Voice_Entries)
            * (VoiceHead.indexs + 1));
          for i := 0 to VoiceHead.indexs - 1 do
          begin
            Rlentry := TRlEntry.Create;
            Rlentry.AName := Format('%.8d', [i]);
            Rlentry.AOffset := VIndexs[i].Start_Offset;
            Rlentry.AOrigin := soFromBeginning;
            Rlentry.AStoreLength := VIndexs[i].Length;
            Rlentry.AKey2 := 1;
            IndexStream.ADD(Rlentry);
          end;
        end;
      pArchPac:
        begin
          Offset := StrToIntDef
            (InputBox('Input Index(and head)''s Offset',
            'In new ver of seraph,index offset is saved in exe.You must point out it.',
            '$814BE99'), $814BE99);
          FileBuffer.Seek(Offset, soFromBeginning);
          FileBuffer.Read(ArcHead, SizeOf(Arc_Head));
          SetLength(Dirs, ArcHead.Dirs);
          FileBuffer.Read(Dirs[0].Base_Offset, SizeOf(Arc_Dir_Entry) *
            ArcHead.Dirs);
          FileBuffer.Read(Offset, 4);
          for i := ArcHead.Dirs - 1 downto 0 do
          begin
            for j := 0 to Dirs[i].indexs - 1 do
            begin
              Files.Offset := Offset;
              FileBuffer.Read(Offset, SizeOf(Arc_File_Entry));
              Rlentry := TRlEntry.Create;
              Rlentry.AName := Format('%.8d\%.8d', [i, j]);
              Rlentry.AOffset := Files.Offset + Dirs[i]
                .Base_Offset;
              Rlentry.AOrigin := soFromBeginning;
              Rlentry.AStoreLength := Offset - Files.Offset;
              Rlentry.ARLength := Rlentry.AStoreLength * 8;
              Rlentry.AKey2 := 2;
              IndexStream.ADD(Rlentry);
            end;
          end;
        end;
    end;
  except
    Result := False;
  end;
end;

{$DEFINE USERLE}

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    FileBuffer.ReadData(Buffer);
    Buffer.Seek(0, soFromBeginning);
    case FileBuffer.PrevEntry.AKey2 of
      0:
        begin
          Buffer.ZlibDecompress(FileBuffer.PrevEntry.ARLength);
          if Buffer.Output.Size <>
            FileBuffer.PrevEntry.ARLength then
            raise Exception.Create('Decompress Error.');
          Buffer.Output.Seek(0, soFromBeginning);
          OutBuffer.Seek(0, soFromBeginning);
{$IFDEF USERLE}
          if FileBuffer.PrevEntry.AKey > 1 then
            RleDecompress(Buffer.Output, OutBuffer)
          else
            OutBuffer.CopyFrom(Buffer.Output,
              Buffer.Output.Size);
{$ELSE}
          OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
{$ENDIF}
        end;
      1:
        begin
          OutBuffer.CopyFrom(Buffer, Buffer.Size);
        end;
      2:
        begin
          Buffer.ZlibDecompress(FileBuffer.PrevEntry.ARLength);
          if Buffer.Output.Size <>
            FileBuffer.PrevEntry.ARLength then
            raise Exception.Create('Decompress Error.');
          Buffer.Output.Seek(0, soFromBeginning);
          OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
        end;
    end;
  finally
    Buffer.Free;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports ReadData;

begin

end.
