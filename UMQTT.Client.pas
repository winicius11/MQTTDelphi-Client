unit UMQTT.Client;

interface

uses
  System.Classes,

  UMQTT.Connection,
  UMQTT.Protocol;

type
  TMQTTClient = class
  private
    fConnection: IMQTTConnection;
    fProtocol: TMQTTProtocol;
    fOnPublish: TPublishEvent;
    fOnPingresp: TNotifyEvent;

    procedure OnConnected(pSuccess: Boolean);
    procedure OnDisconnected;
    procedure OnDataReceived(pData: Pointer; pLen: Integer);

    procedure HandleProtocolPingresp(Sender: TObject);
    procedure HandleProtocolPublish(const pTopic: string; const pMessage: string);
    procedure HandleProtocolSendData(pData: Pointer; pLen: Integer);
  public
    constructor Create(const pHost: string; pPort: Integer; pSsl: Boolean);
    destructor Destroy; override;

    procedure Connect;
//    procedure Disconnect;

    procedure Ping;

    procedure Subscribe(const pTopic: string);
//    procedure Unsubscribe;
    procedure Publish(const pTopic, pMessage: string);

    property OnPingresp: TNotifyEvent read fOnPingresp write fOnPingresp;
    property OnPublish: TPublishEvent read fOnPublish write fOnPublish;
  end;

implementation

uses
  System.SysUtils;

{$REGION 'TMQTTClient'}
constructor TMQTTClient.Create(const pHost: string; pPort: Integer; pSsl: Boolean);
begin
  inherited Create;

  fProtocol := TMQTTProtocol.Create;
  fProtocol.OnSendData := HandleProtocolSendData;
  fProtocol.OnPublish  := HandleProtocolPublish;
  fProtocol.OnPingresp := HandleProtocolPingresp;

  fConnection := TMQTTConnection.Create;
  fConnection.SetConnectionData(pHost, pPort, pSsl);
  fConnection.RegisterCallback(OnConnected, OnDisconnected, OnDataReceived);
end;

destructor TMQTTClient.Destroy;
begin
  fProtocol.Free;
  inherited;
end;

procedure TMQTTClient.HandleProtocolPingresp(Sender: TObject);
begin
  if Assigned(fOnPingresp) then
    fOnPingresp(Self);
end;

procedure TMQTTClient.HandleProtocolPublish(const pTopic: string; const pMessage: string);
begin
  if Assigned(fOnPublish) then
    fOnPublish(pTopic, pMessage);
end;

procedure TMQTTClient.HandleProtocolSendData(pData: Pointer; pLen: Integer);
begin
  fConnection.SendData(pData, pLen);
end;

procedure TMQTTClient.OnConnected(pSuccess: Boolean);
begin
  fProtocol.CommandConnect('CID' + fConnection.LocalPort.ToString);
end;

procedure TMQTTClient.OnDisconnected;
begin

end;

procedure TMQTTClient.OnDataReceived(pData: Pointer; pLen: Integer);
begin
  fProtocol.ParseReceivedData(pData, pLen);
end;

procedure TMQTTClient.Connect;
begin
  fConnection.Connect;
end;

procedure TMQTTClient.Subscribe(const pTopic: string);
begin
  fProtocol.CommandSubscribe(pTopic);
end;

procedure TMQTTClient.Ping;
begin
  fProtocol.CommandPingReq;
end;

procedure TMQTTClient.Publish(const pTopic, pMessage: string);
begin
  fProtocol.CommandPublish(pTopic, pMessage);
end;
{$ENDREGION}

end.
