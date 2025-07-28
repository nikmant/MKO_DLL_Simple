object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = #1052#1086#1076#1091#1083#1100#1085#1086#1077' '#1087#1088#1080#1083#1086#1078#1077#1085#1080#1077' (DLL '#1080#1085#1090#1077#1075#1088#1072#1094#1080#1103')'
  ClientHeight = 579
  ClientWidth = 918
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnActivate = FormActivate
  DesignSize = (
    918
    579)
  PixelsPerInch = 96
  TextHeight = 13
  object TaskList: TListBox
    Left = 8
    Top = 8
    Width = 194
    Height = 200
    ItemHeight = 13
    TabOrder = 0
    OnClick = TaskListClick
  end
  object TaskDesc: TMemo
    Left = 220
    Top = 8
    Width = 565
    Height = 60
    Anchors = [akLeft, akTop, akRight]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
    ExplicitWidth = 561
  end
  object ParamPanel: TPanel
    Left = 220
    Top = 80
    Width = 565
    Height = 128
    Anchors = [akLeft, akTop, akRight]
    BevelOuter = bvLowered
    TabOrder = 2
    ExplicitWidth = 561
  end
  object RunButton: TButton
    Left = 804
    Top = 178
    Width = 100
    Height = 30
    Anchors = [akTop, akRight]
    Caption = #1047#1072#1087#1091#1089#1090#1080#1090#1100
    TabOrder = 3
    OnClick = RunButtonClick
    ExplicitLeft = 800
  end
  object TaskHistory: TListView
    Left = 8
    Top = 220
    Width = 777
    Height = 181
    Anchors = [akLeft, akTop, akRight, akBottom]
    Columns = <
      item
        Caption = #1047#1072#1076#1072#1095#1072
        Width = 120
      end
      item
        Caption = #1055#1072#1088#1072#1084#1077#1090#1088#1099
        Width = 200
      end
      item
        Caption = #1057#1090#1072#1090#1091#1089
        Width = 120
      end
      item
        Caption = #1056#1077#1079#1091#1083#1100#1090#1072#1090
        Width = 290
      end>
    TabOrder = 4
    ViewStyle = vsReport
    OnChange = TaskHistoryChange
    OnClick = TaskHistoryClick
    ExplicitWidth = 773
  end
  object ResultMemo: TMemo
    Left = 8
    Top = 411
    Width = 777
    Height = 150
    Anchors = [akLeft, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 5
    ExplicitWidth = 773
  end
  object StopButton: TButton
    Left = 804
    Top = 371
    Width = 100
    Height = 30
    Anchors = [akTop, akRight]
    Caption = #1054#1089#1090#1072#1085#1086#1074#1080#1090#1100
    TabOrder = 6
    OnClick = StopButtonClick
    ExplicitLeft = 800
  end
end
