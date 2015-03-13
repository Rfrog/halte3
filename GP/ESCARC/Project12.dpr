program Project12;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,
  System.Classes;

type
  THead = packed record
    magic: array [ 0 .. 7 ] of ansichar;
    constrs: Cardinal;
  end;

  TDataHead = packed record
    magic: Cardinal;
    datasize: Cardinal;
  end;

  TListHead = packed record
    offset: Cardinal;
    indexs: Cardinal;
  end;

  NAME_T = packed record
    text: array [ 0 .. 63 ] of ansichar;
    color: Cardinal;
    face: array [ 0 .. 31 ] of ansichar;
  end;

  VAR_T = packed record
    name: array [ 0 .. 31 ] of ansichar;
    index: Word;
    flag: Word;
  end;

  SCENE_T = packed record
    script: Cardinal;
    title: array [ 0 .. 63 ] of ansichar;
    thumbnail: array [ 0 .. 31 ] of ansichar;
    order: Cardinal;
  end;

  BG_T = packed record
    name: array [ 0 .. 31 ] of ansichar;
    color: Cardinal;
    order: Cardinal;
    link: Cardinal;
  end;

  EV_T = packed record
    name: array [ 0 .. 31 ] of ansichar;
    color: Cardinal;
    order: Cardinal;
    link: Cardinal;
  end;

  ST_T = packed record
    name: array [ 0 .. 31 ] of ansichar;
    base: array [ 0 .. 31 ] of ansichar;
    option: array [ 0 .. 63 ] of ansichar;
    pose: Cardinal;
    order: Cardinal;
    link: Cardinal;
  end;

  EM_T = packed record
    _file: array [ 0 .. 31 ] of ansichar;
    x: Integer;
    y: Integer;
    loop: Cardinal;
    pose: Cardinal;
    id: Cardinal;
  end;

  EFX_T = packed record
    _file: array [ 0 .. 31 ] of ansichar;
    x: Integer;
    y: Integer;
    loop: Cardinal;
  end;

  BGM_T = packed record
    name: array [ 0 .. 63 ] of ansichar;
    _file: array [ 0 .. 63 ] of ansichar;
    title: array [ 0 .. 63 ] of ansichar;
    order: Cardinal;
  end;

  AMB_T = packed record
    name: array [ 0 .. 63 ] of ansichar;
    _file: array [ 0 .. 63 ] of ansichar;
  end;

  SE_T = packed record
    name: array [ 0 .. 63 ] of ansichar;
    _file: array [ 0 .. 63 ] of ansichar;
  end;

  SFX_T = packed record
    name: array [ 0 .. 63 ] of ansichar;
    _file: array [ 0 .. 63 ] of ansichar;
  end;

  // konosora.h
  // ユニット
typedef struct {
  uchar	name[32];						// 名前
  int		parent;							// 親ユニット
  int		kind;							// 分類
  int		cg;								// 画像番号
  int		voice;							// 音声番号
  int		ability[ABI_MAX];				// 能力値
  int		growth[ABI_MAX];				// 成長率
  int		resist[RES_MAX];				// 耐性
  int		skill[ENEMY_SKILL_MAX];			// 敵スキル
} UNIT_T;

// 討伐方針
typedef struct {
  int		ability[ABI_MAX];				// 能力成長率
} POLICY_T;

// 獲得経験値テーブル
typedef struct {
  int		point;							// 能力ポイント
  int		kegare[3];						// ケガレ出現数
} EXP_T;

// 習得能力テーブル
typedef struct {
  int		s_char;							// キャラクター
  int		stat;							// ステータス
  int		para;							// 到達ポイント
  int		skill[3];						// 入手能力
} GETSKILL_T;

// アクティブスキル
typedef struct {
  uchar	name[32];						// スキル名
  int		level;							// スキルLV
  int		special;						// 奥義
  int		kind;							// 種類
  int		range;							// 範囲
  int		hit_rate;						// 命中率
  int		element;						// 属性
  int		power;							// 威力
  int		turn;							// 効果ターン
  int		extra;							// 追加効果
  int		effect;							// エフェクト
  int		point;							// 必要ポイント
  uchar	help[256];						// 説明
} ASKILL_T;

// パッシブスキル
typedef struct {
  uchar	name[32];						// 名前
  int		ability[ABI_MAX];				// 付加能力値
  int		resistance[RES_MAX];			// 付加耐性値
  int		extra;							// その他
  int		power;							// 威力
  int		point;							// 必要ポイント
  uchar	help[256];						// 説明
} PSKILL_T;

// エフェクト
typedef struct {
  struct{
  uchar	file[32];					// ファイル名
  int		x, y;						// 固定座標
  int		scale;						// 拡大率
  uint	time;						// 被弾時間
} shot[ 2 ];
struct {
  uchar	file[32];					// ファイル名
  int		x, y;						// 固定座標
  int		scale;						// 拡大率
} hit[ 2 ];
int hit_count; // ヒット数
} EFFECT_T;

// 敵情報
typedef struct {
  int		unit;							// ユニット
  int		level;							// レベル
  int		x, y;							// 表示位置
} ENEMY_INFO;

// 戦闘ステージ
typedef struct {
  ENEMY_INFO	enemy[ENEMY_MAX];			// 敵情報
  uchar		bgm_file[32];				// BGM
  uchar		bg_file[2][32];				// 背景
  int			bg_line;					// 背景の地面座標
  int			script;						// 戦闘スクリプト
} STAGE_T;

// 戦闘スクリプト
typedef struct {
  uchar	file[32];						// ファイル名
} BSCRIPT_T;

// クエスト
typedef struct {
  uchar	name[32];						// クエスト名
  int		kind;							// クエストの種別
  int		h_flag;							// Hフラグ
  int		place;							// 場所
  int		time;							// 時間帯
  int		battle;							// 戦闘ステージ
  int		active_skill;					// 入手アクティブスキル
  int		passive_skill;					// 入手パッシブスキル
  int		limit;							// 期限
  uchar	script[32];						// スクリプト
  uchar	help[256];						// 説明
} QUEST_T;

// 場所
typedef struct {
  uchar	name[32];						// 場所名
  int		x, y;							// マップ座標
  uchar	bg_file[3][32];					// 背景画像
} PLACE_T;

const
  fullSizeCharacter: Array [ 0 .. 63 ] of char = (
    'を', 'ぁ', 'ぃ', 'ぅ', 'ぇ',
    'ぉ', 'ゃ', 'ゅ', 'ょ', 'っ', 'ー', 'あ', 'い', 'う', 'え',
    'お', 'か', 'き', 'く', 'け', 'こ', 'さ', 'し', 'す', 'せ',
    'そ', 'た', 'ち', 'つ', 'て', 'と', 'な', 'に', 'ぬ', 'ね',
    'の', 'は', 'ひ', 'ふ', 'へ', 'ほ', 'ま', 'み', 'む', 'め',
    'も', 'や', 'ゆ', 'よ', 'ら', 'り', 'る', 'れ', 'ろ', 'わ',
    'ん', '…', '　', '！', '？', '。', '「', '」', '、'
    );
  halfSizeCharacter: Array [ 0 .. 63 ] of char = (
    'ｦ', 'ｧ', 'ｨ', 'ｩ', 'ｪ',
    'ｫ', 'ｬ', 'ｭ', 'ｮ', 'ｯ', 'ｰ', 'ｱ', 'ｲ', 'ｳ', 'ｴ',
    'ｵ', 'ｶ', 'ｷ', 'ｸ', 'ｹ', 'ｺ', 'ｻ', 'ｼ', 'ｽ', 'ｾ',
    'ｿ', 'ﾀ', 'ﾁ', 'ﾂ', 'ﾃ', 'ﾄ', 'ﾅ', 'ﾆ', 'ﾇ', 'ﾈ',
    'ﾉ', 'ﾊ', 'ﾋ', 'ﾌ', 'ﾍ', 'ﾎ', 'ﾏ', 'ﾐ', 'ﾑ', 'ﾒ',
    'ﾓ', 'ﾔ', 'ﾕ', 'ﾖ', 'ﾗ', 'ﾘ', 'ﾙ', 'ﾚ', 'ﾛ', 'ﾜ',
    'ﾝ', '･', #$a0, '!', '?', '｡', '｢', '｣', '､'
    );

procedure ReadList(var p: Pointer; size: Cardinal; buf: TStream);
var
  head: TListHead;
begin
  buf.Read(head.offset, SizeOf(TListHead));
  p := SysGetMem(head.indexs * size);
  buf.Seek(head.offset, soFromCurrent);
  buf.Read(p^, head.indexs * size);
end;

function Searchhalf(c: char): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I  := 0 to 62 do
  begin
    if c = halfSizeCharacter[ I ] then
    begin
      Result := I;
      Break;
    end;
  end;
end;

function SearchFull(c: char): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I  := 0 to 62 do
  begin
    if c = fullSizeCharacter[ I ] then
    begin
      Result := I;
      Break;
    end;
  end;
end;

function KATAStrToFullSizeHURI(AStr: string): string;
var
  I: Integer;
begin
  Result := '';
  for I  := 1 to Length(AStr) do
  begin
    StringReplace(AStr, '', '\n', [ rfReplaceAll ]);
    if Searchhalf(AStr[ I ]) <> -1 then
      Result := Result + fullSizeCharacter[ Searchhalf(AStr[ I ]) ]
    else
      Result := Result + AStr[ I ];
  end;
end;

var
  Bin, Bin2 : TMemoryStream;
  text      : TStringList;
  head      : THead;
  Table     : array of Cardinal;
  ParamTable: Cardinal;
  StrTable  : Cardinal;
  I         : Integer;
  Str       : AnsiString;
  StrBuf    : TMemoryStream;
  Zero      : Byte;

begin
  try
    if ParamCount <> 3 then
      raise Exception.Create('Error');
    SetMultiByteConversionCodePage(StrToInt(ParamStr(3)));
    Bin  := TMemoryStream.Create;
    text := TStringList.Create;
    if StrToInt(ParamStr(2)) = 1 then
    begin
      Bin.LoadFromFile(ParamStr(1));
      Bin.Seek(0, soFromBeginning);
      Bin.Read(head.magic[ 0 ], SizeOf(THead));
      if not SameText('ESCR1_00', Trim(head.magic)) then
        raise Exception.Create('magic');
      SetLength(Table, head.constrs + 1);
      Bin.Read(Table[ 0 ], head.constrs * 4);
      Bin.Read(ParamTable, 4);
      Bin.Seek(ParamTable, soFromCurrent);
      Bin.Read(StrTable, 4);
      Table[ head.constrs ] := StrTable;
      for I                 := Low(Table) to High(Table) - 1 do
      begin
        SetLength(Str, Table[ I + 1 ] - Table[ I ]);
        Bin.Read(Pbyte(Str)^, Table[ I + 1 ] - Table[ I ]);
        text.Add(KATAStrToFullSizeHURI(Trim(Str)));
      end;
      text.SaveToFile(ChangeFileExt(ParamStr(1), '.txt'), TEncoding.UTF8);
    end else if StrToInt(ParamStr(2)) = 2 then
    begin
      StrBuf := TMemoryStream.Create;
      if ExtractFileExt(ParamStr(1)) <> '.txt' then
        raise Exception.Create('Error');
      text.LoadFromFile(ParamStr(1), TEncoding.UTF8);
      if not FileExists(ChangeFileExt(ParamStr(1), '.bin')) then
      begin
        raise Exception.Create('BIN');
      end;
      SetLength(Table, text.Count + 1);
      Table[ 0 ] := 0;
      Zero       := 0;
      for I      := 0 to text.Count - 1 do
      begin
        Str            := text[ I ];
        Table[ I + 1 ] := Table[ I ] + Length(Str) + 1;
        StrBuf.Write(Pbyte(Str)^, Length(Str));
        StrBuf.Write(Zero, 1);
      end;
      Str := 'ESCR1_00';
      Bin.Write(Pbyte(Str)^, 8);
      StrTable := text.Count;
      Bin.Write(StrTable, 4);
      Bin.Write(Table[ 0 ], text.Count * 4);
      Bin2 := TMemoryStream.Create;
      Bin2.LoadFromFile(ChangeFileExt(ParamStr(1), '.bin'));
      Bin2.Seek(0, soFromBeginning);
      Bin2.Read(head.magic[ 0 ], SizeOf(THead));
      Bin2.Seek(head.constrs * 4, soFromCurrent);
      Bin2.Read(ParamTable, 4);
      Bin.Write(ParamTable, 4);
      Bin.CopyFrom(Bin2, ParamTable);
      Bin2.Free;
      Bin.Write(Table[ text.Count ], 4);
      StrBuf.Seek(0, soFromBeginning);
      Bin.CopyFrom(StrBuf, StrBuf.size);
      Bin.SaveToFile(ChangeFileExt(ParamStr(1), '.bin'));
      StrBuf.Free;
    end else if StrToInt(ParamStr(2)) = 3 then
    begin

    end else if StrToInt(ParamStr(2)) = 4 then
    begin

    end else if StrToInt(ParamStr(2)) = 5 then
    begin

    end;
    Bin.Free;
    text.Free;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
