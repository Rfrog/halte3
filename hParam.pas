unit hParam;

interface

uses Windows,
  Generics.Collections,
  SysUtils;

const
  PluginPath = '\GP\';

type
  TParamStr = function(Index: Integer): string;
  TParamCount = function(): Integer;
  TParamSel = (psExtract, psPack, psDetect, psFilter, psLog,
    psPlugin, psDest, psSource, psMessage, psFileStream ,psUnknow);

  TParamDict = class(TDictionary<string, TParamSel>)
  public
    procedure Initialize;
  end;

  TParamSet = record
    FStyle: TParamSel;
    FSource: string;
    FDest: string;
    FFilter: Boolean;
    FFilterStr: string;
    FLog: Boolean;
    FPlugin: string;
    FMessage: Boolean;
    FFileStream: Boolean;
  end;

procedure ParserParam(ParamCount: TParamCount;
  ParamStr: TParamStr);
function CheckState(State: TParamSet): Boolean;

var
  ParamSet: TParamSet;

implementation

procedure TParamDict.Initialize;
begin
  // General
  Add('-EXTRACT', psExtract);
  Add('-PACK', psPack);
  Add('-FILTER', psFilter);
  Add('-LOG', psLog);
  Add('-DETECT', psDetect);
  Add('-PLUGIN', psPlugin);
  Add('-DEST', psDest);
  Add('-SOURCE', psSource);
  Add('-MESSAGE', psMessage);
  Add('-FILESTREAM', psFileStream);
end;

function CheckState(State: TParamSet): Boolean;
begin
  Result := True;
  if ((not FileExists(State.FSource)) and
    (State.FStyle in [psExtract .. psDetect])) or
    ((not DirectoryExists(State.FSource)) and
    (State.FStyle in [psPack])) then
  begin
    Result := False;
    Exit;
  end;
  if State.FFilter and (State.FFilterStr = '') then
  begin
    Result := False;
    Exit;
  end;
  if State.FPlugin = '' then
  begin
    Result := False;
    Exit;
  end;
  if (State.FDest <> '') and
    (not ForceDirectories(State.FDest)) then
  begin
    Result := False;
    Exit;
  end;
end;

procedure ParserParam(ParamCount: TParamCount;
  ParamStr: TParamStr);
var
  i: Integer;
  ParamDict: TParamDict;
begin
  ParamDict := TParamDict.Create;
  ParamDict.Initialize;
  try
    i := 1;
    while i <= ParamCount do
    begin
      if not ParamDict.ContainsKey
        (strupper(PChar(ParamStr(i)))) then
      begin
        inc(i);
        Continue;
      end;
      case ParamDict.Items[strupper(PChar(ParamStr(i)))] of
        psExtract:
          begin
            if ParamSet.FStyle <> psUnknow then
              raise Exception.Create('Param duplicated.');
            ParamSet.FStyle := psExtract;
          end;
        psPack:
          begin
            if ParamSet.FStyle <> psUnknow then
              raise Exception.Create('Param duplicated.');
            ParamSet.FStyle := psPack;
          end;
        psDetect:
          begin
            if ParamSet.FStyle <> psUnknow then
              raise Exception.Create('Param duplicated.');
            ParamSet.FStyle := psDetect;
          end;
        psFilter:
          begin
            if ParamSet.FFilter then
              raise Exception.Create('Param duplicated.');
            ParamSet.FFilter := True;
            ParamSet.FFilterStr := ParamStr(i + 1);
            inc(i);
          end;
        psLog:
          begin
            if ParamSet.FLog then
              raise Exception.Create('Param duplicated.');
            ParamSet.FLog := True;
          end;
        psPlugin:
          begin
            ParamSet.FPlugin := ParamStr(i + 1);
            inc(i);
          end;
        psDest:
          begin
            ParamSet.FDest := ParamStr(i + 1);
            inc(i);
          end;
        psSource:
          begin
            ParamSet.FSource := ParamStr(i + 1);
            inc(i);
          end;
        psMessage:
          begin
            if ParamSet.FMessage then
              raise Exception.Create('Param duplicated.');
            ParamSet.FMessage := True;
          end;
      else
        raise Exception.Create('Param error.');
      end;
      inc(i);
    end;
  finally
    ParamDict.Free;
  end;
end;

initialization

begin
  with ParamSet do
  begin
    FStyle := psUnknow;
    FSource := '';
    FDest := '';
    FFilter := False;
    FFilterStr := '';
    FLog := False;
    FPlugin := '';
    FMessage := False;
  end;
end;

end.
