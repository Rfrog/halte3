library Taskforce;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Vcl.Dialogs;
{$E GP}
{$R *.res}


Type
  Pack_Head = Packed Record
    magic: array [ 0 .. 7 ] of AnsiChar;
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [ 1 .. $100 ] of AnsiChar;
    start_offset: Cardinal;
    decomprelen: Cardinal;
    length: Cardinal;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('Task Force', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: integer;
  Rlentry: TRlEntry;
begin
  Result := true;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.magic[ 0 ], sizeof(Pack_Head));
    if (Head.indexs * sizeof(Pack_Entries)) > FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    for i := 0 to Head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.filename[ 1 ], sizeof(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := indexs.decomprelen;
      if (Rlentry.AOffset + Rlentry.AStoreLength) > FileBuffer.Size then
        raise Exception.Create('OverFlow');
      IndexStream.Add(Rlentry);
    end;
  except
    Result := false;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  Decompr: TGlCompressBuffer;
  DecomprLen: Cardinal;
begin
  DecomprLen := FileBuffer.Rlentry.ARLength;
  if FileBuffer.Rlentry.ARLength <> FileBuffer.Rlentry.AStoreLength then
  begin
    Decompr := TGlCompressBuffer.Create;
    try
      Result := FileBuffer.ReadData(Decompr);
      Decompr.Seek(0, soFromBeginning);
      Decompr.LzssDecompress(Decompr.Size, $FEE, $FFF);
      Decompr.Output.Seek(0, soFromBeginning);
      OutBuffer.CopyFrom(Decompr.Output, Decompr.Output.Size);
    finally
      Decompr.Free;
    end;
  end
  else
    Result := FileBuffer.ReadData(OutBuffer);

end;

const
  magic: AnsiString = 'tskforce';

function PackData(IndexStream: TIndexStream; FileBuffer: TFileBufferStream;
  var Percent: word): boolean;
var
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  i: integer;
  tmpStream: TFileStream;
begin
  Result := true;
  try
    Percent := 0;
    Head.indexs := IndexStream.Count;
    Move(pbyte(magic)^, Head.magic[ 0 ], 8);
    SetLength(indexs, Head.indexs);
    ZeroMemory(@indexs[ 0 ].filename[ 1 ], Head.indexs * sizeof(Pack_Entries));
    FileBuffer.Size := 0;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.magic[ 0 ], sizeof(Pack_Head));
    FileBuffer.Write(indexs[ 0 ].filename[ 1 ],
      Head.indexs * sizeof(Pack_Entries));
    for i := 0 to Head.indexs - 1 do
    begin
      if length(IndexStream.Rlentry[ i ].AName) > $100 then
        raise Exception.Create('Name too long.');
      Move(pbyte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
        indexs[ i ].filename[ 1 ], $100);
      indexs[ i ].start_offset := FileBuffer.Position;
      indexs[ i ].length := IndexStream.Rlentry[ i ].ARLength;
      indexs[ i ].decomprelen := indexs[ i ].length;
      tmpStream := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[ i ].AName, fmOpenRead);
      FileBuffer.CopyFrom(tmpStream, tmpStream.Size);
      tmpStream.Free;
      Percent := 97 * (i + 1) div Head.indexs;
    end;
    FileBuffer.Seek(sizeof(Pack_Head), soFromBeginning);
    FileBuffer.Write(indexs[ 0 ].filename[ 1 ],
      Head.indexs * sizeof(Pack_Entries));
    SetLength(indexs, 0);
  except
    Result := false;
  end;
end;

exports
  GetPluginName;

exports
  GenerateEntries;

exports
  Decyption;

exports
  ReadData;

exports
  PackData;

begin

end.
