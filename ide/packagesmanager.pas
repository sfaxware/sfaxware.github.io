unit PackagesManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, ExtCtrls, StdCtrls, SysUtils, FileUtil, LResources, Forms, Controls,
  Graphics, Dialogs, XMLCfg;

type

  { TPackagesManagerForm }

  TPackagesManagerForm = class(TForm)
    CancelButton: TButton;
    ApplyButton: TButton;
    PackagesListCheckGroup: TCheckGroup;
    PackageFiles: TXMLConfig;
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure UpdateInstalledPackages(Sender: TObject);
  private
    PackagesList: TFPList;
  public
    function IndexOfPackage(PkgName: string): Integer;
    function PackageIsInstalled(PkgIndex: Integer): boolean;
    procedure InstallPackage(PkgIndex: Integer);
    procedure UninstallPackage(PkgIndex: Integer);
  end;

var
  PackagesManagerForm: TPackagesManagerForm;

implementation

uses
  Configuration;

const
  PackagesQty = 2;
  PackagesList: array[1..PackagesQty] of string[32] = ('rsdcore', 'toto');

{ TPackagesManagerForm }

function Compare(Item1, Item2: Pointer): Integer;
var
  S1, S2: PString;
begin
  S1 := Item1;
  S2 := Item2;
  Result := CompareStr(S1^, S2^);
end;

procedure TPackagesManagerForm.FormCreate(Sender: TObject);
  function BuildPackagesList: TFPList;
  var
    ProgPath, ProgDir, LibDir: string;
    SearchRec: TSearchRec;
    SearchPath, PackagePath: string;
  begin
    ProgPath := ParamStr(0);
    ProgDir := ExtractFileDir(ProgPath);
    LibDir := ExtractFileDir(ProgDir) + '/lib/' + ExtractFileNameOnly(ProgPath);
    //WriteLn('LibDir = "', LibDir, '"');
    SearchPath := LibDir + '/*';
    Result := TFPList.Create;
    if FindFirst(SearchPath, faDirectory, SearchRec) = 0 then with Result do begin
      repeat
        with SearchRec do begin
          PackagePath := LibDir + '/' + Name + '/rsd' + Name + '.lpk';
          if(Attr and faDirectory) = faDirectory then begin
            if FileExists(PackagePath) then begin
              Add(NewStr(PackagePath));
            end;
          end;
        end;
      until FindNext(SearchRec) <> 0;
      Sort(@Compare);
    end;
    FindClose(SearchRec);
  end;
  procedure UpdateForm(PackagesList: TFPList);
  var
    n: Integer;
    PackagePath: PString;
  begin
    with PackagesList do  begin
      for n := 0 to Count - 1 do begin
        PackagePath := Items[n];
        PackagesListCheckGroup.Items.Add(ExtractFileNameOnly(PackagePath^));
      end;
    end;
  end;
var
  n: Integer;
  PackagePath: string;
begin
  PackagesList := BuildPackagesList;
  UpdateForm(PackagesList);
  with PackageFiles do begin
    PackagePath := FileName;
    PackagePath := GetEnvironmentVariable('HOME') + PackagePath;
    FileName := PackagePath;
  end;
end;

procedure TPackagesManagerForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose := False;
  UpdateInstalledPackages(Sender);
end;

procedure TPackagesManagerForm.FormDestroy(Sender: TObject);
var
  n: Integer;
  PackagePath: PString;
begin
  with PackagesList do  begin
    for n := 0 to Count - 1 do begin
      PackagePath := Items[n];
      DisposeStr(PackagePath);
    end;
    Destroy;
  end;
end;

procedure TPackagesManagerForm.FormShow(Sender: TObject);
var
  n: Integer;
begin
  with PackagesListCheckGroup, PackagesList do begin
    for n := 0 to Count - 1 do begin
      Checked[n] := PackageIsInstalled(n);
    end;
  end;
end;

procedure TPackagesManagerForm.UpdateInstalledPackages(Sender: TObject);
var
  n: Integer;
begin
  if Sender = ApplyButton then with PackagesListCheckGroup do begin
    for n := 0 to Items.Count do begin
      if Checked[n] then begin
        InstallPackage(n);
      end else begin
        UninstallPackage(n);
      end;
    end;
  end else begin
  end;
  Visible := False;
end;

function TPackagesManagerForm.IndexOfPackage(PkgName: string): Integer;
var
  n: Integer;
  PkgXmlName: string;
begin
  Result := -1;
  with PackageFiles do begin
    for n := 1 to GetValue('UserPkgLinks/Count', 0) do begin
      PkgXmlName := GetValue('UserPkgLinks/Item' + IntToStr(n) + '/Name/Value', '');
      //WriteLn('XmlPath = "', XmlPath, '"');
      if PkgXmlName = PkgName then begin
        Exit(n)
      end;
    end;
  end;
end;

function TPackagesManagerForm.PackageIsInstalled(PkgIndex: Integer): boolean;
var
  n: Integer;
  PkgName: string;
  PkgPath: PString;
  PkgXmlPath: string;
begin
  PkgName := PackagesListCheckGroup.Items[PkgIndex];
  //WriteLn('PkgPath = "', PkgPath, '"');
  n := IndexOfPackage(PkgName);
  if n >= 0 then with PackageFiles do begin
    PkgPath := PackagesList.Items[PkgIndex];
    PkgXmlPath := GetValue('UserPkgLinks/Item' + IntToStr(n) + '/Filename/Value', '');
    Result := PkgXmlPath = PkgPath^;
  end else begin
    Result := False;
  end;
end;

procedure TPackagesManagerForm.InstallPackage(PkgIndex: Integer);
var
  n: Integer;
  PkgName: string;
  PkgPath: PString;
  PkgXmlPath: string;
begin
  PkgName := PackagesListCheckGroup.Items[PkgIndex];
  //WriteLn('PkgPath = "', PkgPath, '"');
  n := IndexOfPackage(PkgName);
  PkgPath := PackagesList.Items[PkgIndex];
  with PackageFiles do begin
    if n < 0 then begin
      n := GetValue('UserPkgLinks/Count', 1) + 1;
      SetValue('UserPkgLinks/Count', n);
    end;
    PkgXmlPath := 'UserPkgLinks/Item' + IntToStr(n);
    SetValue(PkgXmlPath + '/Name/Value', PkgName);
    SetValue(PkgXmlPath + '/Filename/Value', PkgPath^);
    Flush;
  end;
end;

procedure TPackagesManagerForm.UninstallPackage(PkgIndex: Integer);
var
  n: Integer;
  PkgName: string;
  PkgPath: PString;
  PkgXmlPath: string;
begin
  PkgName := PackagesListCheckGroup.Items[PkgIndex];
  //WriteLn('PkgPath = "', PkgPath, '"');
  n := IndexOfPackage(PkgName);
  if n >= 0 then with PackageFiles do begin
    DeletePath('UserPkgLinks/Item' + IntToStr(n));
    Flush;
  end;
end;

initialization
  {$R packagesmanager.lfm}
end.
