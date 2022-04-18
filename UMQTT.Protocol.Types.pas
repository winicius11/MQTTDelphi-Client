unit UMQTT.Protocol.Types;

interface

uses
  System.SysUtils;

const
  c_MQTTName: TArray<Byte> = [$4D, $51, $54, $54]; // "M Q T T" in UTF-8
  c_MQTTVersion = 5;

type
  {
  | Fixed header (2 bytes), mandatory   |
  | Variable header, mandatory for some |
  | Payload, mandatory for some         |
  }
  TControlPacket = (cpNone        = 0,
                    cpConnect     = 1,
                    cpConnack     = 2,
                    cpPublish     = 3,
                    cpPuback      = 4,
                    cpPubrec      = 5,
                    cpPubrel      = 6,
                    cpPubcomp     = 7,
                    cpSubscribe   = 8,
                    cpSuback      = 9,
                    cpUnsubscribe = 10,
                    cpUnsuback    = 11,
                    cpPingreq     = 12,
                    cpPingresp    = 13,
                    cpDisconnect  = 14,
                    cpAuth        = 15);

  TConnackReasonCodes = (caSuccess = 0, caUnspecifiedError = $80,
                         caMalformedPacket = $81, caProtocolError = $82,
                         caImplementationSpecificError = $83,
                         caConnectionRateExceeded = $9F);

  TQos = (AtMostOnce = 0, AtLeastOnce = 1, ExactlyOnce = 2);

  TMQTTFixedHeader = packed record
    ControlAndFlags: Byte; // 4 bits control packet type | 4bits for flags
    RemainingLength: Byte; // Remaining length
    procedure SetDefaults;
    procedure ControlPacketType(const pValue: TControlPacket);
  end;

  TMQTTVariableHeader = packed record
    Content: TArray<Byte>;
    procedure AppendData(const pData: TBytes);
    procedure AddStrLength(const pLen: Integer);
    procedure AddLength(const pLen: Integer);
//    procedure SetContent;
  end;

  TMQTTPayload = packed record
    Content: TArray<Byte>;
    procedure AddLength(const pLen: Integer);
//    procedure SetContent;
    procedure AddStrLength(const pLen: Integer);
    procedure AppendData(const pData: TBytes);
  end;

  TMQTTPacket = packed record
    FixedHeader:    TMQTTFixedHeader;
    VariableHeader: TMQTTVariableHeader;
    Payload:        TMQTTPayload;
    procedure BeginUpdate;
    procedure EndUpdate;

    function ToBytes: TBytes;
  end;

implementation

{$REGION 'Auxiliary'}
procedure _AddStrLength(var aData: TBytes; pLen: Integer);
begin
  aData := aData + [(pLen div $100), (pLen mod $100)];
end;

procedure _AddLength(var pData: TBytes; pLen: Integer);
var
  x: Integer;
  dig: Byte;
begin
  x := pLen;
  repeat
    dig := x mod 128;
    x := x div 128;
    if (x > 0) then
      dig := dig or $80;
    pData := pData + [dig];
  until (x = 0);
end;
{$ENDREGION}

{$REGION 'TMQTTFixedHeader'}
procedure TMQTTFixedHeader.SetDefaults;
begin
  ControlAndFlags := 0;
  RemainingLength := 0;
end;

procedure TMQTTFixedHeader.ControlPacketType(const pValue: TControlPacket);
begin
  ControlAndFlags := Integer(pValue) shl 4;

  // 2.1.3 Flags
  case pValue of
    cpPublish: ;

    cpUnsubscribe,
    cpSubscribe,
    cpPubrel: ControlAndFlags := ControlAndFlags + (1 shl 1);
  end;
end;
{$ENDREGION}

{$REGION 'TMQTTVariableHeader'}
procedure TMQTTVariableHeader.AddLength(const pLen: Integer);
begin
  _AddLength(Content, pLen);
end;

procedure TMQTTVariableHeader.AddStrLength(const pLen: Integer);
begin
  _AddStrLength(Content, pLen);
end;

procedure TMQTTVariableHeader.AppendData(const pData: TBytes);
begin
  Content := Content + pData;
end;
{$ENDREGION}

{$REGION 'TMQTTPayload'}
procedure TMQTTPayload.AddLength(const pLen: Integer);
begin
  _AddLength(Content, pLen);
end;

procedure TMQTTPayload.AddStrLength(const pLen: Integer);
begin
  _AddStrLength(Content, pLen);
end;

procedure TMQTTPayload.AppendData(const pData: TBytes);
begin
  Content := Content + pData;
end;
{$ENDREGION}

{$REGION 'TMQTTPacket'}
procedure TMQTTPacket.BeginUpdate;
begin
  FixedHeader.SetDefaults;
  VariableHeader.Content := [];
  Payload.Content := [];
end;

procedure TMQTTPacket.EndUpdate;
begin
// The Remaining Length is a Variable Byte Integer that represents the number of bytes remaining within
// the current Control Packet, including data in the Variable Header and the Payload. The Remaining Length
// does not include the bytes used to encode the Remaining Length. The packet size is the total number of
// bytes in an MQTT Control Packet, this is equal to the length of the Fixed Header plus the Remaining
// Length.
  // Calculate remaining length
  FixedHeader.RemainingLength := Length(VariableHeader.Content) + Length(Payload.Content);
end;

function TMQTTPacket.ToBytes: TBytes;
begin
  Result := [FixedHeader.ControlAndFlags, FixedHeader.RemainingLength];

  if Length(VariableHeader.Content) > 0 then
    Result := Result + VariableHeader.Content;

  if Length(Payload.Content) > 0 then
    Result := Result + Payload.Content;
end;
{$ENDREGION}

end.
