program Project1;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  UMQTT.Client in 'UMQTT.Client.pas',
  UMQTT.Connection in 'UMQTT.Connection.pas',
  UMQTT.Protocol in 'UMQTT.Protocol.pas',
  UMQTT.Protocol.Types in 'UMQTT.Protocol.Types.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
