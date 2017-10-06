program Project1;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes, System.NetEncoding, IOUtils, DCPrijndael, DCPcrypt2, Zlib in 'Zlib.pas';

{$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}

var
  WorkbinExist: Byte;
  WorkbinKey: array [0..15] of Byte;
  Workbin: array [0..511] of Byte;

function Swap64(Value: Int64): Int64; register; overload;
asm
  mov edx, [esp+8]
  bswap edx
  mov eax, [esp+12]
  bswap eax
end;

function Swap32(Value: LongWord): LongWord;
begin
  Result := Swap(Value shr 16) or (Swap(Value) shl 16);
end;

function HexToByte(HexStr: string): Byte;
var
  w: Word;
  i: Integer;
begin
  Result:=0;
  for i:=1 to Length(HexStr) do begin
    w:=Word(HexStr[i]);
    case w of
      48..57: Result:=(Result shl 4)+(w-48);
      65..70,97..102: Result:=(Result shl 4)+(w-55)
      else begin Result:=0; break end
    end;
  end;
end;

function ProcessSFO(MemoryStream1: TMemoryStream; var Title: UTF8String): Word;
var
  NameStart, ValueStart, NumOfEntries, LongWord1, InitPos: LongWord;
  Int641: Int64;
  Word1, ValueLength: Word;
begin
  SetLength(Title, 6);
  InitPos := MemoryStream1.Position - 8;
  MemoryStream1.ReadBuffer(NameStart, 4);
  NameStart := NameStart + InitPos;
  MemoryStream1.ReadBuffer(ValueStart, 4);
  ValueStart := ValueStart + InitPos;
  MemoryStream1.ReadBuffer(NumOfEntries, 4);

  for LongWord1:=0 to NumOfEntries-1 do begin
    MemoryStream1.Position := ($10 * LongWord1) + $14 + InitPos;
    MemoryStream1.ReadBuffer(Word1, 2);
    MemoryStream1.Position := Word1 + NameStart;
    MemoryStream1.ReadBuffer(Int641, 8);
    if Int641=$59524F4745544143 then break;      // CATEGORY
  end;
  MemoryStream1.Position := ($10 * LongWord1) + $20 + InitPos;
  MemoryStream1.ReadBuffer(LongWord1, 4);
  MemoryStream1.Position := LongWord1 + ValueStart;
  MemoryStream1.ReadBuffer(Result, 2);

  for LongWord1:=0 to NumOfEntries-1 do begin
    MemoryStream1.Position := ($10 * LongWord1) + $14 + InitPos;
    MemoryStream1.ReadBuffer(Word1, 2);
    MemoryStream1.Position := MemoryStream1.Position + 2;
    MemoryStream1.ReadBuffer(ValueLength, 2);
    MemoryStream1.Position := Word1 + NameStart;
    MemoryStream1.ReadBuffer(Title[1], 6);
    if Title='TITLE'#0 then break;
  end;
  MemoryStream1.Position := ($10 * LongWord1) + $20 + InitPos;
  MemoryStream1.ReadBuffer(LongWord1, 4);
  MemoryStream1.Position := LongWord1 + ValueStart;
  SetLength(Title, ValueLength);
  MemoryStream1.ReadBuffer(Title[1], ValueLength);
end;

function CheckKey(const ParamNum: LongWord): Boolean;
var
  MemoryStream1: TMemoryStream;
  BytesStream1: TBytesStream;
  ZDecompressionStream1: TZDecompressionStream;
  LongWord1: LongWord;
  i: Integer;
  s: String;
begin
  Result := True;
  s := Copy(ParamStr(ParamNum), 6);
  case Length(s) of
    0:;
    32: begin
      i:=1;
      LongWord1:=0;
      repeat
        WorkbinKey[LongWord1] := HexToByte(Copy(s,i,2));
        Inc(i, 2);
        Inc(LongWord1);
      until i>=Length(s);
      WorkbinExist := 1;
    end
    else begin
      MemoryStream1:=TMemoryStream.Create;
      try
        BytesStream1:=TBytesStream.Create(TNetEncoding.Base64.DecodeStringToBytes(s));
        try
          ZDecompressionStream1:=TZDecompressionStream.Create(BytesStream1, 10);
          try
            MemoryStream1.CopyFrom(ZDecompressionStream1, ZDecompressionStream1.Size);
          finally ZDecompressionStream1.Free end;
        finally BytesStream1.Free end;

        if MemoryStream1.Size=512 then begin
          MemoryStream1.Position := 0;
          MemoryStream1.ReadBuffer(Workbin, 512);
          WorkbinExist := 2;
        end else begin
          Writeln('Error: Invalid zRIF key');
          Result := False;
        end;
      finally MemoryStream1.Free end;
    end
  end;
end;

const
  PkgKeyPSP: array[0..15] of Byte = ($07,$F2,$C6,$82,$90,$B5,$0D,$2C,$33,$81,$8D,$70,$9B,$60,$E6,$2B);
  PkgVita2: array[0..15] of Byte = ($E3,$1A,$70,$C9,$CE,$1D,$D7,$2B,$F3,$C0,$62,$29,$63,$F2,$EC,$CB);
  PkgVita3: array[0..15] of Byte = ($42,$3A,$CA,$3A,$2B,$D5,$64,$9F,$96,$86,$AB,$AD,$6F,$D8,$80,$1F);
  PkgVita4: array[0..15] of Byte = ($AF,$07,$FD,$59,$65,$25,$27,$BA,$F1,$33,$89,$66,$8B,$17,$D9,$EA);
  RifHdr: array[0..15] of Byte = (0,1,0,1,0,1,0,2,239,205,171,137,103,69,35,1);
  PsfMagic: Int64 = $10146535000;
  ZeroByte: Byte = 0;
  PDB1: array[0..209] of Byte = (0,0,0,0,100,0,0,0,4,0,0,0,4,0,0,0,0,0,0,0,101,
  0,0,0,4,0,0,0,4,0,0,0,2,0,0,0,102,0,0,0,1,0,0,0,1,0,0,0,0,107,0,0,0,4,0,0,0,4,
  0,0,0,7,0,0,0,104,0,0,0,4,0,0,0,4,0,0,0,0,0,0,0,108,0,0,0,4,0,0,0,4,0,0,0,1,0,
  0,0,109,0,0,0,4,0,0,0,4,0,0,0,4,0,0,0,110,0,0,0,1,0,0,0,1,0,0,0,0,112,0,0,0,1,
  0,0,0,1,0,0,0,1,113,0,0,0,1,0,0,0,1,0,0,0,1,114,0,0,0,4,0,0,0,4,0,0,0,0,0,0,0,
  115,0,0,0,1,0,0,0,1,0,0,0,0,116,0,0,0,1,0,0,0,1,0,0,0,0,111,0,0,0,4,0,0,0,4,0,
  0,0,0,0,0,0);
  PDB2: array[0..184] of Byte = (230,0,0,0,29,0,0,0,29,0,0,0,32,32,32,32,32,32,
  32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,0,217,0,0,0,
  37,0,0,0,37,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,218,0,0,0,1,0,0,0,1,0,0,0,1,206,0,0,0,8,0,0,0,8,0,0,0,0,144,1,0,
  0,0,0,0,208,0,0,0,8,0,0,0,8,0,0,0,0,144,1,0,0,0,0,0,204,0,0,0,30,0,0,0,30,0,0,
  0,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,
  32,32,32,32,0);
  PDB3: array[0..204] of Byte = (232,0,0,0,120,0,0,0,120,0,0,0,2,0,0,0,22,0,0,0,
  14,0,0,128,13,0,0,0,16,15,0,0,0,0,0,0,0,144,1,0,0,0,0,0,0,144,1,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  205,0,0,0,1,0,0,0,1,0,0,0,0,236,0,0,0,4,0,0,0,4,0,0,0,199,8,120,149,237,0,0,0,
  32,0,0,0,32,0,0,0,191,31,176,182,101,19,244,6,161,144,115,57,24,86,53,208,34,
  131,37,93,67,148,147,158,117,166,119,106,126,3,133,198);
var
  Cipher: TDCP_rijndael;
  FileStream1, FileStream2: TFileStream;
  MemoryStream1, MemoryStream2: TMemoryStream;
  PkgKey, CtrKey: array [0..15] of Byte;
  ItemCnt, NumOfFiles, NameOffset, NameSize, ListPos, HeadSize, SkuFlags, LongWord1: LongWord;
  DataOffset, ItemOffset, ItemSize, SomeFlags, Int641: Int64;
  KeyType: Byte;
  LicenseFlags, Category: Word;
  utf8s, ContentID, Title: UTF8String;
  OutFolder, DlcFolder, s, s2, s3: String;
  i: Integer;
  BytesStream1: TBytesStream;
  ZDecompressionStream1: TZDecompressionStream;
begin
  try
    Writeln('PS Vita PKG Unpacker v1.6 by RikuKH3');
    Writeln('------------------------------------');
    WorkbinExist := 0;
    case ParamCount of
      0: begin Writeln('Usage: '+ExtractFileName(ParamStr(0))+' <input pkg file> [output folder] [-key=FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF]'); Readln; exit end;
      1: OutFolder:=ExtractFileDir(ExpandFileName(ParamStr(1)));
      2: begin
        if Pos('-key=', LowerCase(ParamStr(2)))=1 then begin
          if CheckKey(2)=False then begin Readln; exit end;
          OutFolder:=ExtractFileDir(ExpandFileName(ParamStr(1)));
        end else begin
          OutFolder := ExpandFileName(ParamStr(2));
          repeat if OutFolder[Length(OutFolder)]='\' then SetLength(OutFolder, Length(OutFolder)-1) until not (OutFolder[Length(OutFolder)]='\');
        end;
      end
      else begin
        if Pos('-key=', LowerCase(ParamStr(3)))=1 then if CheckKey(3)=False then begin Readln; exit end;
        OutFolder := ExpandFileName(ParamStr(2));
        repeat if OutFolder[Length(OutFolder)]='\' then SetLength(OutFolder, Length(OutFolder)-1) until not (OutFolder[Length(OutFolder)]='\');
      end;
    end;

    FileStream1:=TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
    try
      FileStream1.Position := $20;
      FileStream1.ReadBuffer(DataOffset, 8);
      DataOffset := Swap64(DataOffset);

      FileStream1.Position := 0;
      MemoryStream1:=TMemoryStream.Create;
      try
        MemoryStream1.CopyFrom(FileStream1, DataOffset);
        MemoryStream1.Position := MemoryStream1.Position - 8;
        repeat
          MemoryStream1.ReadBuffer(Int641, 8);
          if Int641=PsfMagic then break else MemoryStream1.Position:=MemoryStream1.Position-9;
        until MemoryStream1.Position = 0;

        Category := 0;
        if Int641=PsfMagic then begin
          Category:=ProcessSFO(MemoryStream1, Title);
        end;

        MemoryStream1.Position := $37;
        SetLength(utf8s, 9);
        MemoryStream1.ReadBuffer(utf8s[1], 9);
        MemoryStream1.Position := $30;
        SetLength(ContentID, $24);
        MemoryStream1.ReadBuffer(ContentID[1], $24);

        case Category of
          $6467: OutFolder := OutFolder+'\app\'+string(utf8s)+'\';   // gd
          $7067: OutFolder := OutFolder+'\patch\'+string(utf8s)+'\'; // gp
          $6361: begin
            s := OutFolder+'\bgdl\t\';
            i:=0;
            repeat Inc(i); DlcFolder:=s+LowerCase(IntToHex(i,8))+'\' until DirectoryExists(DlcFolder)=False;
            OutFolder := DlcFolder+string(utf8s)+'\'
          end else OutFolder := OutFolder+'\'+string(utf8s)+'\'
        end;

        if WorkbinExist=2 then begin
          SetLength(utf8s, $24);
          for i:=1 to 36 do utf8s[i]:=UTF8Char(Workbin[i+15]);
          if not (utf8s=ContentID) then begin Writeln('Error: Key doesn'#39't match'); Readln; exit end
        end;

        MemoryStream1.Position := $14;
        MemoryStream1.ReadBuffer(ItemCnt, 4);
        ItemCnt := Swap32(ItemCnt);

        MemoryStream1.Position := $70;
        MemoryStream1.ReadBuffer(PkgKey[0], $10);

        MemoryStream1.Position := $E7;
        MemoryStream1.ReadBuffer(KeyType, 1);
        KeyType := KeyType and 7;

        MemoryStream1.Clear;

        case KeyType of
          2: begin
            Cipher:=TDCP_rijndael.Create(nil);
            try
              Cipher.Init(PkgVita2, 128, nil);
              Cipher.EncryptECB(PkgKey, CtrKey);
            finally Cipher.Free end
          end;
          3: begin
            Cipher:=TDCP_rijndael.Create(nil);
            try
              Cipher.Init(PkgVita3, 128, nil);
              Cipher.EncryptECB(PkgKey, CtrKey);
            finally Cipher.Free end
          end;
          4: begin
            Cipher:=TDCP_rijndael.Create(nil);
            try
              Cipher.Init(PkgVita4, 128, nil);
              Cipher.EncryptECB(PkgKey, CtrKey);
            finally Cipher.Free end
          end
        end;

        FileStream1.Position := DataOffset;
        Cipher:=TDCP_rijndael.Create(nil);
        try
          if KeyType=1 then Cipher.Init(PkgKeyPSP, 128, nil) else Cipher.Init(CtrKey, 128, nil);
          Cipher.SetIV(PkgKey);
          Cipher.CipherMode := cmCTR;
          Cipher.DecryptStream(FileStream1, MemoryStream1, ItemCnt*$20);
          MemoryStream1.Position := 8;
          MemoryStream1.ReadBuffer(Int641, 8);
          Int641 := Swap64(Int641);
          MemoryStream1.Position := MemoryStream1.Size;
          Cipher.DecryptStream(FileStream1, MemoryStream1, Int641-MemoryStream1.Size);

          ListPos := 1;
          NumOfFiles := 0;
          for LongWord1:=0 to ItemCnt-1 do begin
            MemoryStream1.Position := LongWord1 * $20 + $10;
            MemoryStream1.ReadBuffer(ItemSize, 8);
            if ItemSize<>0 then Inc(NumOfFiles);
          end;
          s := IntToStr(NumOfFiles);
          i := Length(s);

          for LongWord1:=0 to ItemCnt-1 do begin
            MemoryStream1.Position := LongWord1 * $20;
            MemoryStream1.ReadBuffer(NameOffset, 4);
            NameOffset := Swap32(NameOffset);
            MemoryStream1.ReadBuffer(NameSize, 4);
            NameSize := Swap32(NameSize);
            MemoryStream1.ReadBuffer(ItemOffset, 8);
            ItemOffset := Swap64(ItemOffset);
            MemoryStream1.ReadBuffer(ItemSize, 8);
            ItemSize := Swap64(ItemSize);

            if ItemSize>0 then begin
              MemoryStream1.Position := NameOffset;
              SetLength(utf8s, NameSize);
              MemoryStream1.ReadBuffer(utf8s[1], NameSize);
              s3 := StringReplace(string(utf8s),'/','\',[rfReplaceAll]);
              ForceDirectories(OutFolder+ExtractFilePath(s3));

              FileStream1.Position := DataOffset + ItemOffset;
              s2 := IntToStr(ListPos);
              s2 := StringOfChar('0', i-Length(s2)) + s2;
              Writeln('['+s2+'/'+s+'] ', s3);
              Inc(ListPos);
              FileStream2:=TFileStream.Create(OutFolder+s3, fmCreate or fmOpenWrite or fmShareDenyWrite);
              try
                Cipher.DecryptStream(FileStream1, FileStream2, ItemSize);
              finally FileStream2.Free end;
            end;
          end;
        finally Cipher.Free end;
        HeadSize := MemoryStream1.Size + DataOffset;
      finally MemoryStream1.Free end;

      case Category of
        $6467,$7067,$6361: begin // app, patch, dlc
          if DirectoryExists(OutFolder+'sce_sys\package\') then begin
            FileStream1.Position := FileStream1.Size - $1E0;
            FileStream2:=TFileStream.Create(OutFolder+'sce_sys\package\tail.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
            try
              FileStream2.CopyFrom(FileStream1, $1E0);
            finally FileStream2.Free end;

            FileStream1.Position := 0;
            FileStream2:=TFileStream.Create(OutFolder+'sce_sys\package\head.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
            try
              FileStream2.CopyFrom(FileStream1, HeadSize);
            finally FileStream2.Free end;
          end;

          case WorkbinExist of
            1: if (Category=$6467) or (Category=$6361) then begin // app, dlc
              SkuFlags := 0;
              LicenseFlags := $200;
              SomeFlags := 0;
              MemoryStream1:=TMemoryStream.Create;
              try
                if FileExists(OutFolder+'sce_sys\package\temp.bin') then begin
                  MemoryStream1.LoadFromFile(OutFolder+'sce_sys\package\temp.bin');
                  if MemoryStream1.Size=512 then begin
                    MemoryStream1.Position := $FC;
                    MemoryStream1.ReadBuffer(LongWord1, 4);
                    if LongWord1=$1000000 then begin
                      SkuFlags := $3000000;
                      MemoryStream1.Position := 6;
                      MemoryStream1.ReadBuffer(LicenseFlags, 2);
                      MemoryStream1.Position := $98;
                      MemoryStream1.ReadBuffer(SomeFlags, 8);
                    end;
                  end;
                  MemoryStream1.Clear;
                end;
                MemoryStream1.WriteBuffer(RifHdr[0], 6);
                MemoryStream1.WriteBuffer(LicenseFlags, 2);
                MemoryStream1.WriteBuffer(RifHdr[8], 8);
                FileStream1.Position := $30;
                MemoryStream1.CopyFrom(FileStream1, $30);
                for i:=0 to 15 do MemoryStream1.WriteBuffer(ZeroByte, 1);
                MemoryStream1.WriteBuffer(WorkbinKey, $10);
                for i:=0 to 55 do MemoryStream1.WriteBuffer(ZeroByte, 1);
                MemoryStream1.WriteBuffer(SomeFlags, 8);
                for i:=0 to 91 do MemoryStream1.WriteBuffer(ZeroByte, 1);
                MemoryStream1.WriteBuffer(SkuFlags, 4);
                for i:=0 to 255 do MemoryStream1.WriteBuffer(ZeroByte, 1);
                MemoryStream1.SaveToFile(OutFolder+'sce_sys\package\work.bin');
              finally MemoryStream1.Free end;
            end;
            2: if (Category=$6467) or (Category=$6361) then begin // app, dlc
              MemoryStream1:=TMemoryStream.Create;
              try
                MemoryStream1.WriteBuffer(Workbin[0], 512);
                MemoryStream1.SaveToFile(OutFolder+'sce_sys\package\work.bin');
              finally MemoryStream1.Free end;
            end;
          end;

          if Category=$6361 then begin // dlc
            MemoryStream1:=TMemoryStream.Create;
            try
              MemoryStream1.SaveToFile(DlcFolder+'f0.pdb');
              for i:=0 to 767 do MemoryStream1.WriteBuffer(ZeroByte, 1);
              MemoryStream1.SaveToFile(OutFolder+'sce_sys\package\stat.bin');
              MemoryStream1.Clear;
              MemoryStream1.WriteBuffer(PDB1[0], 210);
              LongWord1 := $69;
              MemoryStream1.WriteBuffer(LongWord1, 4);
              LongWord1 := Length(Title);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(Title[1], LongWord1);
              LongWord1 := $CB;
              MemoryStream1.WriteBuffer(LongWord1, 4);
              utf8s := 'pkg.pkg'#0;
              LongWord1 := Length(utf8s);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(utf8s[1], LongWord1);
              LongWord1 := $CA;
              MemoryStream1.WriteBuffer(LongWord1, 4);
              utf8s := 'https://example.com/pkg.pkg'#0;
              LongWord1 := Length(utf8s);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(utf8s[1], LongWord1);
              LongWord1 := $6A;
              MemoryStream1.WriteBuffer(LongWord1, 4);
              utf8s := 'ux0:bgdl/t/'+UTF8String(Copy(DlcFolder, Length(DlcFolder)-8, 8))+'/icon.png'#0;
              LongWord1 := Length(utf8s);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(utf8s[1], LongWord1);
              MemoryStream1.WriteBuffer(PDB2[0], 185);
              LongWord1 := $DC;
              MemoryStream1.WriteBuffer(LongWord1, 4);
              utf8s := Copy(ContentID,8,9)+#0;
              LongWord1 := Length(utf8s);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(LongWord1, 4);
              MemoryStream1.WriteBuffer(utf8s[1], LongWord1);
              MemoryStream1.WriteBuffer(PDB3[0], 205);
              MemoryStream1.Position := MemoryStream1.Position - $8D;
              MemoryStream1.WriteBuffer(utf8s[1], LongWord1);
              MemoryStream1.SaveToFile(DlcFolder+'d0.pdb');
              MemoryStream1.Position := $20;
              MemoryStream1.WriteBuffer(ZeroByte, 1);
              MemoryStream1.SaveToFile(DlcFolder+'d1.pdb');
            finally MemoryStream1.Free end;
          end;
          DeleteFile(OutFolder+'sce_sys\package\digs.bin');
        end;
      end;
    finally FileStream1.Free end;
    DeleteFile(OutFolder+'sce_pfs\pflist');
  except on E: Exception do begin Writeln('Error: '+E.Message); Readln end end;
end.
