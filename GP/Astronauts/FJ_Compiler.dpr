program FJ_Compiler;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,
  System.Classes,
  Compiler_Base in 'Compiler_Base.pas',
  strutils;

type

  TMyCompiler = class(
    TCompiler)
  protected
    JumpTableTable: array [ 0 .. $110 ] of Cardinal;
    JumpTable: array of array of Cardinal;
    procedure Initialize; override;
    procedure write(Text: TTextReader; Token: string; state: TState;
      Buffer: TStream); override;

    procedure MyWriteToken(Token: string; state: TState;
      Buffer: TStream);
  end;

const
  OPS: array [ 0 .. 72 ] of toperater =
    (
    (Operater: $1; Style: 1; ParamCount: - 1; op_str: 'LPT'),
    (Operater: $2; Style: 1; ParamCount: - 1; op_str: 'LoadScript'),
    (Operater: $3; Style: 1; ParamCount: - 1; op_str: 'ScriptJumpTo'),
    (Operater: $4; Style: 1; ParamCount: - 1; op_str: 'OnScriptJumpTo'),
    (Operater: $5; Style: 1; ParamCount: - 1; op_str: 'Move'),
    (Operater: $6; Style: 1; ParamCount: - 1; op_str: 'IF'),
    (Operater: $7; Style: 1; ParamCount: - 1; op_str: 'ATimes'),
    (Operater: $8; Style: 1; ParamCount: - 1; op_str: 'AWait'),
    (Operater: $9; Style: 1; ParamCount: - 1; op_str: 'Random'),
    (Operater: $A; Style: 1; ParamCount: - 1; op_str: 'CompareString'),
    (Operater: $64; Style: 1; ParamCount: - 1; op_str: 'ImageRead'),
    (Operater: $65; Style: 1; ParamCount: - 1; op_str: 'ImageFree'),
    (Operater: $66; Style: 1; ParamCount: - 1; op_str: 'LYImage'),
    (Operater: $67; Style: 1; ParamCount: - 1; op_str: 'LYPosition'),
    (Operater: $68; Style: 1; ParamCount: - 1; op_str: 'LYSize'),
    (Operater: $69; Style: 1; ParamCount: - 1; op_str: 'LYColor'),
    (Operater: $6A; Style: 1; ParamCount: - 1; op_str: 'LYBlend'),
    (Operater: $6B; Style: 1; ParamCount: - 1; op_str: 'LYAnti'),
    (Operater: $6C; Style: 1; ParamCount: - 1; op_str: 'LYAction'),
    (Operater: $6D; Style: 1; ParamCount: - 1; op_str: 'LYCameraState'),
    (Operater: $6E; Style: 1; ParamCount: - 1; op_str: 'LYOverLap'),
    (Operater: $6F; Style: 1; ParamCount: - 1; op_str: 'LYCameraMove'),
    (Operater: $70; Style: 1; ParamCount: - 1; op_str: 'Cursor'),
    (Operater: $71; Style: 1; ParamCount: - 1; op_str: 'Movie'),
    (Operater: $C8; Style: 1; ParamCount: - 1; op_str: 'BGMList'),
    (Operater: $C9; Style: 1; ParamCount: - 1; op_str: 'BGMPlay'),
    (Operater: $CA; Style: 1; ParamCount: - 1; op_str: 'BGMStop'),
    (Operater: $CB; Style: 1; ParamCount: - 1; op_str: 'BGMWait'),
    (Operater: $CC; Style: 1; ParamCount: - 1; op_str: 'VoiceList'),
    (Operater: $CD; Style: 1; ParamCount: - 1; op_str: 'VoicePlay'),
    (Operater: $CE; Style: 1; ParamCount: - 1; op_str: 'VoiceStop'),
    (Operater: $CF; Style: 1; ParamCount: - 1; op_str: 'VoiceWait'),
    (Operater: $D0; Style: 1; ParamCount: - 1; op_str: 'SEPlay'),
    (Operater: $D1; Style: 1; ParamCount: - 1; op_str: 'SEStop'),
    (Operater: $D2; Style: 1; ParamCount: - 1; op_str: 'SEWait'),
    (Operater: $D3; Style: 1; ParamCount: - 1; op_str: 'SERead'),
    (Operater: $D4; Style: 1; ParamCount: - 1; op_str: 'SEFree'),
    (Operater: $3E8; Style: 1; ParamCount: - 1; op_str: 'Message'),
    (Operater: $3E9; Style: 1; ParamCount: - 1; op_str: 'Mwo'),
    (Operater: $3EA; Style: 1; ParamCount: - 1; op_str: 'Mwc'),
    (Operater: $3EB; Style: 1; ParamCount: - 1; op_str: 'Select'),
    (Operater: $3EC; Style: 1; ParamCount: - 1; op_str: 'CheckScenarioXEC'),
    (Operater: $3ED; Style: 1; ParamCount: - 1; op_str: 'SubTitle'),
    (Operater: $3EE; Style: 1; ParamCount: - 1; op_str: 'SetCGFlag'),
    (Operater: $3EF; Style: 1; ParamCount: - 1; op_str: 'SetSceneFlag'),
    (Operater: $3F0; Style: 1; ParamCount: - 1; op_str: 'SetMesSkip'),
    (Operater: $3F1; Style: 1; ParamCount: - 1; op_str: 'SelectItem'),
    (Operater: $7D0; Style: 1; ParamCount: - 1; op_str: 'SetFontSize'),
    (Operater: $7D1; Style: 1; ParamCount: - 1; op_str: 'SetFontColor'),
    (Operater: $7D2; Style: 1; ParamCount: - 1; op_str: 'SetFontBold'),
    (Operater: $7D3; Style: 1; ParamCount: - 1; op_str: 'SetFontShadow'),
    (Operater: $7D4; Style: 1; ParamCount: - 1; op_str: 'TxArea'),
    (Operater: $7D5; Style: 1; ParamCount: - 1; op_str: 'TxKinSoku'),
    (Operater: $7D6; Style: 1; ParamCount: - 1; op_str: 'TxDown'),
    (Operater: $7D7; Style: 1; ParamCount: - 1; op_str: 'MesName'),
    (Operater: $7D8; Style: 1; ParamCount: - 1; op_str: 'VPlay'),
    (Operater: $7D9; Style: 1; ParamCount: - 1; op_str: 'VStop'),
    (Operater: $7DA; Style: 1; ParamCount: - 1; op_str: 'Run'),
    (Operater: $7DB; Style: 1; ParamCount: - 1; op_str: 'BlogSaveBegin'),
    (Operater: $7DC; Style: 1; ParamCount: - 1; op_str: 'BlogSaveEnd'),
    (Operater: $7DD; Style: 1; ParamCount: - 1; op_str: 'SelMake'),
    (Operater: $7DE; Style: 1; ParamCount: - 1; op_str: 'SelRun'),
    (Operater: $7DF; Style: 1; ParamCount: - 1; op_str: 'ActMake'),
    (Operater: $7E0; Style: 1; ParamCount: - 1; op_str: 'ActFree'),
    (Operater: $7E1; Style: 1; ParamCount: - 1; op_str: 'ActPlay'),
    (Operater: $7E2; Style: 1; ParamCount: - 1; op_str: 'ActStop'),
    (Operater: $7E3; Style: 1; ParamCount: - 1; op_str: 'ScreenAct'),
    (Operater: $7E4; Style: 1; ParamCount: - 1; op_str: 'SaveSam'),
    (Operater: $7E5; Style: 1; ParamCount: - 1; op_str: 'Face'),
    (Operater: $2710; Style: 1; ParamCount: - 1; op_str: 'Reset'),
    (Operater: $0; Style: 0; ParamCount: - 1; op_str: 'CONST'),
    (Operater: $FFFF; Style: 0; ParamCount: 2; op_str: 'define'),
    (Operater: $FFFE; Style: 0; ParamCount: 1; op_str: 'label')
    );

  { TMyCompiler }
procedure TMyCompiler.Initialize;
var
  i: integer;
begin
  for i := Low(OPS) to High(OPS) do
  begin
    addtoken(OPS[ i ]);
  end;
  for i := Low(JumpTableTable) to High(JumpTableTable) do
    JumpTableTable[ i ] := 0;
  setlength(JumpTable, 0);
end;

procedure TMyCompiler.MyWriteToken(Token: string; state: TState;
  Buffer: TStream);
begin
  case state of
    sChar:
      begin
        writebyte('3', Buffer);
        WriteString(Token, Buffer, TEncoding.GetEncoding(932));
      end;
    sInt:
      begin
        writebyte('1', Buffer);
        WriteInt(Token, Buffer);
      end;
    sCardinal:
      begin
        writebyte('5', Buffer);
        WriteInt(Token, Buffer);
      end;
    sMemory:
      begin
        writebyte('4', Buffer);
        WriteMemory(Token, Buffer, 4);
        if length(Token) mod 16 = 0 then
          WriteInt('$FFFFFFFF', Buffer)
        else
        begin
          WriteInt('$FFFFFFFF', Buffer);
          WriteInt('$FFFFFFFF', Buffer);
        end;
        WriteInt('$0', Buffer);
      end;
    sHex:
      begin
        writebyte('5', Buffer);
        WriteInt(Token, Buffer);
      end;
    sIntVar:
      begin

        begin
          writebyte('2', Buffer);
          WriteInt(Token, Buffer);
        end;
      end
  else
    raise Exception.Create('This state can not be written directly.');
  end;
end;

type
  THead = packed record
    magic: array [ 0 .. $F ] of AnsiChar;
    minor_ver: Word;
    major_ver: Word;
  end;

const
  Head: THead = (magic: 'MSCENARIO FILE  '; minor_ver: 0; major_ver: 1);

procedure TMyCompiler.write(Text: TTextReader; Token: string; state: TState;
  Buffer: TStream);
var
  op: Poperater;
  i, j: integer;
  s: string;
begin
  databin.Clear;
  case state of
    sInit:
      begin
        writeln('started');
      end;
    sFinish:
      begin
        headbin.write(Head.magic[ 0 ], sizeof(THead));
        headbin.write(JumpTableTable[ 0 ], 273 * 4);
        for i := Low(JumpTable) to High(JumpTable) do
          for j := Low(JumpTable[ i ]) to High(JumpTable[ i ]) do
          begin
            headbin.write(JumpTable[ i ][ j ], 4);
          end;
        Buffer.Seek(0, sofrombeginning);
        headbin.CopyFrom(Buffer, Buffer.Size);
        headbin.Seek(0, sofrombeginning);
        Buffer.Size := 0;
        Buffer.CopyFrom(headbin, headbin.Size);
        headbin.Clear;
        writeln('finished.');
      end;
    sVar:
      begin
        op := rltoken(Token);
        if op = nil then
        begin
          raise Exception.Create('Unknow op: ' + Token);
        end;
        if op.Style <> 1 then
          raise Exception.Create
            (format('Style 1 operater expected, but "%s" found.',
            [ Token ]));
        case op.Operater of
          - 1:
            begin

            end
        else
          begin
            writeword(inttostr(op.Operater), Buffer);
            if op.ParamCount = -1 then
            begin
              s := GetToken(Text, state);
              if s <> '(' then
                raise Exception.Create(format('"(" expected, but "%s" found.',
                  [ s ]))
              else
              begin
                s := GetToken(Text, state);
              end;
              while state <> sBlock do
              begin
                MyWriteToken(s, state, databin);
                s := GetToken(Text, state);
                if s <> ',' then
                  if s <> ')' then
                    raise Exception.Create
                      (format('Delimiter expected, but "%s" found.',
                      [ s ]))
                  else
                    break;
                s := GetToken(Text, state);
              end;
            end else if op.ParamCount > -1 then
            begin
              s := GetToken(Text, state);
              if s <> '(' then
                raise Exception.Create(format('"(" expected, but "%s" found.',
                  [ Token ]))
              else if op.ParamCount > 0 then
              begin
                s := GetToken(Text, state);
              end;
              for i := 0 to op.ParamCount - 1 do
              begin
                MyWriteToken(s, state, databin);
                s := GetToken(Text, state);
                if s <> ',' then
                  if s <> ')' then
                    raise Exception.Create
                      (format('Delimiter expected, but "%s" found.',
                      [ s ]))
                  else
                    break;
                s := GetToken(Text, state);
              end;
              if s <> ')' then
                raise Exception.Create(format('")" expected, but "%s" found.',
                  [ s ]));
            end
            else
              raise Exception.Create('Error parameter count.');
            s := GetToken(Text, state);
            if s <> ';' then
              raise Exception.Create(format('";" expected, but "%s" found.',
                [ s ]));

            writeword(inttostr(databin.Size), Buffer);
            databin.Seek(0, sofrombeginning);
            Buffer.CopyFrom(databin, databin.Size);
          end;
        end;
      end;
    sDefine:
      begin
        s := GetToken(Text, state);
        if state <> sVar then
          raise Exception.Create(format('Variable expected, but "%s" found.',
            [ Token ]));
        op := rltoken(s);
        if op = nil then
          raise Exception.Create('Unknow op: ' + Token);
        if op.Style <> 0 then
          raise Exception.Create
            (format('Style 0 operater expected, but "%s" found.',
            [ s ]));
        case op.Operater of
          0:
            begin
              writeword(inttostr(op.Operater), Buffer);
              s := GetToken(Text, state);
              while s <> ';' do
              begin
                MyWriteToken(s, state, databin);
                s := GetToken(Text, state);
                if s <> ',' then
                  if s <> ';' then
                    raise Exception.Create
                      (format('Delimiter expected, but "%s" found.',
                      [ s ]))
                  else
                    break;
                s := GetToken(Text, state);
              end;

              writeword(inttostr(databin.Size), Buffer);
              databin.Seek(0, sofrombeginning);
              Buffer.CopyFrom(databin, databin.Size);
            end;
          $FFFE:
            begin
              s := GetToken(Text, state);
              if state <> sVar then
                raise Exception.Create
                  (format('Variable expected, but "%s" found.',
                  [ s ]));
              inc(JumpTableTable[ strtoint(copy(s, 2, posex('_', s,
                2) - 2)) ]);
              if length(JumpTable) < (strtoint(copy(s, 2, posex('_', s, 2) - 2))
                + 1)
              then
                setlength(JumpTable,
                  strtoint(copy(s, 2, posex('_', s, 2) - 2)) + 1);
              if length(JumpTable[ strtoint(copy(s, 2, posex('_', s, 2) - 2)) ])
                < (strtoint(copy(s, posex('_', s, 2) + 1,
                length(s) - posex('_', s, 2))) + 1) then
                setlength(JumpTable[ strtoint(copy(s, 2, posex('_', s, 2) - 2))
                  ], strtoint(copy(s, posex('_', s, 2) + 1,
                  length(s) - posex('_', s, 2))) + 1);
              JumpTable[ strtoint(copy(s, 2, posex('_', s, 2) - 2))
                ][ strtoint(copy(s, posex('_', s, 2) + 1,
                length(s) - posex('_', s, 2))) ] := Buffer.Size;
              s := GetToken(Text, state);
              if s <> ':' then
                raise Exception.Create
                  (format('":" expected, but "%s" found.',
                  [ s ]));
            end;
          $FFFF:
            begin
              s := GetToken(Text, state);
              if state <> sVar then
                raise Exception.Create
                  (format('Variable expected, but "%s" found.',
                  [ s ]));
              s := s + ' = ' + GetToken(Text, state);
              writeln(s);
            end;
        end;
      end;
    sBlockAnnotation:
      ;
    sAnnotation:
      ;
  else
    raise Exception.Create('This type is not expected: ' + Token);
  end;
end;

var
  StrList: TStringList;
  Text: TStringReader;
  Buffer: TMemoryStream;
  Compiler: TMyCompiler;

begin
  try
    writeln('FJ-System Compiler ver 1.00');
    writeln('SakuraTomo34@Gmail.com');
    writeln('XXXC.AT');
    if ParamCount <> 1 then
      raise Exception.Create('Error.');
    if not fileexists(paramstr(1)) then
      raise Exception.Create('Not exitst.');
    StrList := TStringList.Create;
    StrList.LoadFromFile
      (paramstr(1));
    Text := TStringReader.Create(StrList.Text);
    Compiler := TMyCompiler.Create;
    Buffer := TMemoryStream.Create;
    StrList.Free;
    try
      Compiler.Parse(Text, Buffer);
      Buffer.SaveToFile(paramstr(1) + '.bin');
    finally
      Text.Free;
      Compiler.Free;
      Buffer.Free;
    end;
    readln;
  except
    on E: Exception do
    begin
      writeln(E.ClassName, ': ', E.Message);
      readln;
    end;
  end;

end.
