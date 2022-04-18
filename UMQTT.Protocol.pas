unit UMQTT.Protocol;

interface

uses
  System.Classes,
  System.SysUtils,
  UMQTT.Protocol.Types;

type
  TSendDataEvent = procedure(pData: Pointer; pLen: Integer) of object;
  TPublishEvent  = procedure(const pTopic: string; const pMessage: string) of object;

  TMQTTProtocol = class
  private
    fBuffer: TBytes;
    fOnConnack: TNotifyEvent;
    fOnSendData: TSendDataEvent;
    fOnPublish: TPublishEvent;
    fOnPingresp: TNotifyEvent;

    procedure TriggerSendData(const pData: TBytes);

    procedure ProcessPingresp;
    procedure ProcessPublish(pData: Pointer; pLen: Integer);
    procedure ProcessSuback(pData: Pointer; pLen: Integer);
    procedure ProcessPuback(pData: Pointer; pLen: Integer);
    procedure ProcessConnack(pData: Pointer; pLen: Integer);
  public
    procedure ParseReceivedData(pData: Pointer; pLen: Integer);

    procedure CommandConnect(const pClientId: string);
    procedure CommandPingReq;
    procedure CommandPublish(const pTopic, pMessage: string);
    procedure CommandSubscribe(const pTopic: string);

    property OnConnack: TNotifyEvent read fOnConnack write fOnConnack;
    property OnSendData: TSendDataEvent read fOnSendData write fOnSendData;
    property OnPublish: TPublishEvent read fOnPublish write fOnPublish;
    property OnPingresp: TNotifyEvent read fOnPingresp write fOnPingresp;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.Winsock;

{$REGION 'TMQTTProtocol'}
procedure TMQTTProtocol.TriggerSendData(const pData: TBytes);
begin
  if Assigned(fOnSendData) then
    fOnSendData(@pData[0], Length(pData));
end;

procedure TMQTTProtocol.ProcessPingresp;
begin
  if Assigned(fOnPingresp) then
    fOnPingresp(Self);
end;

procedure TMQTTProtocol.ProcessPublish(pData: Pointer; pLen: Integer);
var
  LMSB, LLSB: Byte;
  Bytes: TBytes;
  vTotal, vTopicLen: Integer;
  vTopic, vMessage: string;
begin
  vTotal := 0;
  Bytes := Copy(TBytes(pData), 0, pLen);

  LMSB := Bytes[0];
  LLSB := Bytes[1];
  Inc(vTotal, 2);

  vTopicLen := LMSB * $100 + LLSB;
  Inc(vTotal, vTopicLen);

  vTopic := TEncoding.UTF8.GetString(Bytes, 2, vTopicLen);

  // Packet identifier
  if (Bytes[vTotal] = 0) and (Bytes[vTotal + 1] = 10) then
    Inc(vTotal, 2);

  // Properties
  if (Bytes[vTotal] = 0) then
    Inc(vTotal);

  vMessage := TEncoding.UTF8.GetString(Bytes, vTotal, pLen - vTotal);

  if Assigned(fOnPublish) then
    fOnPublish(vTopic, vMessage);

  OutputDebugString(PWideChar(vTopic + '/' + vMessage));
end;

procedure TMQTTProtocol.ProcessSuback(pData: Pointer; pLen: Integer);
begin

end;

procedure TMQTTProtocol.ProcessPuback(pData: Pointer; pLen: Integer);
begin

end;

procedure TMQTTProtocol.ProcessConnack(pData: Pointer; pLen: Integer);
var
  vConnectAckFlags: Byte;
  vConnectReasonCode: Byte;
begin
  if pLen < 2 then
    Exit;

  // vConnectAckFlags   := TBytes(pData)[0];
  vConnectReasonCode := TBytes(pData)[1];

  if TConnackReasonCodes(vConnectReasonCode) <> caSuccess then
    Exit;

  if Assigned(fOnConnack) then
    fOnConnack(Self);   
end;

procedure TMQTTProtocol.ParseReceivedData(pData: Pointer; pLen: Integer);
var
  vTotal, vPacketSize: Integer;
  vIdentifier: Byte;
begin
  fBuffer := fBuffer + Copy(TBytes(pData), 0, pLen);

  vTotal := 0;

  while Length(fBuffer) > 0 do
  begin
    if Length(fBuffer) < vTotal + SizeOf(TMQTTFixedHeader) then
      Break;

    vIdentifier := fBuffer[vTotal] shr 4;
    vPacketSize := fBuffer[vTotal + 1];

    if Length(fBuffer) < vTotal + 2 + vPacketSize then
      Break;

    case TControlPacket(vIdentifier) of
      cpConnack:  ProcessConnack(@Copy(fBuffer, vTotal + 2, vPacketSize)[0], vPacketSize);
      cpPuback:   ProcessPuback(@Copy(fBuffer, vTotal + 2, vPacketSize)[0], vPacketSize);
      cpSuback:   ProcessSuback(@Copy(fBuffer, vTotal + 2, vPacketSize)[0], vPacketSize);
      cpPublish:  ProcessPublish(@Copy(fBuffer, vTotal + 2, vPacketSize)[0], vPacketSize);
      cpPingresp: ProcessPingresp;
    end;

    // Increment total read
    Inc(vTotal, SizeOf(TMQTTFixedHeader) + vPacketSize);
  end;

  Delete(fBuffer, 0, vTotal);
end;

procedure TMQTTProtocol.CommandConnect(const pClientId: string);
var
  vPacket: TMQTTPacket;
begin
  vPacket.BeginUpdate;
  try
    vPacket.FixedHeader.ControlPacketType(cpConnect);

    // Protocol name and version
    vPacket.VariableHeader.AddStrLength(Length(c_MQTTName));
    vPacket.VariableHeader.AppendData(c_MQTTName);
    vPacket.VariableHeader.AppendData([c_MQTTVersion]);

    // Connect flags
    // User Name | Flag | Password | Flag | Will Retain | Will QoS | Will Flag | Clean Start | Reserved
    vPacket.VariableHeader.AppendData([0]);

    // Keep alive
    vPacket.VariableHeader.AppendData([0, 0]);

    // Properties
    vPacket.VariableHeader.AppendData([0]);

    // Payload
    vPacket.Payload.AddStrLength(Length(pClientId));
    vPacket.Payload.AppendData(TEncoding.UTF8.GetBytes(pClientId));
  finally
    vPacket.EndUpdate;
  end;

  TriggerSendData(vPacket.ToBytes);
end;

procedure TMQTTProtocol.CommandPingReq;
var
  vPacket: TMQTTPacket;
begin
  vPacket.BeginUpdate;
  try
    vPacket.FixedHeader.ControlPacketType(cpPingreq);
  finally
    vPacket.EndUpdate;
  end;

  TriggerSendData(vPacket.ToBytes);
end;

procedure TMQTTProtocol.CommandPublish(const pTopic, pMessage: string);
var
  vPacket: TMQTTPacket;
begin
  vPacket.BeginUpdate;
  try   
    vPacket.FixedHeader.ControlPacketType(cpPublish);

    // Topic
    vPacket.VariableHeader.AddStrLength(Length(pTopic));
    vPacket.VariableHeader.AppendData(TEncoding.UTF8.GetBytes(pTopic));
  
    // Packet identifier
    // if (QOS = 1) or (QOS = 2) then
    //   vPacket.VariableHeader.AppendData();
//    vPacket.VariableHeader.AppendData([0]);

    vPacket.VariableHeader.AppendData([0, 10]);

    // Property length
    vPacket.VariableHeader.AppendData([0]);

    // Payload
    vPacket.Payload.AppendData(TEncoding.UTF8.GetBytes(pMessage));
  finally
    vPacket.EndUpdate;
  end;

  TriggerSendData(vPacket.ToBytes)
end;

procedure TMQTTProtocol.CommandSubscribe(const pTopic: string);
var
  vPacket: TMQTTPacket;
begin
  vPacket.BeginUpdate;
  try   
    vPacket.FixedHeader.ControlPacketType(cpSubscribe);

    // Packet identifier
    vPacket.VariableHeader.AppendData([0, 10, 0]);
  
    // Payload
    vPacket.Payload.AddStrLength(Length(pTopic));
    vPacket.Payload.AppendData(TEncoding.UTF8.GetBytes(pTopic));
  
    // Subscription options
    vPacket.Payload.AppendData([0]);
  finally
    vPacket.EndUpdate;
  end;

  TriggerSendData(vPacket.ToBytes);
end;
{$ENDREGION}

{$REGION 'Tests'}
procedure TestFixedHeader;
var
  vHeader: TMQTTFixedHeader;
  vProtocol: TMQTTProtocol;
begin
  vHeader.ControlPacketType(cpConnect);
  if not vHeader.ControlAndFlags = 16 then
    raise Exception.Create('Invalid byte 1 value');

  vHeader.ControlPacketType(cpConnack);
  if not vHeader.ControlAndFlags = 32 then
    raise Exception.Create('Invalid byte 1 value');

  vHeader.ControlPacketType(cpSubscribe);
  if not vHeader.ControlAndFlags = 130 then
    raise Exception.Create('Invalid byte 1 value');

//  var vIdentifier := fBuffer[0] shr 4;
//  case TControlPacket(vIdentifier) of
//    cpConnack:
//    begin
//    end;
//  end;

  vProtocol := TMQTTProtocol.Create;
  try
    vProtocol.CommandConnect('CID1883');

  finally
    vProtocol.Free;
  end;

end;
{$ENDREGION}

initialization
  TestFixedHeader;

end.
