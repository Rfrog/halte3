program Project11;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type

  TState = (sScriptList, sFuncList, sMainBIN);

  TScript = record
    str: string;
    count: Integer;
    jump_to: Integer;
    rlstr: string;
    flag: Integer;
  end;

  TScrArray = array of TScript;

  TFunc = record
    str: string;
    op: Integer;
    op_context_state: Integer;
    param_Count: Integer;
  end;

  TFuncArray = array of TFunc;

  TOperater = record
    case op: Byte of
      01, 02:
        (Val_Byte: Byte;);
      03, 04:
        (Val_Word: Word;);
      05, 06:
        (Val_DWORD: Cardinal;);
      07, 08:
        (Val_Int64: int64;);
      09:
        (Val_Float: Single);
      $0A:
        (Val_Double: Double;);
      $0B:
        (Val_Boolean: Byte;);
      $0C:
        (Val_Vecror_2D: array [ 0 .. 1 ] of Cardinal;);
      $0D:
        (Val_Vecror_3D: array [ 0 .. 2 ] of Cardinal;);
      $0E:
        (Val_Vecror_4D: array [ 0 .. 3 ] of Cardinal;);
      $0F:
        (Val_Quat: array [ 0 .. 3 ] of Cardinal;);
      $10:
        (Val_Color: array [ 0 .. 3 ] of Cardinal;);
      $11:
        (Val_Matrix: array [ 0 .. 3, 0 .. 3 ] of Cardinal;);
      $12:
        (Val_Rect: array [ 0 .. 3 ] of Cardinal;);
      $13:
        (Val_Rect_Float: array [ 0 .. 3 ] of Single;);
      $14:
        (Val_Hash_128: array [ 0 .. 3 ] of Cardinal;);
      $15:
        (Val_Bit_32: Cardinal;);
      $18:
        (Val_JIS_String_Length: Cardinal;
          Val_JIS_String: PAnsiString;);
      $1A:
        (Val_UTF8_String_Length: Cardinal;
          Val_UTF8_String: PUTF8String;);
      $1B:
        (Val_Binary_Length: Cardinal;
          Val_Binary: PByte;);
      $20:
        (
          // Type_List_Begin;
          List_Count: Cardinal;
        );
      $21:
        (
          // Type_List_End;
        );
      $22:
        (
          // Type_Tree_Begin;
        );
      $23:
        (
          // Type_List_End;
        );
      $24:
        (
          // Type_TreeStratum_Begin;
        );
      $25:
        (
          // Type_TreeStratum_End;
        );
  end;

function EndianSwap(const a: Integer): Integer;
asm
  bswap eax
end;

function PrintOP(Buffer: TStream; op: TOperater): string;
var
  print_str: string;
  Buf: PByte;
  i: Integer;
  bytes: TBytes;
  chars: TCharArray;
begin
  case op.op of
    01:
      print_str :=
        Format('%d', [ op.Val_Byte ]);
    02:
      print_str :=
        Format('%u', [ op.Val_Byte ]);
    03:
      print_str :=
        Format('%d', [ op.Val_Word ]);
    04:
      print_str :=
        Format('%u', [ op.Val_Word ]);
    05:
      print_str :=
        Format('%d', [ EndianSwap(op.Val_DWORD) ]);
    06:
      print_str :=
        Format('%u', [ EndianSwap(op.Val_DWORD) ]);
    07:
      begin
        i := op.Val_Vecror_2D[ 0 ];
        op.Val_Vecror_2D[ 0 ] := EndianSwap(op.Val_Vecror_2D[ 1 ]);
        op.Val_Vecror_2D[ 1 ] := EndianSwap(i);
        print_str :=
          Format('Int64(%d,%d)',
          [ op.Val_Vecror_2D[ 0 ], op.Val_Vecror_2D[ 1 ] ]);
      end;
    08:
      begin
        i := op.Val_Vecror_2D[ 0 ];
        op.Val_Vecror_2D[ 0 ] := EndianSwap(op.Val_Vecror_2D[ 1 ]);
        op.Val_Vecror_2D[ 1 ] := EndianSwap(i);
        print_str :=
          Format('Int64(%d,%d)',
          [ op.Val_Vecror_2D[ 0 ], op.Val_Vecror_2D[ 1 ] ]);
      end;
    09:
      begin
        op.Val_Vecror_2D[ 0 ] := EndianSwap(op.Val_Vecror_2D[ 0 ]);
        print_str :=
          Format('%f', [ op.Val_Float ]);
      end;
    $0A:
      begin
        i := op.Val_Vecror_2D[ 0 ];
        op.Val_Vecror_2D[ 0 ] := EndianSwap(op.Val_Vecror_2D[ 1 ]);
        op.Val_Vecror_2D[ 1 ] := EndianSwap(i);
        print_str :=
          Format('%f', [ op.Val_Double ]);
      end;
    $0B:
      print_str :=
        Format('Bool(%u)', [ op.Val_Boolean ]);
    $0C:
      print_str :=
        Format('[%u , %u]', [ EndianSwap(op.Val_Vecror_2D[ 0 ]),
        EndianSwap(op.Val_Vecror_2D[ 1 ]) ]);
    $0D:
      print_str :=
        Format('[%u , %u , %u]',
        [ EndianSwap(op.Val_Vecror_3D[ 0 ]),
        EndianSwap(op.Val_Vecror_3D[ 1 ]), EndianSwap(op.Val_Vecror_3D[ 2 ]) ]);
    $0E:
      print_str :=
        Format('[%u , %u , %u , %u]',
        [ EndianSwap(op.Val_Vecror_4D[ 0 ]),
        EndianSwap(op.Val_Vecror_4D[ 1 ]), EndianSwap(op.Val_Vecror_4D[ 2 ]),
        EndianSwap(op.Val_Vecror_4D[ 3 ]) ]);
    $0F:
      print_str :=
        Format('[%u , %u , %u , %u]',
        [ EndianSwap(op.Val_Vecror_4D[ 0 ]),
        EndianSwap(op.Val_Vecror_4D[ 1 ]), EndianSwap(op.Val_Vecror_4D[ 2 ]),
        EndianSwap(op.Val_Vecror_4D[ 3 ]) ]);
    $10:
      print_str :=
        Format('[%u , %u , %u , %u]',
        [ EndianSwap(op.Val_Vecror_4D[ 0 ]),
        EndianSwap(op.Val_Vecror_4D[ 1 ]), EndianSwap(op.Val_Vecror_4D[ 2 ]),
        EndianSwap(op.Val_Vecror_4D[ 3 ]) ]);
    $11:
      print_str :=
        Format('[%u,%u,%u,%u],[%u,%u,%u,%u],[%u,%u,%u,%u],[%u,%u,%u,%u]',
        [ EndianSwap(op.Val_Matrix[ 0, 0 ]),
        EndianSwap(op.Val_Matrix[ 0, 1 ]), EndianSwap(op.Val_Matrix[ 0, 2 ]),
        EndianSwap(op.Val_Matrix[ 0,
        3 ])
        , EndianSwap(op.Val_Matrix[ 1, 0 ]),
        EndianSwap(op.Val_Matrix[ 1, 1 ]), EndianSwap(op.Val_Matrix[ 1, 2 ]),
        EndianSwap(op.Val_Matrix[ 1,
        3 ])
        , EndianSwap(op.Val_Matrix[ 2, 0 ]),
        EndianSwap(op.Val_Matrix[ 2, 1 ]), EndianSwap(op.Val_Matrix[ 2, 2 ]),
        EndianSwap(op.Val_Matrix[ 2,
        3 ])
        , EndianSwap(op.Val_Matrix[ 3, 0 ]),
        EndianSwap(op.Val_Matrix[ 3, 1 ]), EndianSwap(op.Val_Matrix[ 3, 2 ]),
        EndianSwap(op.Val_Matrix[ 3, 3 ]) ]);
    $12:
      print_str :=
        Format('[%u , %u , %u , %u]',
        [ EndianSwap(op.Val_Vecror_4D[ 0 ]),
        EndianSwap(op.Val_Vecror_4D[ 1 ]), EndianSwap(op.Val_Vecror_4D[ 2 ]),
        EndianSwap(op.Val_Vecror_4D[ 3 ]) ]);
    $13:
      print_str :=
        Format('[%f , %f , %f , %f]',
        [ op.Val_Rect_Float[ 0 ],
        op.Val_Rect_Float[ 1 ], op.Val_Rect_Float[ 2 ],
        op.Val_Rect_Float[ 3 ] ]);
    $14:
      print_str :=
        Format('[%u , %u , %u , %u]',
        [ EndianSwap(op.Val_Vecror_4D[ 0 ]),
        EndianSwap(op.Val_Vecror_4D[ 1 ]), EndianSwap(op.Val_Vecror_4D[ 2 ]),
        EndianSwap(op.Val_Vecror_4D[ 3 ]) ]);
    $15:
      print_str :=
        Format('%u', [ EndianSwap(op.Val_DWORD) ]);
    $18:
      begin
        Buf := SysGetMem(EndianSwap(op.Val_JIS_String_Length) + 1);
        Buffer.Read(Buf^, EndianSwap(op.Val_JIS_String_Length) + 1);
        print_str :=
          Format('%s', [ trim(PChar(chars)) ]);
        SysFreeMem(Buf);
      end;
    $1A:
      begin
        SetLength(bytes, EndianSwap(op.Val_UTF8_String_Length) + 1);
        Buffer.Read(bytes[ 0 ], EndianSwap(op.Val_UTF8_String_Length) + 1);
        chars := tencoding.UTF8.GetChars(bytes);
        print_str :=
          Format('%s',
          [ trim(PChar(chars)) ]);
        SetLength(bytes, 0);
      end;
    $1B:
      begin
        Buf := SysGetMem(EndianSwap(op.Val_Binary_Length));
        Buffer.Read(Buf^, EndianSwap(op.Val_Binary_Length));
        print_str := '[';
        for i := 0 to EndianSwap(op.Val_Binary_Length) - 1 do
        begin
          print_str := print_str + IntToHex(Buf[ i ], 1);
        end;
        print_str := print_str + '];';
        SysFreeMem(Buf);
      end;
    $20:
      print_str :=
        Format('Typedef List[%u] {', [ EndianSwap(op.List_Count) ]);
    $21:
      print_str :=
        Format('}List;', [ ]);
    $22:
      print_str :=
        Format('Typedef Tree {', [ ]);
    $23:
      print_str :=
        Format('}Tree;', [ ]);
    $24:
      print_str :=
        Format('Typedef TreeStratum {', [ ]);
    $25:
      print_str :=
        Format('}TreeStratum;', [ ]);
  end;
  Result := print_str;
end;

procedure ReadNextOp(Buffer: TStream; var op: TOperater);
begin
  Buffer.Read(op.op, 1);
  case op.op of
    01, 02:
      begin
        Buffer.Read(op.Val_Byte, 1);
      end;
    03, 04:
      begin
        Buffer.Read(op.Val_Word, 2);
      end;
    05, 06:
      begin
        Buffer.Read(op.Val_DWORD, 4);
      end;
    07, 08:
      begin
        Buffer.Read(op.Val_Int64, 8);
      end;
    09:
      begin
        Buffer.Read(op.Val_Float, 4);
      end;
    $0A:
      begin
        Buffer.Read(op.Val_Double, 8);
      end;
    $0B:
      begin
        Buffer.Read(op.Val_Boolean, 1);
      end;
    $0C:
      begin
        Buffer.Read(op.Val_Vecror_2D[ 0 ], 4 * 2);
      end;
    $0D:
      begin
        Buffer.Read(op.Val_Vecror_3D[ 0 ], 4 * 3);
      end;
    $0E:
      begin
        Buffer.Read(op.Val_Vecror_4D[ 0 ], 4 * 4);
      end;
    $0F:
      begin
        Buffer.Read(op.Val_Quat[ 0 ], 4 * 4);
      end;
    $10:
      begin
        Buffer.Read(op.Val_Color[ 0 ], 4 * 4);
      end;
    $11:
      begin
        Buffer.Read(op.Val_Matrix[ 0 ], 4 * 4 * 4);
      end;
    $12:
      begin
        Buffer.Read(op.Val_Rect[ 0 ], 4 * 4);
      end;
    $13:
      begin
        Buffer.Read(op.Val_Rect_Float[ 0 ], 4 * 4);
      end;
    $14:
      begin
        Buffer.Read(op.Val_Hash_128[ 0 ], 4 * 4);
      end;
    $15:
      begin
        Buffer.Read(op.Val_Bit_32, 4);
      end;
    $18:
      begin
        Buffer.Read(op.Val_JIS_String_Length, 4);
      end;
    $1A:
      begin
        Buffer.Read(op.Val_UTF8_String_Length, 4);

      end;
    $1B:
      begin
        Buffer.Read(op.Val_Binary_Length, 4);
      end;
    $20:
      begin
        Buffer.Read(op.List_Count, 4);
      end;
    $21:
      begin
          ;
      end;
    $22:
      begin
          ;
      end;
    $23:
      begin
          ;
      end;
    $24:
      begin
          ;
      end;
    $25:
      begin
          ;
      end
  else
    raise Exception.Create('Unknow type ident.');
  end;
end;

procedure Parser(Buffer: TStream; Text: TStrings);
var
  op: TOperater;
  FuncArray: TFuncArray;
  tmp: string;
  i: Integer;
  Stack: TStack< Integer >;
  function SearchFunction(Const code: Integer): string;
  var
    i, j: Integer;
  begin
    Result := '!FunctionNotFound';
    if code = 0 then
    begin
      ReadNextOp(Buffer, op);
      Result := Format('SystemCall( %s );', [ PrintOP(Buffer, op) ]);
      Exit;
    end;
    for i := Low(FuncArray) to High(FuncArray) do
    begin
      if FuncArray[ i ].op = code then
      begin
        Result := FuncArray[ i ].str + '( ';
        for j := 0 to FuncArray[ i ].param_Count do
        begin
          ReadNextOp(Buffer, op);
          case op.op of
            $18, $1A:
              begin
                Result := Result + '"' + PrintOP(Buffer, op) + '" ,';
              end;
            else
            Result := Result + PrintOP(Buffer, op) + ',';
          end;
        end;
        Delete(Result, Length(Result), 1);
        Result := Result + ' );';
        Break;
      end;
    end;
  end;

begin
  ReadNextOp(Buffer, op);
  Text.Add(Format('%s', [ PrintOP(Buffer, op) ]));
  ReadNextOp(Buffer, op);
  while op.op <> $21 do
  begin
    tmp := '';
    Text.Add(Format(' item {', [ ]));
    tmp := '  Lable: "' + PrintOP(Buffer, op) + '"';
    ReadNextOp(Buffer, op);
    tmp := Format('%s,%s', [ tmp, PrintOP(Buffer, op) ]);
    ReadNextOp(Buffer, op);
    tmp := Format('%s,%s', [ tmp, PrintOP(Buffer, op) ]);
    Text.Add(tmp);
    ReadNextOp(Buffer, op);
    tmp := '  Content: "' + PrintOP(Buffer, op) + '"';
    ReadNextOp(Buffer, op);
    tmp := Format('%s,%s', [ tmp, PrintOP(Buffer, op) ]);
    Text.Add(tmp);
    Text.Add(Format(' }', [ ]));
    ReadNextOp(Buffer, op);
  end;
  Text.Add(Format('}ScriptList', [ ]));
  Text.Add('');
  ReadNextOp(Buffer, op);
  Text.Add(Format('%s', [ PrintOP(Buffer, op) ]));
  ReadNextOp(Buffer, op);
  while op.op <> $21 do
  begin
    tmp := '';
    Text.Add(Format(' item {', [ ]));
    tmp := '  Lable: "' + PrintOP(Buffer, op) + '"';
    ReadNextOp(Buffer, op);
    tmp := Format('%s,%s', [ tmp, PrintOP(Buffer, op) ]);
    ReadNextOp(Buffer, op);
    tmp := Format('%s,%s', [ tmp, PrintOP(Buffer, op) ]);
    ReadNextOp(Buffer, op);
    tmp := Format('%s,%s', [ tmp, PrintOP(Buffer, op) ]);
    Text.Add(tmp);
    ReadNextOp(Buffer, op);
    tmp := '  Content: "' + PrintOP(Buffer, op) + '"';
    ReadNextOp(Buffer, op);
    tmp := Format('%s,%s', [ tmp, PrintOP(Buffer, op) ]);
    Text.Add(tmp);
    Text.Add(Format(' }', [ ]));
    ReadNextOp(Buffer, op);
  end;
  Text.Add(Format('}ScriptJointList', [ ]));
  Text.Add('');
  ReadNextOp(Buffer, op);
  Text.Add(Format('%s', [ PrintOP(Buffer, op) ]));
  SetLength(FuncArray, EndianSwap(op.Val_DWORD));
  ReadNextOp(Buffer, op);
  i := 0;
  while op.op <> $21 do
  begin
    tmp := '';
    Text.Add(Format(' Function {', [ ]));
    tmp := PrintOP(Buffer, op);
    FuncArray[ i ].str := tmp;
    ReadNextOp(Buffer, op);
    tmp := Format(' %s,%s', [ tmp, PrintOP(Buffer, op) ]);
    FuncArray[ i ].op := EndianSwap(op.Val_DWORD);
    ReadNextOp(Buffer, op);
    tmp := Format('%s,%s', [ tmp, PrintOP(Buffer, op) ]);
    FuncArray[ i ].op_context_state := EndianSwap(op.Val_DWORD);
    ReadNextOp(Buffer, op);
    tmp := Format('%s,%s', [ tmp, PrintOP(Buffer, op) ]);
    FuncArray[ i ].param_Count := EndianSwap(op.Val_DWORD);
    Text.Add(tmp);
    Text.Add(Format(' }', [ ]));
    ReadNextOp(Buffer, op);
    i := i + 1;
  end;
  Text.Add(Format('}FunctionList', [ ]));
  Text.Add('');

  Stack := TStack< Integer >.Create;
  try
    ReadNextOp(Buffer, op);
    Text.Add(Format('%s', [ PrintOP(Buffer, op) ]));
    Stack.Push(1);
    SetLength(FuncArray, EndianSwap(op.Val_DWORD));
    ReadNextOp(Buffer, op);
    while Stack.count > 0 do
    begin
      case op.op of
        $20:
          begin
            if EndianSwap(op.Val_DWORD) > 0 then
            begin
              tmp := '';
              for i := 0 to Stack.count - 1 do
                tmp := tmp + ' ';
              Text.Add(tmp + PrintOP(Buffer, op));
              Stack.Push(1);
            end
            else
              Stack.Push(0);
          end;
        $21:
          begin
            if Stack.Pop = 1 then
            begin
              tmp := '';
              for i := 0 to Stack.count - 1 do
                tmp := tmp + ' ';
              Text.Add(tmp + PrintOP(Buffer, op));
              Text.Add('');
            end;
          end;
        $15:
          begin
            tmp := '';
            for i := 0 to Stack.count - 1 do
              tmp := tmp + ' ';
            Text.Add(tmp + SearchFunction(EndianSwap(op.Val_Bit_32)));
          end;
        $18, $1A:
          begin
            tmp := '';
            for i := 0 to Stack.count - 1 do
              tmp := tmp + ' ';
            Text.Add(tmp + '//' + PrintOP(Buffer, op));
          end
      else
        begin
          tmp := '';
          for i := 0 to Stack.count - 1 do
            tmp := tmp + ' ';
          Text.Add(tmp + PrintOP(Buffer, op));
        end;
      end;
      ReadNextOp(Buffer, op);
    end;
    Text.Add(Format('}ScriptMainList', [ ]));
  finally
    Stack.Free;
  end;
end;

var
  Buffer: tmemorystream;
  Text: TStringList;

begin
  try
    if ParamCount <> 1 then
      raise Exception.Create('Error.');
    if not FileExists(ParamStr(1)) then
      raise Exception.Create('Error input.');
    Writeln('SakuraTomo34@Gmail.com');
    Buffer := tmemorystream.Create;
    Text := TStringList.Create;
    try
      Writeln('Load.');
      Buffer.LoadFromFile(ParamStr(1));
      Buffer.Seek(0, soFromBeginning);
      Writeln('Decompile.');
      Parser(Buffer, Text);
      Writeln('Save.');
      Text.SaveToFile(ParamStr(1) + '.txt', tencoding.UTF8);
      Writeln('Finished.');
    finally
      Buffer.Free;
      Text.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
