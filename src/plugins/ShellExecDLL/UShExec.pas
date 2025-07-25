unit UShExec;

interface

uses
  SysUtils, Classes, Windows, ShellAPI, PluginAPI;

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
    'ShellCommand',
    'OpenFileOrFolder'
  );
  TASK_DESCRIPTIONS: array[0..1] of string = (
    'Выполнение shell-команды (CreateProcess)',
    'Открытие файла или папки через ShellExecute'
  );
  TASK_PARAMS: array[0..1] of string = (
    'CommandLine;WorkingDir',
    'Path'
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

function ShellCommand(const CommandLine, WorkingDir: string): string;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  Success: BOOL;
  ExitCode: DWORD;
  WaitRes: DWORD;
begin
  Result := '';
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  FillChar(ProcessInfo, SizeOf(ProcessInfo), 0);
  Success := CreateProcess(nil, PChar(CommandLine), nil, nil, False, CREATE_NO_WINDOW, nil, PChar(WorkingDir), StartupInfo, ProcessInfo);
  if not Success then
  begin
    Result := 'Ошибка запуска: ' + SysErrorMessage(GetLastError);
    Exit;
  end;
  try
    WaitRes := WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    if WaitRes = WAIT_OBJECT_0 then
    begin
      if GetExitCodeProcess(ProcessInfo.hProcess, ExitCode) then
        Result := 'ExitCode: ' + IntToStr(ExitCode)
      else
        Result := 'Не удалось получить код завершения процесса';
    end
    else
      Result := 'Процесс не завершился корректно';
  finally
    CloseHandle(ProcessInfo.hProcess);
    CloseHandle(ProcessInfo.hThread);
  end;
end;

function OpenFileOrFolder(const Path: string): string;
var
  Res: HINST;
begin
  Res := ShellExecute(0, 'open', PChar(Path), nil, nil, SW_SHOWNORMAL);
  if Res <= 32 then
    Result := 'Ошибка ShellExecute: ' + IntToStr(Res)
  else
    Result := 'OK';
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
      0: // ShellCommand
        if ParamList.Count = 2 then
          ResultBuffer := ShellCommand(ParamList[0], ParamList[1])
        else
          LastErrorText := 'Ожидалось 2 параметра: CommandLine;WorkingDir';
      1: // OpenFileOrFolder
        if ParamList.Count = 1 then
          ResultBuffer := OpenFileOrFolder(ParamList[0])
        else
          LastErrorText := 'Ожидался 1 параметр: Path';
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