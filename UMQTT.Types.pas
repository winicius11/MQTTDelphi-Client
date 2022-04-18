unit UMQTT.Types;

interface

type
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

  TMQTTFixedHeader = packed record
    Byte1: Byte; // 4bits control packet type | 4bits for flags
    Byte2: Byte; // Remaining length
    procedure ControlPacketType(const pValue: TControlPacket);
  end;



implementation

uses
  System.SysUtils;

{$REGION 'TMQTTFixedHeader'}
procedure TMQTTFixedHeader.ControlPacketType(const pValue: TControlPacket);
begin
  Byte1 := Integer(pValue) shl 4;

  // 2.1.3 Flags
  case pValue of
    cpPublish: ;

    cpUnsubscribe,
    cpSubscribe,
    cpPubrel: Byte1 := Byte1 + (1 shl 1);
  end;
end;
{$ENDREGION}

procedure TestFixedHeader;
var
  vHeader: TMQTTFixedHeader;
begin
  vHeader.ControlPacketType(cpConnect);
  if not vHeader.Byte1 = 16 then
    raise Exception.Create('Invalid byte 1 value');

  vHeader.ControlPacketType(cpConnack);
  if not vHeader.Byte1 = 32 then
    raise Exception.Create('Invalid byte 1 value');

  vHeader.ControlPacketType(cpSubscribe);
  if not vHeader.Byte1 = 130 then
    raise Exception.Create('Invalid byte 1 value');

end;

initialization
  TestFixedHeader;

end.
