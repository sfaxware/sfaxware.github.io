unit DesignGraph;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, XMLCfg, CodeCache, GraphComponents;

type
  TCGraphDesign = class(TScrollBox)
  private
    _Blocks:TFPList;
    procedure StreamBlock(Block: TCGraphBlock;var Project: TXMLConfig);
  public
    CodeBuffer: array[TCodeType] of TCodeBuffer;
    SelectedBlock:TCGraphBlock;
    SelectedInputPort: TCGraphInputPort;
    SelectedOutputPort: TCGraphOutputPort;
    constructor Create(AOwner: TComponent); override;
    function BlockCount: Integer; inline;
    function CreateNewBlock: TCGraphBlock; virtual;
    function Load: Boolean;
    function Load(Path: string; const Project: TXMLConfig): Boolean;
    function Save(DesignName: string; var Project: TXMLConfig): Boolean;
    procedure ConnectPorts(Sender: TObject);
    procedure InsertBlock(Block:TCGraphBlock);
    procedure RemoveBlock(var Block:TCGraphBlock);
    procedure SelectBlock(Sender: TObject);
  end;
  TScrollBox = class(TCGraphDesign);

implementation
uses
  Graphics, LFMTrees, CodeToolManager, BasicCodeTools;
                        
constructor TCGraphDesign.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  _blocks := TFPList.Create;
  //WriteLn('Created new TCGraphDesign class instance');
end;

function TCGraphDesign.BlockCount: Integer; inline;
begin
  Result := _Blocks.Count;
end;

procedure TCGraphDesign.ConnectPorts(Sender: TObject);
var
  Connector: TCGraphConnector;
begin
  Connector := TCGraphConnector.Create(Self);
  with Connector do begin
    Parent := Self;
    Connect(SelectedOutputPort, SelectedInputPort);
  end;
end;

function TCGraphDesign.CreateNewBlock:TCGraphBlock;
var
  BlockQuantity: integer = 0;
begin
  Result := TCGraphBlock.Create(Self);
  with Result do begin
    Parent := Self;
    Left := Random(Self.Width - Width);
    Top := Random(Self.Height - Height);
    BlockQuantity += 1;
    repeat
      try
        Name := 'Block' + IntToStr(BlockQuantity);
        break;
      except
        BlockQuantity += 1;
      end;
    until false;
    Caption := 'Block ' + IntToStr(BlockQuantity);
    OnClick := @SelectBlock;
    OnDblClick := Self.OnDblClick;
    PopupMenu := Self.PopupMenu;
    Selected := True;
  end;
end;

procedure TCGraphDesign.InsertBlock(Block:TCGraphBlock);
begin
  _blocks.Add(Block);
end;

procedure TCGraphDesign.RemoveBlock(var Block:TCGraphBlock);
begin
  _blocks.Remove(Block);
  Block.Destroy;
  Block := nil;
end;

procedure TCGraphDesign.SelectBlock(Sender: TObject);
begin
  if Sender is TCGraphBlock then begin
     if Assigned(SelectedBlock) then
       SelectedBlock.Selected := False;
    SelectedBlock := Sender as TCGraphBlock;
    SelectedBlock.Selected := True;
  end;
end;

procedure TCGraphDesign.StreamBlock(Block: TCGraphBlock;var Project: TXMLConfig);
var
  Path: string;
begin
  with Project, Block do begin
    Save;
    Path := 'design/blocks/' + Name + '/';
    SetValue(Path + 'name', Caption);
  end;
end;

function TCGraphDesign.Load: boolean;
var
  CodeFile: array[TCodeType] of string;
  CodeType: TCodeType;
begin
  codeFile[ctSource] := DesignDir + '/' + Name + '.pas';
  codeFile[ctDescription] := DesignDir + '/' + Name + '.lfm';
  for CodeType := Low(CodeType) To High(CodeType) do begin
    WriteLn(CodeFile[CodeType]);
    if Assigned(CodeBuffer[CodeType]) then
      CodeBuffer[CodeType].Reload
    else begin
      CodeBuffer[CodeType] := TCodeCache.Create.LoadFile(CodeFile[CodeType]);
    end;
  end;
  Result := true;
end;

function TCGraphDesign.Load(Path: string; const Project: TXMLConfig): Boolean;
var
  BlockPath: string;    
  BlocksCount: integer;
  DesignDescription: TLFMTree;
  BlockDescription: TLFMObjectNode;
begin
  if Load() then with CodeToolBoss do begin
    WriteLn('TCGraphDesign.Load : CodeBuffer[ctDescription] = "', CodeBuffer[ctDescription].Filename, '"');
    WriteLn('TCGraphDesign.Load : CodeBuffer[ctSource] = "', CodeBuffer[ctSource].Filename, '"');
    GetCodeToolForSource(CodeBuffer[ctSource], true, false);
    if not CheckLFM(CodeBuffer[ctSource], CodeBuffer[ctDescription], DesignDescription, False, False) then
      Exit(False);
  end;
  WriteLn('TCGraphDesign.Load : LFM created');
  with Project do begin
    for BlocksCount := 1 to GetValue(Path + 'count', 0) do begin
      WriteLn('**************');
      BlockPath := 'Design.Block' + IntToStr(BlocksCount);
      WriteLn('Loading "', BlockPath, '"');
      if Assigned(SelectedBlock) then
        SelectedBlock.Selected := False;
      SelectedBlock := TCGraphBlock.Create(Self);
      with SelectedBlock do begin
        Parent := Self;
        try
          Name := 'Block' + IntToStr(BlocksCount);
        except
          WriteLn('Invalid block name "', BlockPath, '"');
          Destroy;
          SelectedBlock := nil;
          continue;
        end;
        BlockDescription := FindObjectProperty(Name, nil, DesignDescription);
        if not Assigned(BlockDescription) then begin
          WriteLn('BlockDescription = nil');
          SelectedBlock.Free;
          continue;
        end;
        Load(DesignDescription, BlockDescription);
        OnClick := @SelectBlock;
        OnDblClick := Self.OnDblClick;
        PopupMenu := Self.PopupMenu;
        WriteLn('++++++++++++++');
      end;
      InsertBlock(SelectedBlock);
    end;
  end;
end;

function TCGraphDesign.Save(DesignName: string; var Project: TXMLConfig): Boolean;
var              
  Component: TComponent;
  i: Integer;
  f: System.Text;
begin
  with Project do begin
    SetValue('design/name', DesignName);
    SetValue('design/blocks/count', _Blocks.Count);
  end;
  System.Assign(f, DesignDir + '/' + Name + '.lfm');
  ReWrite(f);
  for i := 0 to ComponentCount - 1 do begin
    Component := Components[i];
    if Component is TCGraphConnector then with Component as TCGraphConnector do begin
      Save(f);
    end else if Component is TCGraphBlock then with Component as TCGraphBlock do begin
      Save(f);
      StreamBlock(Component as TCGraphBlock, Project);
    end; 
  end;
  Close(f);
  Result := True;
end;

{procedure Register;
begin
  RegisterComponents('GraphDesign', [TCGraphDesign]);
end;

initialization
  RegisterClass(TCGraphDesign);}
end.

