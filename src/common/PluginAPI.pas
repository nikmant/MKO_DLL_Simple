unit PluginAPI;

interface

const
  // Максимальная длина строки для имени/описания задачи (рекомендация)
  MAX_TASK_NAME_LEN = 256;
  MAX_TASK_DESC_LEN = 512;
  MAX_TASK_PARAMS_LEN = 1024;
  
type
  // Индекс задачи
  TTaskIndex = Integer;

  // Сигнатуры экспортируемых функций DLL
  TGetTaskCountFunc = function: Integer; stdcall;
  TGetTaskNameFunc = function(Index: TTaskIndex): PChar; stdcall;
  TGetTaskDescriptionFunc = function(Index: TTaskIndex): PChar; stdcall;
  TGetTaskParamsFunc = function(Index: TTaskIndex): PChar; stdcall;
  TGetLastErrorTextFunc = function: PChar; stdcall; // опционально

  TRunTaskFunc = function(Index: TTaskIndex; TaskRunId: Integer; Params: PChar): PChar; stdcall;
  TStopTaskProc = procedure(TaskRunId: Integer); stdcall;

implementation

end. 