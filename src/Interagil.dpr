
program Interagil;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  UnitConfig in 'UnitConfig.pas' {FormConfig},
  ProcessUtil in 'ProcessUtil.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
