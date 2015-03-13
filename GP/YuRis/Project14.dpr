program Project14;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,
  System.Classes;

type
  TYSTBHeader = packed record
    Magic: array [ 0 .. 3 ] of AnsiChar;
    Version: Cardinal;
    OPCount: Cardinal;
    data1_length: Cardinal;
    data2_length: Cardinal;
    data3_length: Cardinal;
    data4_length: Cardinal;
    reserved: Cardinal;
  end;

  TBaseTrunkInfo = packed record
    Kind: Byte;
    InfoTrunks: Byte;
    Reserved0: Byte;
    Reserved1: Byte;
  end;

  TDataTrunkInfo = packed record
    Kind: Word;
    HeaderSize: Word;
    Length: Cardinal;
    Offset: Cardinal;
  end;

var
  Header: TYSTBHeader;
  Table1: array of TBaseTrunkInfo;
  Table2: array of TDataTrunkInfo;
  Table3: array of Byte;
  Table4: array of Cardinal;
  Data  : TMemoryStream;
  i, j  : integer;
  buf   : array of Byte;
  Text  : TStrings;
  StrLen: Word;
  S     : AnsiString;

begin
  try
    if ParamCount <> 2 then
      raise Exception.Create('Error');
    if FileExists(ParamStr(1)) then
    begin
      Data := TMemoryStream.Create;
      Text := TStringList.Create;
      Data.LoadFromFile(ParamStr(1));
      Data.Seek(0, soFromBeginning);
      Data.Read(Header.Magic[ 0 ], SizeOf(TYSTBHeader));
      if not SameText(Trim(Header.Magic), 'YSTB') then
        raise Exception.Create('Error file type.');
      SetLength(Table1, Header.data1_length div 4);
      SetLength(Table3, Header.data3_length);
      SetLength(Table4, Header.data4_length div 4);
      Data.Read(Table1[ 0 ].Kind, Header.data1_length); // flag&len
      Data.Seek(Header.data2_length, soFromCurrent);
      Data.Read(Table3[ 0 ], Header.data3_length); // raw data
      Data.Read(Table4[ 0 ], Header.data4_length); // table
      Data.Seek(Header.data1_length + SizeOf(TYSTBHeader), soFromBeginning);
      for i := 0 to Header.OPCount - 1 do
      begin
        SetLength(Table2, Table1[ i ].InfoTrunks);
        Data.Read(Table2[ 0 ].Kind, Table1[ i ].InfoTrunks *
          SizeOf(TDataTrunkInfo));
        for j := 0 to Table1[ i ].InfoTrunks - 1 do
        begin
          case Table1[ i ].Kind of
            $1C, $1D:
              begin
                Move(Table3[ Table2[ j ].Offset + 1 ], StrLen, 2);
                case Table3[ Table2[ j ].Offset ] of
                  $48:
                    begin
                      { if StrLen <> 3 then
                        raise Exception.Create('Paramlen do not match');
                        Text.Add(AnsiChar(Table3[ p + 3 ]) +
                        IntToHex(PWORD(@Table3[ p + 4 ])^, 4)); }
                    end;
                  $4D:
                    begin
                      SetLength(S, StrLen);
                      Move(Table3[ Table2[ j ].Offset + 3 ], PByte(S)^, StrLen);
                      Text.Add(S);
                    end;
                else
                  begin
                    writeln(' Unknown Type of SubOP: ' +
                      inttohex(Table3[ Table2[ j ].Offset ], 2));
                    writeln(' Trace InfoTable: ');
                    writeln(' { Kind: ' + inttohex(Table2[ j ].Kind, 4));
                    writeln(' HeaderSize: ' +
                      inttohex(Table2[ j ].HeaderSize, 4));
                    writeln(' Length: ' + inttohex(Table2[ j ].Length, 8));
                    writeln(' Offset: ' + inttohex(Table2[ j ].Offset, 8));
                    writeln(' }');
                  end;
                end;
              end;
            $1E:
              begin
                if (Header.Version = 474) then
                begin
                  Move(Table3[ Table2[ j ].Offset + 1 ], StrLen, 2);
                  case Table3[ Table2[ j ].Offset ] of
                    $4D:
                      begin
                        SetLength(S, StrLen);
                        Move(Table3[ Table2[ j ].Offset + 3 ],
                          PByte(S)^, StrLen);
                        Text.Add(S);
                      end;
                  end;

                end;
              end;
            $57:
              begin

              end;
            $5B:
              begin
                SetLength(S, Table2[ j ].Length);
                Move(Table3[ Table2[ j ].Offset ], PByte(S)^,
                  Table2[ j ].Length);
                Text.Add(S);
              end;
          else
            begin
              writeln('Unknown BaseType of op: ' +
                inttohex(Table1[ i ].Kind, 2));
              writeln('Trace InfoTable: ');
              writeln('{ Kind: ' + inttohex(Table2[ j ].Kind, 4));
              writeln('HeaderSize: ' + inttohex(Table2[ j ].HeaderSize, 4));
              writeln('Length: ' + inttohex(Table2[ j ].Length, 8));
              writeln('Offset: ' + inttohex(Table2[ j ].Offset, 8));
              writeln('}');
            end;
          end;
        end;
      end;
      Text.SaveToFile(ParamStr(2));
      Data.Free;
      Text.Free;
    end;
  except
    on E: Exception do
      writeln(E.ClassName, ': ', E.Message);
  end;

end.
