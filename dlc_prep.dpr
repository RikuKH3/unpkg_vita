program dlc_prep;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes, IOUtils;

{$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}

function FindInFolder(sFolder, sFile: String): String;
var
  sr: TSearchRec;
begin
  Result := '';
  sFolder := IncludeTrailingPathDelimiter(sFolder);
  if FindFirst(sFolder + sFile, faAnyFile - faDirectory, sr) = 0 then begin
    Result := sFolder + sr.Name;
    FindClose(sr);
    exit;
  end;
  if FindFirst(sFolder + '*.*', faDirectory, sr) = 0 then begin
    try
      repeat
        if ((sr.Attr and faDirectory) <> 0) and (sr.Name <> '.') and (sr.Name <> '..') then begin
          Result := FindInFolder(sFolder + sr.Name, sFile);
          if Length(Result) > 0 then break;
        end;
      until FindNext(sr) <> 0;
    finally FindClose(sr) end;
  end;
end;

const
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
  MemoryStream1: TMemoryStream;
  FileStream1: TFileStream;
  LongWord1, LongWord2, SfoNameStart, SfoValueStart, SfoNumOfEntries: LongWord;
  Word1, Category: Word;
  utf8s, TitleID, ContentID, Title: UTF8String;
  s, s2, TitleNum, InputDir, OutDir: String;
begin
  try
    Writeln('PS Vita DLC Installation Prep Tool v1.0 by RikuKH3');
    Writeln('--------------------------------------------------');
    case ParamCount of
      0..1: begin Writeln('Usage: '+ExtractFileName(ParamStr(0))+' <input folder> <rif file> [output folder]'); Readln; exit end;
      2: begin
        s2 := ExtractFilePath(ParamStr(0))+'bgdl\t\';
      end else begin
        s2 := ExpandFileName(ParamStr(3));
        repeat if s2[Length(s2)]='\' then SetLength(s2, Length(s2)-1) until not (s2[Length(s2)]='\');
        s2 := s2+'\bgdl\t\';;
      end;
    end;

    InputDir := ExpandFileName(ParamStr(1));
    repeat if InputDir[Length(InputDir)]='\' then SetLength(InputDir, Length(InputDir)-1) until not (InputDir[Length(InputDir)]='\');

    s := FindInFolder(InputDir, 'param.sfo');
    MemoryStream1:=TMemoryStream.Create;
    try
      MemoryStream1.LoadFromFile(s);
      MemoryStream1.Position := 8;
      MemoryStream1.ReadBuffer(SfoNameStart, 4);
      MemoryStream1.ReadBuffer(SfoValueStart, 4);
      MemoryStream1.ReadBuffer(SfoNumOfEntries, 4);

      for SfoNumOfEntries:=0 to SfoNumOfEntries-1 do begin
        MemoryStream1.Position := ($10 * SfoNumOfEntries) + $14;
        MemoryStream1.ReadBuffer(Word1, 2);     // NamePos
        MemoryStream1.Position := MemoryStream1.Position + 2;
        MemoryStream1.ReadBuffer(LongWord1, 4); // ValueSize
        MemoryStream1.Position := MemoryStream1.Position + 4;
        MemoryStream1.ReadBuffer(LongWord2, 4); // ValuePos
        MemoryStream1.Position := Word1 + SfoNameStart;
        SetLength(utf8s, $B);
        MemoryStream1.ReadBuffer(utf8s[1], $B);
        MemoryStream1.Position := SfoValueStart + LongWord2;

        if utf8s='CONTENT_ID'#0 then begin
          SetLength(ContentID, $24);
          MemoryStream1.ReadBuffer(ContentID[1], $24);
          TitleID := Copy(ContentID, 8, 9);
        end else begin
          SetLength(utf8s, 9);
          if utf8s='CATEGORY'#0 then begin
            MemoryStream1.ReadBuffer(Category, 2);
          end else begin
            SetLength(utf8s, 6);
            if utf8s='TITLE'#0 then begin
              SetLength(Title, LongWord1);
              MemoryStream1.ReadBuffer(Title[1], LongWord1);
            end
          end
        end;
      end;

      LongWord1 := 0;
      repeat
        Inc(LongWord1);
        TitleNum := LowerCase(IntToHex(LongWord1,8));
        OutDir := s2+TitleNum+'\';
      until DirectoryExists(OutDir)=False;

      SetLength(utf8s, $24);
      MemoryStream1.LoadFromFile(ParamStr(2));
      if MemoryStream1.Size<>512 then begin Writeln('Error: Invalid RIF file'); Readln; exit end;
      MemoryStream1.Position := $10;
      MemoryStream1.ReadBuffer(utf8s[1], $24);
      if not (utf8s=ContentID) then begin Writeln('Error: RIF file doesn'#39't match'); Readln; exit end;

      SetLength(s, Length(s)-10);
      if FileExists(s+'\package.bin')=False then begin Writeln('Error: Input folder doesn'#39't contain PS Vita DLC'); Readln; exit end;

      MemoryStream1.Position := 0;
      s2 := OutDir+String(TitleID);
      TDirectory.Copy(ExtractFilePath(s), s2);
      s2 := s2+'\sce_sys\package';
      DeleteFile(s2+'.bin');
      CreateDir(s2);
      FileStream1:=TFileStream.Create(s2+'\work.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        FileStream1.CopyFrom(MemoryStream1, MemoryStream1.Size)
      finally FileStream1.Free end;

      MemoryStream1.LoadFromFile(s+'\package.bin');

      MemoryStream1.Position := $18;
      MemoryStream1.ReadBuffer(LongWord1, 4);
      MemoryStream1.ReadBuffer(LongWord2, 4);
      MemoryStream1.Position := LongWord1;
      FileStream1:=TFileStream.Create(s2+'\stat.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        FileStream1.CopyFrom(MemoryStream1, LongWord2)
      finally FileStream1.Free end;
      MemoryStream1.Position := $28;
      MemoryStream1.ReadBuffer(LongWord1, 4);
      MemoryStream1.ReadBuffer(LongWord2, 4);
      MemoryStream1.Position := LongWord1;
      FileStream1:=TFileStream.Create(s2+'\head.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        FileStream1.CopyFrom(MemoryStream1, LongWord2)
      finally FileStream1.Free end;
      MemoryStream1.Position := $38;
      MemoryStream1.ReadBuffer(LongWord1, 4);
      MemoryStream1.ReadBuffer(LongWord2, 4);
      MemoryStream1.Position := LongWord1;
      FileStream1:=TFileStream.Create(s2+'\body.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        FileStream1.CopyFrom(MemoryStream1, LongWord2)
      finally FileStream1.Free end;
      MemoryStream1.Position := $48;
      MemoryStream1.ReadBuffer(LongWord1, 4);
      MemoryStream1.ReadBuffer(LongWord2, 4);
      MemoryStream1.Position := LongWord1;
      FileStream1:=TFileStream.Create(s2+'\inst.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        FileStream1.CopyFrom(MemoryStream1, LongWord2)
      finally FileStream1.Free end;
      MemoryStream1.Position := $58;
      MemoryStream1.ReadBuffer(LongWord1, 4);
      MemoryStream1.ReadBuffer(LongWord2, 4);
      MemoryStream1.Position := LongWord1;
      FileStream1:=TFileStream.Create(s2+'\temp.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        FileStream1.CopyFrom(MemoryStream1, LongWord2)
      finally FileStream1.Free end;
      MemoryStream1.Position := $78;
      MemoryStream1.ReadBuffer(LongWord1, 4);
      MemoryStream1.ReadBuffer(LongWord2, 4);
      MemoryStream1.Position := LongWord1;
      FileStream1:=TFileStream.Create(s2+'\tail.bin', fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        FileStream1.CopyFrom(MemoryStream1, LongWord2)
      finally FileStream1.Free end;

      MemoryStream1.Clear;
      MemoryStream1.SaveToFile(OutDir+'f0.pdb');
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
      utf8s := 'ux0:bgdl/t/'+UTF8String(TitleNum)+'/icon.png'#0;
      LongWord1 := Length(utf8s);
      MemoryStream1.WriteBuffer(LongWord1, 4);
      MemoryStream1.WriteBuffer(LongWord1, 4);
      MemoryStream1.WriteBuffer(utf8s[1], LongWord1);
      MemoryStream1.WriteBuffer(PDB2[0], 185);
      LongWord1 := $DC;
      MemoryStream1.WriteBuffer(LongWord1, 4);
      TitleID := TitleID+#0;
      LongWord1 := Length(TitleID);
      MemoryStream1.WriteBuffer(LongWord1, 4);
      MemoryStream1.WriteBuffer(LongWord1, 4);
      MemoryStream1.WriteBuffer(TitleID[1], LongWord1);
      MemoryStream1.WriteBuffer(PDB3[0], 205);
      MemoryStream1.Position := MemoryStream1.Position - $8D;
      MemoryStream1.WriteBuffer(TitleID[1], LongWord1);
      MemoryStream1.SaveToFile(OutDir+'d0.pdb');
      MemoryStream1.Position := $20;
      MemoryStream1.WriteBuffer(PDB1[0], 1);
      MemoryStream1.SaveToFile(OutDir+'d1.pdb');
    finally MemoryStream1.Free end;
    Writeln('Done!');
  except on E: Exception do begin Writeln(E.Message); Readln end end;
end.
