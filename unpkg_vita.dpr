program unpkg_vita;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes, IOUtils, DCPrijndael, DCPcrypt2;

{$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}

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

function ProcessSFO(MemoryStream1: TMemoryStream): UTF8String;
var
  NameStart, ValueStart, NumOfEntries, LongWord1: LongWord;
  Word1: Word;
begin
  MemoryStream1.ReadBuffer(LongWord1, 4);
  if LongWord1<>$46535000 then exit;
  MemoryStream1.Position := 8;
  MemoryStream1.ReadBuffer(NameStart, 4);
  MemoryStream1.ReadBuffer(ValueStart, 4);
  MemoryStream1.ReadBuffer(NumOfEntries, 4);

  SetLength(Result, 8);
  for LongWord1:=0 to NumOfEntries-1 do begin
    MemoryStream1.Position := ($10 * LongWord1) + $14;
    MemoryStream1.ReadBuffer(Word1, 2);
    MemoryStream1.Position := Word1 + NameStart;
    MemoryStream1.ReadBuffer(Result[1], 8);
    if Result='CATEGORY' then break;
  end;
  MemoryStream1.Position := ($10 * LongWord1) + $20;
  MemoryStream1.ReadBuffer(LongWord1, 4);
  MemoryStream1.Position := LongWord1 + ValueStart;
  SetLength(Result, 2);
  MemoryStream1.ReadBuffer(Result[1], 2);
end;

const
  PkgKeyPSP: array[0..15] of Byte = ($07,$F2,$C6,$82,$90,$B5,$0D,$2C,$33,$81,$8D,$70,$9B,$60,$E6,$2B);
  PkgVita2: array[0..15] of Byte = ($E3,$1A,$70,$C9,$CE,$1D,$D7,$2B,$F3,$C0,$62,$29,$63,$F2,$EC,$CB);
  PkgVita3: array[0..15] of Byte = ($42,$3A,$CA,$3A,$2B,$D5,$64,$9F,$96,$86,$AB,$AD,$6F,$D8,$80,$1F);
  PkgVita4: array[0..15] of Byte = ($AF,$07,$FD,$59,$65,$25,$27,$BA,$F1,$33,$89,$66,$8B,$17,$D9,$EA);
  RifHdr: array[0..15] of Byte = (0,1,0,1,0,1,0,2,239,205,171,137,103,69,35,1);
  ZeroByte: Byte=0;
var
  Cipher: TDCP_rijndael;
  FileStream1, FileStream2: TFileStream;
  MemoryStream1: TMemoryStream;
  PkgKey, CtrKey, WorkbinKey: array [0..15] of Byte;
  ItemCnt, NumOfFiles, NameOffset, NameSize, ListPos, HeadSize, SkuFlags, LongWord1: LongWord;
  DataOffset, ItemOffset, ItemSize, SomeFlags, Int641: Int64;
  KeyType: Byte;
  LicenseFlags: Word;
  utf8s: UTF8String;
  WorkbinExist: Boolean;
  OutFolder, s, s2, s3: String;
  i: Integer;
begin
  try
    Writeln('PS Vita PKG Unpacker v1.3 by RikuKH3');
    Writeln('------------------------------------');
    if ParamCount=0 then begin Writeln('Usage: '+ExtractFileName(ParamStr(0))+' <input pkg file> [output folder] [-key=FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF]'); Readln; exit end;

    WorkbinExist := False;
    if ParamCount>1 then begin
      if Pos('-key=', LowerCase(ParamStr(2)))=1 then begin
        WorkbinExist := True;
        s := Copy(ParamStr(2), 6);
        if Length(s) mod 2 > 0 then s:='0'+s;
        if Length(s)>0 then begin
          i:=1;
          LongWord1:=0;
          repeat
            WorkbinKey[LongWord1] := HexToByte(Copy(s,i,2));
            Inc(i, 2);
            Inc(LongWord1);
          until i>=Length(s);
        end;
        OutFolder:=ExpandFileName(Copy(ParamStr(1),1,Length(ParamStr(1))-Length(ExtractFileExt(ParamStr(1)))));
      end else begin
        OutFolder := ExpandFileName(ParamStr(2));
        repeat if OutFolder[Length(OutFolder)]='\' then SetLength(OutFolder, Length(OutFolder)-1) until not (OutFolder[Length(OutFolder)]='\');
      end;
    end else OutFolder:=ExpandFileName(Copy(ParamStr(1),1,Length(ParamStr(1))-Length(ExtractFileExt(ParamStr(1)))));

    FileStream1:=TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
    try
      FileStream1.Position := $14;
      FileStream1.ReadBuffer(ItemCnt, 4);
      ItemCnt := Swap32(ItemCnt);

      FileStream1.Position := $20;
      FileStream1.ReadBuffer(DataOffset, 8);
      DataOffset := Swap64(DataOffset);

      FileStream1.Position := $37;
      SetLength(utf8s, 9);
      FileStream1.ReadBuffer(utf8s[1], 9);
      OutFolder := OutFolder+'\'+string(utf8s)+'\';

      FileStream1.Position := $70;
      FileStream1.ReadBuffer(PkgKey[0], $10);

      FileStream1.Position := $E7;
      FileStream1.ReadBuffer(KeyType, 1);
      KeyType := KeyType and 7;

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
      MemoryStream1:=TMemoryStream.Create;
      try
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

      if FileExists(OutFolder+'sce_sys\param.sfo') then begin
        MemoryStream1:=TMemoryStream.Create;
        try
          MemoryStream1.LoadFromFile(OutFolder+'sce_sys\param.sfo');
          utf8s := ProcessSFO(MemoryStream1);
        finally MemoryStream1.Free end;

        if (utf8s='gd') or (utf8s='gp') then begin  // gd=app, ac=addcont, gp=patch
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

          if WorkbinExist=False then if ParamCount>2 then if Pos('-key=', LowerCase(ParamStr(3)))=1 then begin
            WorkbinExist := True;
            s := Copy(ParamStr(3), 6);
            if Length(s) mod 2 > 0 then s:='0'+s;
            if Length(s)>0 then begin
              i:=1;
              LongWord1:=0;
              repeat
                WorkbinKey[LongWord1] := HexToByte(Copy(s,i,2));
                Inc(i, 2);
                Inc(LongWord1);
              until i>=Length(s);
            end;
          end;

          if WorkbinExist then if utf8s='gd' then begin
            SkuFlags := 0;
            LicenseFlags := $200;
            SomeFlags := 0;
            MemoryStream1:=TMemoryStream.Create;
            try
              if FileExists(OutFolder+'sce_sys\package\temp.bin') then begin
                MemoryStream1.LoadFromFile(OutFolder+'sce_sys\package\temp.bin');
                MemoryStream1.Position := $FC;
                MemoryStream1.ReadBuffer(LongWord1, 4);
                if LongWord1=$1000000 then begin
                  SkuFlags := $3000000;
                  MemoryStream1.Position := 6;
                  MemoryStream1.ReadBuffer(LicenseFlags, 2);
                  MemoryStream1.Position := $98;
                  MemoryStream1.ReadBuffer(SomeFlags, 8);
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
        end else if utf8s='ac' then begin
          if DirectoryExists(OutFolder+'sce_sys\package\') then TDirectory.Delete(OutFolder+'sce_sys\package\', True);
        end;
      end;
    finally FileStream1.Free end;
    DeleteFile(OutFolder+'sce_pfs\pflist');
  except on E: Exception do begin Writeln(E.Message); Readln end end;
end.
