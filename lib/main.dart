import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'services/discovery_service.dart';
import 'services/file_server_service.dart';
import 'services/transfer_client_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FastTransferApp());
}

class FastTransferApp extends StatefulWidget {
  const FastTransferApp({super.key});

  @override
  State<FastTransferApp> createState() => _FastTransferAppState();
}

class _FastTransferAppState extends State<FastTransferApp> {
  late final String _deviceId;
  late final String _deviceName;
  late final TransferClientService _clientService;

  DiscoveryService? _discoveryService;
  FileServerService? _fileServerService;
  int _serverPort = 8080;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission.audio,
        Permission.nearbyWifiDevices,
      ].request();
    }
  }

  Future<void> _initApp() async {
    await _requestPermissions();

    final rand = Random().nextInt(9999);
    _deviceId = 'dev_${Platform.operatingSystem}_$rand';
    _deviceName = '${Platform.operatingSystem.toUpperCase()}-$rand';

    _clientService = TransferClientService(myDeviceName: _deviceName);

    // Jalankan HTTP File Server
    _fileServerService = FileServerService(
      port: 8080,
      deviceName: _deviceName,
    );
    _serverPort = await _fileServerService!.start();

    // Jalankan UDP Discovery Service
    _discoveryService = DiscoveryService(
      deviceId: _deviceId,
      deviceName: _deviceName,
      serverPort: _serverPort,
    );
    await _discoveryService!.start();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _discoveryService?.stop();
    _fileServerService?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FastTransfer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: _isInitialized
          ? HomeScreen(
              discoveryService: _discoveryService!,
              fileServerService: _fileServerService!,
              clientService: _clientService,
              myName: _deviceName,
              myPort: _serverPort,
            )
          : const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Menyiapkan jaringan lokal FastTransfer...'),
                  ],
                ),
              ),
            ),
    );
  }
}
