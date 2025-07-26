unit UEndlessLoop;

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
  TASK_COUNT = 1;
  TASK_NAMES: array[0..0] of string = (
    'EndlessLoop'
  );
  TASK_DESCRIPTIONS: array[0..0] of string = (
    'Бесконечный цикл в течение N секунд'
  );
  TASK_PARAMS: array[0..0] of string = (
    'Seconds'
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

function EndlessLoop(const Seconds: string): string;
var
  Duration: Integer;
  StartTime: TDateTime;
  i: Integer;
begin
  Result := '';
  try
    Duration := StrToInt(Seconds);
    if Duration <= 0 then
    begin
      Result := 'Ошибка: количество секунд должно быть больше 0';
      Exit;
    end;
    
    StartTime := Now;
    i := 0;
    
    // Бесконечный цикл до истечения времени
    while True do
    begin
      Inc(i);      
      if (Now - StartTime) * 24 * 60 * 60 >= Duration then
        Break;
    end;
    
    Result := 'Completed. Iterations: ' + IntToStr(i);
  except
    on E: Exception do
      Result := 'Ошибка: ' + E.Message;
  end;
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
      0: // EndlessLoop
        if ParamList.Count = 1 then
          ResultBuffer := EndlessLoop(ParamList[0])
        else
          LastErrorText := 'Ожидался 1 параметр: Seconds';
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