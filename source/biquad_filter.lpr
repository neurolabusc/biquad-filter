program biquad_filter;

{$MODE Delphi}

uses
  Forms, Interfaces,
  main in 'main.pas' {Form1};
{$IFDEF Win32}
{$R *.RES}
{$ENDIF}
begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
