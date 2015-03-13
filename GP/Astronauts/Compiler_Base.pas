unit Compiler_Base;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Classes;

type

  POperater = ^TOperater;

  TOperater = record
    Operater: Integer;
    Style: Integer;
    ParamCount: Integer;
    op_str: string;
  end;

  TToken = TDictionary< string, POperater >;

  TState = (sInit, sFinish, sChar, sInt, sCardinal, sInt64, sUInt64, sFloat,
    sFloat64,
    sBlock, sMemory, sIntVar,
    sHex, sVar, sDelimiter, sAnnotation, sDefine, sBlockAnnotation);

  TCompiler = class
  private
    Dict: TToken;
  protected
    token_f: string;
    state_f: TState;
    block_s, block_m, block_b: Integer;
    HeadBin, DataBin, TableBin: TMemoryStream;

    procedure Initialize; virtual;
    procedure write(Text: TTextReader; Token: string; state: TState;
      Buffer: TStream); virtual;

    procedure AddToken(Operater: TOperater);
    procedure WriteToken(Token: string; state: TState; Buffer: TStream);
    procedure WriteMemory(Token: string; Buffer: TStream;
      Divide: Integer = 1);
    procedure WriteInt(Token: string; Buffer: TStream);
    procedure WriteInt64(Token: string; Buffer: TStream);
    procedure WriteFloat(Token: string; Buffer: TStream);
    procedure WriteFloat64(Token: string; Buffer: TStream);
    procedure WriteString(Token: string; Buffer: TStream; Encoding: TEncoding);
    procedure WriteByte(Token: string; Buffer: TStream);
    procedure WriteWord(Token: string; Buffer: TStream);
  public
    constructor Create;
    destructor Destroy; override;

    function GetToken(Text: TTextReader; var state: TState): string;
    function RlToken(Token: string): POperater;
    procedure Parse(Text: TTextReader; Buffer: TStream);

    function DebugPrint(state: TState): string;
  end;

implementation

{ TCompiler }

procedure TCompiler.AddToken(Operater: TOperater);
var
  opr: POperater;
begin
  opr := GetMemory(SizeOf(TOperater));
  Move(Pointer(@Operater)^, opr^, SizeOf(TOperater));
  Dict.Add(UpperCase(Trim(Operater.op_str)), opr);
end;

constructor TCompiler.Create;
begin
  Dict := TToken.Create;
  HeadBin := TMemoryStream.Create;
  DataBin := TMemoryStream.Create;
  TableBin := TMemoryStream.Create;
  block_s := 0;
  block_m := 0;
  block_b := 0;
  Initialize;
end;

function TCompiler.DebugPrint(state: TState): string;
begin
  Result := 'State: ';
  case state of
    sInit:
      Result := Result + 'Initialize';
    sInt:
      Result := Result + 'Integer';
    sHex:
      Result := Result + 'HEX';
    sVar:
      Result := Result + 'Variable';
    sChar:
      Result := Result + 'Char';
    sBlock:
      Result := Result + 'Block';
    sFloat:
      Result := Result + 'Float';
    sDelimiter:
      Result := Result + 'Delimiter';
    sCardinal:
      Result := Result + 'Cardinal';
    sInt64:
      Result := Result + 'Int64';
    sUInt64:
      Result := Result + 'UInt64';
    sAnnotation:
      Result := Result + 'Annotation';
    sBlockAnnotation:
      Result := Result + 'BlockAnnotation';
    sDefine:
      Result := Result + 'Define';
    sMemory:
      Result := Result + 'Memory';
    sFinish:
      Result := Result + 'Finish';
  end;
end;

destructor TCompiler.Destroy;
begin
  while Dict.Count > 0 do
  begin
    FreeMem(Dict.ToArray[ Dict.Count - 1 ].Value);
    Dict.Remove(Dict.ToArray[ Dict.Count - 1 ].Key);
  end;
  DataBin.Free;
  TableBin.Free;
  HeadBin.Free;
  Dict.Free;
  inherited;
end;

function TCompiler.GetToken(Text: TTextReader;
  var state: TState): string;
var
  c: Char;
begin
  Result := '';
  state := sInit;
  while True do
  begin
    c := UpCase(Char(Text.Peek));
    if c = Char(-1) then
    begin
      state := sFinish;
      Break;
    end;
    case state of
      sInit:
        begin
          case c of
            '0' .. '9', '-', '+':
              begin
                state := sInt;
                Result := Result + c;
              end;
            '.':
              begin
                state := sFloat;
                Result := '0';
                Result := Result + c;
              end;
            'A' .. 'Z', '_':
              begin
                state := sVar;
                Result := Result + c;
              end;
            '"':
              begin
                state := sChar;
              end;
            '''':
              begin
                state := sMemory;
              end;
            '[', '{', '(', '}', ']', ')':
              begin
                case c of
                  '[':
                    inc(block_m);
                  ']':
                    Dec(block_m);
                  '(':
                    inc(block_s);
                  ')':
                    Dec(block_s);
                  '{':
                    inc(block_b);
                  '}':
                    Dec(block_b);
                end;
                state := sBlock;
                Result := Result + c;
              end;
            '$':
              begin
                state := sHex;
                Result := Result + c;
              end;
            ' ', #13, #10:
              begin

              end;
            ':', ';', ',':
              begin
                state := sDelimiter;
                Result := Result + c;
              end;
            '/':
              begin
                Text.Read;
                c := UpCase(Char(Text.Peek));
                if c = Char(-1) then
                begin
                  state := sFinish;
                  Break;
                end;
                if c = '/' then
                begin
                  state := sAnnotation;
                end else if c = '*' then
                  state := sBlockAnnotation
                else
                  raise Exception.Create('Unknown char after "/"');
              end;
            '#':
              begin
                Result := Result + c;
                state := sDefine;
              end
          else
            raise Exception.Create('Unknown char: ' + c);
          end;
        end;
      sMemory:
        begin
          case c of
            '''':
              begin
                Text.Read;
                Break;
              end;
            '0' .. '9', 'A' .. 'F':
              begin
                Result := Result + c;
              end;
            ' ', #10, #13:
              begin

              end
          else
            raise Exception.Create('Error hex string.');
          end;
        end;
      sBlockAnnotation:
        begin
          case c of
            '*':
              begin
                Text.Read;
                c := Char(Text.Peek);
                if c = Char(-1) then
                begin
                  state := sFinish;
                  Break;
                end;
                if c = '/' then
                begin
                  Text.Read;
                  Break;
                end
                else
                  Result := Result + '*' + c;
              end;
          else
            Result := Result + c;
          end;
        end;
      sDefine:
        begin
          Break;
        end;
      sAnnotation:
        begin
          case c of
            #10, #13:
              begin
                Text.Read;
                Break;
              end;
          else
            Result := Result + c;
          end;
        end;
      sChar:
        begin
          case c of
            '"':
              begin
                Text.Read;
                Break;
              end;
            '/':
              begin
                Text.Read;
                c := UpCase(Char(Text.Peek));
                if c = Char(-1) then
                begin
                  state := sFinish;
                  Break;
                end;
                case c of
                  '/', '"':
                    Result := Result + c;
                else
                  Result := Result + '/' + c;
                end;
              end
          else
            Result := Result + c;
          end;
        end;
      sIntVar:
        Break;
      sInt:
        begin
          case c of
            '0' .. '9':
              begin
                Result := Result + c;
              end;
            '.':
              begin
                state := sFloat;
                Result := Result + c;
              end;
            ' ', #13, #10:
              begin
                if Result = '.' then
                begin
                  raise Exception.Create
                    (Format('Float expected, but %s found.', [ c ]));
                end;
                Text.Read;
                Break;
              end;
            'U':
              begin
                state := sCardinal;
                Text.Read;
                Break;
              end;
            'V':
              begin
                state := sIntVar;
                Text.Read;
                Break;
              end;
          else
            Break;
          end;
          if state = sInt then
            if StrToInt64(Result) > High(Integer) then
            begin
              state := sInt64;
            end;
        end;
      sInt64:
        begin
          case c of
            '0' .. '9':
              begin
                Result := Result + c;
              end;
            '.':
              begin
                state := sFloat;
                Result := Result + c;
              end;
            ' ', #13, #10:
              begin
                Text.Read;
                Break;
              end;
            'U':
              begin
                state := sUInt64;
                Text.Read;
                Break;
              end;
            'V':
              begin
                state := sIntVar;
                Text.Read;
                Break;
              end;
          else
            Break;
          end;
        end;
      sFloat:
        begin
          case c of
            '0' .. '9':
              begin
                Result := Result + c;
              end;
            ' ', #13, #10:
              begin
                Text.Read;
                Break;
              end;
            'L':
              begin
                state := sFloat64;
                Text.Read;
                Break;
              end
          else
            raise Exception.Create('Unknown char: ' + c);
          end;
        end;
      sBlock:
        begin
          Break;
        end;
      sDelimiter:
        begin
          Break;
        end;
      sVar:
        begin
          case c of
            '0' .. '9', 'A' .. 'Z', '_':
              begin
                Result := Result + c;
              end;
            ' ', #13, #10:
              begin
                Text.Read;
                Break;
              end;
          else
            Break;
          end;
        end;
      sHex:
        begin
          case c of
            '0' .. '9', 'A' .. 'F':
              begin
                Result := Result + c;
              end;
            ' ', #13, #10:
              begin
                Text.Read;
                Break;
              end;
          else
            raise Exception.Create('Unknown char: ' + c);
          end;
        end;
    end;
    Text.Read;
  end;
end;

procedure TCompiler.Initialize;
begin
end;

procedure TCompiler.write(Text: TTextReader; Token: string; state: TState;
  Buffer: TStream);
begin
end;

procedure TCompiler.WriteByte(Token: string; Buffer: TStream);
var
  i: byte;
begin
  i := StrToInt(Token);
  Buffer.write(i, SizeOf(byte));
end;

procedure TCompiler.WriteFloat(Token: string; Buffer: TStream);
var
  f: Single;
begin
  f := StrToFloat(Token);
  Buffer.write(f, SizeOf(Single));
end;

procedure TCompiler.WriteFloat64(Token: string; Buffer: TStream);
var
  f: Double;
begin
  f := StrToFloat(Token);
  Buffer.write(f, SizeOf(Double));
end;

procedure TCompiler.WriteInt(Token: string; Buffer: TStream);
var
  i: Integer;
begin
  i := StrToInt(Token);
  Buffer.write(i, SizeOf(Integer));
end;

procedure TCompiler.WriteInt64(Token: string; Buffer: TStream);
var
  i: Int64;
begin
  i := StrToInt64(Token);
  Buffer.write(i, SizeOf(Int64));
end;

procedure TCompiler.WriteMemory(Token: string; Buffer: TStream;
  Divide: Integer = 1);
var
  b: byte;
  w: word;
  c: cardinal;
  i: Integer;
begin
  if Divide > 4 then
    raise Exception.Create('Divide too large.');
  for i := 0 to (Length(Token) div (Divide * 2)) - 1 do
  begin
    case Divide of
      1:
        begin
          b := StrToInt('$' + Copy(Token, i * (Divide * 2), (Divide * 2)));
          Buffer.write(b, Divide);
        end;
      2:
        begin
          w := StrToInt('$' + Copy(Token, i * (Divide * 2), (Divide * 2)));
          Buffer.write(w, Divide);
        end;
      3:
        begin
          raise Exception.Create('This divide is not allowed.');
        end;
      4:
        begin
          c := StrToInt('$' + Copy(Token, i * (Divide * 2) + 1, (Divide * 2)));
          Buffer.write(c, Divide);
        end;
    end;
  end;
end;

procedure TCompiler.WriteString(Token: string; Buffer: TStream;
  Encoding: TEncoding);
var
  b: TBytes;
  zero: byte;
begin
  zero := 0;
  b := Encoding.GetBytes(Token);
  Buffer.write(b[ Low(b) ], Length(b));
  Buffer.write(zero, 1);
  SetLength(b, 0);
end;

procedure TCompiler.WriteToken(Token: string; state: TState; Buffer: TStream);
begin
  case state of
    sChar:
      begin
        WriteString(Token, Buffer, TEncoding.UTF8);
      end;
    sInt, sCardinal:
      begin
        WriteInt(Token, Buffer);
      end;
    sInt64, sUInt64:
      begin
        WriteInt64(Token, Buffer);
      end;
    sFloat:
      begin
        WriteFloat(Token, Buffer);
      end;
    sFloat64:
      begin
        WriteFloat64(Token, Buffer);
      end;
    sMemory:
      begin
        WriteMemory(Token, Buffer);
      end;
    sHex:
      begin
        WriteInt(Token, Buffer);
      end;
  else
    raise Exception.Create('This state can not be written directly.');
  end;
end;

procedure TCompiler.WriteWord(Token: string; Buffer: TStream);
var
  i: word;
begin
  i := StrToInt(Token);
  Buffer.write(i, SizeOf(word));
end;

procedure TCompiler.Parse(Text: TTextReader; Buffer: TStream);
var
  state: TState;
  s: string;
begin
  state := sInit;
  while state <> sFinish do
  begin
    s := GetToken(Text, state);
    write(Text, s, state, Buffer);
  end;
end;

function TCompiler.RlToken(Token: string): POperater;
begin
  if Dict.ContainsKey(UpperCase(Token)) then
    Result := Dict.Items[ UpperCase(Token) ]
  else
    Result := nil;
end;

end.
