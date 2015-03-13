library FrontWing3;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas';

{$E GP}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: Array [0 .. 7] of ansichar;
    unknow: dword;
    unknow2: dword;
    ENTRIES_COUNT: dword;
    hash: dword;
    unknow3: dword;
    zero: dword;
  End;

  Pack_Entries = Record // 2c
    file_name: array [1 .. $110 - $C] of ansichar;
    start_offset: dword;
    Decompressed_Length: dword;
    Length: dword;
  End;

Const
  Magic: Ansistring = '1AWF';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if SameText(Trim(Head.Magic), Magic) and
      (Head.zero = 0) and
      (Head.ENTRIES_COUNT < FileBuffer.Size) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('Front Wing 3D ADV Engine2', clGameMaker));
end;

const
  Tmp: Ansistring = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

Procedure Decode(Buffer: Pbyte; Length: dword; decode_type: byte);
label start, val2, val3, un, start2, start3, t;
var
  Xor_Table: Array [0 .. 25] of byte;
begin
  move(Pbyte(Tmp)^, Xor_Table[0], 26);
  asm
    push edi
    push ecx
    push ebx
    push eax
    push edx
    push esi
    mov esi,Buffer
    mov eax,length
    mov al,decode_type
    mov ebx,length
    cmp al,0
    jnz val2
    xor edi,edi
    mov dl,$cb
    start:
    Mov al,byte ptr [esi+edi]
    xor al,dl
    ror al,1
    Mov Byte Ptr [esi+edi],al
    mov al,dl
    and al,$fe
    neg al
    sbb eax,eax
    xor ecx,ecx
    neg eax
    test dl,dl
    setne cl
    or cl,al
    add edi,1
    cmp edi,ebx
    mov dl,cl
    jl start
    jmp un

    val2:
    cmp al,1
    jnz val3
    xor eax,eax
    xor edi,edi
    lea edx,[Xor_Table]
    mov esi,Buffer
    start2:
    Mov cl,[edx+eax]
    xor [esi+edi],cl
    add eax,1
    cmp eax,26
    jnz t
    xor eax,eax
    t:
    add edi,1
    cmp edi,ebx
    jl start2
    jmp un
    val3:
    cmp al,2
    jnz un
    xor edi,edi
    mov dl,$da

    start3:
    Mov al,byte ptr [esi+edi]
    xor al,dl
    ror al,1
    Mov Byte Ptr [esi+edi],al
    mov al,dl
    and al,$fe
    neg al
    sbb eax,eax
    xor ecx,ecx
    neg eax
    test dl,dl
    setne cl
    or cl,al
    add edi,1
    cmp edi,ebx
    mov dl,cl
    jl start
    un:
    pop esi
    pop edx
    pop eax
    pop ebx
    pop ecx
    pop edi
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i, j: Integer;
  Rlentry: TRlEntry;
  tmpbuf: TMemoryStream;
begin
  Result := true;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if not SameText(Trim(Head.Magic), Magic) then
      raise Exception.Create('Magic Error.');
    if (Head.ENTRIES_COUNT * SizeOf(Pack_Entries)) > FileBuffer.size then
      raise Exception.Create('OVERFLOW');
    tmpbuf := TMemoryStream.Create;
    tmpbuf.CopyFrom(FileBuffer, Head.ENTRIES_COUNT * SizeOf(Pack_Entries));
    Decode(tmpbuf.Memory, Head.ENTRIES_COUNT * SizeOf(Pack_Entries), 0);
    tmpbuf.Seek(0, soFromBeginning);
    for i := 0 to Head.ENTRIES_COUNT - 1 do
    begin
      tmpbuf.Read(indexs.file_name[1], SizeOf(Pack_Entries));
      j := 0;
      while indexs.file_name[j] <> #0 do
        if indexs.file_name[j] = '/' then
          indexs.file_name[j] := '\';
      ZeroMemory(@indexs.file_name[j], $110 - $C - j);
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.file_name);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := indexs.Decompressed_Length;
      if (Rlentry.AOffset + Rlentry.AStoreLength) > FileBuffer.size then
        raise Exception.Create('OverFlow');
      IndexStream.add(Rlentry);
    end;
    tmpbuf.Free;
  except
    Result := False;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  decompr: TGlCompressBuffer;
  tmp: array[0..$18] of Byte;
begin
  Result := FileBuffer.ReadData(OutBuffer);
  FileBuffer.EntrySelected := FileBuffer.EntrySelected - 1;
  OutBuffer.Seek(0,soFromBeginning);
  OutBuffer.Read(tmp[0],$19);
  Decode(@tmp[0],$19,0);
  OutBuffer.Seek(0,soFromBeginning);
  OutBuffer.Write(tmp[0],$19);
  OutBuffer.Seek(0,soFromBeginning);
  decompr := TGlCompressBuffer.Create;
  decompr.CopyFrom(OutBuffer, OutBuffer.size);
  decompr.Seek(0, soFromBeginning);
  decompr.Seek(0, soFromBeginning);
  decompr.Output.Seek(0, soFromBeginning);
  decompr.ZlibDecompress(FileBuffer.RlEntry.ARLength);
  decompr.Output.Seek(0, soFromBeginning);
  OutBuffer.size := 0;
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.CopyFrom(decompr.Output, decompr.Output.size);
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

exports Autodetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
