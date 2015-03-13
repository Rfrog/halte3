program Project12;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,
  System.Classes;

type
  TOperater = record
    case OP: Byte of
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

function EndianSwap(const a: integer): integer;
asm
  bswap eax
end;

procedure Print(Buffer: TStream; Text: TStrings; OP: TOperater);
var
  print_str: string;
  Buf: PByte;
  i: integer;
  bytes: TBytes;
  chars: TCharArray;
begin
  case OP.OP of
    01:
      print_str :=
        Format('Byte_Signed %d;', [ OP.Val_Byte ]);
    02:
      print_str :=
        Format('Byte_Unsigned %u;', [ OP.Val_Byte ]);
    03:
      print_str :=
        Format('Word_Signed %d;', [ OP.Val_Word ]);
    04:
      print_str :=
        Format('Word_Unsigned %u;', [ OP.Val_Word ]);
    05:
      print_str :=
        Format('Cardinal_Signed %d;', [ EndianSwap(OP.Val_DWORD) ]);
    06:
      print_str :=
        Format('Cardinal_Unsigned %u;', [ EndianSwap(OP.Val_DWORD) ]);
    07:
      begin
        i := OP.Val_Vecror_2D[ 0 ];
        OP.Val_Vecror_2D[ 0 ] := EndianSwap(OP.Val_Vecror_2D[ 1 ]);
        OP.Val_Vecror_2D[ 1 ] := EndianSwap(i);
        print_str :=
          Format('Int64_Signed %d,%d;',
          [ OP.Val_Vecror_2D[ 0 ], OP.Val_Vecror_2D[ 1 ] ]);
      end;
    08:
      begin
        i := OP.Val_Vecror_2D[ 0 ];
        OP.Val_Vecror_2D[ 0 ] := EndianSwap(OP.Val_Vecror_2D[ 1 ]);
        OP.Val_Vecror_2D[ 1 ] := EndianSwap(i);
        print_str :=
          Format('Int64_Unsigned %d,%d;',
          [ OP.Val_Vecror_2D[ 0 ], OP.Val_Vecror_2D[ 1 ] ]);
      end;
    09:
      begin
        OP.Val_Vecror_2D[ 0 ] := EndianSwap(OP.Val_Vecror_2D[ 0 ]);
        print_str :=
          Format('Float32 %f;', [ OP.Val_Float ]);
      end;
    $0A:
      begin
        i := OP.Val_Vecror_2D[ 0 ];
        OP.Val_Vecror_2D[ 0 ] := EndianSwap(OP.Val_Vecror_2D[ 1 ]);
        OP.Val_Vecror_2D[ 1 ] := EndianSwap(i);
        print_str :=
          Format('Float64 %f;', [ OP.Val_Double ]);
      end;
    $0B:
      print_str :=
        Format('Boolean %u;', [ OP.Val_Boolean ]);
    $0C:
      print_str :=
        Format('Vecror_2D [%u , %u];', [ EndianSwap(OP.Val_Vecror_2D[ 0 ]),
        EndianSwap(OP.Val_Vecror_2D[ 1 ]) ]);
    $0D:
      print_str :=
        Format('Vecror_3D [%u , %u , %u];',
        [ EndianSwap(OP.Val_Vecror_3D[ 0 ]),
        EndianSwap(OP.Val_Vecror_3D[ 1 ]), EndianSwap(OP.Val_Vecror_3D[ 2 ]) ]);
    $0E:
      print_str :=
        Format('Vecror_4D [%u , %u , %u , %u];',
        [ EndianSwap(OP.Val_Vecror_4D[ 0 ]),
        EndianSwap(OP.Val_Vecror_4D[ 1 ]), EndianSwap(OP.Val_Vecror_4D[ 2 ]),
        EndianSwap(OP.Val_Vecror_4D[ 3 ]) ]);
    $0F:
      print_str :=
        Format('Vecror_Quad [%u , %u , %u , %u];',
        [ EndianSwap(OP.Val_Vecror_4D[ 0 ]),
        EndianSwap(OP.Val_Vecror_4D[ 1 ]), EndianSwap(OP.Val_Vecror_4D[ 2 ]),
        EndianSwap(OP.Val_Vecror_4D[ 3 ]) ]);
    $10:
      print_str :=
        Format('Vecror_Color [%u , %u , %u , %u];',
        [ EndianSwap(OP.Val_Vecror_4D[ 0 ]),
        EndianSwap(OP.Val_Vecror_4D[ 1 ]), EndianSwap(OP.Val_Vecror_4D[ 2 ]),
        EndianSwap(OP.Val_Vecror_4D[ 3 ]) ]);
    $11:
      print_str :=
        Format('Matrix [%u,%u,%u,%u],[%u,%u,%u,%u],[%u,%u,%u,%u],[%u,%u,%u,%u];',
        [ EndianSwap(OP.Val_Matrix[ 0, 0 ]),
        EndianSwap(OP.Val_Matrix[ 0, 1 ]), EndianSwap(OP.Val_Matrix[ 0, 2 ]),
        EndianSwap(OP.Val_Matrix[ 0,
        3 ])
        , EndianSwap(OP.Val_Matrix[ 1, 0 ]),
        EndianSwap(OP.Val_Matrix[ 1, 1 ]), EndianSwap(OP.Val_Matrix[ 1, 2 ]),
        EndianSwap(OP.Val_Matrix[ 1,
        3 ])
        , EndianSwap(OP.Val_Matrix[ 2, 0 ]),
        EndianSwap(OP.Val_Matrix[ 2, 1 ]), EndianSwap(OP.Val_Matrix[ 2, 2 ]),
        EndianSwap(OP.Val_Matrix[ 2,
        3 ])
        , EndianSwap(OP.Val_Matrix[ 3, 0 ]),
        EndianSwap(OP.Val_Matrix[ 3, 1 ]), EndianSwap(OP.Val_Matrix[ 3, 2 ]),
        EndianSwap(OP.Val_Matrix[ 3, 3 ]) ]);
    $12:
      print_str :=
        Format('Vecror_Rect [%u , %u , %u , %u];',
        [ EndianSwap(OP.Val_Vecror_4D[ 0 ]),
        EndianSwap(OP.Val_Vecror_4D[ 1 ]), EndianSwap(OP.Val_Vecror_4D[ 2 ]),
        EndianSwap(OP.Val_Vecror_4D[ 3 ]) ]);
    $13:
      print_str :=
        Format('Vecror_Rect_Float [%f , %f , %f , %f];',
        [ OP.Val_Rect_Float[ 0 ],
        OP.Val_Rect_Float[ 1 ], OP.Val_Rect_Float[ 2 ],
        OP.Val_Rect_Float[ 3 ] ]);
    $14:
      print_str :=
        Format('Hash_128 [%u , %u , %u , %u];',
        [ EndianSwap(OP.Val_Vecror_4D[ 0 ]),
        EndianSwap(OP.Val_Vecror_4D[ 1 ]), EndianSwap(OP.Val_Vecror_4D[ 2 ]),
        EndianSwap(OP.Val_Vecror_4D[ 3 ]) ]);
    $15:
      print_str :=
        Format('Byte_32 %u;', [ EndianSwap(OP.Val_DWORD) ]);
    $18:
      begin
        Buf := SysGetMem(EndianSwap(OP.Val_JIS_String_Length) + 1);
        Buffer.Read(Buf^, EndianSwap(OP.Val_JIS_String_Length) + 1);
        print_str :=
          Format('JIS_Str %s;', [ trim(PChar(chars)) ]);
        SysFreeMem(Buf);
      end;
    $1A:
      begin
        SetLength(bytes, EndianSwap(OP.Val_UTF8_String_Length) + 1);
        Buffer.Read(bytes[ 0 ], EndianSwap(OP.Val_UTF8_String_Length) + 1);
        chars := tencoding.UTF8.GetChars(bytes);
        print_str :=
          Format('UTF8_Str %s;',
          [ trim(PChar(chars)) ]);
        SetLength(bytes, 0);
      end;
    $1B:
      begin
        Buf := SysGetMem(EndianSwap(OP.Val_Binary_Length));
        Buffer.Read(Buf^, EndianSwap(OP.Val_Binary_Length));
        print_str := 'Binary [';
        for i := 0 to EndianSwap(OP.Val_Binary_Length) - 1 do
        begin
          print_str := print_str + IntToHex(Buf[ i ], 1);
        end;
        print_str := print_str + '];';
        SysFreeMem(Buf);
      end;
    $20:
      print_str :=
        Format('Typedef List[%u] {', [ EndianSwap(OP.List_Count) ]);
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
  Text.Add(print_str);
end;

var
  Buffer: tmemorystream;
  Text: TStringList;
  OP: TOperater;

begin
  try
    if ParamCount <> 1 then
      raise Exception.Create('Error.');
    if not FileExists(ParamStr(1)) then
      raise Exception.Create('Error input.');
    Buffer := tmemorystream.Create;
    Text := TStringList.Create;
    try
      Buffer.LoadFromFile(ParamStr(1));
      Buffer.Seek(0, soFromBeginning);
      while Buffer.Position < Buffer.Size do
      begin
        Buffer.Read(OP.OP, 1);
        case OP.OP of
          01, 02:
            Buffer.Read(OP.Val_Byte, 1);
          03, 04:
            Buffer.Read(OP.Val_Word, 2);
          05, 06:
            Buffer.Read(OP.Val_DWORD, 4);
          07, 08:
            Buffer.Read(OP.Val_Int64, 8);
          09:
            Buffer.Read(OP.Val_Float, 4);
          $0A:
            Buffer.Read(OP.Val_Double, 8);
          $0B:
            Buffer.Read(OP.Val_Boolean, 1);
          $0C:
            begin
              Buffer.Read(OP.Val_Vecror_2D[ 0 ], 4 * 2);
            end;
          $0D:
            begin
              Buffer.Read(OP.Val_Vecror_3D[ 0 ], 4 * 3);
            end;
          $0E:
            begin
              Buffer.Read(OP.Val_Vecror_4D[ 0 ], 4 * 4);
            end;
          $0F:
            begin
              Buffer.Read(OP.Val_Quat[ 0 ], 4 * 4);
            end;
          $10:
            begin
              Buffer.Read(OP.Val_Color[ 0 ], 4 * 4);
            end;
          $11:
            begin
              Buffer.Read(OP.Val_Matrix[ 0 ], 4 * 4 * 4);
            end;
          $12:
            begin
              Buffer.Read(OP.Val_Rect[ 0 ], 4 * 4);
            end;
          $13:
            begin
              Buffer.Read(OP.Val_Rect_Float[ 0 ], 4 * 4);
            end;
          $14:
            begin
              Buffer.Read(OP.Val_Hash_128[ 0 ], 4 * 4);
            end;
          $15:
            Buffer.Read(OP.Val_Bit_32, 4);
          $18:
            begin
              Buffer.Read(OP.Val_JIS_String_Length, 4);

            end;
          $1A:
            begin
              Buffer.Read(OP.Val_UTF8_String_Length, 4);

            end;
          $1B:
            begin
              Buffer.Read(OP.Val_Binary_Length, 4);
            end;
          $20:
            Buffer.Read(OP.List_Count, 4);
          $21:
            ;
          $22:
            ;
          $23:
            ;
          $24:
            ;
          $25:
            ;
        else
          raise Exception.Create('Unknow op.');
        end;
        Print(Buffer, Text, OP);
      end;
      Text.SaveToFile(ParamStr(1) + '.txt', tencoding.UTF8);
    finally
      Buffer.Free;
      Text.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
