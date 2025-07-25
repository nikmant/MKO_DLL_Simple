unit UMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  PluginAPI;

type
  TTaskInfo = record
    DllHandle: HMODULE;
    Name: string;
    Description: string;
    Params: TArray<string>;
    Index: Integer;
    DllName: string;
    RunTask: TRunTaskFunc;
  end;

  TMainForm = class(TForm)
    TaskList: TListBox;
    TaskDesc: TMemo;
    ParamPanel: TPanel;
    RunButton: TButton;
    TaskHistory: TListView;
    ResultMemo: TMemo;
    procedure TaskListClick(Sender: TObject);
    procedure RunButtonClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure TaskHistoryClick(Sender: TObject);
  private
    FTaskInfos: TList;
    FParamEdits: TList;
    procedure BuildParamInputs;
    procedure AddTaskToHistory(const TaskName, Params, Status, Result: string);
    procedure LoadAllDllTasks;
    procedure ClearParamInputs;
    procedure CancelTask(TaskRunId: Integer);
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  IOUtils, Types, Generics.Collections, System.SyncObjs;

var
  // Уникальный идентификатор задачи
  GTaskRunId: Integer = 0;
  // Структура для сопоставления TaskRunId и потока/строки TaskHistory
  // Храним потоки для возможности прерывания
  TaskThreads: TDictionary<Integer, TThread>;

type
  // Класс потока для асинхронного выполнения задачи
  TTaskThread = class(TThread)
  private
    FTaskInfo: TTaskInfo;
    FParams: string;
    FTaskRunId: Integer;
    FMainForm: TMainForm;
    FResult: string;
    FStatus: string;
    FListItem: TListItem;
  protected
    procedure Execute; override;
    procedure UpdateStatus;
  public
    constructor Create(const TaskInfo: TTaskInfo; const Params: string; TaskRunId: Integer; MainForm: TMainForm; ListItem: TListItem);
  end;

constructor TTaskThread.Create(const TaskInfo: TTaskInfo; const Params: string; TaskRunId: Integer; MainForm: TMainForm; ListItem: TListItem);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FTaskInfo := TaskInfo;
  FParams := Params;
  FTaskRunId := TaskRunId;
  FMainForm := MainForm;
  FListItem := ListItem;
  FResult := '';
  FStatus := 'Выполнено';
end;

procedure TTaskThread.Execute;
begin
  try
    if Terminated then
    begin
      FStatus := 'Прервано';
      FResult := 'Задача была прервана до запуска.';
    end
    else
    begin
      FResult := FTaskInfo.RunTask(FTaskInfo.Index, PChar(FParams));
      if Terminated then
        FStatus := 'Прервано'
      else
        FStatus := 'Выполнено';
    end;
  except
    on E: Exception do
    begin
      FStatus := 'Ошибка';
      FResult := E.Message;
    end;
  end;
  Synchronize(UpdateStatus);
end;

procedure TTaskThread.UpdateStatus;
begin
  if Assigned(FListItem) then
  begin
    FListItem.SubItems[1] := FStatus;
    FListItem.SubItems[2] := FResult;
  end;
  // Удаляем поток из словаря после завершения
  if Assigned(TaskThreads) then
    TaskThreads.Remove(FTaskRunId);
end;

procedure TMainForm.FormActivate(Sender: TObject);
begin
  FTaskInfos := TList.Create;
  FParamEdits := TList.Create;
  if not Assigned(TaskThreads) then
    TaskThreads := TDictionary<Integer, TThread>.Create;
  LoadAllDllTasks;
end;

procedure TMainForm.LoadAllDllTasks;
var
  SearchRes: TSearchRec;
  DllPath, DllName: string;
  DllHandle: HMODULE;
  GetTaskCount: TGetTaskCountFunc;
  GetTaskName: TGetTaskNameFunc;
  GetTaskDescription: TGetTaskDescriptionFunc;
  GetTaskParams: TGetTaskParamsFunc;
  RunTask: TRunTaskFunc;
  i, TaskCount: Integer;
  TaskInfo: ^TTaskInfo;
  ParamStrs: string;
  ParamArr: TArray<string>;
  DllList: TStringDynArray;
begin
  TaskList.Items.Clear;
  FTaskInfos.Clear;
  DllList := TDirectory.GetFiles(ExtractFilePath(Application.ExeName), '*.dll');
  for DllName in DllList do
  begin
    DllPath := DllName;
    DllHandle := LoadLibrary(PChar(DllPath));
    if DllHandle = 0 then Continue;
    @GetTaskCount := GetProcAddress(DllHandle, 'GetTaskCount');
    @GetTaskName := GetProcAddress(DllHandle, 'GetTaskName');
    @GetTaskDescription := GetProcAddress(DllHandle, 'GetTaskDescription');
    @GetTaskParams := GetProcAddress(DllHandle, 'GetTaskParams');
    @RunTask := GetProcAddress(DllHandle, 'RunTask');
    if not Assigned(GetTaskCount) or not Assigned(GetTaskName) or not Assigned(GetTaskDescription) or not Assigned(GetTaskParams) or not Assigned(RunTask) then
    begin
      FreeLibrary(DllHandle);
      Continue;
    end;
    TaskCount := GetTaskCount;
    for i := 0 to TaskCount - 1 do
    begin
      New(TaskInfo);
      TaskInfo^.DllHandle := DllHandle;
      TaskInfo^.Name := GetTaskName(i);
      TaskInfo^.Description := GetTaskDescription(i);
      ParamStrs := GetTaskParams(i);
      TaskInfo^.Params := ParamStrs.Split([';']);
      TaskInfo^.Index := i;
      TaskInfo^.DllName := ExtractFileName(DllPath);
      TaskInfo^.RunTask := RunTask;
      FTaskInfos.Add(TaskInfo);
      TaskList.Items.Add(TaskInfo^.Name + ' (' + TaskInfo^.DllName + ')');
    end;
  end;
end;

procedure TMainForm.TaskHistoryClick(Sender: TObject);
begin
  if (TaskHistory.Selected <> nil) and (TaskHistory.Selected.SubItems.Count >= 3) then
    ResultMemo.Lines.Text := TaskHistory.Selected.SubItems[2]
  else
    ResultMemo.Lines.Clear;
end;

procedure TMainForm.TaskListClick(Sender: TObject);
var
  idx: Integer;
  TaskInfo: ^TTaskInfo;
  i: Integer;
  ParamLabel: TLabel;
  ParamEdit: TEdit;
begin
  idx := TaskList.ItemIndex;
  if (idx < 0) or (idx >= FTaskInfos.Count) then Exit;
  TaskInfo := FTaskInfos[idx];
  TaskDesc.Lines.Text := TaskInfo^.Description;
  BuildParamInputs;
end;

procedure TMainForm.BuildParamInputs;
var
  idx: Integer;
  TaskInfo: ^TTaskInfo;
  i: Integer;
  ParamLabel: TLabel;
  ParamEdit: TEdit;
begin
  ClearParamInputs;
  idx := TaskList.ItemIndex;
  if (idx < 0) or (idx >= FTaskInfos.Count) then Exit;
  TaskInfo := FTaskInfos[idx];
  for i := 0 to High(TaskInfo^.Params) do
  begin
    ParamLabel := TLabel.Create(ParamPanel);
    ParamLabel.Parent := ParamPanel;
    ParamLabel.Left := 8;
    ParamLabel.Top := 8 + i * 28;
    ParamLabel.Caption := TaskInfo^.Params[i] + ':';
    ParamEdit := TEdit.Create(ParamPanel);
    ParamEdit.Parent := ParamPanel;
    ParamEdit.Left := 120;
    ParamEdit.Top := 8 + i * 28;
    ParamEdit.Width := 200;
    FParamEdits.Add(ParamEdit);
  end;
end;

procedure TMainForm.ClearParamInputs;
var
  i: Integer;
begin
  for i := 0 to FParamEdits.Count - 1 do
    TObject(FParamEdits[i]).Free;
  FParamEdits.Clear;
  ParamPanel.DestroyComponents;
end;

procedure TMainForm.RunButtonClick(Sender: TObject);
var
  idx: Integer;
  TaskInfo: ^TTaskInfo;
  Params: string;
  i: Integer;
  ParamEdit: TEdit;
  TaskRunId: Integer;
  ListItem: TListItem;
  Thread: TTaskThread;
begin
  idx := TaskList.ItemIndex;
  if (idx < 0) or (idx >= FTaskInfos.Count) then Exit;
  TaskInfo := FTaskInfos[idx];
  Params := '';
  for i := 0 to FParamEdits.Count - 1 do
  begin
    ParamEdit := TEdit(FParamEdits[i]);
    if i > 0 then Params := Params + ';';
    Params := Params + ParamEdit.Text;
  end;
  Inc(GTaskRunId);
  ListItem := TaskHistory.Items.Add;
  ListItem.Caption := TaskInfo^.Name;
  ListItem.SubItems.Add(Params);
  ListItem.SubItems.Add('Выполняется');
  ListItem.SubItems.Add('');
  ListItem.Data := Pointer(GTaskRunId);
  Thread := TTaskThread.Create(TaskInfo^, Params, GTaskRunId, Self, ListItem);
  TaskThreads.Add(GTaskRunId, Thread);
end;

procedure TMainForm.AddTaskToHistory(const TaskName, Params, Status, Result: string);
var
  Item: TListItem;
begin
  Item := TaskHistory.Items.Add;
  Item.Caption := TaskName;
  Item.SubItems.Add(Params);
  Item.SubItems.Add(Status);
  Item.SubItems.Add(Result);
end;

// Добавим процедуру для прерывания задачи по TaskRunId
procedure TMainForm.CancelTask(TaskRunId: Integer);
var
  Thread: TThread;
begin
  if TaskThreads.TryGetValue(TaskRunId, Thread) then
    Thread.Terminate;
end;

end. 