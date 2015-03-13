library LeafLAC;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  Windows,
  StrUtils,
  Vcl.Dialogs,
  IOUtils,
  Types,
  CustomStream in '..\..\..\Core\CustomStream.pas',
  PluginFunc in '..\..\..\Core\PluginFunc.pas',
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas';

{$E GP}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: Array [0 .. 3] of AnsiChar;
    ENTRIES_COUNT: Cardinal;
  End;

  Pack_Entries = packed Record
    File_name: ARRAY [1 .. $20] OF AnsiChar;
    Length: Cardinal;
    START_OFFSET: Cardinal;
  End;

  Pack_Entries1 = Record
    sign: DWORD;
    File_name: ARRAY [1 .. $18] OF AnsiChar;
    START_OFFSET: Cardinal;
    Length: Cardinal;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Leaf-LAC',clGameMaker));
end;

const
  Magic: AnsiString = 'LAC'#0;
  Magic1: AnsiString = 'KCAP';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if SameText(Trim(Head.Magic), Trim(Magic))or SameText(Trim(Head.Magic), Trim(Magic1)) then
      Result := dsTrue;
  except
    Result := dsError;
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  indexs1: Pack_Entries1;
  i, j: Integer;
  Rlentry: TRlEntry;
  inttype: Integer;
  tmpath: string;
begin
  Result := True;
  tmpath := '';
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if SameText(Trim(Head.Magic), Trim(Magic)) then
      inttype := 1
    else if SameText(Trim(Head.Magic), Trim(Magic1)) then
      inttype := 2
    else
      raise Exception.Create('Magic Error.');
    for i := 0 to Head.ENTRIES_COUNT - 1 do
    begin
      if inttype = 1 then
      begin
        FileBuffer.Read(indexs.File_name[1],
          SizeOf(Pack_Entries));
        Rlentry := TRlEntry.Create;
        j := 1;
        while indexs.File_name[j] <> #0 do
        begin
          indexs.File_name[j] :=
            AnsiChar(not Byte(indexs.File_name[j]));
          j := j + 1;
        end;
        Rlentry.AName := Trim(indexs.File_name);
        Rlentry.AOffset := indexs.START_OFFSET;
        Rlentry.AOrigin := soFromBeginning;
        Rlentry.AStoreLength := indexs.Length;
        Rlentry.ARLength := 0;
        if (Rlentry.AOffset + Rlentry.AStoreLength) >
          FileBuffer.Size then
          raise Exception.Create('OverFlow');
        IndexStream.Add(Rlentry);
      end
      else if inttype = 2 then
      begin
        FileBuffer.Read(indexs1.sign, SizeOf(Pack_Entries1));
        Rlentry := TRlEntry.Create;
        if indexs1.sign = $CCCCCCCC then
        begin
          tmpath := tmpath + Trim(indexs1.File_name) + '\';
          Continue;
        end;
        Rlentry.AName := tmpath + Trim(indexs1.File_name);
        Rlentry.AOffset := indexs1.START_OFFSET;
        Rlentry.AOrigin := soFromBeginning;
        Rlentry.AStoreLength := indexs1.Length;
        Rlentry.ARLength := 0;
        if (Rlentry.AOffset + Rlentry.AStoreLength) >
          FileBuffer.Size then
          raise Exception.Create('OverFlow');
        IndexStream.Add(Rlentry);
      end;
    end;
  except
    Result := False;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  decompr: TGlCompressBuffer;
  decomsize: Cardinal;
  comprsize: Cardinal;
begin
  if SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.bmp')
    or SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.TGA')
    or SameText(ExtractFileExt(FileBuffer.Rlentry.AName),
    '.sdt') then
  begin
    OutBuffer.Seek(0, soFromBeginning);
    Result := FileBuffer.ReadData(OutBuffer);
    decompr := TGlCompressBuffer.Create;
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Read(comprsize, 4);
    OutBuffer.Read(decomsize, 4);
    { if comprsize <> FileBuffer.RlEntry.AStoreLength then
      raise Exception.Create('File Error.'); }
    decompr.CopyFrom(OutBuffer, OutBuffer.Size - 8);
    decompr.Seek(0, soFromBeginning);
    decompr.LzssDecompress(decompr.Size, $FEE, $FFF);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    decompr.Output.Seek(0, soFromBeginning);
    { if decompr.Output.Size <> decomsize then
      raise Exception.Create('Decompress Error.'); }
    OutBuffer.CopyFrom(decompr.Output, decompr.Output.Size);
    decompr.Destroy;
  end
  else
    Result := FileBuffer.ReadData(OutBuffer);

end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  indexs1: array of Pack_Entries1;
  i, j: Integer;
  tmpstream: TFileStream;
  intype: string;
  tmpsize: Cardinal;
  compr: TGlCompressBuffer;
begin
  Result := True;
  try
    Percent := 0;
    intype := InputBox('Choose Package Mode:',
      'There are more than one package type available.'#13#10'1 = LAC,2 = KCAP',
      '1');
    if StrToInt(intype) = 1 then
    begin
      SetLength(indexs, IndexStream.Count);
      ZeroMemory(@indexs[0].File_name[1], IndexStream.Count *
        SizeOf(Pack_Entries));
      Head.ENTRIES_COUNT := IndexStream.Count;
      Move(Pbyte(Magic)^, Head.Magic[0], 4);
      tmpsize := SizeOf(Pack_Head) + IndexStream.Count *
        SizeOf(Pack_Entries);
      for i := 0 to IndexStream.Count - 1 do
      begin
        Move(Pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
          indexs[i].File_name[1],
          Length(IndexStream.Rlentry[i].AName));
        j := 1;
        while indexs[i].File_name[j] <> #0 do
        begin
          indexs[i].File_name[j] :=
            AnsiChar(not Byte(indexs[i].File_name[j]));
          j := j + 1;
        end;
        indexs[i].Length := IndexStream.Rlentry[i].ARLength;
        indexs[i].START_OFFSET := tmpsize;
        tmpsize := tmpsize + indexs[i].Length;
        Percent := 30 * (i + 1) div IndexStream.Count;
      end;
      FileBuffer.Seek(0, soFromBeginning);
      FileBuffer.Write(Head.Magic[0], SizeOf(Pack_Head));
      FileBuffer.Write(indexs[0].File_name[1],
        IndexStream.Count * SizeOf(Pack_Entries));
      for i := 0 to IndexStream.Count - 1 do
      begin
        tmpstream := TFileStream.Create(IndexStream.ParentPath +
          IndexStream.Rlentry[i].AName, fmOpenRead);
        FileBuffer.CopyFrom(tmpstream, tmpstream.Size);
        tmpstream.Free;
        Percent := 30 + 70 * (i + 1) div IndexStream.Count;
      end;
      SetLength(indexs, 0);
    end
    else if StrToInt(intype) = 2 then
    begin
      if High(TDirectory.GetDirectories
        (IndexStream.ParentPath)) > 0 then
        raise Exception.Create('Unsupported Now.');
      SetLength(indexs1, IndexStream.Count);
      ZeroMemory(@indexs1[0].sign, IndexStream.Count *
        SizeOf(Pack_Entries1));
      Head.ENTRIES_COUNT := IndexStream.Count;
      Move(Pbyte(Magic1)^, Head.Magic[0], 4);
      tmpsize := SizeOf(Pack_Head) + IndexStream.Count *
        SizeOf(Pack_Entries1);
      for i := 0 to IndexStream.Count - 1 do
      begin
        Move(Pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
          indexs1[i].File_name[1],
          Length(IndexStream.Rlentry[i].AName));
        indexs1[i].Length := IndexStream.Rlentry[i].ARLength;
        indexs1[i].START_OFFSET := tmpsize;
        tmpsize := tmpsize + indexs[i].Length;
        Percent := 30 * (i + 1) div IndexStream.Count;
      end;
      FileBuffer.Seek(0, soFromBeginning);
      FileBuffer.Write(Head.Magic[0], SizeOf(Pack_Head));
      FileBuffer.Write(indexs1[0].sign, IndexStream.Count *
        SizeOf(Pack_Entries1));
      compr := TGlCompressBuffer.Create;
      for i := 0 to IndexStream.Count - 1 do
      begin
        if SameText(ExtractFileExt(IndexStream.Rlentry[i].AName),
          '.bmp') or
          SameText(ExtractFileExt(IndexStream.Rlentry[i].AName),
          '.TGA') or
          SameText(ExtractFileExt(IndexStream.Rlentry[i].AName),
          '.sdt') then
        begin
          compr.Clear;
          tmpstream := TFileStream.Create(IndexStream.ParentPath
            + IndexStream.Rlentry[i].AName, fmOpenRead);
          compr.Seek(0, soFromBeginning);
          compr.CopyFrom(tmpstream, tmpstream.Size);
          compr.Seek(0, soFromBeginning);
          compr.Output.Seek(0, soFromBeginning);
          compr.LzssCompress;
          indexs[i].Length := compr.Output.Size + 8;
          FileBuffer.Write(indexs[i].Length, 4);
          tmpsize := compr.Size;
          FileBuffer.Write(tmpsize, 4);
          compr.Output.Seek(0, soFromBeginning);
          FileBuffer.CopyFrom(compr.Output, compr.Output.Size);
          tmpstream.Free;
        end
        else
        begin
          tmpstream := TFileStream.Create(IndexStream.ParentPath
            + IndexStream.Rlentry[i].AName, fmOpenRead);
          FileBuffer.CopyFrom(tmpstream, tmpstream.Size);
          tmpstream.Free;
        end;
        Percent := 30 + 70 * (i + 1) div IndexStream.Count;
      end;
      FileBuffer.Seek(SizeOf(Pack_Head), soFromBeginning);
      FileBuffer.Write(indexs1[0].sign, IndexStream.Count *
        SizeOf(Pack_Entries1));
      compr.Destroy;
      SetLength(indexs1, 0);
    end
    else
      raise Exception.Create('user cancelled.');
  except
    Result := False;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

exports PackData;

begin

end.
