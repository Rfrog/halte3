{ ******************************************************* }
{ }
{ Assistant Constant Unit }
{ }
{ Copyright (C) 2010 HatsuneTakumi }
{ }
{ HalTe2 Public License V1 }
{ }
{ ******************************************************* }

unit AssistantConst;

interface

uses Classes;

const
  Sigule_DecodeTable: array [0 .. $FF] of byte = ($70, $F8, $A6, $B0, $A1, $A5,
    $28, $4F, $B5, $2F, $48, $FA, $E1, $E9, $4B, $DE, $B7, $4F, $62, $95, $8B,
    $E0, $03, $80, $E7, $CF, $0F, $6B, $92, $01, $EB, $F8, $A2, $88, $CE, $63,
    $04, $38, $D2, $6D, $8C, $D2, $88, $76, $A7, $92, $71, $8F, $4E, $B6, $8D,
    $01, $79, $88, $83, $0A, $F9, $E9, $2C, $DB, $67, $DB, $91, $14, $D5, $9A,
    $4E, $79, $17, $23, $08, $96, $0E, $1D, $15, $F9, $A5, $A0, $6F, $58, $17,
    $C8, $A9, $46, $DA, $22, $FF, $FD, $87, $12, $42, $FB, $A9, $B8, $67, $6C,
    $91, $67, $64, $F9, $D1, $1E, $E4, $50, $64, $6F, $F2, $0B, $DE, $40, $E7,
    $47, $F1, $03, $CC, $2A, $AD, $7F, $34, $21, $A0, $64, $26, $98, $6C, $ED,
    $69, $F4, $B5, $23, $08, $6E, $7D, $92, $F6, $EB, $93, $F0, $7A, $89, $5E,
    $F9, $F8, $7A, $AF, $E8, $A9, $48, $C2, $AC, $11, $6B, $2B, $33, $A7, $40,
    $0D, $DC, $7D, $A7, $5B, $CF, $C8, $31, $D1, $77, $52, $8D, $82, $AC, $41,
    $B8, $73, $A5, $4F, $26, $7C, $0F, $39, $DA, $5B, $37, $4A, $DE, $A4, $49,
    $0B, $7C, $17, $A3, $43, $AE, $77, $06, $64, $73, $C0, $43, $A3, $18, $5A,
    $0F, $9F, $02, $4C, $7E, $8B, $01, $9F, $2D, $AE, $72, $54, $13, $FF, $96,
    $AE, $0B, $34, $58, $CF, $E3, $00, $78, $BE, $E3, $F5, $61, $E4, $87, $7C,
    $FC, $80, $AF, $C4, $8D, $46, $3A, $5D, $D0, $36, $BC, $E5, $60, $77, $68,
    $08, $4F, $BB, $AB, $E2, $78, $07, $E8, $73, $BF);

  FrontWing_DecodeTable: Ansistring = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  EAGLS_DecodeTable1: array [0 .. 46] of byte = ($31, $71, $61, $7A, $32, $77,
    $73, $78, $33, $65, $64, $63, $34, $72, $66, $76, $35, $74, $67, $62, $36,
    $79, $68, $6E, $37, $75, $6A, $6D, $38, $69, $6B, $2C, $39, $6F, $6C, $2E,
    $30, $70, $3B, $2F, $2D, $40, $3A, $5E, $5B, $5D, $00);

  EAGLS_DecodeTable2: array [0 .. $C - 1] of byte = ($45, $41, $47, $4C, $53,
    $5F, $53, $59, $53, $54, $45, $4D);

type
  TByteArray = array of Byte;

  TDecyptionAs = record
  public
    class procedure Sigule(Input, Output: TMemoryStream); static;
    class Procedure FrontWingDecode(Input, Output: TMemoryStream;
      Length: Cardinal; decode_type: byte); static;
    class function EAGLSRefreshSeed(var seed: Cardinal): Cardinal; static;
    class Procedure TsystemXorTableUpdate; static;
    class Procedure TsystemTableCreate(KEY: Integer); static;
    class procedure XorDecode(Input, Output: TMemoryStream;DecodeTable: TByteArray); static;
    class procedure PlusDecode(Input, Output: TMemoryStream;DecodeTable: TByteArray); static;
    class procedure MinusDecode(Input, Output: TMemoryStream;DecodeTable: TByteArray); static;
  end;

implementation

class procedure TDecyptionAs.Sigule(Input, Output: TMemoryStream);
var
  esi, i: Integer;
begin
  esi := 0;
  Output.Size := Input.Size;
  for i := 0 to Input.Size - 1 do
  begin
    PByte(Output.Memory)[i] := PByte(Input.Memory)
      [i] xor Sigule_DecodeTable[esi];
    inc(esi);
    esi := esi and $800000FF;
  end;
end;

class Procedure TDecyptionAs.FrontWingDecode(Input, Output: TMemoryStream;
  Length: Cardinal; decode_type: byte);
label start, val2, val3, un, start2, start3, t;
var
  Xor_Table: Array [0 .. 25] of byte;
  PInput, Poutput: PByte;
begin
  move(PByte(FrontWing_DecodeTable)^, Xor_Table[0], 26);
  Input.Seek(0, soFromBeginning);
  Output.CopyFrom(Input, Input.Size);
  PInput := Input.Memory;
  Poutput := Output.Memory;
  asm
    push edi
    push ecx
    push ebx
    push eax
    push edx
    push esi
    push ebp
    mov esi,PInput
    mov ebp,Poutput
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
    Mov Byte Ptr [ebp+edi],al
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
    mov esi,PInput
    mov ebp,Poutput
    start2:
    Mov cl,[edx+eax]
    xor [ebp+edi],cl
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
    Mov Byte Ptr [ebp+edi],al
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
    pop ebp
    pop esi
    pop edx
    pop eax
    pop ebx
    pop ecx
    pop edi
  end;
end;

class function TDecyptionAs.EAGLSRefreshSeed(var seed: Cardinal): Cardinal;
begin
  seed := Cardinal((Integer(seed) * $343FD)) + $269EC3;
  Result := (seed SHR $10) AND $7FFF;
end;

var
  TsystemXorTable: ARRAY [0 .. $6 * $68 + 1] OF Cardinal;
  TsystemXorTableNew: ARRAY [0 .. $6 * $68 + 1] OF Cardinal;

class Procedure TDecyptionAs.TsystemTableCreate(KEY: Integer);
VAR
  edi: Cardinal;
  COUNTER: Integer;
BEGIN
  for COUNTER := 0 to $6 * $68 do
  begin
    edi := KEY;
    KEY := KEY * $10DCD;
    edi := edi AND $FFFF0000;
    inc(KEY);
    TsystemXorTable[COUNTER] := edi;
    edi := KEY;
    KEY := KEY * $10DCD;
    edi := edi SHR $10;
    TsystemXorTable[COUNTER] := TsystemXorTable[COUNTER] or edi;
    inc(KEY);
  end;
END;

Procedure XOR_TABLE_Update1();
var
  eax, edx, ebx: Cardinal;
  count: Integer;
begin
  for count := 0 to $E3 - 1 do
  begin
    eax := TsystemXorTable[count];
    ebx := TsystemXorTable[count + 1];
    eax := eax AND $80000000;
    ebx := ebx AND $7FFFFFFF;
    edx := TsystemXorTable[$18D + count];
    eax := eax OR ebx;
    eax := eax SHR 1;
    ebx := ebx OR $FFFFFFFE;
    eax := eax XOR edx;
    ebx := ebx + 1;
    eax := eax XOR $9908B0DF;
    ebx := ebx AND $9908B0DF;
    ebx := ebx XOR eax;
    TsystemXorTable[count] := ebx;
  end;
end;

Procedure XOR_TABLE_Update2();
var
  eax, edx, ebx: Cardinal;
  count: Integer;
begin
  TsystemXorTable[$6 * $68] := TsystemXorTable[0];
  for count := 0 to $18D - 1 do
  begin
    eax := TsystemXorTable[$E3 + count];
    ebx := TsystemXorTable[$E3 + count + 1];
    eax := eax AND $80000000;
    ebx := ebx AND $7FFFFFFF;
    edx := TsystemXorTable[count];
    eax := eax OR ebx;
    eax := eax SHR 1;
    ebx := ebx OR $FFFFFFFE;
    eax := eax XOR edx;
    ebx := ebx + 1;
    eax := eax XOR $9908B0DF;
    ebx := ebx AND $9908B0DF;
    ebx := ebx XOR eax;
    TsystemXorTable[$E3 + count] := ebx;
  end;
end;

Procedure XOR_TABLE_Update3();
var
  eax, edx, ebp, ebx: Cardinal;
  count: Integer;
begin
  for count := 0 to $138 do
  begin
    eax := TsystemXorTable[count * 2];
    edx := TsystemXorTable[count * 2 + 1];
    ebx := eax;
    eax := eax SHR $B;
    ebp := edx;
    edx := edx SHR $B;
    eax := eax XOR ebx;
    edx := edx XOR ebp;
    ebx := eax;
    eax := eax SHL $7;
    ebp := edx;
    edx := edx SHL $7;
    eax := eax AND $9D2C5680;
    edx := edx AND $9D2C5680;
    eax := eax XOR ebx;
    edx := edx XOR ebp;
    ebx := eax;
    eax := eax SHL $F;
    ebp := edx;
    edx := edx SHL $F;
    eax := eax AND $EFC60000;
    edx := edx AND $EFC60000;
    eax := eax XOR ebx;
    edx := edx XOR ebp;
    ebx := eax;
    eax := eax SHR $12;
    ebp := edx;
    edx := edx SHR $12;
    eax := eax XOR ebx;
    edx := edx XOR ebp;
    TsystemXorTableNew[count * 2] := eax;
    TsystemXorTableNew[count * 2 + 1] := edx;
  end;
end;

class Procedure TDecyptionAs.TsystemXorTableUpdate;
begin
  XOR_TABLE_Update1();
  XOR_TABLE_Update2();
  XOR_TABLE_Update3();
end;

class Procedure TDecyptionAs.XorDecode(Input, Output: TMemoryStream;DecodeTable: TByteArray);
var i,j: Integer;
tmp: Byte;
begin
  j := Low(DecodeTable);
  for I := Input.Position to Input.Size - 1 do
  begin
    Input.Read(tmp,1);
    tmp := tmp xor DecodeTable[j];
    Output.Write(tmp,1);
    if j = High(DecodeTable) then
      j := Low(DecodeTable);
    Inc(j);
  end;
end;

class Procedure TDecyptionAs.PlusDecode(Input, Output: TMemoryStream;DecodeTable: TByteArray);
var i,j: Integer;
tmp: Byte;
begin
  j := Low(DecodeTable);
  for I := Input.Position to Input.Size - 1 do
  begin
    Input.Read(tmp,1);
    tmp := tmp + DecodeTable[j];
    Output.Write(tmp,1);
    if j = High(DecodeTable) then
      j := Low(DecodeTable);
    Inc(j);
  end;
end;

class Procedure TDecyptionAs.MinusDecode(Input, Output: TMemoryStream;DecodeTable: TByteArray);
var i,j: Integer;
tmp: Byte;
begin
  j := Low(DecodeTable);
  for I := Input.Position to Input.Size - 1 do
  begin
    Input.Read(tmp,1);
    tmp := tmp - DecodeTable[j];
    Output.Write(tmp,1);
    if j = High(DecodeTable) then
      j := Low(DecodeTable);
    Inc(j);
  end;
end;

end.
