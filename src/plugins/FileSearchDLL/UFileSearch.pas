unit UFileSearch;

interface

uses
  SysUtils, Classes, Generics.Collections;

function GetTaskCount: Integer; stdcall;
function GetTaskName(Index: Integer): PChar; stdcall;
function GetTaskDescription(Index: Integer): PChar; stdcall;
function GetTaskParams(Index: Integer): PChar; stdcall;
function RunTask(Index: Integer; TaskRunId: Integer; Params: PChar): PChar; stdcall;
function GetLastErrorText: PChar; stdcall;
procedure StopTask(TaskRunId: Integer); stdcall;

implementation

var
  LastErrorText: string = '';
  ResultBuffer: string = '';
  TerminatedTasks: TList<Integer> = nil;

const
  TASK_COUNT = 2;
  TASK_NAMES: array[0..1] of string = (
    'FileMaskSearch',
    'SubstringSearch'
  );
  TASK_DESCRIPTIONS: array[0..1] of string = (
    'Поиск файлов по маске(ам) и папке (поддерживает множественные маски через |)',
    'Поиск вхождений последовательности символов в файле'
  );
  TASK_PARAMS: array[0..1] of string = (
    'Mask (пример: *.exe|*.doc|*.txt);Path',
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

function SplitMasks(const MaskString: string): TStringList;
var
  MaskList: TStringList;
begin
  MaskList := TStringList.Create;
  MaskList.Delimiter := '|';
  MaskList.StrictDelimiter := True;
  MaskList.DelimitedText := MaskString;
  Result := MaskList;
end;

function IsTaskTerminated(TaskRunId: Integer): Boolean;
begin
  Result := False;
  if (TerminatedTasks <> nil) then
    if (TerminatedTasks.IndexOf(TaskRunId) <> -1) then
      Result := True;
end;

procedure StopTask(TaskRunId: Integer); stdcall;
begin
  TerminatedTasks.Add(TaskRunId);
end;

function FileMaskSearchRecursive(TaskRunId: Integer; const Mask, Path: string; FileList: TStringList): Integer;
var
  SR: TSearchRec;
  CurrentDir, SearchPath, SubDir: string;
  Found: Integer;
  DirList: TStringList;
  MaskList: TStringList;
  i: Integer;
begin
  Result := 0;
  DirList := TStringList.Create;
  MaskList := SplitMasks(Mask);
  try
    DirList.Add(Path);
    // Используем DirList как стек: пока есть папки для обработки
    while (DirList.Count > 0) do
    begin
      if IsTaskTerminated(TaskRunId) then Exit;
      CurrentDir := DirList[DirList.Count - 1];
      DirList.Delete(DirList.Count - 1);
      
      // Обрабатываем каждую маску отдельно
      for i := 0 to MaskList.Count - 1 do
      begin
        if IsTaskTerminated(TaskRunId) then Exit;
        // Ищем файлы по текущей маске в текущей папке
        SearchPath := IncludeTrailingPathDelimiter(CurrentDir) + MaskList[i];
        Found := FindFirst(SearchPath, faAnyFile and not faDirectory, SR);
        if Found = 0 then
        try
          repeat
            if IsTaskTerminated(TaskRunId) then Exit;
            FileList.Add(IncludeTrailingPathDelimiter(CurrentDir) + SR.Name);
          until FindNext(SR) <> 0;
        finally
          FindClose(SR);
        end;
      end;
      
      // Ищем подпапки и добавляем их в стек
      Found := FindFirst(IncludeTrailingPathDelimiter(CurrentDir) + '*', faDirectory, SR);
      if Found = 0 then
      try
        repeat
          if ((SR.Attr and faDirectory) <> 0) and (SR.Name <> '.') and (SR.Name <> '..') then
          begin
            if IsTaskTerminated(TaskRunId) then Exit;
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
    MaskList.Free;
  end;
end;

function FileMaskSearch(TaskRunId: Integer; const Mask, Path: string): string;
var
  FileList: TStringList;
begin
  Result := '';
  if IsTaskTerminated(TaskRunId) then
  begin
    Result := Result+'Прервано';
    Exit;
  end;
  FileList := TStringList.Create;
  try
    FileMaskSearchRecursive(TaskRunId, Mask, Path, FileList);
    if IsTaskTerminated(TaskRunId) then
    begin
      Result := Result+'Прервано';
      Exit;
    end;
    Result := IntToStr(FileList.Count);
    if FileList.Count > 0 then
      Result := Result + #13#10 + FileList.Text;
  finally
    FileList.Free;
  end;
end;

function SubstringSearch(TaskRunId: Integer; const Substring, FilePath: string): string;
var
  FS: TFileStream;
  Buffer: array[0..4095] of Byte;
  ReadBytes, i, j, MatchCount: Integer;
  SubBytes: TBytes;
  PosList: TStringList;
  FilePos: Int64;
  Match: Boolean;
begin
  Result := '';
  if IsTaskTerminated(TaskRunId) then
  begin
    Result := Result+'Прервано';
    Exit;
  end;
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
        if IsTaskTerminated(TaskRunId) then
        begin
          Result := Result+'Прервано';
          Exit;
        end;
        ReadBytes := FS.Read(Buffer, SizeOf(Buffer));
        for i := 0 to ReadBytes - Length(SubBytes) do
        begin
          if IsTaskTerminated(TaskRunId) then
          begin
            Result := Result+'Прервано';
            Exit;
          end;
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
    if IsTaskTerminated(TaskRunId) then
    begin
      Result := Result+'Прервано';
      Exit;
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

function RunTask(Index: Integer; TaskRunId: Integer; Params: PChar): PChar; stdcall;
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
          ResultBuffer := FileMaskSearch(TaskRunId, ParamList[0], ParamList[1])
        else
          LastErrorText := 'Ожидалось 2 параметра: Mask;Path (маски разделяются символом |)';
      1: // SubstringSearch
        if ParamList.Count = 2 then
          ResultBuffer := SubstringSearch(TaskRunId, ParamList[0], ParamList[1])
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

initialization
  TerminatedTasks := TList<Integer>.Create;
  TerminatedTasks.Capacity := 1000;

finalization
  TerminatedTasks.Free;

end.