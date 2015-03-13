library ActX;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils
{$IFDEF debug}
    , codesitelogging
{$ENDIF};

{$E GP}

Type
  Pack_Head = Packed Record
    Magic: array [0 .. 3] of AnsiChar;
    indexs: Cardinal;
    Data_offset: Cardinal;
    reserved: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [1 .. 16] of AnsiChar;
    length: Cardinal;
    start_offset: Cardinal;
  End;

const
  Magic: AnsiString = 'PACK';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Read(head.Magic[0], SizeOf(Pack_Head));
    if SameText(Trim(head.Magic), Magic) then
    begin
      if head.indexs < FileBuffer.Size then
      begin
        Result := dsTrue;
        Exit;
      end;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('ActX', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  indexs: Pack_Entries;
  i: integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.Magic[0], SizeOf(Pack_Head));
    if not SameText(Trim(head.Magic), Magic) then
      raise Exception.Create('Magic Error.');

{$IFDEF debug}
    CodeSite.Send('Indexs: ', head.indexs);
{$ENDIF}
    for i := 0 to head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.filename[1], SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := indexs.length;
      IndexStream.ADD(Rlentry);

{$IFDEF debug}
      CodeSite.Send('Entry: ', Rlentry);
{$ENDIF}
    end;
  except
    Result := False;
  end;
end;

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    FileBuffer.ReadData(Buffer);
    Buffer.Seek(0, soFromBeginning);
    Buffer.Output.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(Buffer, Buffer.Size);
  finally
    Buffer.Free;
  end;
end;

function PackProcessData(Rlentry: TRlEntry;
  InputBuffer, FileOutBuffer: TStream): Boolean;
var
  Compr: TGlCompressBuffer;
begin
  Compr := TGlCompressBuffer.Create;
  try
    InputBuffer.Seek(0, soFromBeginning);
    Compr.CopyFrom(InputBuffer, InputBuffer.Size);
    FileOutBuffer.CopyFrom(Compr, Compr.Size);
  finally
    Compr.Free;
  end;
end;

function PackProcessIndex(IndexStream: TIndexStream;
  IndexOutBuffer: TStream): Boolean;
var
  indexs: array of Pack_Entries;
  i: integer;
begin
  SetLength(indexs, IndexStream.Count);
  ZeroMemory(@indexs[0].filename[1], IndexStream.Count * SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin
    if length(IndexStream.Rlentry[i].AName) > 32 then
      raise Exception.Create('Filename too long.');
    Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
      indexs[i].filename[1], length(IndexStream.Rlentry[i].AName));
    indexs[i].start_offset := IndexStream.Rlentry[i].AOffset + IndexStream.Count
      * SizeOf(Pack_Entries) + SizeOf(Pack_Head);
    indexs[i].length := IndexStream.Rlentry[i].AStoreLength;
  end;
  IndexOutBuffer.Write(indexs[0].filename[1], IndexStream.Count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream; Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
begin
  Move(PByte(Magic)^, head.Magic[0], length(Magic));
  head.indexs := IndexStream.Count;
Package.Write(head.Magic[0], SizeOf(Pack_Head));
IndexOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(IndexOutBuffer, IndexOutBuffer.Size);
FileOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(FileOutBuffer, FileOutBuffer.Size);
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports ReadData;

exports PackProcessData;

exports PackProcessIndex;

exports MakePackage;

begin

end.
