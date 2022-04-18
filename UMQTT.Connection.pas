unit UMQTT.Connection;

interface

uses
  System.SysUtils,
  OverbyteIcsWSocket;

type
  IMQTTConnection = interface
    procedure SetConnectionData(const pHost: string; pPort: Integer; pSsl: Boolean);
    procedure RegisterCallback(pConnected: TProc<Boolean>; pDisconnected: TProc; pDataReceived: TProc<Pointer, Integer>);
    procedure SendData(const pData: Pointer; pLen: Integer);

    procedure Connect;
    procedure Disconnect;

    function LocalPort: Integer;
  end;

  TMQTTConnection = class(TInterfacedObject, IMQTTConnection)
  private
    fSocket: TWSocket;

    fOnConnected: TProc<Boolean>;
    fOnDisconnected: TProc;
    fOnDataReceived: TProc<Pointer, Integer>;

    procedure HandleSocketSslHandshakeDone(Sender: TObject; ErrCode: Word; PeerCert: TX509Base; var Disconnect: Boolean);
    procedure HandleSocketConnected(Sender: TObject; ErrCode: Word);
    procedure HandleSocketDataReceived(Sender: TObject; ErrCode: Word);
  public
    destructor Destroy; override;

    procedure SetConnectionData(const pHost: string; pPort: Integer; pSsl: Boolean);
    procedure RegisterCallback(pConnected: TProc<Boolean>; pDisconnected: TProc; pDataReceived: TProc<Pointer, Integer>);
    procedure SendData(const pData: Pointer; pLen: Integer);

    procedure Connect;
    procedure Disconnect;

    function LocalPort: Integer;
  end;

implementation

{$REGION 'TMQTTConnection'}
destructor TMQTTConnection.Destroy;
begin
  fSocket.Free;
  inherited;
end;

procedure TMQTTConnection.HandleSocketSslHandshakeDone(Sender: TObject;
  ErrCode: Word; PeerCert: TX509Base; var Disconnect: Boolean);
begin

end;

procedure TMQTTConnection.HandleSocketConnected(Sender: TObject; ErrCode: Word);
var
  vContext: TSslContext;
begin
  if Assigned(fOnConnected) then
    fOnConnected(ErrCode = 0);

  if fSocket is TSslWSocket then
  begin
    vContext := TSslContext.Create(fSocket);

//    TSslWSocket(fSocket).ss
    TSslWSocket(fSocket).SslContext := vContext;
    TSslWSocket(fSocket).SslEnable  := True;
    TSslWSocket(fSocket).StartSslHandshake;
  end;
end;

procedure TMQTTConnection.HandleSocketDataReceived(Sender: TObject;
  ErrCode: Word);
var
  vBuffer: AnsiString;
begin
  vBuffer := fSocket.ReceiveStrA;

  if Assigned(fOnDataReceived) then
    fOnDataReceived(@vBuffer[1], Length(vBuffer));
end;

function TMQTTConnection.LocalPort: Integer;
begin
  Result := fSocket.GetXPort.ToInteger;
end;

procedure TMQTTConnection.SetConnectionData(const pHost: string; pPort: Integer; pSsl: Boolean);
begin
  if pSsl then
    fSocket := TSslWSocket.Create(nil)
  else
    fSocket := TWSocket.Create(nil);
  fSocket.Addr  := pHost;
  fSocket.Port  := IntToStr(pPort);
  fSocket.Proto := 'tcp';

  fSocket.OnSslHandshakeDone := HandleSocketSslHandshakeDone;
  fSocket.OnSessionConnected := HandleSocketConnected;
  fSocket.OnDataAvailable    := HandleSocketDataReceived;
end;

procedure TMQTTConnection.RegisterCallback(pConnected: TProc<Boolean>; pDisconnected: TProc; pDataReceived: TProc<Pointer, Integer>);
begin
  fOnConnected    := pConnected;
  fOnDisconnected := pDisconnected;
  fOnDataReceived := pDataReceived;
end;

procedure TMQTTConnection.SendData(const pData: Pointer; pLen: Integer);
begin
  fSocket.Send(pData, pLen);
end;

procedure TMQTTConnection.Connect;
begin
  fSocket.Connect;
end;

procedure TMQTTConnection.Disconnect;
begin
  fSocket.Close;
end;
{$ENDREGION}

end.
