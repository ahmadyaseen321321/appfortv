import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../constants/api_constants.dart';
import '../../data/models/device_model.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  socket_io.Socket? _socket;
  String? _currentDeviceCode;

  void Function(DeviceData deviceData)? onDeviceUpdated;
  void Function()? onDeviceStatusDisconnected;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String deviceCode) {
    _currentDeviceCode = deviceCode;

    final url = ApiConstants.socketUrl;
    debugPrint("SocketService: Connecting to $url for deviceCode: $deviceCode");

    if (_socket != null) {
      if (_socket!.connected) {
        _joinDevice(deviceCode);
        return;
      } else {
        _socket!.dispose();
        _socket = null;
      }
    }

    _socket = socket_io.io(
      url,
      socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint("SocketService: Connected successfully.");
      if (_currentDeviceCode != null) {
        _joinDevice(_currentDeviceCode!);
      }
    });

    _socket!.on('device_updated', (data) {
      debugPrint("SocketService: Received device_updated event: $data");
      try {
        final DeviceData? deviceData = _parseDevicePayload(data);
        if (deviceData != null) {
          onDeviceUpdated?.call(deviceData);
        }
      } catch (e) {
        debugPrint("SocketService: Error parsing device_updated data: $e");
      }
    });

    // Spec event: device_disconnected — emitted by backend when a device
    // is disconnected. Payload: { "status": false, "message": "Disconnected" }
    _socket!.on('device_disconnected', (data) {
      debugPrint("SocketService: Received device_disconnected event: $data");
      onDeviceStatusDisconnected?.call();
    });

    _socket!.on('device_status', (data) {
      debugPrint("SocketService: Received device_status event: $data");
      try {
        final Map<String, dynamic>? map = _extractMap(data);
        if (map != null) {
          final connectedRaw = map['connected'];
          final isConnected = connectedRaw == true ||
              connectedRaw?.toString().toLowerCase() == 'true';

          final status = map['status']?.toString();

          if (connectedRaw != null && !isConnected) {
            onDeviceStatusDisconnected?.call();
          } else if (status == 'disconnected' ||
              status == 'false' ||
              status == 'Deleted' ||
              status == 'Suspended') {
            onDeviceStatusDisconnected?.call();
          }
        }
      } catch (e) {
        debugPrint("SocketService: Error handling device_status data: $e");
      }
    });

    _socket!.onDisconnect((reason) {
      debugPrint("SocketService: Disconnected: $reason");
    });

    _socket!.onConnectError((err) {
      debugPrint("SocketService: Connection Error: $err");
    });

    _socket!.onError((err) {
      debugPrint("SocketService: Socket Error: $err");
    });

    _socket!.connect();
  }

  void _joinDevice(String code) {
    debugPrint("SocketService: Emitting join_device with code: $code");
    _socket?.emit('join_device', code);
  }

  Map<String, dynamic>? _extractMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else if (data is List && data.isNotEmpty && data[0] is Map) {
      return Map<String, dynamic>.from(data[0] as Map);
    }
    return null;
  }

  DeviceData? _parseDevicePayload(dynamic data) {
    final map = _extractMap(data);
    if (map == null) return null;

    if (map.containsKey('data') && map['data'] is Map) {
      return DeviceData.fromJson(Map<String, dynamic>.from(map['data'] as Map));
    }
    return DeviceData.fromJson(map);
  }

  void disconnect() {
    debugPrint("SocketService: Disconnecting socket.");
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentDeviceCode = null;
  }
}
