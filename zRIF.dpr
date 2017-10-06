program zRIF;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes, System.NetEncoding, Zlib in 'Zlib.pas';

{$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}

procedure DecodeKey(Key: String);
var
  MemoryStream1: TMemoryStream;
  BytesStream1: TBytesStream;
  ZDecompressionStream1: TZDecompressionStream;
  Byte1: Byte;
  i: Integer;
  utf8s: UTF8String;
  s: String;
begin
  MemoryStream1:=TMemoryStream.Create;
  try
    BytesStream1:=TBytesStream.Create(TNetEncoding.Base64.DecodeStringToBytes(Key));
    try
      ZDecompressionStream1:=TZDecompressionStream.Create(BytesStream1, 10);
      try
        MemoryStream1.CopyFrom(ZDecompressionStream1, ZDecompressionStream1.Size);
      finally ZDecompressionStream1.Free end;
    finally BytesStream1.Free end;
    if MemoryStream1.Size<>512 then begin Writeln('Error: Invalid zRIF key'); Readln; exit end;
    s:='Klicensee: ';
    SetLength(utf8s, $24);
    MemoryStream1.Position := $10;
    MemoryStream1.ReadBuffer(utf8s[1], $24);
    MemoryStream1.Position := $50;
    for i:=0 to 15 do begin MemoryStream1.ReadBuffer(Byte1, 1); s:=s+IntToHex(Byte1,2) end;
    Writeln('ContentID: ', utf8s);
    Writeln(s);
    Writeln('zRIF: ', Key);
    MemoryStream1.SaveToFile(ExtractFilePath(ParamStr(0))+'work.bin');
    Writeln('');
    Writeln(#39'work.bin'#39' file created.');
    Readln;
  finally MemoryStream1.Free end;
end;

procedure EncodeKey;
var
  MemoryStream1, MemoryStream2: TMemoryStream;
  ZCompressionStream1: TZCompressionStream;
  Buffer: array of Byte;
  LongWord1: LongWord;
  Byte1: Byte;
  i: Integer;
  utf8s: UTF8String;
  s, s2, s3: String;
begin
  MemoryStream1:=TMemoryStream.Create;
  try
    MemoryStream2:=TMemoryStream.Create;
    try
      MemoryStream2.LoadFromFile(ParamStr(1));
      if MemoryStream2.Size<>512 then begin Writeln('Error: Input file is not a valid '#39'work.bin'#39' file'); Readln; exit end;

      MemoryStream2.Position := $100;
      for i:=0 to 63 do begin
        MemoryStream2.ReadBuffer(LongWord1, 4);
        if LongWord1 > 0 then break;
      end;
      if LongWord1 > 0 then begin Writeln('Error: work.bin is not made by NoNpDrm plugin'); Readln; exit end;
      MemoryStream2.Position := 0;

      ZCompressionStream1:=TZCompressionStream.Create(MemoryStream1, zcMax, 10);
      try
        ZCompressionStream1.SetDictionary;
        ZCompressionStream1.CopyFrom(MemoryStream2, 512);
      finally ZCompressionStream1.Free end;
      s2:='Klicensee: ';
      SetLength(utf8s, $24);
      MemoryStream2.Position := $10;
      MemoryStream2.ReadBuffer(utf8s[1], $24);
      MemoryStream2.Position := $50;
      for i:=0 to 15 do begin MemoryStream2.ReadBuffer(Byte1, 1); s2:=s2+IntToHex(Byte1,2) end;
    finally MemoryStream2.Free end;
    LongWord1 := MemoryStream1.Size;
    SetLength(Buffer, LongWord1);
    MemoryStream1.Position := 0;
    MemoryStream1.ReadBuffer(Buffer[0], LongWord1);
    MemoryStream1.Clear;
    if LongWord1 mod 3 > 0 then SetLength(Buffer, 3-(LongWord1 mod 3)+LongWord1);
    s := StringReplace(TNetEncoding.Base64.EncodeBytesToString(Buffer), #13#10, '', [rfReplaceAll]);
    s3 := string(utf8s);
    with TStringList.Create do try Append(s); SaveToStream(MemoryStream1) finally Free end;
    MemoryStream1.Size := MemoryStream1.Size-2;
    MemoryStream1.SaveToFile(ExtractFilePath(ParamStr(0))+s3+'.txt');
  finally MemoryStream1.Free end;
  Writeln('ContentID: ', s3);
  Writeln(s2);
  Writeln('zRIF: ', s);
  Writeln('');
  Writeln(#39+s3+'.txt'#39' file created.');
  Readln;
end;

var
  StringList1: TStringList;
  s: String;
begin
  try
    Writeln('PS Vita zRIF Tool v1.0 by RikuKH3');
    Writeln('---------------------------------');
    if ParamCount=0 then begin Writeln('Usage: '+ExtractFileName(ParamStr(0))+' <input file or zRIF key>'); Readln; exit end;
    if Pos('.', ExtractFileName(ParamStr(1)))>0 then begin
      if ExtractFileExt(ParamStr(1))='.txt' then begin
        StringList1:=TStringList.Create;
        try
          StringList1.LoadFromFile(ParamStr(1));
          if StringList1.Count=0 then begin Writeln('Error: '#39+ExtractFileName(ParamStr(1))+#39' is empty'); Readln; exit end;
          s:=StringList1[0];
        finally StringList1.Free end;
        DecodeKey(s);
      end else EncodeKey;
    end else DecodeKey(ParamStr(1));
  except on E: Exception do begin Writeln('Error: '+E.Message); Readln end end;
end.
