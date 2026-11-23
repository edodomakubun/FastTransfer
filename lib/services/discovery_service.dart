import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/device_info.dart';

class DiscoveryService {
  static const int broadcastPort = 42100;
  final String deviceId;
  final String deviceName;
  final int serverPort;

  RawDatagramSocket? _socket;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;

  final _devicesController = StreamController<List<DeviceInfo>>.broadcast();
  Stream<List<DeviceInfo>> get devicesStream => _devicesController.stream;

  final Map<String, DeviceInfo> _discovered = {};
  List<DeviceInfo> get currentDevices => _discovered.values.toList();

  DiscoveryService({
    required this.deviceId,
    required this.deviceName,
    required this.serverPort,
  });

  Future<void> start() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        broadcastPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket!.broadcastEnabled = true;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handlePacket(datagram);
          }
        }
      });

      // Kirim beacon setiap 2 detik
      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        broadcastBeacon();
      });

      // Bersihkan perangkat offline setiap 5 detik
      _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _pruneOfflineDevices();
      });

      // Kirim beacon awal
      broadcastBeacon();
    } catch (e) {
      // Log atau tangani jika socket terblokir
      stderr.writeln('DiscoveryService error: $e');
    }
  }

  void broadcastBeacon() {
    if (_socket == null) return;
    try {
      final payload = jsonEncode({
        'id': deviceId,
        'name': deviceName,
        'port': serverPort,
        'os': Platform.operatingSystem,
      });
      final bytes = utf8.encode(payload);
      _socket!.send(bytes, InternetAddress('255.255.255.255'), broadcastPort);
    } catch (_) {}
  }

  void _handlePacket(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;
      final id = json['id'] as String?;
      if (id == null || id == deviceId) return; // Abaikan pesan dari diri sendiri

      final senderIp = datagram.address.address;
      final device = DeviceInfo.fromJson(json, senderIp);

      _discovered[id] = device;
      _devicesController.add(_discovered.values.toList());
    } catch (_) {}
  }

  void _pruneOfflineDevices() {
    final now = DateTime.now();
    final beforeCount = _discovered.length;
    _discovered.removeWhere(
      (_, device) => now.difference(device.lastSeen).inSeconds > 7,
    );
    if (_discovered.length != beforeCount) {
      _devicesController.add(_discovered.values.toList());
    }
  }

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
  }
}
