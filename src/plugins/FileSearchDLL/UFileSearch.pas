unit UFileSearch;

interface

uses
  SysUtils, Classes, PluginAPI;

function GetTaskCount: Integer; stdcall;
function GetTaskName(Index: Integer): PChar; stdcall;
function GetTaskDescription(Index: Integer): PChar; stdcall;
function GetTaskParams(Index: Integer): PChar; stdcall;
function RunTask(Index: Integer; Params: PChar): PChar; stdcall;
function GetLastErrorText: PChar; stdcall;

implementation

var
  LastErrorText: string = '';
  ResultBuffer: string = '';

const
  TASK_COUNT = 2;
  TASK_NAMES: array[0..1] of string = (
    'FileMaskSearch',
    'SubstringSearch'
  );
  TASK_DESCRIPTIONS: array[0..1] of string = (
    'Поиск файлов по маске и папке',
    'Поиск вхождений последовательности символов в файле'
  );
  TASK_PARAMS: array[0..1] of string = (
    'Mask;Path',
    'Substring;FilePath'
  );

function GetTaskCount: Integer; stdcall;
begin
  Result := TASK_COUNT;
end;

function GetTaskName(Index: Integer): PChar; stdcall;
begin
  if (Index >= 0) and (Index < TASK_COUNT) then
    Result := PChar(TASK_NAMES[Index])
  else
  begin
    LastErrorText := 'Invalid task index';
    Result := '';
  end;
end;

function GetTaskDescription(Index: Integer): PChar; stdcall;
begin
  if (Index >= 0) and (Index < TASK_COUNT) then
    Result := PChar(TASK_DESCRIPTIONS[Index])
  else
  begin
    LastErrorText := 'Invalid task index';
    Result := '';
  end;
end;

function GetTaskParams(Index: Integer): PChar; stdcall;
begin
  if (Index >= 0) and (Index < TASK_COUNT) then
    Result := PChar(TASK_PARAMS[Index])
  else
  begin
    LastErrorText := 'Invalid task index';
    Result := '';
  end;
end;

// --- Реализация задач ---

function FileMaskSearchRecursive(const Mask, Path: string; FileList: TStringList): Integer;
var
  SR: TSearchRec;
  CurrentDir, SearchPath, SubDir: string;
  Found: Integer;
  DirList: TStringList;
begin
  Result := 0;
  DirList := TStringList.Create;
  try
    DirList.Add(Path);
    // Используем DirList как стек: пока есть папки для обработки
    while DirList.Count > 0 do
    begin
      CurrentDir := DirList[DirList.Count - 1];
      DirList.Delete(DirList.Count - 1);
      // Ищем файлы по маске в текущей папке
      SearchPath := IncludeTrailingPathDelimiter(CurrentDir) + Mask;
      Found := FindFirst(SearchPath, faAnyFile and not faDirectory, SR);
      if Found = 0 then
      try
        repeat
          FileList.Add(IncludeTrailingPathDelimiter(CurrentDir) + SR.Name);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
      // Ищем подпапки и добавляем их в стек
      Found := FindFirst(IncludeTrailingPathDelimiter(CurrentDir) + '*', faDirectory, SR);
      if Found = 0 then
      try
        repeat
          if ((SR.Attr and faDirectory) <> 0) and (SR.Name <> '.') and (SR.Name <> '..') then
          begin
            SubDir := IncludeTrailingPathDelimiter(CurrentDir) + SR.Name;
            DirList.Add(SubDir);
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
    Result := FileList.Count;
  finally
    DirList.Free;
  end;
end;

function FileMaskSearch(const Mask, Path: string): string;
var
  FileList: TStringList;
  Count: Integer;
begin
  Result := '';
  FileList := TStringList.Create;
  try
    Count := FileMaskSearchRecursive(Mask, Path, FileList);
    Result := IntToStr(FileList.Count);
    if FileList.Count > 0 then
      Result := Result + #13#10 + FileList.Text;
  finally
    FileList.Free;
  end;
end;

function SubstringSearch(const Substring, FilePath: string): string;
var
  FS: TFileStream;
  Buffer: array[0..4095] of Byte;
  ReadBytes, i, j, MatchCount: Integer;
  SubBytes: TBytes;
  PosList: TStringList;
  FilePos, BufPos: Int64;
  Match: Boolean;
begin
  Result := '';
  MatchCount := 0;
  PosList := TStringList.Create;
  try
    FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
    try
      SetLength(SubBytes, Length(Substring));
      for i := 1 to Length(Substring) do
        SubBytes[i-1] := Byte(Substring[i]);
      FilePos := 0;
      repeat
        ReadBytes := FS.Read(Buffer, SizeOf(Buffer));
        for i := 0 to ReadBytes - Length(SubBytes) do
        begin
          Match := True;
          for j := 0 to Length(SubBytes) - 1 do
            if Buffer[i + j] <> SubBytes[j] then
            begin
              Match := False;
              Break;
            end;
          if Match then
          begin
            Inc(MatchCount);
            PosList.Add(IntToStr(FilePos + i));
          end;
        end;
        FilePos := FilePos + ReadBytes - Length(SubBytes) + 1;
        if FilePos < 0 then FilePos := 0;
        if ReadBytes < SizeOf(Buffer) then Break;
        FS.Position := FilePos;
      until False;
    finally
      FS.Free;
    end;
    Result := IntToStr(MatchCount);
    if MatchCount > 0 then
      Result := Result + #13#10 + PosList.Text;
  except
    on E: Exception do
      Result := 'Ошибка: ' + E.Message;
  end;
  PosList.Free;
end;

function RunTask(Index: Integer; Params: PChar): PChar; stdcall;
var
  ParamList: TStringList;
begin
  LastErrorText := '';
  ResultBuffer := '';
  ParamList := TStringList.Create;
  try
    ParamList.Delimiter := ';';
    ParamList.StrictDelimiter := True;
    ParamList.DelimitedText := string(Params);
    case Index of
      0: // FileMaskSearch
        if ParamList.Count = 2 then
          ResultBuffer := FileMaskSearch(ParamList[0], ParamList[1])
        else
          LastErrorText := 'Ожидалось 2 параметра: Mask;Path';
      1: // SubstringSearch
        if ParamList.Count = 2 then
          ResultBuffer := SubstringSearch(ParamList[0], ParamList[1])
        else
          LastErrorText := 'Ожидалось 2 параметра: Substring;FilePath';
    else
      LastErrorText := 'Invalid task index';
    end;
  finally
    ParamList.Free;
  end;
  Result := PChar(ResultBuffer);
end;

function GetLastErrorText: PChar; stdcall;
begin
  Result := PChar(LastErrorText);
end;

end.