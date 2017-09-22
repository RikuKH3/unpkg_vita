program unpkg_vita;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes, DCPrijndael, DCPcrypt2;

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

const
  PkgKeyPSP: array[0..15] of Byte = ($07,$F2,$C6,$82,$90,$B5,$0D,$2C,$33,$81,$8D,$70,$9B,$60,$E6,$2B);
  PkgVita2: array[0..15] of Byte = ($E3,$1A,$70,$C9,$CE,$1D,$D7,$2B,$F3,$C0,$62,$29,$63,$F2,$EC,$CB);
  PkgVita3: array[0..15] of Byte = ($42,$3A,$CA,$3A,$2B,$D5,$64,$9F,$96,$86,$AB,$AD,$6F,$D8,$80,$1F);
  PkgVita4: array[0..15] of Byte = ($AF,$07,$FD,$59,$65,$25,$27,$BA,$F1,$33,$89,$66,$8B,$17,$D9,$EA);
var
  Cipher: TDCP_rijndael;
  FileStream1, FileStream2: TFileStream;
  MemoryStream1: TMemoryStream;
  PkgKey, CtrKey: array [0..15] of Byte;
  ItemCnt, NumOfFiles, NameOffset, NameSize, ListPos, LongWord1, HeadSize: LongWord;
  DataOffset, ItemOffset, ItemSize, Int641: Int64;
  KeyType, ItemFlags: Byte;
  utf8s: UTF8String;
  OutFolder, s, s2: String;
  i: Integer;
begin
  try
    Writeln('PS Vita PKG Unpacker v1.0 by RikuKH3');
    Writeln('------------------------------------');
    if ParamCount=0 then begin Writeln('Usage: '+ExtractFileName(ParamStr(0))+' <input pkg file> [output folder]'); Readln; exit end;

    if ParamCount>1 then begin
      OutFolder := ExpandFileName(ParamStr(2));
      repeat if OutFolder[Length(OutFolder)]='\' then SetLength(OutFolder, Length(OutFolder)-1) until not (OutFolder[Length(OutFolder)]='\');
    end else OutFolder:=ExpandFileName(Copy(ParamStr(1),1,Length(ParamStr(1))-Length(ExtractFileExt(ParamStr(1)))));

    FileStream1:=TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
    try
      FileStream1.Position := $14;
      FileStream1.ReadBuffer(ItemCnt, 4);
      ItemCnt := Swap32(ItemCnt);

      FileStream1.Position := $20;
      FileStream1.ReadBuffer(DataOffset, 8);
      DataOffset := Swap64(DataOffset);

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
            MemoryStream1.Position := LongWord1 * $20 + $1B;
            MemoryStream1.ReadBuffer(ItemFlags, 1);
            case ItemFlags of
              0,1,3,14..17,19,21,22: Inc(NumOfFiles);
            end;
          end;
          s := IntToStr(NumOfFiles);
          i := Length(s);

          CreateDir(OutFolder);

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
            MemoryStream1.Position := MemoryStream1.Position + 3;
            MemoryStream1.ReadBuffer(ItemFlags, 1);

            case ItemFlags of
              4,18: begin
                MemoryStream1.Position := NameOffset;
                SetLength(utf8s, NameSize);
                MemoryStream1.ReadBuffer(utf8s[1], NameSize);
                CreateDir(OutFolder+'\'+string(utf8s));
              end;
              0,1,3,14..17,19,21,22: begin
                MemoryStream1.Position := NameOffset;
                SetLength(utf8s, NameSize);
                MemoryStream1.ReadBuffer(utf8s[1], NameSize);
                FileStream1.Position := DataOffset + ItemOffset;
                FileStream2:=TFileStream.Create(OutFolder+'\'+string(utf8s), fmCreate or fmOpenWrite or fmShareDenyWrite);
                try
                  Cipher.DecryptStream(FileStream1, FileStream2, ItemSize);
                finally FileStream2.Free end;
                s2 := IntToStr(ListPos);
                s2 := StringOfChar('0', i-Length(s2)) + s2;
                Writeln('['+s2+'/'+s+'] ', utf8s);
                Inc(ListPos);
              end;
            end;
          end;
        finally Cipher.Free end;
        HeadSize := MemoryStream1.Size + DataOffset;
      finally MemoryStream1.Free end;

      if DirectoryExists(OutFolder+'\sce_sys\package\') then begin
        FileStream1.Position := FileStream1.Size - $1E0;
        FileStream2:=TFileStream.Create(OutFolder+'\sce_sys\package\tail.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
        try
          FileStream2.CopyFrom(FileStream1, $1E0);
        finally FileStream2.Free end;

        FileStream1.Position := 0;
        FileStream2:=TFileStream.Create(OutFolder+'\sce_sys\package\head.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
        try
          FileStream2.CopyFrom(FileStream1, HeadSize);
        finally FileStream2.Free end;
      end;
    finally FileStream1.Free end;
    DeleteFile(OutFolder+'\sce_pfs\pflist');
  except on E: Exception do begin Writeln(E.Message); Readln end end;
end.
