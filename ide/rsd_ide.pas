program rsd_ide;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, mainWindow, BlockProperties, PackagesManager, Configuration;

begin
  Application.Initialize;
  Application.CreateForm(TSplashWindow, SplashWindow);
  Application.CreateForm(TIdeMainWindow, IdeMainWindow);
  Application.CreateForm(TBlockPropertiesDialog, BlockPropertiesDialog);
  Application.CreateForm(TPackagesManagerForm, PackagesManagerForm);
  Application.Run;
end.

