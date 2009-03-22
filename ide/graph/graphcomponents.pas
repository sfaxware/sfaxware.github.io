unit GraphComponents;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, Types, CodeCache;

const
  DefaultBlockWidth = 100;
  DefaultBlockHeight = 100;
  DefaultPortWidth = 8;
  DefaultPortHeight = 4;
  MinPortSpacing = 10;

type
  TCodeType = (ctSource, ctDescription);
  TCGraphPort = class(TGraphicControl)
  public
    constructor Create(AOwner: TComponent); override;
  protected
    procedure Paint; override;
    procedure UpdateBounds(Idx: Integer; Interval: Integer); virtual; abstract;
    procedure ValidateContainer(AComponent: TComponent); override;
  end;
  TCGraphInputPort = class(TCGraphPort)
  protected
    procedure UpdateBounds(Idx: Integer; Interval: Integer); override;
  end;
  TCGraphOutputPort = class(TCGraphPort)
  protected
    procedure UpdateBounds(Idx: Integer; Interval: Integer); override;
  end;
  TCGraphBlock = class(TGraphicControl)
  private
    _MouseDown: Boolean;
    _MousePos: TPoint;
    FInputComponentCount: Integer;
    FOutputComponentCount: Integer;
    procedure StartMove(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer ) ;
    procedure EndMove(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer ) ;
    procedure Move(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure MouseLeaved(Sender: TObject);
  public
    constructor Create(AOwner:TComponent);override;
    CodeBuffer: array[TCodeType] of TCodeBuffer;
    function Load: boolean;
    function Save: boolean;
  protected
    FSelected: Boolean;
    FType: string;
    procedure SetSeleted(AValue: Boolean);
    procedure Paint; override;
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
    property Typ: string read FType;
    property InputComponentCount: Integer read FInputComponentCount;
    property OutputComponentCount: Integer read FOutputComponentCount;
  end;

implementation

constructor TCGraphPort.Create(AOwner: TComponent);
begin
  Inherited Create(AOwner);
  UpdateBounds(-1, -1);
end;

procedure TCGraphPort.Paint;
var
  PaintRect: TRect;
  TXTStyle : TTextStyle;
begin
  //WriteLn('TCGraphPort.Paint ',Name,':',ClassName,' Parent.Name=',Parent.Name);
  PaintRect:=ClientRect;
  with Canvas do begin
    //WriteLn('TCGraphPort.Paint PaintRect=',PaintRect.Left,', ',PaintRect.TOp,', ',PaintRect.Right,', ',PaintRect.Bottom,', ',caption,', ', TXTStyle.SystemFont);
    If not Enabled then
      Brush.Color := clBtnShadow
    else
      Brush.Color:= clBlack;
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

procedure TCGraphPort.ValidateContainer(AComponent: TComponent);
begin
  if AComponent is TCGraphBlock then with AComponent as TCGraphBlock do begin
    ValidateInsert(Self);
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
  FType := 'TCGraphBlock';
end;

function TCGraphBlock.Load: boolean;
var
  CodeFile: array[TCodeType] of string;
  CodeType: TCodeType;
begin
  codeFile[ctSource] := '/tmp/' + Name + '.pas';
  codeFile[ctDescription] := '/tmp/' + Name + '.lfm';
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
  function WriteSourceTemplate: string;
  var
    f: System.Text;
  begin
    Result := '/tmp/' + Name + '.pas';
    if not FileExists(Result) then begin
      System.Assign(f, Result);
      ReWrite(f);
      WriteLn(f, 'unit ', Name, ';');
      WriteLn(f, 'interface');
      WriteLn(f, 'uses');
      WriteLn(f, '  Blocks;');
      WriteLn(f);
      WriteLn(f, 'type');
      WriteLn(f, '  T', Name, ' = class(TBlock)');
      WriteLn(f, '    procedure Execute; override;');
      WriteLn(f, '  end;');
      WriteLn(f);
      WriteLn(f, 'implementation');
      WriteLn(f, 'procedure T', Name, '.Execute;');
      WriteLn(f, 'begin;');
      WriteLn(f, '  {Write here your code}');
      WriteLn(f, 'end;');
      WriteLn(f);
      WriteLn(f, 'initialization');
      WriteLn(f);
      WriteLn(f, 'finalization');
      WriteLn(f);
      WriteLn(f, 'end.');
      System.Close(f);
    end;
  end;
  function WriteDescriptionTemplate: string;
  var
    f: System.Text;
  begin
    Result := '/tmp/' + Name + '.lfm';
    System.Assign(f, Result);
    ReWrite(f);
    WriteLn(f, 'object ', Name, ': T' + Name);
    WriteLn(f, '  Name = ''', Name, '''');
    WriteLn(f, '  Typ = ''', Typ, '''');
    WriteLn(f, '  Left = ', Left);
    WriteLn(f, '  Top = ', Top);
    WriteLn(f, '  Width = ', Width);
    WriteLn(f, '  Height = ', Height);
    WriteLn(f, 'end');
    System.Close(f);
  end;
var
  CodeType: TCodeType;
begin
  for CodeType := Low(CodeType) To High(CodeType) do
    if Assigned(CodeBuffer[CodeType]) then
      CodeBuffer[CodeType].Save;
  WriteSourceTemplate;
  WriteDescriptionTemplate;
  Result := true;
end;

procedure TCGraphBlock.StartMove(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Sender = Self then case Button of
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
  _MouseDown := False;
end;

procedure TCGraphBlock.MouseLeaved(Sender: TObject);
begin
  _MouseDown := False;
end;

procedure TCGraphBlock.Move(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  dx, dy: Integer;
  i: Integer;
begin
  if(Sender = Self)and _MouseDown then begin
    X += Left;           
    Y += Top;
    dx := X - _MousePos.x;
    dy := Y - _MousePos.y;
    _MousePos.x := X;
    _MousePos.y := Y;
    ChangeBounds(Left + dx, Top + dy, Width, Height);
    for i := 0 to ComponentCount - 1 do with Components[i] as TCGraphPort do begin
      ChangeBounds(Left + dx, Top + dy, Width, Height);
    end;
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
  with Canvas do begin
    //WriteLn('TCGraphBlock.Paint PaintRect=',PaintRect.Left,', ',PaintRect.TOp,', ',PaintRect.Right,', ',PaintRect.Bottom,', ',caption,', ', TXTStyle.SystemFont);
    if FSelected then begin
      Color := clBlack;
      Brush.Color := clGray;
      Rectangle(PaintRect);
      InflateRect(PaintRect, -2, -2);
    end;
    If not Enabled then
      Brush.Color := clBtnShadow
    else
      Brush.Color:= clRed;
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

procedure TCGraphBlock.ValidateInsert(AComponent: TComponent);
var
  i: Integer;
  Idx: Integer;
  dy: Integer;
  Component: TComponent;
begin
  Idx := 0;
  if AComponent is TCGraphInputPort then begin
    FInputComponentCount += 1;
    dy := Height div FInputComponentCount;
    for i := 0 to ComponentCount - 1 do begin
      Component := Components[i];
      if Component is TCGraphInputPort then with Component as TCGraphInputPort do begin
        UpdateBounds(Idx, dy);
        Idx += 1;
      end;
    end;
  end else if AComponent is TCGraphOutputPort then begin
    FOutputComponentCount += 1;
    dy := Height div FOutputComponentCount;
    for i := 0 to ComponentCount - 1 do begin
      Component := Components[i];
      if Component is TCGraphOutputPort then with Component as TCGraphOutputPort do begin
        UpdateBounds(Idx, dy);
        Idx += 1;
      end;
    end;
  end;
end;

end.

