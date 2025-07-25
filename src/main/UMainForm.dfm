object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = #1052#1086#1076#1091#1083#1100#1085#1086#1077' '#1087#1088#1080#1083#1086#1078#1077#1085#1080#1077' (DLL '#1080#1085#1090#1077#1075#1088#1072#1094#1080#1103')'
  ClientHeight = 598
  ClientWidth = 894
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
    894
    598)
  PixelsPerInch = 96
  TextHeight = 13
  object TaskList: TListBox
    Left = 8
    Top = 8
    Width = 194
    Height = 200
    Anchors = [akLeft, akTop, akRight]
    ItemHeight = 13
    TabOrder = 0
    OnClick = TaskListClick
  end
  object TaskDesc: TMemo
    Left = 220
    Top = 8
    Width = 350
    Height = 60
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object ParamPanel: TPanel
    Left = 220
    Top = 80
    Width = 350
    Height = 128
    BevelOuter = bvLowered
    TabOrder = 2
  end
  object RunButton: TButton
    Left = 588
    Top = 130
    Width = 100
    Height = 30
    Caption = #1047#1072#1087#1091#1089#1090#1080#1090#1100
    TabOrder = 3
    OnClick = RunButtonClick
  end
  object TaskHistory: TListView
    Left = 8
    Top = 220
    Width = 872
    Height = 200
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
        Width = 80
      end
      item
        Caption = #1056#1077#1079#1091#1083#1100#1090#1072#1090
        Width = 400
      end>
    TabOrder = 4
    ViewStyle = vsReport
  end
  object ResultMemo: TMemo
    Left = 8
    Top = 430
    Width = 872
    Height = 150
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 5
  end
end
