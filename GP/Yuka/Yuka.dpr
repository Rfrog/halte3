library Yuka;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows;

{$E gp}
{$R *.res}


Type
  Pack_Head = Packed Record
    Magic: ARRAY [ 0 .. 7 ] OF ANSICHAR;
    headlength: Cardinal; // 05
    reserved: Cardinal;
    entries_offset: Cardinal;
    entries_length: Cardinal;
  End;

  Pack_Entries = packed Record
    nameOffset: Cardinal;
    nameLength: Cardinal;
    start_offset: Cardinal;
    length: Cardinal;
    reserved: Cardinal;
  End;

  Pic_Head = packed record
    Magic: ARRAY [ 0 .. 7 ] OF ANSICHAR;
    headerLength: Cardinal;
    zeroed: array [ 0 .. 6 ] of Cardinal;
    offset0: Cardinal;
    length0: Cardinal;
    offset1: Cardinal;
    length1: Cardinal;
    offset2: Cardinal;
    length2: Cardinal;
  end;

  Scr_Head = packed record
    Magic: ARRAY [ 0 .. 5 ] OF ANSICHAR;
    encoded: Word;
    headlength: Cardinal;
    buf: array [ 0 .. 4 ] of Cardinal;
    textoffset: Cardinal;
    textlength: Cardinal;
  end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Yuka Script Engine',
    clEngine));
end;

const
  ykg                  = '.ykg';
  ykgMagic: AnsiString = 'YKG000';
  ykcMagic: AnsiString = 'YKC001';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[ 0 ], sizeof(Pack_Head));
    if (Head.entries_length < FileBuffer.Size) and
      (Head.entries_offset < FileBuffer.Size) and
      (Head.headlength < FileBuffer.Size) and (Head.reserved = 0)
      and SameText(Trim(Head.Magic), ykcMagic) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head   : Pack_Head;
  indexs : array of Pack_Entries;
  i      : Integer;
  Rlentry: TRlEntry;
  tmpstr : AnsiString;
  pic    : Pic_Head;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[ 0 ], sizeof(Pack_Head));
    if not SameText(ykcMagic, Trim(Head.Magic)) then
      raise Exception.Create('Magic Error.');
    SetLength(indexs, Head.entries_length div sizeof
      (Pack_Entries));
    FileBuffer.Seek(Head.entries_offset, soFromBeginning);
    FileBuffer.Read(indexs[ 0 ].nameOffset, Head.entries_length);
    for i := 0 to Head.entries_length div sizeof
      (Pack_Entries) - 1 do
    begin
      SetLength(tmpstr, indexs[ i ].nameLength);
      FileBuffer.Seek(indexs[ i ].nameOffset, 0);
      FileBuffer.Read(PByte(tmpstr)^, indexs[ i ].nameLength);
      if SameStr(ykg, ExtractFileExt(Trim(tmpstr))) then
      begin
        FileBuffer.Seek(indexs[ i ].start_offset, soFromBeginning);
        FileBuffer.Read(pic.Magic[ 0 ], sizeof(Pic_Head));
        if not SameText(Trim(pic.Magic), ykgMagic) then
          raise Exception.Create('Package Error.');
        if pic.offset0 <> 0 then
        begin
          Rlentry       := TRlEntry.Create;
          Rlentry.AName := ChangeFileExt(Trim(tmpstr),
            '.part1.png');
          Rlentry.AOffset := indexs[ i ].start_offset +
            pic.offset0;
          Rlentry.AOrigin      := soFromBeginning;
          Rlentry.AStoreLength := pic.length0;
          IndexStream.Add(Rlentry);
        end;
        if pic.offset1 <> 0 then
        begin
          Rlentry       := TRlEntry.Create;
          Rlentry.AName := ChangeFileExt(Trim(tmpstr),
            '.part2.png');
          Rlentry.AOffset := indexs[ i ].start_offset +
            pic.offset1;
          Rlentry.AOrigin      := soFromBeginning;
          Rlentry.AStoreLength := pic.length1;
          IndexStream.Add(Rlentry);
        end;
        if pic.offset2 <> 0 then
        begin
          Rlentry       := TRlEntry.Create;
          Rlentry.AName := ChangeFileExt(Trim(tmpstr),
            '.part3.png');
          Rlentry.AOffset := indexs[ i ].start_offset +
            pic.offset2;
          Rlentry.AOrigin      := soFromBeginning;
          Rlentry.AStoreLength := pic.length2;
          IndexStream.Add(Rlentry);
        end;
        Continue;
      end;
      Rlentry              := TRlEntry.Create;
      Rlentry.AName        := Trim(tmpstr);
      Rlentry.AOffset      := indexs[ i ].start_offset;
      Rlentry.AOrigin      := soFromBeginning;
      Rlentry.AStoreLength := indexs[ i ].length;
      IndexStream.Add(Rlentry);
    end;
  except
    Result := False;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

const
  GNP: AnsiString    = #$89'GNP';
  PNG: AnsiString    = #$89'PNG';
  YKS001: AnsiString = 'YKS001';

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  buf : array [ 0 .. 3 ] of Byte;
  Head: Scr_Head;
  i   : Integer;
begin
  Result := FileBuffer.ReadData(OutBuffer);
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.Read(buf[ 0 ], 4);
  if CompareMem(@buf[ 0 ], PByte(GNP), 4) then
  begin
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Write(PByte(PNG)^, 4);
  end
  else
  begin
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Read(Head.Magic[ 0 ], sizeof(Scr_Head));
    if SameStr(Trim(Head.Magic), YKS001) then
    begin
      if Head.encoded = 1 then
      begin
        OutBuffer.Seek(Head.textoffset, soFromBeginning);
        for i := 0 to Head.textlength - 1 do
        begin
          OutBuffer.Read(buf[ 0 ], 1);
          OutBuffer.Seek(-1, soFromCurrent);
          buf[ 0 ] := buf[ 0 ] xor $AA;
          OutBuffer.Write(buf[ 0 ], 1);
        end;
        Head.encoded := 0;
        OutBuffer.Seek(6, soFromBeginning);
        OutBuffer.Write(Head.encoded, 2);
      end;
    end;
  end;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  Head     : Pack_Head;
  pic      : Pic_Head;
  indexs   : array of Pack_Entries;
  name     : array of AnsiString;
  i, J     : Integer;
  tmpbuffer: TFileStream;
  zero     : Byte;
  Tmp      : array [ 0 .. 4 ] of Byte;
begin
  Result := True;
  try
    Percent := 0;
    fillmemory(@Head.Magic[ 0 ], sizeof(Pack_Head), $0);
    fillmemory(@pic.Magic[ 0 ], sizeof(Pic_Head), $0);
    pic.headerLength := sizeof(Pic_Head);
    Move(PByte(ykgMagic)^, pic.Magic[ 0 ], 8);
    Move(PByte(ykcMagic)^, Head.Magic[ 0 ], 8);
    Head.headlength := sizeof(Pack_Head);
    Head.reserved   := 0;
    SetLength(indexs, IndexStream.Count);
    SetLength(name, IndexStream.Count);
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.Magic[ 0 ], Head.headlength);
    J     := 0;
    for i := 0 to IndexStream.Count - 1 do
    begin
      if SameText(RightStr(IndexStream.Rlentry[ i ].AName, 10),
        '.part2.png') then
        Continue
      else if SameText(RightStr(IndexStream.Rlentry[ i ].AName,
        10), '.part3.png') then
        Continue
      else if SameText(RightStr(IndexStream.Rlentry[ i ].AName,
        10), '.part1.png') then
      begin
        indexs[ J ].start_offset := FileBuffer.Position;
        FileBuffer.Write(pic.Magic[ 0 ], sizeof(Pic_Head));
        tmpbuffer := TFileStream.Create(IndexStream.ParentPath +
          IndexStream.Rlentry[ i ].AName, fmOpenRead);
        pic.offset0 := FileBuffer.Position - indexs[ J ]
          .start_offset;
        pic.length0 := tmpbuffer.Size;
        tmpbuffer.Seek(0, soFromBeginning);
        tmpbuffer.Read(Tmp[ 0 ], 4);
        tmpbuffer.Seek(0, soFromBeginning);
        FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
        if CompareMem(@Tmp[ 0 ], PByte(PNG), 4) then
        begin
          FileBuffer.Seek(-tmpbuffer.Size, soFromCurrent);
          FileBuffer.Write(PByte(GNP)^, 4);
          FileBuffer.Seek(tmpbuffer.Size - 4, soFromCurrent);
        end;
        tmpbuffer.Free;
        if FileExists(IndexStream.ParentPath +
          ReplaceStr(IndexStream.Rlentry[ i ].AName, '.part1.png',
          '.part2.png')) then
        begin
          tmpbuffer := TFileStream.Create(IndexStream.ParentPath
            + ReplaceStr(IndexStream.Rlentry[ i ].AName,
            '.part1.png', '.part2.png'), fmOpenRead);
          pic.offset1 := FileBuffer.Position - indexs[ J ]
            .start_offset;
          tmpbuffer.Seek(0, soFromBeginning);
          pic.length1 := tmpbuffer.Size;
          tmpbuffer.Read(Tmp[ 0 ], 4);
          tmpbuffer.Seek(0, soFromBeginning);
          FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
          if CompareMem(@Tmp[ 0 ], PByte(PNG), 4) then
          begin
            FileBuffer.Seek(-tmpbuffer.Size, soFromCurrent);
            FileBuffer.Write(PByte(GNP)^, 4);
            FileBuffer.Seek(tmpbuffer.Size - 4, soFromCurrent);
          end;
          tmpbuffer.Free;
        end
        else
        begin
          pic.offset1 := 0;
          pic.length1 := 0;
        end;
        if FileExists(IndexStream.ParentPath +
          ReplaceStr(IndexStream.Rlentry[ i ].AName, '.part1.png',
          '.part3.png')) then
        begin
          tmpbuffer := TFileStream.Create(IndexStream.ParentPath
            + ReplaceStr(IndexStream.Rlentry[ i ].AName,
            '.part1.png', '.part3.png'), fmOpenRead);
          pic.offset2 := FileBuffer.Position - indexs[ J ]
            .start_offset;
          pic.length2 := tmpbuffer.Size;
          tmpbuffer.Seek(0, soFromBeginning);
          tmpbuffer.Read(Tmp[ 0 ], 4);
          tmpbuffer.Seek(0, soFromBeginning);
          FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
          if CompareMem(@Tmp[ 0 ], PByte(PNG), 4) then
          begin
            FileBuffer.Seek(-tmpbuffer.Size, soFromCurrent);
            FileBuffer.Write(PByte(GNP)^, 4);
            FileBuffer.Seek(tmpbuffer.Size - 4, soFromCurrent);
          end;
          tmpbuffer.Free;
        end
        else
        begin
          pic.offset2 := 0;
          pic.length2 := 0;
        end;
        FileBuffer.Seek(indexs[ J ].start_offset,
          soFromBeginning);
        FileBuffer.Write(pic.Magic[ 0 ], sizeof(Pic_Head));
        name[ J ] := ReplaceStr(IndexStream.Rlentry[ i ].AName,
          '.part1.png', '.ykg');
        indexs[ J ].nameLength := length(name[ J ]) + 1;
        indexs[ J ].reserved   := 0;
        indexs[ J ].length     := pic.offset0 + pic.length0 + pic.length1 +
          pic.length2;
        FileBuffer.Seek(indexs[ J ].start_offset + indexs[ J ].length,
          soFromBeginning);
        J := J + 1;
      end
      else
      begin
        indexs[ J ].start_offset := FileBuffer.Position;
        indexs[ J ].reserved     := 0;
        name[ J ]                := IndexStream.Rlentry[ i ].AName;
        indexs[ J ].nameLength   := length(name[ J ]) + 1;
        tmpbuffer                := TFileStream.Create(IndexStream.ParentPath +
          IndexStream.Rlentry[ i ].AName, fmOpenRead);
        indexs[ J ].length := tmpbuffer.Size;
        FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
        tmpbuffer.Free;
        J := J + 1;
      end;
      Percent := 90 * (i + 1) div IndexStream.Count;
    end;
    zero  := 0;
    for i := 0 to J - 1 do
    begin
      indexs[ i ].nameOffset := FileBuffer.Position;
      FileBuffer.Write(PByte(name[ i ])^,
        indexs[ i ].nameLength - 1);
      FileBuffer.Write(zero, 1);
    end;
    Percent             := 95;
    Head.entries_offset := FileBuffer.Position;
    Head.entries_length := J * sizeof(Pack_Entries);
    FileBuffer.Write(indexs[ 0 ].nameOffset,
      J * sizeof(Pack_Entries));
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.Magic[ 0 ], sizeof(Pack_Head));
    SetLength(indexs, 0);
    SetLength(name, 0);
  except
    Result := False;
  end;
end;

exports
  AutoDetect;

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
