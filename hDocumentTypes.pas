unit hDocumentTypes;

interface

uses Contnrs, Classes, SysUtils, Windows;

const
  Magic: array [0 .. $F] of Char = 'Halte3HelpDoc   ';

  EngineLen = $50;
  NameLen = $100;
  GameMakerLen = $50;
  ExtensionLen = $50;
  StateLen = $50;

type

  TDataHead = packed record
    AMagic: array [0 .. $F] of Char;
    ANodes: Cardinal;
    Seed: Cardinal;
  end;

  TRecNode = packed record
    AEngine: array [1 .. $50] of Char;
    AName: array [1 .. $100] of Char;
    AGameMaker: array [1 .. $50] of Char;
    AExtension: array [1 .. $50] of Char;
    AState: array [1 .. $50] of Char;
  end;

  TDataNode = class(TObject)
    AEngine: array [1 .. $50] of Char;
    AName: array [1 .. $100] of Char;
    AGameMaker: array [1 .. $50] of Char;
    AExtension: array [1 .. $50] of Char;
    AState: array [1 .. $50] of Char;
  public
    procedure Assign(Source: TDataNode); overload;
    procedure Assign(Source: TRecNode); overload;
  end;

  TNodeList = class(TObjectList)
  protected
    function GetItem(Index: Integer): TDataNode; inline;
    procedure SetItem(Index: Integer;
      AObject: TDataNode); inline;
  public
    function Add(AObject: TDataNode): Integer; inline;
    function Remove(AObject: TDataNode): Integer;
      overload; inline;
    function IndexOf(AObject: TDataNode): Integer; inline;
    procedure Insert(Index: Integer; AObject: TDataNode); inline;
    function First: TDataNode; inline;
    function Last: TDataNode; inline;
    property Items[Index: Integer]: TDataNode read GetItem
      write SetItem; default;
  end;

  TDataConnect = class(TObject)
  private
    FDataHead: TDataHead;
    Nodes: TNodeList;
  protected
    procedure UpdateKey;
    procedure Decode(var Node: TRecNode);
  public
    property NodeList: TNodeList read Nodes;
    constructor Create;
    destructor Destroy; override;
    procedure LoadDocument(Path: string);
    procedure SaveDocument(Path: string);
  end;

implementation

procedure TDataNode.Assign(Source: TDataNode);
begin
  AEngine := Source.AEngine;
  AName := Source.AName;
  AGameMaker := Source.AGameMaker;
  AExtension := Source.AExtension;
  AState := Source.AState;
end;

procedure TDataNode.Assign(Source: TRecNode);
begin
  MoveChars(Source.AEngine[1], AEngine[1], EngineLen);
  MoveChars(Source.AName[1], AName[1], NameLen);
  MoveChars(Source.AGameMaker[1], AGameMaker[1], GameMakerLen);
  MoveChars(Source.AExtension[1], AExtension[1], ExtensionLen);
  MoveChars(Source.AState[1], AState[1], StateLen);
end;

procedure TNodeList.SetItem(Index: Integer; AObject: TDataNode);
begin
  inherited Items[Index] := AObject;
end;

procedure TNodeList.Insert(Index: Integer; AObject: TDataNode);
begin
  inherited Insert(Index, AObject);
end;

function TNodeList.GetItem;
begin
  Result := TDataNode( inherited Items[Index]);
end;

function TNodeList.Add;
begin
  Result := inherited Add(AObject);
end;

function TNodeList.Remove(AObject: TDataNode): Integer;
begin
  Result := inherited Remove(AObject);
end;

function TNodeList.IndexOf;
begin
  Result := inherited IndexOf(AObject);
end;

function TNodeList.First;
begin
  Result := TDataNode( inherited First);
end;

function TNodeList.Last;
begin
  Result := TDataNode( inherited First);
end;

constructor TDataConnect.Create;
begin
  inherited Create;
  Nodes := TNodeList.Create;
end;

destructor TDataConnect.Destroy;
begin
  Nodes.Free;
  inherited Destroy;
end;

procedure TDataConnect.UpdateKey;
begin
  FDataHead.Seed := FDataHead.Seed xor $8973E2A4;
  FDataHead.Seed := (((FDataHead.Seed shr 1) xor FDataHead.Seed)
    shr 3) xor (((FDataHead.Seed shl 1) xor FDataHead.Seed)
    shl 3) xor FDataHead.Seed;
end;

procedure TDataConnect.Decode(var Node: TRecNode);
var
  Mask: array [0 .. 3] of Byte;
  i: Integer;
begin
  UpdateKey;
  Move(FDataHead.Seed, Mask[0], 4);
  for i := 1 to (EngineLen - 1) * SizeOf(Char) do
  begin
    if i mod $F = 0 then
    begin
      UpdateKey;
      Move(FDataHead.Seed, Mask[0], 4);
    end;
    PByte(@Node.AEngine[1])[i] := PByte(@Node.AEngine[1])
      [i] xor Mask[i mod 4];
  end;
  UpdateKey;
  for i := 1 to (NameLen - 1) * SizeOf(Char) do
  begin
    if i mod $F = 0 then
    begin
      UpdateKey;
      Move(FDataHead.Seed, Mask[0], 4);
    end;
    PByte(@Node.AName[1])[i] := PByte(@Node.AName[1])
      [i] xor Mask[i mod 4];
  end;
  UpdateKey;
  for i := 1 to (GameMakerLen - 1) * SizeOf(Char) do
  begin
    if i mod $F = 0 then
    begin
      UpdateKey;
      Move(FDataHead.Seed, Mask[0], 4);
    end;
    PByte(@Node.AGameMaker[1])[i] := PByte(@Node.AGameMaker[1])
      [i] xor Mask[i mod 4];
  end;
  UpdateKey;
  for i := 1 to (ExtensionLen - 1) * SizeOf(Char) do
  begin
    if i mod $F = 0 then
    begin
      UpdateKey;
      Move(FDataHead.Seed, Mask[0], 4);
    end;
    PByte(@Node.AExtension[1])[i] := PByte(@Node.AExtension[1])
      [i] xor Mask[i mod 4];
  end;
  UpdateKey;
  for i := 1 to (StateLen - 1) * SizeOf(Char) do
  begin
    if i mod $F = 0 then
    begin
      UpdateKey;
      Move(FDataHead.Seed, Mask[0], 4);
    end;
    PByte(@Node.AState[1])[i] := PByte(@Node.AState[1])
      [i] xor Mask[i mod 4];
  end;
end;

procedure TDataConnect.LoadDocument(Path: string);
var
  Buffer: TFileStream;
  Node: TDataNode;
  tmpNode: TRecNode;
  i: Integer;
begin
  Buffer := TFileStream.Create(Path, fmOpenRead);
  try
    Buffer.Read(FDataHead, SizeOf(TDataHead));
    if not SameText(FDataHead.AMagic, Magic) then
      raise Exception.Create('Incorrect Document.');
    for i := 0 to FDataHead.ANodes - 1 do
    begin
      Buffer.Read(tmpNode.AEngine[1], SizeOf(TRecNode));
      Decode(tmpNode);
      Node := TDataNode.Create;
      Node.Assign(tmpNode);
      Nodes.Add(Node);
    end;
  finally
    Buffer.Free;
  end;
end;

procedure TDataConnect.SaveDocument(Path: string);
var
  Buffer: TFileStream;
  tmpNode: TRecNode;
  i: Integer;
begin
  Buffer := TFileStream.Create(Path, fmCreate);
  try
    MoveChars(Magic[0], FDataHead.AMagic[0], Length(Magic));
    FDataHead.ANodes := Nodes.Count;
    FDataHead.Seed := Random($7FFFFFFF);
    Buffer.Write(FDataHead.AMagic[0], SizeOf(TDataHead));
    if not SameText(FDataHead.AMagic, Magic) then
      raise Exception.Create('Incorrect Document.');
    for i := 0 to FDataHead.ANodes - 1 do
    begin
      with tmpNode do
      begin
        MoveChars(Nodes[i].AEngine[1], AEngine[1], EngineLen);
        MoveChars(Nodes[i].AName[1], AName[1], NameLen);
        MoveChars(Nodes[i].AGameMaker[1], AGameMaker[1],
          GameMakerLen);
        MoveChars(Nodes[i].AExtension[1], AExtension[1],
          ExtensionLen);
        MoveChars(Nodes[i].AState[1], AState[1], StateLen);
      end;
      Decode(tmpNode);
      Buffer.Write(tmpNode.AEngine[1], SizeOf(TRecNode));
    end;
  finally
    Buffer.Free;
  end;
end;

end.
