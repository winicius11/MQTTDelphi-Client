unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, UMQTT.Client, Vcl.StdCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Memo1: TMemo;
    Button4: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
  private
    fClient: TMQTTClient;

    procedure HandleMQTTPingResp(Sender: TObject);
    procedure HandleMQTTPublish(const pTopic: string; const pMessage: string);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
begin
  fClient.Connect;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  Data: string;
begin
  InputQuery('Digite a mensagem', 'Para publicar no tópico "winicius"', Data);

  fClient.Publish('winicius', Data);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  fClient.Subscribe('winicius');
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  fClient.Ping;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  fClient := TMQTTClient.Create('127.0.0.1', 1883, false);
//  fClient := TMQTTClient.Create('broker.emqx.io'{'127.0.0.1'}, 8883, True);

  fClient.OnPublish  := HandleMQTTPublish;
  fClient.OnPingResp := HandleMQTTPingResp;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  fClient.Free;
end;

procedure TForm1.HandleMQTTPingResp(Sender: TObject);
begin
  Memo1.Lines.Add('PINGRESP received');
  Memo1.Lines.Add('');
end;

procedure TForm1.HandleMQTTPublish(const pTopic, pMessage: string);
begin
  Memo1.Lines.Add('PUBLISH received');
  Memo1.Lines.Add('Topic: ' + pTopic);
  Memo1.Lines.Add('Message: ' + pMessage);
  Memo1.Lines.Add('');
end;

end.
