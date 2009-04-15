unit GraphComponents;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, Types, CodeCache, LFMTrees;

const
  DefaultBlockWidth = 100;
  DefaultBlockHeight = 100;
  DefaultPortWidth = 10;
  DefaultPortHeight = 10;
  MinPortSpacing = 10;

var
  DesignDir: string;

type
  TCodeType = (ctSource, ctDescription);
  TCGraphConnector = class;
  TCGraphPort = class(TGraphicControl)
  private
    FConnector: TCGraphConnector;
  protected
    procedure HandleMouseEnterLeaveEvents(Sender: TObject); virtual;
    procedure HandleMouseDownEvents(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure HandleMouseUpEvents(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Paint; override;
    procedure UpdateBounds(Idx: Integer; Interval: Integer); virtual; abstract;
    procedure ValidateContainer(AComponent: TComponent); override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetUpdatedDescription: string;
    function Load(const DesignDescription: TLFMTree; ContextNode:TLFMObjectNode): Boolean;
  end;
  TCGraphInputPort = class(TCGraphPort)
  protected
    procedure Paint; override;
    procedure UpdateBounds(Idx: Integer; Interval: Integer); override;
  end;
  TCGraphOutputPort = class(TCGraphPort)
  protected
    procedure Paint; override;
    procedure UpdateBounds(Idx: Integer; Interval: Integer); override;
  end;
  TPortType = class of TCGraphPort;
  TCGraphBlock = class(TGraphicControl)
  private
    _MouseDown: Boolean;
    _MousePos: TPoint;
    FInputComponentCount: Integer;
    FOutputComponentCount: Integer;
    procedure StartMove(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure EndMove(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Move(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure MouseLeaved(Sender: TObject);
  public
    CodeBuffer: array[TCodeType] of TCodeBuffer;
    constructor Create(AOwner: TComponent);override;
    function GetDescription: TLFMTree;
    function GetUpdatedDescription: string;
    function Load: boolean;
    function Load(const DesignDescription: TLFMTree; ContextNode:TLFMObjectNode): Boolean;
    function Save: boolean;
  protected
    FSelected: Boolean;
    procedure SetSeleted(AValue: Boolean);
    procedure Paint; override;
    procedure UpdatePortsBounds(PortType: TPortType);
    procedure ValidateInsert(AComponent: TComponent); override;
  published
    property Selected: Boolean read FSelected write SetSeleted;
    property BorderSpacing;
    property Constraints;
    property Caption;
    property Enabled;
    property Font;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnPaint;
    property OnResize;
    property ShowHint;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property InputComponentCount: Integer read FInputComponentCount;
    property OutputComponentCount: Integer read FOutputComponentCount;
  end;
  TCGraphConnector = class(TGraphicControl)
  private
    FInputPort: TCGraphInputPort;
    FOutputPort: TCGraphOutputPort;
    FPoints: array of TPoint;
  public
    constructor Create(AOwner: TComponent); override;
    function GetUpdatedDescription: string;
    procedure Connect(AOutputPort: TCGraphOutputPort; AInputPort: TCGraphInputPort);
  protected
    procedure Paint; override;
    procedure SetInputPort(Value: TCGraphInputPort);
    procedure SetOutputPort(Value: TCGraphOutputPort);
    procedure UpdatePoints; virtual;
  published
    property InputPort: TCGraphInputPort read FInputPort write SetInputPort;
    property OutputPort: TCGraphOutputPort read FoutputPort write SetOutputPort;
  end;

function GetPropertyValue(ContextNode: TLFMObjectNode; PropertyName: string; Self: TLFMTree): string;
function FindObjectProperty(ContextNode: TLFMTreeNode; Self: TLFMTree): TLFMObjectNode;
function FindObjectProperty(PropertyPath: string; ContextNode: TLFMTreeNode; Self: TLFMTree): TLFMObjectNode;

implementation
uses
  math, DesignGraph, CodeToolManager, CodeWriter;

type
  TConnection = array of TPoint;

function GetPropertyValue(ContextNode: TLFMObjectNode; PropertyName: string; Self: TLFMTree): string;
var
  PropertyNode: TLFMPropertyNode;
  ValueNode: TLFMTreeNode;
  c: char;
  p: integer;
  Digits: set of Char;
begin
  while Assigned(ContextNode) do with ContextNode do begin
    PropertyName := Name + '.' + PropertyName;
    ContextNode := Parent as TLFMObjectNode;
  end;
  Result := '';
  PropertyNode := Self.FindProperty(PropertyName, nil);
  ValueNode := PropertyNode.Next;
  //WriteLn('GetPropertyValue : PropertyName = ', PropertyName, ', PropertyType = ', Integer(ValueNode.TheType));
  if ValueNode.TheType = lfmnValue then with ValueNode as TLFMValueNode do
    case ValueType of
      lfmvString: Result := ReadString;
      lfmvInteger: begin
        p := StartPos;
        c := Tree.LFMBuffer.Source[p];
        Digits := [];
        case c of
          '0'..'9': Digits := ['0'..'9'];
          '$': begin
            Digits := ['0'..'9', 'A'..'F', 'a'..'f'];
            Result += c;
            p += 1;
            c:= Tree.LFMBuffer.Source[p];
          end;
        else
          WriteLn('Invalid integer start digit "', c, '"');
        end;
        while c in Digits do begin
          Result += c;
          p += 1;
          c := Tree.LFMBuffer.Source[p];
        end;
      end;
      lfmvSymbol: begin
        p := StartPos;
        c := Tree.LFMBuffer.Source[p];
        while c in ['0'..'9', 'A'..'Z', 'a'..'z', '_', '.'] do begin
          Result += c;
          p += 1;
          c := Tree.LFMBuffer.Source[p]
        end;
      end;
    else
      WriteLn('GetPropertyValue : Unsupported node type "', Integer(ValueType), '"');
    end;
  //WriteLn('GetPropertyValue(', PropertyName, ') = "', Result, '"');
end;

function FindObjectProperty(ContextNode: TLFMTreeNode; Self: TLFMTree): TLFMObjectNode;
var
  Node: TLFMTreeNode;
  p: LongInt;
  FirstPart: String;
  RestParts: String;
begin
  if Assigned(ContextNode) then
    Node := ContextNode.NextSibling
  else
    Node := Self.Root.FirstChild;
  while Node <> nil do begin
    if Node is TLFMObjectNode then begin
      Result := Node as TLFMObjectNode;
      //WriteLn('Name = ', Result.Name, ', Type = ', Result.TypeName);
      Exit;
    end;
    Node := Node.NextSibling;
  end;
  Result:=nil;
end;

function FindObjectProperty(PropertyPath: string; ContextNode: TLFMTreeNode; Self: TLFMTree): TLFMObjectNode;
var
  p: LongInt;
  FirstPart: String;
  RestParts: String;
begin
  p:=System.Pos('.', PropertyPath);
  if p > 0 then begin
    FirstPart:=copy(PropertyPath, 1, p - 1);
    RestParts:=copy(PropertyPath, p + 1, length(PropertyPath));
  end else begin
    FirstPart := PropertyPath;
    RestParts := '';
  end;
  //WriteLn('FindObjectProperty : FirstPart = ', FirstPart, ', RestParts = ', RestParts);
  repeat
    Result := FindObjectProperty(ContextNode, Self);
    ContextNode := Result;
  until (Result = nil) or (SysUtils.CompareText(Result.Name, PropertyPath) = 0);
end;

function Translate(Points: TConnection; dx, dy: Integer): TConnection;
var
  l: Integer;
begin
  l := Length(Points);
  SetLength(Result, l);
  while l > 0 do begin
    l -= 1;
    Result[l].x := Points[l].x + dx;
    Result[l].y := Points[l].y + dy;
  end;
end;

constructor TCGraphPort.Create(AOwner: TComponent);
begin
  Inherited Create(AOwner);
  UpdateBounds(-1, -1);
  OnMouseEnter := @HandleMouseEnterLeaveEvents;
  OnMouseLeave := @HandleMouseEnterLeaveEvents;
  OnMouseDown := @HandleMouseDownEvents;
  OnMouseUp := @HandleMouseUpEvents;
  Name := 'Port' + IntToStr(Owner.ComponentCount);
end;

procedure TCGraphPort.HandleMouseEnterLeaveEvents(Sender: TObject);
begin
  //WriteLn('MouseEntered = ', MouseEntered);
  Repaint;
end;

procedure TCGraphPort.HandleMouseDownEvents(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  //WriteLn('TCGraphPort.HandleMouseDownEvents');
  case Button of
    mbLeft:with Parent as TCGraphDesign do begin
      if Self is TCGraphOutputPort then
       SelectedOutputPort := Self as TCGraphOutputPort
      else
       SelectedOutputPort := nil;
    end;
  end;
end;

procedure TCGraphPort.HandleMouseUpEvents(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  //WriteLn('TCGraphPort.HandleMouseUpEvents');
  case Button of
    mbLeft:with Parent as TCGraphDesign do begin
      if (Self is TCGraphInputPort) and (Assigned(SelectedOutputPort)) then begin
        SelectedInputPort := Self as TCGraphInputPort;
        //WriteLn('SelectedOutputPort = ', SelectedOutputPort.Top, ', ', SelectedOutputPort.Left);
        //WriteLn('SelectedInputPort = ', SelectedInputPort.Top, ', ', SelectedInputPort.Left);
        ConnectPorts(Self);
      end else
        SelectedInputPort := nil;
    end;
  end;
end;

procedure TCGraphPort.Paint;
var
  PaintRect: TRect;
  TXTStyle : TTextStyle;
begin
  inherited Paint;
  PaintRect := ClientRect;
  Color := clBlack;
  with Canvas do begin
    with Brush do begin
      Style := bsSolid;
      Color := clWhite;
      Rectangle(PaintRect);
      If not Enabled then
        Color := clBtnShadow
      else if MouseEntered then
        Color := clYellow
      else
        Color:= clBlack;
    end;
  end;
end;

function TCGraphPort.Load(const DesignDescription: TLFMTree; ContextNode:TLFMObjectNode): Boolean;
var
  Path: string;
begin
  Path := '';
  while Assigned(ContextNode) do with ContextNode do begin
    Path := Name + '.' + Path;
    ContextNode := Parent as TLFMObjectNode;
  end;
  //WriteLn('TCGraphPort : Path = ', Path);
//  Left := StrToInt(GetPropertyValue(DesignDescription, Path + 'Left'));
//  Top := StrToInt(GetPropertyValue(DesignDescription, Path + 'Top'));
  Color := clBlack;
//  Caption := GetPropertyValue(DesignDescription, Path + 'Name');
  Result := True;
end;

function TCGraphPort.GetUpdatedDescription: string;
var
  PortType: string;
begin
  if Self is TCGraphInputPort then
    PortType := 'Input'
  else if Self is TCGraphOutputPort then
    PortType := 'Output'
  else
    PortType := '';
  Result := '    object ' + Name + ': T' + PortType + 'Port' + LineEnding +
    '    end' + LineEnding;
end;

procedure TCGraphPort.ValidateContainer(AComponent: TComponent);
begin
  if AComponent is TCGraphBlock then with AComponent as TCGraphBlock do begin
    ValidateInsert(Self);
  end;
end;

procedure TCGraphInputPort.Paint;
var
  PaintRect: TRect;
  Triangle: array[0..2] of TPoint;
begin
  inherited Paint;
  PaintRect := ClientRect;
  with PaintRect do begin
    Triangle[0] := Point(Left, Top + Height div 2);
    Triangle[1] := Point(Left + Width, Top);
    Triangle[2] := Point(Left + Width, Top + Height - 1);
  end;
  with Canvas do begin
    Polygon(Triangle);
  end;
end;

procedure TCGraphInputPort.UpdateBounds(Idx: Integer; Interval: Integer);
var
  PortTop, PortLeft: Integer;
begin
  with Owner as TCGraphBlock do begin
    if Interval <= 0 then begin
      Interval := Height div FInputComponentCount;
    end;
    if idx < 0 then begin
      idx := FInputComponentCount - 1;
    end;
    PortTop := Top + idx * Interval + Interval div 2 - DefaultPortHeight div 2;
    PortLeft := Left + Width;
  end;
  //WriteLn('idx = ', idx, ' PortTop = ', PortTop, ' PortLeft = ', PortLeft);
  ChangeBounds(PortLeft, PortTop, DefaultPortWidth, DefaultPortHeight);
  if Assigned(FConnector) then with FConnector do begin
    UpdatePoints;
  end;
end;

procedure TCGraphOutputPort.Paint;
var
  PaintRect: TRect;
  Triangle: array[0..2] of TPoint;
begin
  inherited Paint;
  PaintRect := ClientRect;
  with PaintRect do begin
    Triangle[0] := Point(Left, Top + Height div 2);
    Triangle[1] := Point(Left + Width, Top);
    Triangle[2] := Point(Left + Width, Top + Height - 1);
  end;
  with Canvas do begin
    Polygon(Triangle);
  end;
end;

procedure TCGraphOutputPort.UpdateBounds(Idx: Integer; Interval: Integer);
var
  PortTop, PortLeft: Integer;
begin
  with Owner as TCGraphBlock do begin
    if Interval <= 0 then begin
      Interval := Height div FOutputComponentCount;
    end;
    if Idx < 0 then begin
      Idx := FOutputComponentCount - 1;
    end;
    PortTop := Top + Idx * Interval + Interval div 2 - DefaultPortHeight div 2;
    PortLeft := Left - DefaultPortWidth;
  end;
  //WriteLn('idx = ', idx, ' PortTop = ', PortTop, ' PortLeft = ', PortLeft);
  ChangeBounds(PortLeft, PortTop, DefaultPortWidth, DefaultPortHeight);
  if Assigned(FConnector) then with FConnector do begin
    UpdatePoints;
  end;
end;

constructor TCGraphBlock.Create(AOwner:TComponent);
begin
  inherited Create(AOwner);
  FInputComponentCount := 0;
  FOutputComponentCount := 0;
  Width := DefaultBlockWidth;
  Height := DefaultBlockHeight;
  FSelected := False;
  OnMouseDown := @StartMove;
  OnMouseUp := @EndMove;
  OnMouseMove := @Move;
  OnMouseLeave := @MouseLeaved;
  Canvas.Brush.Color := clRed;
end;

function TCGraphBlock.GetDescription: TLFMTree;
begin
  if Load then with CodeToolBoss do begin
    GetCodeToolForSource(CodeBuffer[ctSource], true, false);
    if not CheckLFM(CodeBuffer[ctSource], CodeBuffer[ctDescription], Result, False, False) then
      Result := nil;
  end;
end;

function TCGraphBlock.Load(const DesignDescription: TLFMTree; ContextNode:TLFMObjectNode): Boolean;
var
  ChildNode: TLFMTreeNode;
  PortDescription: TLFMObjectNode;
  Port: TCGraphPort;
begin
  ChildNode := ContextNode.FirstChild;
  Left := StrToInt(GetPropertyValue(ContextNode, 'Left', DesignDescription));
  Top := StrToInt(GetPropertyValue(ContextNode, 'Top', DesignDescription));
  Canvas.Brush.Color := StrToInt(GetPropertyValue(ContextNode, 'Color', DesignDescription));
  Caption := GetPropertyValue(ContextNode, 'Name', DesignDescription);
  Selected := True;
  PortDescription := FindObjectProperty(ChildNode, DesignDescription);
  while Assigned(PortDescription) do begin
    //WriteLn('PortDescription.TypeName = ', PortDescription.TypeName);
    if PortDescription.TypeName = 'TOutputPort' then
      Port := TCGraphOutputPort.Create(Self)
    else if PortDescription.TypeName = 'TInputPort' then
      Port := TCGraphInputPort.Create(Self)
    else
      Exit(False);
    with Port do begin
      Parent := Self.Parent;
      Load(DesignDescription, PortDescription);
      OnDblClick := Self.OnDblClick;
    end;
    PortDescription := FindObjectProperty(PortDescription, DesignDescription);
  end;
  Result := True;
end;

function TCGraphBlock.Load: boolean;
var
  CodeFile: array[TCodeType] of string;
  CodeType: TCodeType;
begin
  codeFile[ctSource] := DesignDir + '/' + Name + '.pas';
  codeFile[ctDescription] := DesignDir + '/' + Name + '.lfm';
  for CodeType := Low(CodeType) To High(CodeType) do begin
    if Assigned(CodeBuffer[CodeType]) then
      CodeBuffer[CodeType].Reload
    else begin
      CodeBuffer[CodeType] := TCodeCache.Create.LoadFile(CodeFile[CodeType]);
    end;
  end;
  Result := true;
end;

function TCGraphBlock.Save: boolean;
var
  CodeType: TCodeType;
  CodeFileName: string;
begin
  Result := true;
  CodeFileName := DesignDir + '/' + Name + '.lfm';
  GetCodeBuffer(CodeFileName, Self, CodeBuffer[ctDescription]);
  CodeBuffer[ctDescription].Source := GetUpdatedDescription;
  Result := CodeBuffer[ctDescription].Save;
  CodeFileName := DesignDir + '/' + Name + '.pas';
  GetCodeBuffer(CodeFileName, Self, CodeBuffer[ctSource]);
  UpdateUsedBlocks(Self, CodeBuffer[ctSource]);
  Result := Result and CodeBuffer[ctSource].Save;
  for CodeType := Low(CodeType) To High(CodeType) do
    if not Assigned(CodeBuffer[CodeType]) then
      Result := Load;
end;

function TCGraphBlock.GetUpdatedDescription: string;
var
  i: Integer;
begin
  Result := '  object ' + Name + ': T' + Name + LineEnding +
    '    Name = ''' + Caption + '''' + LineEnding +
    '    Color = $' + HexStr(Canvas.Brush.Color, 8) + LineEnding +
    '    Left = ' + IntToStr(Left) + LineEnding +
    '    Top = ' + IntToStr(Top) + LineEnding +
    '    Width = ' + IntToStr(Width) + LineEnding +
    '    Height = ' + IntToStr(Height) + LineEnding;
  for i := 0 to ComponentCount - 1 do with Components[i] as TCGraphPort do begin
    Result += GetUpdatedDescription;
  end;
  Result += '  end' + LineEnding;
end;

procedure TCGraphBlock.StartMove(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  case Button of
    mbLeft:begin
      _MouseDown := True;
      _MousePos.x := X + Left;
      _MousePos.y := Y + Top;
    end;
    mbRight:begin
      PopupMenu.PopUp;
    end;
  end;
end;

procedure TCGraphBlock.EndMove(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer ) ;
begin
  case Button of
    mbLeft:begin
      _MouseDown := False;
    end;
  end;
end;

procedure TCGraphBlock.MouseLeaved(Sender: TObject);
begin
  _MouseDown := False;
end;

procedure TCGraphBlock.Move(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  dx, dy: Integer;
begin
  if(Sender = Self)and _MouseDown then begin
    X += Left;
    Y += Top;
    dx := X - _MousePos.x;
    dy := Y - _MousePos.y;
    _MousePos.x := X;
    _MousePos.y := Y;
    ChangeBounds(Left + dx, Top + dy, Width, Height);
    UpdatePortsBounds(TCGraphInputPort);
    UpdatePortsBounds(TCGraphOutputPort);
  end;
end;

procedure TCGraphBlock.SetSeleted(AValue: Boolean);
begin
  if FSelected <> AValue then begin
    FSelected := AValue;
    Refresh;
  end
end;

procedure TCGraphBlock.Paint;
var
  PaintRect: TRect;
  TXTStyle : TTextStyle;
begin
  //WriteLn('TCGraphBlock.Paint ',Name,':',ClassName,' Parent.Name=',Parent.Name);
  PaintRect:=ClientRect;
  //with PaintRect do WriteLn('TCGraphBlock.Paint PaintRect=', Left,', ', Top,', ', Right,', ', Bottom);
  with Canvas do begin
    if FSelected then begin
      Pen.Color := clBlack;
      Rectangle(PaintRect);
      InflateRect(PaintRect, -2, -2);
    end;
    If not Enabled then
      Brush.Color := clBtnShadow;
    Rectangle(PaintRect);
    if Caption <> '' then begin
      TXTStyle := Canvas.TextStyle;
      with TXTStyle do begin
        Opaque := False;
        Clipping := True;
        ShowPrefix := False;
        Alignment := taCenter;
        Layout := tlCenter;
      end;
    // set color here, otherwise SystemFont is wrong if the button was disabled before
      Font.Color := Self.Font.Color;
      TextRect(PaintRect, PaintRect.Left, PaintRect.Top, Caption, TXTStyle);
    end;
  end;
  inherited Paint;
end;

procedure TCGraphBlock.UpdatePortsBounds(PortType: TPortType);
var
  i: Integer;
  Idx: Integer;
  dy: Integer;
  Component: TComponent;
begin
  if (PortType = TCGraphInputPort) and (FInputComponentCount > 0) then
    dy := Height div FInputComponentCount
  else if (PortType = TCGraphOutputPort) and (FOutputComponentCount > 0) then
    dy := Height div FOutputComponentCount
  else
    Exit;
  Idx := 0;
  for i := 0 to ComponentCount - 1 do begin
    Component := Components[i];
    if Component is PortType then with Component as PortType do begin
      UpdateBounds(Idx, dy);
      Idx += 1;
    end;
  end;
end;

procedure TCGraphBlock.ValidateInsert(AComponent: TComponent);
begin
  if AComponent is TCGraphInputPort then begin
    FInputComponentCount += 1;
    UpdatePortsBounds(TCGraphInputPort);
  end else if AComponent is TCGraphOutputPort then begin
    FOutputComponentCount += 1;
    UpdatePortsBounds(TCGraphOutputPort);
  end;
end;

constructor TCGraphConnector.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Name := 'Connector' + IntToStr(AOwner.ComponentCount);
end;

function TCGraphConnector.GetUpdatedDescription: string;
begin
  Result := '  object ' + Name + ': TConnector' + LineEnding +
    '    OutputPort = ' + OutputPort.Owner.Name + '.' + OutputPort.Name + LineEnding +
    '    InputPort = ' + InputPort.Owner.Name + '.' + InputPort.Name + LineEnding +
    '  end' + LineEnding;
end;

procedure TCGraphConnector.Connect(AOutputPort: TCGraphOutputPort; AInputPort: TCGraphInputPort);
begin
  OutputPort := AOutputPort;
  InputPort := AInputPort;
end;

Procedure TCGraphConnector.Paint;
begin
  //WriteLn('TCGraphConnector.Paint Self=', Left,', ', Top,', ', Width,', ', Height);
  if Length(FPoints) > 0 then with Canvas do begin
    {if FSelected then begin
      Color := clBlack;
      Brush.Color := clGray;
      InflateRect(PaintRect, -2, -2);
    end;}
    If not Enabled then
      Color := clBtnShadow
    else
      Color:= clGreen;
    Polyline(Translate(FPoints, -Left, -Top));
  end;
  inherited Paint;
end;

procedure TCGraphConnector.SetInputPort(Value: TCGraphInputPort);
begin
  FInputPort := Value;
  FInputPort.FConnector := Self;
  if Assigned(FOutputPort) then begin
    UpdatePoints;
  end;
end;

procedure TCGraphConnector.SetOutputPort(Value: TCGraphOutputPort);
begin
  FOutputPort := Value;
  FOutputPort.FConnector := Self;
  if Assigned(FInputPort) then begin
    UpdatePoints;
  end;
end;

procedure TCGraphConnector.UpdatePoints;
begin
  SetLength(FPoints, 4);
  FPoints[0] := Point(FOutputPort.Left, FOutputPort.Top + FOutputPort.Height div 2);
  FPoints[3] := Point(FInputPort.Left + FInputPort.Width, FInputPort.Top + FInputPort.Height div 2);
  FPoints[1] := Point((FPoints[0].x + FPoints[3].x) div 2, FPoints[0].y);
  FPoints[2] := Point((FPoints[0].x + FPoints[3].x) div 2, FPoints[3].y);
  //WriteLn('OutputPort = (', FPoints[0].x, ', ', FPoints[0].y, ' ), InputPort = (', FPoints[3].x, ', ', FPoints[3].y, ' )');
  SetBounds(min(FOutputPort.Left, FInputPort.Left + FInputPort.Width), min(FOutputPort.Top + FOutputPort.Height div 2, FInputPort.Top + FInputPort.Height div 2), 1 + abs(FPoints[0].x - FPoints[3].x), 1 + abs(FPoints[0].y - FPoints[3].y));
end;

end.

