unit BlockBasics;

{$mode objfpc}{$H+}{$interfaces corba}

interface

uses
  Classes, FifoBasics;

type
  TDeviceRunFlags = (drfTerminated, drfBlockedByInput, drfBlockedByOutput);
  TDeviceRunStatus = set of TDeviceRunFlags;

  TIDevice = interface
    function GetName:string;
    property DeviceName: string read GetName;
  end;

  TCConnector = class;

  TCDevice = class(TComponent, TIDevice)
  private
    FDeviceName: string;
    function GetName: string;
  protected
    procedure ValidateContainer(AComponent: TComponent); override;
    procedure ValidateInsert(AComponent: TComponent); override; abstract;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property DeviceName: string read FDeviceName write FDeviceName;
  end;

  TCPort = class(TCDevice)
  private
    FConnector: TCConnector;
    function GetConnector: TCConnector;
    procedure SetConnector(Value: TCConnector);
  public
  end;

  TCInputPort = class(TCPort)
  protected
    function GetIsEmpty: Boolean;
  public
    property IsEmpty: Boolean read GetIsEmpty;
    function Pop(out Sample: Integer): Boolean;
  end;
  
  TCOutputPort = class(TCPort)
  protected
    function GetIsFull: Boolean;
  public
    property IsFull: Boolean read GetIsFull;
    function Push(Sample: Integer): Boolean;
  end;

  TCBlock = class(TCDevice)
  private
    FBlocks: array of TCBlock;
    FInputPorts: array of TCInputPort;
    FOutputPorts: array of TCOutputPort;
  protected
    FRunStatus: TDeviceRunStatus;
    procedure ValidateInsert(AComponent: TComponent); override;
    function GetRunStatus: TDeviceRunStatus; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    function GetInputQty: Integer;
    function GetOutputQty: Integer;
    function GetInputIdx(const InputName: string): Integer;
    function GetOutputIdx(const OutputName: string): Integer;
    procedure Execute; virtual;
    property RunStatus: TDeviceRunStatus read FRunStatus;
  end;

  TCConnector = class(TCDevice)
  private
    FOutputPort: TCOutputPort;
    FInputPort: TCInputPort;
    FSamples: TCFifo;
    procedure SetOutputPort(Output: TCOutputPort);
    procedure SetInputPort(Input:TCInputPort);
    function GetIsEmpty: Boolean;
    function GetIsFull: Boolean;
    function Push(Sample: Integer): Boolean;
    function Pop(out Sample: Integer): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    property IsEmpty: Boolean read GetIsEmpty;
    property IsFull: Boolean read GetIsFull;
  published
    property OutputPort: TCOutputPort read FOutputPort write SetOutputPort;
    property InputPort: TCInputPort read FInputPort write SetInputPort;
 end;

  TFuncName = string[31];
  TFuncPrefix = string[63];

function FuncB(name: TFuncName): TFuncPrefix;
function FuncC(name: TFuncName): TFuncPrefix;
function FuncE(name: TFuncName): TFuncPrefix;

implementation

uses
  LResources;

var
  FuncLevel: TFuncName;

function FuncB(name: TFuncName): TFuncPrefix;
begin
  Result := FuncLevel + '>>' + name + ': ';
  FuncLevel += '  ';
end;

function FuncC(name: TFuncName): TFuncPrefix;
begin
  Result := FuncLevel + name + ': ';
end;

function FuncE(name: TFuncName): TFuncPrefix;
begin
  SetLength(FuncLevel,  Length(FuncLevel) - 2);
  Result := FuncLevel + '<<' + name + ': ';
end;

function TCDevice.GetName: string;
begin
  Result := FDeviceName;
end;

procedure TCDevice.ValidateContainer(AComponent: TComponent);
begin
  //WriteLn(FuncB('TCDevice.ValidateContainer'), 'Name = ', Name, ', ClassName = ', ClassName, ', DeviceName = ', DeviceName, ', ComponentCount = ', ComponentCount);
  //with AComponent do begin
  //  WriteLn(FuncC('TCDevice.ValidateContainer'), 'Name = ', Name, ', ClassName = ', ClassName, ', DeviceName = ', DeviceName, ', ComponentCount = ', ComponentCount);
  //end;
  if AComponent is TCBlock then with AComponent as TCBlock do begin
    ValidateInsert(Self);
  end;
  //WriteLn(FuncE('TCDevice.ValidateContainer'), 'Name = ', Name, ', ClassName = ', ClassName, ', DeviceName = ', DeviceName, ', ComponentCount = ', ComponentCount);
end;

constructor TCDevice.Create(AOwner: TComponent);
  function InitComponentFromResource(Instance: TComponent; ClassType: TClass): Boolean;
  var
    FPResource: TFPResourceHandle;
    ResName: String;
    Stream: TStream;
    Reader: TReader;
    DestroyDriver: Boolean;
    Driver: TAbstractObjectReader;
  begin
    Result := False;
    Stream := nil;
    ResName := ClassType.ClassName;
    if Stream = nil then
    begin
      FPResource := FindResource(HInstance, PChar(ResName), RT_RCDATA);
      if FPResource <> 0 then
        Stream := TLazarusResourceStream.CreateFromHandle(HInstance, FPResource);
    end;
    if Stream = nil then
      Exit;
    DestroyDriver:=false;
    try
      Reader := CreateLRSReader(Stream, DestroyDriver);
      try
        Reader.ReadRootComponent(Instance);
      finally
        Driver := Reader.Driver;
        Reader.Free;
        if DestroyDriver then
          Driver.Free;
      end;
    finally
      Stream.Free;
    end;
    Result := True;
  end;
var
  cn: string;
begin
  if Assigned(AOwner) then begin
    cn := AOwner.ClassName;
  end else begin
    cn := 'nil';
  end;
  //WriteLn(FuncB('TCDevice.Create'), 'ClassName = ', ClassName, ', Name = ', Name, ', Owner.Name = ', cn, ', ComponentCount = ', ComponentCount);
  inherited Create(AOwner);
  if not InitComponentFromResource(Self, ClassType) then begin
    WriteLn('Failed to initilize component ', AOwner.Name, '.', Name, ': ', ClassName);
  end;
  if FDeviceName = '' then
    FDeviceName := Name;
  //WriteLn(FuncE('TCDevice.Create'), 'ClassName = ', ClassName, ', Name = ', Name, ', DeviceName = ', DeviceName, ', ComponentCount = ', ComponentCount);
end;

function TCPort.GetConnector: TCConnector;
begin
  Result := FConnector;
end;

procedure TCPort.SetConnector(Value: TCConnector);
begin
  FConnector := Value;
end;

function TCInputPort.GetIsEmpty: Boolean;
begin
  Result := Assigned(FConnector) and FConnector.IsEmpty;
end;

function TCInputPort.Pop(out Sample: Integer): Boolean;
begin
  //WriteLn(FuncB('TCInputPort.Pop'), 'Name = ', Owner.Name, '.', Name);
  if Assigned(FConnector) then begin
    //WriteLn(FuncC('TCInputPort.Pop'), 'Connector assigned');
    Result := FConnector.Pop(Sample);
  end else begin
    //WriteLn(FuncC('TCInputPort.Pop'), 'Connector not assigned');
    Result := False
  end;
  //WriteLn(FuncE('TCInputPort.Pop'), 'Name = ', Owner.Name, '.', Name);
end;

function TCOutputPort.GetIsFull: Boolean;
begin
  Result := Assigned(FConnector) and FConnector.IsFull;
end;

function  TCOutputPort.Push(Sample: Integer): Boolean;
begin
  WriteLn(FuncB('TCOutputPort.Push'));
  if Assigned(FConnector) then begin
    WriteLn(FuncC('TCOutputPort.Push'), 'Connector assigned');
    Result := FConnector.Push(Sample);
  end else begin
    WriteLn(FuncC('TCOutputPort.Push'), 'Connector not assigned');
    Result := False;
  end;
  WriteLn(FuncE('TCOutputPort.Push'));
end;

constructor TCBlock.Create(AOwner: TComponent);
var
  cn: string;
begin
  if Assigned(AOwner) then begin
    cn := AOwner.ClassName;
  end else begin
    cn := 'nil';
  end;
  //WriteLn(FuncB('TCBlock.Create(AOwner: TComponent)'), 'AOwner.ClassName = ', cn);
  inherited Create(AOwner);
  //WriteLn(FuncE('TCBlock.Create(AOwner: TComponent)'), 'AOwner.ClassName = ', cn);
end;

function TCBlock.GetInputQty: Integer;
begin
  Result := Length(FInputPorts);
end;

function TCBlock.GetOutputQty: Integer;
begin
  Result := Length(FOutputPorts);
end;

function TCBlock.GetInputIdx(const InputName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := Low(FInputPorts) to High(FInputPorts) do begin
    if FInputPorts[i].DeviceName = InputName then begin
      Exit(i);
    end;
  end;
end;

function TCBlock.GetOutputIdx(const OutputName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := Low(FOutputPorts) to High(FOutputPorts) do begin
    if FOutputPorts[i].DeviceName = OutputName then begin
      Exit(i);
    end;
  end;
end;

procedure TCBlock.ValidateInsert(AComponent: TComponent);
var
  l: Integer;
begin
  //WriteLn(FuncB('TCBlock.ValidateInsert'), 'Name = ', Name, ', ClassName = ', ClassName, ', DeviceName = ', DeviceName);
  //WriteLn(FuncC('TCBlock.ValidateInsert'), 'InputCount = ', Length(FInputPorts), ', OutputCount', Length(FOutputPorts), ', Blocks = ', Length(FBlocks));
  //WriteLn(FuncC('TCBlock.ValidateInsert'), 'AComponent.ClassName = ', AComponent.ClassName);
  if AComponent is TCInputPort then begin
    l := Length(FInputPorts);
    SetLength(FInputPorts, l + 1);
    FInputPorts[l] := AComponent as TCInputPort;
  end else if AComponent is TCOutputPort then begin
    l := Length(FOutputPorts);
    SetLength(FOutputPorts, l + 1);
    FOutputPorts[l] := AComponent as TCOutputPort;
  end else if AComponent is TCBlock then begin
    l := Length(FBlocks);
    SetLength(FBlocks, l + 1);
    FBlocks[l] := AComponent as TCBlock;
  end;
  //WriteLn(FuncC('TCBlock.ValidateInsert'), 'InputCount = ', Length(FInputPorts), ', OutputCount', Length(FOutputPorts), ', Blocks = ', Length(FBlocks));
  //WriteLn(FuncE('TCBlock.ValidateInsert'), 'Name = ', Name, ', ClassName = ', ClassName, ', DeviceName = ', DeviceName);
end;

function TCBlock.GetRunStatus: TDeviceRunStatus;
var
  i: Integer;
begin
  Result := FRunStatus;
end;

procedure TCBlock.Execute;
var
  i: Integer;
  BlockRunStatus: TDeviceRunStatus;
  RunBlock: Boolean;
begin
  WriteLn(FuncB('TCBlock.Execute'), 'Name = ', FDeviceName, ', BlocksCount = ', Length(FBlocks));
{  RunBlock := Length(FInputPorts) = 0;
  for i := Low(FInputPorts) to High(FInputPorts) do with FInputPorts[i].FConnector.FOutputPort.Owner as TCBlock do begin
    RunBlock := RunBlock or not (drfTerminated in RunStatus)
  end;
  if not RunBlock then begin
    Include(FRunStatus, drfTerminated);
    Exit;
  end;}
  BlockRunStatus := [drfTerminated];
  for i := Low(FBlocks) to High(FBlocks) do with FBlocks[i] do begin
    RunBlock := False;
    if not (drfTerminated in RunStatus) then  begin
      Exclude(BlockRunStatus, drfTerminated);
      RunBlock := True;
    end;
    if drfBlockedByInput in RunStatus then  begin
      Include(BlockRunStatus, drfBlockedByInput);
      RunBlock := False;
    end;
    if drfBlockedByOutput in RunStatus then  begin
      Include(BlockRunStatus, drfBlockedByOutput);
      RunBlock := False;
    end;
    WriteLn(FuncC('TCBlock.Execute'), 'Block[', i, '].DeviceName = ', DeviceName, ', Terminated = ', drfTerminated in RunStatus, ', BlockedByInput = ', drfBlockedByInput in RunStatus, ', BlockedByOutput = ', drfBlockedByOutput in RunStatus);
    if RunBlock then begin
      Execute;
    end;
  end;
  {FRunStatus := BlockRunStatus;
  RunBlock := Length(FOutputPorts) = 0;
  for i := Low(FOutputPorts) to High(FOutputPorts) do with FOutputPorts[i].FConnector.FInputPort.Owner as TCBlock do begin
    RunBlock := RunBlock or not (drfTerminated in RunStatus);
    WriteLn(FuncC('TCBlock.Execute'), 'OutputPort[', i, '].DeviceName = ', DeviceName, ', Terminated = ', drfTerminated in RunStatus);
  end;
  if not RunBlock then begin
    Include(FRunStatus, drfTerminated);
  end;}
  WriteLn(FuncE('TCBlock.Execute'), 'Name = ', FDeviceName, ', BlocksCount = ', Length(FBlocks));
end;

function TCConnector.GetIsEmpty: Boolean;
begin
  Result := FSamples.GetPendingQty = 0;
end;

function TCConnector.GetIsFull: Boolean;
begin
  Result := FSamples.GetAvailableQty = 0;
end;

constructor TCConnector.Create(AOwner: TComponent);
var
  cn: string;
begin
  if Assigned(AOwner) then begin
    cn := AOwner.ClassName;
  end else begin
    cn := 'nil';
  end;
  WriteLn(FuncB('TCConnector.Create'), 'AOwner.ClassName = ', cn);
  inherited Create(AOwner);
  WriteLn(FuncC('TCConnector.Create'), Name, '.InputPort = $', HexStr(PtrInt(FInputPort), 8));
  WriteLn(FuncC('TCConnector.Create'), Name, '.OutputPort = $', HexStr(PtrInt(FOutputPort), 8));
  FSamples := TCFifo.Create(2);
  WriteLn(FuncE('TCConnector.Create'), 'AOwner.ClassName = ', cn);
end;

procedure TCConnector.SetOutputPort(Output:TCOutputPort);
begin
  FOutputPort := Output;
  Output.FConnector := Self;
end;

procedure TCConnector.SetInputPort(Input: TCInputPort);
begin
  FInputPort := Input;
  Input.FConnector := Self;
end;

function TCConnector.Push(Sample: Integer): Boolean;
begin
  WriteLn(FuncB('TCConnector.Push'), Owner.Name, '.', Name, ', Sample = ', Sample, ', Samples.FreeQty = ', FSamples.GetAvailableQty);
  repeat
    Result := FSamples.Push(Pointer(Sample));
    if Result then with InputPort.Owner as TCBlock do begin
      Exclude(FRunStatus, drfBlockedByInput);
    end else with FInputPort.Owner as TCBlock do begin
      if drfTerminated in FRunStatus then with FOutputPort.Owner as TCBlock do begin
        Include(FRunStatus, drfTerminated);
      end else begin
        Execute;
      end;
    end;
  until Result;
  WriteLn(FuncE('TCConnector.Push'), Owner.Name, '.', Name, ', Sample = ', Sample, ', Samples.Qty = ', FSamples.GetPendingQty);
end;

function TCConnector.Pop(out Sample: Integer): Boolean;
begin
  WriteLn(FuncB('TCConnector.Pop'), Owner.Name, '.', Name, ', Sample = ', Sample);
  repeat
    Result := FSamples.Pop(Pointer(Sample));
    if Result then with OutputPort.Owner as TCBlock do begin
      Exclude(FRunStatus, drfBlockedByOutput);
    end else with FOutputPort.Owner as TCBlock do begin
      if drfTerminated in FRunStatus then with FInputPort.Owner as TCBlock do begin
        Include(FRunStatus, drfTerminated);
      end else begin
        Execute;
      end;
    end;
  until Result;
  WriteLn(FuncE('TCConnector.Pop'), Owner.Name, '.', Name, ', Sample = ', Sample);
end;

end.

