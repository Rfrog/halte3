unit camellia;

//*****************************************
//Camellia for delphi2010
//All Right reserved by NTT & HatsuneTakumi
//Copyright (c) 2010
//*****************************************

{Redistribution and use in source ancamelliad binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer as
   the first lines of this file unmodified.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.}

interface

uses
  Windows,SysUtils;
  var KeyTable:array[0..67] of LongWord;
  Encoded_Type:Integer;
{  procedure Camellia_Ekeygen(const keyBitLength:LongWord;rawKey:array of Byte;var keyTable:array of LongWord);
  procedure Camellia_DecryptBlock
(
    keyBitLength:Integer;
    ciphertext:PByte;
    keyTable:array of LongWord;
    plaintext:PByte
);
 procedure Camellia_EncryptBlock
(
    keyBitLength:Integer;
    plaintext:PByte;
    keyTable:array of LongWord;
    ciphertext:PByte
); }
function LeftRotate(x:LongWord;s:Integer):LongWord;
function RightRotate(x:LongWord;s:Integer):LongWord;

implementation


const ZERO_MEMORY = 0;
const USE_C_FEISTEL_CODE = 1;
const LITTLE_ENDIAN = 2; //we need. Because all pro is based on intel;
const BIG_ENDIAN = 3;
const SBOX1_1110:array[0..255] of LongWord =
(
    $70707000, $82828200, $2c2c2c00, $ececec00, $b3b3b300, $27272700,
    $c0c0c000, $e5e5e500, $e4e4e400, $85858500, $57575700, $35353500,
    $eaeaea00, $0c0c0c00, $aeaeae00, $41414100, $23232300, $efefef00,
    $6b6b6b00, $93939300, $45454500, $19191900, $a5a5a500, $21212100,
    $ededed00, $0e0e0e00, $4f4f4f00, $4e4e4e00, $1d1d1d00, $65656500,
    $92929200, $bdbdbd00, $86868600, $b8b8b800, $afafaf00, $8f8f8f00,
    $7c7c7c00, $ebebeb00, $1f1f1f00, $cecece00, $3e3e3e00, $30303000,
    $dcdcdc00, $5f5f5f00, $5e5e5e00, $c5c5c500, $0b0b0b00, $1a1a1a00,
    $a6a6a600, $e1e1e100, $39393900, $cacaca00, $d5d5d500, $47474700,
    $5d5d5d00, $3d3d3d00, $d9d9d900, $01010100, $5a5a5a00, $d6d6d600,
    $51515100, $56565600, $6c6c6c00, $4d4d4d00, $8b8b8b00, $0d0d0d00,
    $9a9a9a00, $66666600, $fbfbfb00, $cccccc00, $b0b0b000, $2d2d2d00,
    $74747400, $12121200, $2b2b2b00, $20202000, $f0f0f000, $b1b1b100,
    $84848400, $99999900, $dfdfdf00, $4c4c4c00, $cbcbcb00, $c2c2c200,
    $34343400, $7e7e7e00, $76767600, $05050500, $6d6d6d00, $b7b7b700,
    $a9a9a900, $31313100, $d1d1d100, $17171700, $04040400, $d7d7d700,
    $14141400, $58585800, $3a3a3a00, $61616100, $dedede00, $1b1b1b00,
    $11111100, $1c1c1c00, $32323200, $0f0f0f00, $9c9c9c00, $16161600,
    $53535300, $18181800, $f2f2f200, $22222200, $fefefe00, $44444400,
    $cfcfcf00, $b2b2b200, $c3c3c300, $b5b5b500, $7a7a7a00, $91919100,
    $24242400, $08080800, $e8e8e800, $a8a8a800, $60606000, $fcfcfc00,
    $69696900, $50505000, $aaaaaa00, $d0d0d000, $a0a0a000, $7d7d7d00,
    $a1a1a100, $89898900, $62626200, $97979700, $54545400, $5b5b5b00,
    $1e1e1e00, $95959500, $e0e0e000, $ffffff00, $64646400, $d2d2d200,
    $10101000, $c4c4c400, $00000000, $48484800, $a3a3a300, $f7f7f700,
    $75757500, $dbdbdb00, $8a8a8a00, $03030300, $e6e6e600, $dadada00,
    $09090900, $3f3f3f00, $dddddd00, $94949400, $87878700, $5c5c5c00,
    $83838300, $02020200, $cdcdcd00, $4a4a4a00, $90909000, $33333300,
    $73737300, $67676700, $f6f6f600, $f3f3f300, $9d9d9d00, $7f7f7f00,
    $bfbfbf00, $e2e2e200, $52525200, $9b9b9b00, $d8d8d800, $26262600,
    $c8c8c800, $37373700, $c6c6c600, $3b3b3b00, $81818100, $96969600,
    $6f6f6f00, $4b4b4b00, $13131300, $bebebe00, $63636300, $2e2e2e00,
    $e9e9e900, $79797900, $a7a7a700, $8c8c8c00, $9f9f9f00, $6e6e6e00,
    $bcbcbc00, $8e8e8e00, $29292900, $f5f5f500, $f9f9f900, $b6b6b600,
    $2f2f2f00, $fdfdfd00, $b4b4b400, $59595900, $78787800, $98989800,
    $06060600, $6a6a6a00, $e7e7e700, $46464600, $71717100, $bababa00,
    $d4d4d400, $25252500, $ababab00, $42424200, $88888800, $a2a2a200,
    $8d8d8d00, $fafafa00, $72727200, $07070700, $b9b9b900, $55555500,
    $f8f8f800, $eeeeee00, $acacac00, $0a0a0a00, $36363600, $49494900,
    $2a2a2a00, $68686800, $3c3c3c00, $38383800, $f1f1f100, $a4a4a400,
    $40404000, $28282800, $d3d3d300, $7b7b7b00, $bbbbbb00, $c9c9c900,
    $43434300, $c1c1c100, $15151500, $e3e3e300, $adadad00, $f4f4f400,
    $77777700, $c7c7c700, $80808000, $9e9e9e00
);
const SBOX4_4404:array[0..255] of LongWord =
(
    $70700070, $2c2c002c, $b3b300b3, $c0c000c0, $e4e400e4, $57570057,
    $eaea00ea, $aeae00ae, $23230023, $6b6b006b, $45450045, $a5a500a5,
    $eded00ed, $4f4f004f, $1d1d001d, $92920092, $86860086, $afaf00af,
    $7c7c007c, $1f1f001f, $3e3e003e, $dcdc00dc, $5e5e005e, $0b0b000b,
    $a6a600a6, $39390039, $d5d500d5, $5d5d005d, $d9d900d9, $5a5a005a,
    $51510051, $6c6c006c, $8b8b008b, $9a9a009a, $fbfb00fb, $b0b000b0,
    $74740074, $2b2b002b, $f0f000f0, $84840084, $dfdf00df, $cbcb00cb,
    $34340034, $76760076, $6d6d006d, $a9a900a9, $d1d100d1, $04040004,
    $14140014, $3a3a003a, $dede00de, $11110011, $32320032, $9c9c009c,
    $53530053, $f2f200f2, $fefe00fe, $cfcf00cf, $c3c300c3, $7a7a007a,
    $24240024, $e8e800e8, $60600060, $69690069, $aaaa00aa, $a0a000a0,
    $a1a100a1, $62620062, $54540054, $1e1e001e, $e0e000e0, $64640064,
    $10100010, $00000000, $a3a300a3, $75750075, $8a8a008a, $e6e600e6,
    $09090009, $dddd00dd, $87870087, $83830083, $cdcd00cd, $90900090,
    $73730073, $f6f600f6, $9d9d009d, $bfbf00bf, $52520052, $d8d800d8,
    $c8c800c8, $c6c600c6, $81810081, $6f6f006f, $13130013, $63630063,
    $e9e900e9, $a7a700a7, $9f9f009f, $bcbc00bc, $29290029, $f9f900f9,
    $2f2f002f, $b4b400b4, $78780078, $06060006, $e7e700e7, $71710071,
    $d4d400d4, $abab00ab, $88880088, $8d8d008d, $72720072, $b9b900b9,
    $f8f800f8, $acac00ac, $36360036, $2a2a002a, $3c3c003c, $f1f100f1,
    $40400040, $d3d300d3, $bbbb00bb, $43430043, $15150015, $adad00ad,
    $77770077, $80800080, $82820082, $ecec00ec, $27270027, $e5e500e5,
    $85850085, $35350035, $0c0c000c, $41410041, $efef00ef, $93930093,
    $19190019, $21210021, $0e0e000e, $4e4e004e, $65650065, $bdbd00bd,
    $b8b800b8, $8f8f008f, $ebeb00eb, $cece00ce, $30300030, $5f5f005f,
    $c5c500c5, $1a1a001a, $e1e100e1, $caca00ca, $47470047, $3d3d003d,
    $01010001, $d6d600d6, $56560056, $4d4d004d, $0d0d000d, $66660066,
    $cccc00cc, $2d2d002d, $12120012, $20200020, $b1b100b1, $99990099,
    $4c4c004c, $c2c200c2, $7e7e007e, $05050005, $b7b700b7, $31310031,
    $17170017, $d7d700d7, $58580058, $61610061, $1b1b001b, $1c1c001c,
    $0f0f000f, $16160016, $18180018, $22220022, $44440044, $b2b200b2,
    $b5b500b5, $91910091, $08080008, $a8a800a8, $fcfc00fc, $50500050,
    $d0d000d0, $7d7d007d, $89890089, $97970097, $5b5b005b, $95950095,
    $ffff00ff, $d2d200d2, $c4c400c4, $48480048, $f7f700f7, $dbdb00db,
    $03030003, $dada00da, $3f3f003f, $94940094, $5c5c005c, $02020002,
    $4a4a004a, $33330033, $67670067, $f3f300f3, $7f7f007f, $e2e200e2,
    $9b9b009b, $26260026, $37370037, $3b3b003b, $96960096, $4b4b004b,
    $bebe00be, $2e2e002e, $79790079, $8c8c008c, $6e6e006e, $8e8e008e,
    $f5f500f5, $b6b600b6, $fdfd00fd, $59590059, $98980098, $6a6a006a,
    $46460046, $baba00ba, $25250025, $42420042, $a2a200a2, $fafa00fa,
    $07070007, $55550055, $eeee00ee, $0a0a000a, $49490049, $68680068,
    $38380038, $a4a400a4, $28280028, $7b7b007b, $c9c900c9, $c1c100c1,
    $e3e300e3, $f4f400f4, $c7c700c7, $9e9e009e
);
const SBOX2_0222:array[0..255] of LongWord =
(
    $00e0e0e0, $00050505, $00585858, $00d9d9d9, $00676767, $004e4e4e,
    $00818181, $00cbcbcb, $00c9c9c9, $000b0b0b, $00aeaeae, $006a6a6a,
    $00d5d5d5, $00181818, $005d5d5d, $00828282, $00464646, $00dfdfdf,
    $00d6d6d6, $00272727, $008a8a8a, $00323232, $004b4b4b, $00424242,
    $00dbdbdb, $001c1c1c, $009e9e9e, $009c9c9c, $003a3a3a, $00cacaca,
    $00252525, $007b7b7b, $000d0d0d, $00717171, $005f5f5f, $001f1f1f,
    $00f8f8f8, $00d7d7d7, $003e3e3e, $009d9d9d, $007c7c7c, $00606060,
    $00b9b9b9, $00bebebe, $00bcbcbc, $008b8b8b, $00161616, $00343434,
    $004d4d4d, $00c3c3c3, $00727272, $00959595, $00ababab, $008e8e8e,
    $00bababa, $007a7a7a, $00b3b3b3, $00020202, $00b4b4b4, $00adadad,
    $00a2a2a2, $00acacac, $00d8d8d8, $009a9a9a, $00171717, $001a1a1a,
    $00353535, $00cccccc, $00f7f7f7, $00999999, $00616161, $005a5a5a,
    $00e8e8e8, $00242424, $00565656, $00404040, $00e1e1e1, $00636363,
    $00090909, $00333333, $00bfbfbf, $00989898, $00979797, $00858585,
    $00686868, $00fcfcfc, $00ececec, $000a0a0a, $00dadada, $006f6f6f,
    $00535353, $00626262, $00a3a3a3, $002e2e2e, $00080808, $00afafaf,
    $00282828, $00b0b0b0, $00747474, $00c2c2c2, $00bdbdbd, $00363636,
    $00222222, $00383838, $00646464, $001e1e1e, $00393939, $002c2c2c,
    $00a6a6a6, $00303030, $00e5e5e5, $00444444, $00fdfdfd, $00888888,
    $009f9f9f, $00656565, $00878787, $006b6b6b, $00f4f4f4, $00232323,
    $00484848, $00101010, $00d1d1d1, $00515151, $00c0c0c0, $00f9f9f9,
    $00d2d2d2, $00a0a0a0, $00555555, $00a1a1a1, $00414141, $00fafafa,
    $00434343, $00131313, $00c4c4c4, $002f2f2f, $00a8a8a8, $00b6b6b6,
    $003c3c3c, $002b2b2b, $00c1c1c1, $00ffffff, $00c8c8c8, $00a5a5a5,
    $00202020, $00898989, $00000000, $00909090, $00474747, $00efefef,
    $00eaeaea, $00b7b7b7, $00151515, $00060606, $00cdcdcd, $00b5b5b5,
    $00121212, $007e7e7e, $00bbbbbb, $00292929, $000f0f0f, $00b8b8b8,
    $00070707, $00040404, $009b9b9b, $00949494, $00212121, $00666666,
    $00e6e6e6, $00cecece, $00ededed, $00e7e7e7, $003b3b3b, $00fefefe,
    $007f7f7f, $00c5c5c5, $00a4a4a4, $00373737, $00b1b1b1, $004c4c4c,
    $00919191, $006e6e6e, $008d8d8d, $00767676, $00030303, $002d2d2d,
    $00dedede, $00969696, $00262626, $007d7d7d, $00c6c6c6, $005c5c5c,
    $00d3d3d3, $00f2f2f2, $004f4f4f, $00191919, $003f3f3f, $00dcdcdc,
    $00797979, $001d1d1d, $00525252, $00ebebeb, $00f3f3f3, $006d6d6d,
    $005e5e5e, $00fbfbfb, $00696969, $00b2b2b2, $00f0f0f0, $00313131,
    $000c0c0c, $00d4d4d4, $00cfcfcf, $008c8c8c, $00e2e2e2, $00757575,
    $00a9a9a9, $004a4a4a, $00575757, $00848484, $00111111, $00454545,
    $001b1b1b, $00f5f5f5, $00e4e4e4, $000e0e0e, $00737373, $00aaaaaa,
    $00f1f1f1, $00dddddd, $00595959, $00141414, $006c6c6c, $00929292,
    $00545454, $00d0d0d0, $00787878, $00707070, $00e3e3e3, $00494949,
    $00808080, $00505050, $00a7a7a7, $00f6f6f6, $00777777, $00939393,
    $00868686, $00838383, $002a2a2a, $00c7c7c7, $005b5b5b, $00e9e9e9,
    $00eeeeee, $008f8f8f, $00010101, $003d3d3d
);
const SBOX3_3033:array[0..255] of LongWord =
(
    $38003838, $41004141, $16001616, $76007676, $d900d9d9, $93009393,
    $60006060, $f200f2f2, $72007272, $c200c2c2, $ab00abab, $9a009a9a,
    $75007575, $06000606, $57005757, $a000a0a0, $91009191, $f700f7f7,
    $b500b5b5, $c900c9c9, $a200a2a2, $8c008c8c, $d200d2d2, $90009090,
    $f600f6f6, $07000707, $a700a7a7, $27002727, $8e008e8e, $b200b2b2,
    $49004949, $de00dede, $43004343, $5c005c5c, $d700d7d7, $c700c7c7,
    $3e003e3e, $f500f5f5, $8f008f8f, $67006767, $1f001f1f, $18001818,
    $6e006e6e, $af00afaf, $2f002f2f, $e200e2e2, $85008585, $0d000d0d,
    $53005353, $f000f0f0, $9c009c9c, $65006565, $ea00eaea, $a300a3a3,
    $ae00aeae, $9e009e9e, $ec00ecec, $80008080, $2d002d2d, $6b006b6b,
    $a800a8a8, $2b002b2b, $36003636, $a600a6a6, $c500c5c5, $86008686,
    $4d004d4d, $33003333, $fd00fdfd, $66006666, $58005858, $96009696,
    $3a003a3a, $09000909, $95009595, $10001010, $78007878, $d800d8d8,
    $42004242, $cc00cccc, $ef00efef, $26002626, $e500e5e5, $61006161,
    $1a001a1a, $3f003f3f, $3b003b3b, $82008282, $b600b6b6, $db00dbdb,
    $d400d4d4, $98009898, $e800e8e8, $8b008b8b, $02000202, $eb00ebeb,
    $0a000a0a, $2c002c2c, $1d001d1d, $b000b0b0, $6f006f6f, $8d008d8d,
    $88008888, $0e000e0e, $19001919, $87008787, $4e004e4e, $0b000b0b,
    $a900a9a9, $0c000c0c, $79007979, $11001111, $7f007f7f, $22002222,
    $e700e7e7, $59005959, $e100e1e1, $da00dada, $3d003d3d, $c800c8c8,
    $12001212, $04000404, $74007474, $54005454, $30003030, $7e007e7e,
    $b400b4b4, $28002828, $55005555, $68006868, $50005050, $be00bebe,
    $d000d0d0, $c400c4c4, $31003131, $cb00cbcb, $2a002a2a, $ad00adad,
    $0f000f0f, $ca00caca, $70007070, $ff00ffff, $32003232, $69006969,
    $08000808, $62006262, $00000000, $24002424, $d100d1d1, $fb00fbfb,
    $ba00baba, $ed00eded, $45004545, $81008181, $73007373, $6d006d6d,
    $84008484, $9f009f9f, $ee00eeee, $4a004a4a, $c300c3c3, $2e002e2e,
    $c100c1c1, $01000101, $e600e6e6, $25002525, $48004848, $99009999,
    $b900b9b9, $b300b3b3, $7b007b7b, $f900f9f9, $ce00cece, $bf00bfbf,
    $df00dfdf, $71007171, $29002929, $cd00cdcd, $6c006c6c, $13001313,
    $64006464, $9b009b9b, $63006363, $9d009d9d, $c000c0c0, $4b004b4b,
    $b700b7b7, $a500a5a5, $89008989, $5f005f5f, $b100b1b1, $17001717,
    $f400f4f4, $bc00bcbc, $d300d3d3, $46004646, $cf00cfcf, $37003737,
    $5e005e5e, $47004747, $94009494, $fa00fafa, $fc00fcfc, $5b005b5b,
    $97009797, $fe00fefe, $5a005a5a, $ac00acac, $3c003c3c, $4c004c4c,
    $03000303, $35003535, $f300f3f3, $23002323, $b800b8b8, $5d005d5d,
    $6a006a6a, $92009292, $d500d5d5, $21002121, $44004444, $51005151,
    $c600c6c6, $7d007d7d, $39003939, $83008383, $dc00dcdc, $aa00aaaa,
    $7c007c7c, $77007777, $56005656, $05000505, $1b001b1b, $a400a4a4,
    $15001515, $34003434, $1e001e1e, $1c001c1c, $f800f8f8, $52005252,
    $20002020, $14001414, $e900e9e9, $bd00bdbd, $dd00dddd, $e400e4e4,
    $a100a1a1, $e000e0e0, $8a008a8a, $f100f1f1, $d600d6d6, $7a007a7a,
    $bb00bbbb, $e300e3e3, $40004040, $4f004f4f
);

//Cover Endianess

function LeftRotate(x:LongWord;s:Integer):LongWord;
begin
  result:=( ((x) shl (s)) + ((x) shr (32 - s)) );
end;

function RightRotate(x:LongWord;s:Integer):LongWord;
begin
  result:=( ((x) shr (s)) + ((x) shl (32 - s)) );
end;

procedure CopyConvertEndianness16(var src1;var dst1);
var
src,dst:Pbyte;
begin
    src:=@src1;
    dst:=@dst1;
    PDword(@dst[0])^ := (LeftRotate(PDword(@src[0])^, 8) and $00ff00ff) or
        (RightRotate(PDword(@src[0])^, 8) and $ff00ff00);
    PDword(@dst[4])^ := (LeftRotate(PDword(@src[4])^, 8) and $00ff00ff) or
        (RightRotate(PDword(@src[4])^, 8) and $ff00ff00);
    PDword(@dst[8])^ := (LeftRotate(PDword(@src[8])^, 8) and $00ff00ff) or
        (RightRotate(PDword(@src[8])^, 8) and $ff00ff00);
    PDword(@dst[12])^ := (LeftRotate(PDword(@src[12])^, 8) and $00ff00ff) or
        (RightRotate(PDword(@src[12])^, 8) and $ff00ff00);
end;

procedure XorBlock(var x1,y1,z1);
var
x,y,z:Pbyte;
begin
{asm
  push eax
  push edx
  push esi
  push edi
  mov eax,x
  mov edx,y
  mov esi,z
  mov edi,DWORD PTR [x]
  xor edi,[edx]
  mov DWORD PTR [esi],EDI
  mov edi,DWORD PTR [x+4]
  xor edi,[edx+4]
  mov DWORD PTR [esi+4],EDI
  mov edi,DWORD PTR [x+8]
  xor edi,[edx+8]
  mov DWORD PTR [esi+8],EDI
  mov edi,DWORD PTR [x+12]
  xor edi,[edx+12]
  mov DWORD PTR [esi+12],EDI
  pop edi
  pop esi
  pop edx
  pop eax
end;}
    x:=@x1;
    y:=@y1;
    z:=@z1;
    PDWORD(@z[0])^ := PDWORD(@x[0])^ xor PDWORD(@y[0])^;
    PDWORD(@z[4])^ := PDWORD(@x[4])^ xor PDWORD(@y[4])^;
    PDWORD(@z[8])^ := PDWORD(@x[8])^ xor PDWORD(@y[8])^;
    PDWORD(@z[12])^ := PDWORD(@x[12])^ xor PDWORD(@y[12])^;
end;

procedure SwapHalf(var x1);
var _t:LongWord;
x:Pbyte;
begin
    x:=@x1;
    _t   := Pdword(@x[0])^;
    Pdword(@x[0])^ := Pdword(@x[8])^;
    Pdword(@x[8])^ := _t;
    _t   := Pdword(@x[4])^;
    Pdword(@x[4])^ := Pdword(@x[12])^;
    Pdword(@x[12])^ := _t;
end;


procedure RotBlock(var x1;n:LongWord;var y1);
var
r,idx,idx1,idx2:LongWord;
x,y:Pbyte;
begin
    x:=@x1;
    y:=@y1;
    r := (n and 31);   // Must not be 0
    idx := (n shr 5);
    idx1 := (idx + 1) and 3;
    idx2 := (idx1 + 1) and 3;
    PDword(@y[0])^ := (PDword(@x[idx*4])^ shl r) or (PDword(@x[idx1*4])^ shr (32 - r));
    PDword(@y[4])^ := (PDword(@x[idx1*4])^ shl r) or (PDword(@x[idx2*4])^ shr (32 - r));
end;

procedure Camellia_Feistel(var x1;var k1;key_offset:INTEGER);
var
d,u,s1,s2:LongWord;
x,k:PByte;
begin
    x:=@x1;
    k:=@k1;
    s1 := PDword(@x[0])^ xor PDword(@k[0])^;
    U  := SBOX4_4404[Byte(s1)];
    U := U xor SBOX3_3033[Byte(s1 shr 8)];
    U := U xor SBOX2_0222[Byte(s1 shr 16)];
    U := U xor SBOX1_1110[Byte(s1 shr 24)];
    s2 := PDword(@x[4])^ xor PDword(@k[4])^;
    D  := SBOX1_1110[Byte(s2)];
    D := D xor SBOX4_4404[Byte(s2 shr 8)];
    D := D xor SBOX3_3033[Byte(s2 shr 16)];
    D := D xor SBOX2_0222[Byte(s2 shr 24)];
    PDword(@x[8])^ := PDword(@x[8])^ xor (D xor U);
    PDword(@x[12])^ := PDword(@x[12])^ xor (D xor U xor RightRotate(U, 8));
    s1 := PDword(@x[8])^ xor PDword(@k[key_offset*4])^;
    U := U xor SBOX4_4404[Byte(s1)];
    U := U xor SBOX3_3033[Byte(s1 shr 8)];
    U := U xor SBOX2_0222[Byte(s1 shr 16)];
    U := U xor SBOX1_1110[Byte(s1 shr 24)];
    s2 := PDword(@x[12])^ xor PDword(@k[key_offset*4+4])^;
    D := SBOX1_1110[Byte(s2)];
    D := D xor SBOX4_4404[Byte(s2 shr 8)];
    D := D xor SBOX3_3033[Byte(s2 shr 16)];
    D := D xor SBOX2_0222[Byte(s2 shr 24)];
    PDword(@x[0])^ := PDword(@x[0])^ xor (D xor U);
    PDword(@x[4])^ := PDword(@x[4])^ xor (D xor U xor RightRotate(U, 8));
end;

//Key generation constants

const SIGMA:array[0..11] of LongWord = (
    $a09e667f, $3bcc908b,
    $b67ae858, $4caa73b2,
    $c6ef372f, $e94f82be,
    $54ff53a5, $f1d36f1c,
    $10e527fa, $de682d1d,
    $b05688c2, $b3e6c1fd
);

const KSFT1:array[0..25] of LongWord = (
    0, 64, 0, 64, 15, 79, 15, 79, 30, 94, 45, 109, 45, 124, 60, 124, 77, 13,
    94, 30, 94, 30, 111, 47, 111, 47
);

const KIDX1:array[0..25] of LongWord = (
    0, 0, 8, 8, 0, 0, 8, 8, 8, 8, 0, 0, 8, 0, 8, 8, 0, 0, 0, 0, 8, 8, 0, 0, 8, 8
);

const KSFT2:array[0..33] of LongWord = (
    0, 64, 0, 64, 15, 79, 15, 79, 30, 94, 30, 94, 45, 109, 45, 109, 60, 124,
    60, 124, 60, 124, 77, 13, 77, 13, 94, 30, 94, 30, 111, 47, 111, 47
);

const KIDX2:array[0..33] of LongWord = (
    0, 0, 12, 12, 4, 4, 8, 8, 4, 4, 12, 12, 0, 0, 8, 8, 0, 0, 4, 4, 12, 12,
    0, 0, 8, 8, 4, 4, 8, 8, 0, 0, 12, 12
);


procedure Camellia_Ekeygen(const keyBitLength:LongWord;rawKey:array of Byte;var keyTable:array of LongWord);
var
 t:array[0..15] of LongWord;
 i:LongWord;
 tmp:LongWord;
 SIGMA1:array[0..11] of LongWord;
begin
    Move(SIGMA[0],SIGMA1[0],12*4);
    FillMemory(@t[0],4*16,0);
    if (keyBitLength = 128) then
    begin
        CopyConvertEndianness16(rawKey[0], t[0]);
        for i := 4 to 7 do t[i] := 0;
    end else if (keyBitLength = 192) then
    begin
        CopyConvertEndianness16(rawKey[0], t[0]);
        for i :=  4 to 5 do
        begin
            tmp := (rawKey[4*i] shl 24) or (rawKey[4*i+1] shl 16) or
                (rawKey[4*i+2] shl 8) or (rawKey[4*i+3] shl 0);
            t[i] := tmp;
            t[i+2] := not tmp;
        end;
    end else if (keyBitLength = 256) then
    begin
        CopyConvertEndianness16(rawKey[0], t[0]);
        CopyConvertEndianness16(rawKey[16], t[4]);
    end;
    XorBlock(t[0], t[4], t[8]);
    Camellia_Feistel(t[8], SIGMA1[0], 2);
    XorBlock(t[8], t[0], t[8]);
    Camellia_Feistel(t[8], SIGMA1[4],2);
    if (keyBitLength = 128) then
    begin
        move(t[0], keyTable[0], 16);
        move(t[8], keyTable[4], 16);
        i := 4;
        while i<26 do
        begin
            RotBlock(t[KIDX1[i + 0]], KSFT1[i + 0], keyTable[i*2]);
            RotBlock(t[KIDX1[i + 1]], KSFT1[i + 1], keyTable[i*2+2]);
            inc(i,2);
        end;
    end else begin
        XorBlock(t[8], t[4], t[12]);
        Camellia_Feistel(t[12], SIGMA1[8],2);
        move(t[0], keyTable[0], 16);
        move(t[12], keyTable[4], 16);
        i := 4;
        while i<34 do
        begin
            RotBlock(t[KIDX2[i + 0]], KSFT2[i + 0], keyTable[i*2]);
            RotBlock(t[KIDX2[i + 1]], KSFT2[i + 1], keyTable[i*2+2]);
            inc(i,2);
        end;
    end;
end;

procedure Camellia_EncryptBlock
(
    keyBitLength:Integer;
    plaintext:PByte;
    keyTable:array of LongWord;
    ciphertext:PByte
);
var
 j,grandRounds,totalGrandRounds,flayerLimit:LongWord;
 ct:PByte;
 k:PLongWord;
 begin
    if keyBitLength = 128 then totalGrandRounds := 3 else totalGrandRounds :=4;
    ct := ciphertext;
    flayerLimit := totalGrandRounds - 1;
    k := @keyTable[4];
    CopyConvertEndianness16(plaintext[0], Pdword(@ct[0])^);
    XorBlock(Pdword(@ct[0])^, keyTable[0], Pdword(@ct[0])^);
    for grandRounds := 0 to totalGrandRounds-1 do
     begin
            j := 0;
            while j<6 do
            begin
                Camellia_Feistel(Pdword(@ct[0])^,k^,2);
                Inc(j,2);
                Inc(k,4);
            end;
        if (grandRounds < flayerLimit) then
         begin
            Pdword(@ct[4])^ := Pdword(@ct[4])^ xor (LeftRotate(Pdword(@ct[0])^ and k^, 1));
            Inc(k,1);
            Pdword(@ct[0])^ := Pdword(@ct[0])^ xor (Pdword(@ct[4])^ or k^);
            Inc(k,2);
            Pdword(@ct[8])^ := Pdword(@ct[8])^ xor (Pdword(@ct[12])^ or k^);
            Dec(k,1);
            Pdword(@ct[12])^ := Pdword(@ct[12])^ xor (LeftRotate(Pdword(@ct[8])^ and k^, 1));
            Inc(k,2);
        end;
    end;
    SwapHalf(Pdword(@ct[0])^);
    XorBlock(Pdword(@ct[0])^, k^, Pdword(@ct[0])^);
    CopyConvertEndianness16(Pdword(@ct[0])^, Pdword(@ct[0])^);
 end;

procedure Camellia_DecryptBlock
(
    keyBitLength:Integer;
    ciphertext:PByte;
    keyTable:array of LongWord;
    plaintext:PByte
);
var
 j,grandRounds,totalGrandRounds,flayerLimit,keyTableOffset:LongWord;
 pt:PByte;
 k:PByte;
 begin
    pt := plaintext;
    if (keyBitLength = 128) then
    begin
        totalGrandRounds := 3;
        keyTableOffset := 48;
    end else begin
        totalGrandRounds := 4;
        keyTableOffset := 64;
    end;
    k := @keyTable[keyTableOffset];
    flayerLimit := totalGrandRounds - 1;
    CopyConvertEndianness16(ciphertext[0], Pdword(@pt[0])^);
    XorBlock(Pdword(@pt[0])^, PDword(@k[0])^, Pdword(@pt[0])^);
    Dec(k,8);

    for grandRounds := 0 to totalGrandRounds -1 do
     begin
        j := 0;
        while j<6 do
        begin
            Camellia_Feistel(Pdword(@pt[0])^,PDword(@k[0])^,-2);
            Inc(j,2);
            Dec(k,16);
        end;
        if (grandRounds < flayerLimit)then
         begin
            Pdword(@pt[4])^ := Pdword(@pt[4])^ xor (LeftRotate(Pdword(@pt[0])^ and PDword(@k[0])^, 1));
            Pdword(@pt[0])^ := Pdword(@pt[0])^ xor (Pdword(@pt[4])^ or PDword(@k[4])^);
            Pdword(@pt[8])^ := Pdword(@pt[8])^ xor (Pdword(@pt[12])^ or PDword(@k[-4])^);
            Pdword(@pt[12])^ := Pdword(@pt[12])^ xor (LeftRotate(Pdword(@pt[8])^ and PDword(@k[-8])^, 1));
            Dec(k,16);
        end;
    end;
    Dec(k,8);
    SwapHalf(Pdword(@pt[0])^);
    XorBlock(Pdword(@pt[0])^, PDword(@k[0])^, Pdword(@pt[0])^);
    CopyConvertEndianness16(Pdword(@pt[0])^, Pdword(@pt[0])^);
end;

end.
