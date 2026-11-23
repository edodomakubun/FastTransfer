import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../models/transfer_task.dart';
import '../services/discovery_service.dart';
import '../services/file_server_service.dart';
import '../services/transfer_client_service.dart';

class HomeScreen extends StatefulWidget {
  final DiscoveryService discoveryService;
  final FileServerService fileServerService;
  final TransferClientService clientService;
  final String myName;
  final int myPort;

  const HomeScreen({
    super.key,
    required this.discoveryService,
    required this.fileServerService,
    required this.clientService,
    required this.myName,
    required this.myPort,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<TransferTask> _tasks = [];
  DeviceInfo? _selectedDevice;
  List<File> _selectedFiles = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _onTaskUpdated(TransferTask task) {
    if (!mounted) return;
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        _tasks[index] = task;
      } else {
        _tasks.insert(0, task);
      }
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();
      });
    }
  }

  Future<void> _startSending() async {
    if (_selectedDevice == null || _selectedFiles.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    for (final file in _selectedFiles) {
      final taskId = 'send_${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      await widget.clientService.sendFile(
        targetDevice: _selectedDevice!,
        file: file,
        taskId: taskId,
        onProgress: _onTaskUpdated,
      );
    }

    if (mounted) {
      setState(() {
        _isSending = false;
        _selectedFiles.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua file telah selesai dikirim!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            const Text('FastTransfer (Offline)'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.send_rounded), text: 'Kirim File'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Aktivitas & Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSendTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildSendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Status Perangkat Ini
          _buildMyDeviceCard(),
          const SizedBox(height: 16),

          // Daftar Perangkat Terdekat
          const Text(
            '1. Pilih Perangkat Tujuan (Otomatis Terdeteksi)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildNearbyDevicesList(),
          const SizedBox(height: 16),

          // Pemilihan File
          const Text(
            '2. Pilih File atau Media',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildFilePickerSection(),
          const SizedBox(height: 24),

          // Tombol Eksekusi Kirim
          ElevatedButton.icon(
            onPressed: (_selectedDevice != null && _selectedFiles.isNotEmpty && !_isSending)
                ? _startSending
                : null,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.rocket_launch),
            label: Text(_isSending ? 'Sedang Mengirim...' : 'Kirim Sekarang (>10 MB/s)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          if (_tasks.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const Text(
              'Transfer Terakhir:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildTaskCard(_tasks.first),
          ]
        ],
      ),
    );
  }

  Widget _buildMyDeviceCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                Platform.isAndroid ? Icons.android : Icons.laptop_windows,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.myName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    'Aktif di Port ${widget.myPort} • Mode Offline Lokal',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Pindai Ulang',
              onPressed: () {
                widget.discoveryService.broadcastBeacon();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyDevicesList() {
    return StreamBuilder<List<DeviceInfo>>(
      stream: widget.discoveryService.devicesStream,
      initialData: widget.discoveryService.currentDevices,
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];
        if (devices.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.wifi_tethering, size: 36, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Mencari perangkat di Wi-Fi/Hotspot yang sama...',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 4),
                Text(
                  'Pastikan kedua perangkat terhubung ke Wi-Fi / Hotspot yang sama.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          );
        }

        return Column(
          children: devices.map((device) {
            final isSelected = _selectedDevice?.id == device.id;
            return Card(
              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  device.os.toLowerCase().contains('android')
                      ? Icons.android
                      : Icons.laptop,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.blueGrey,
                ),
                title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${device.address}:${device.port} (${device.os})'),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.radio_button_unchecked),
                onTap: () {
                  setState(() {
                    _selectedDevice = device;
                  });
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFilePickerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.file_present),
            label: const Text('Pilih Berkas / Foto / Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${_selectedFiles.length} file dipilih:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ..._selectedFiles.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          f.uri.pathSegments.last,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        TransferTask.formatBytes(f.lengthSync()),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )),
          ]
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_tasks.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada aktivitas transfer file.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        return _buildTaskCard(_tasks[index]);
      },
    );
  }

  Widget _buildTaskCard(TransferTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.isIncoming ? Icons.download_rounded : Icons.upload_rounded,
                  color: task.isIncoming ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(task),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.status == TransferStatus.transferring ? task.progress : (task.status == TransferStatus.completed ? 1.0 : 0.0),
              backgroundColor: Colors.grey.shade200,
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${task.formattedTransferred} / ${task.formattedSize}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (task.status == TransferStatus.transferring)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '⚡ ${task.speedMBps.toStringAsFixed(1)} MB/s',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                Text(
                  '${(task.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(TransferTask task) {
    Color color;
    String text;
    switch (task.status) {
      case TransferStatus.completed:
        color = Colors.green;
        text = 'Selesai';
        break;
      case TransferStatus.transferring:
        color = Colors.blue;
        text = 'Mengirim...';
        break;
      case TransferStatus.failed:
        color = Colors.red;
        text = 'Gagal';
        break;
      default:
        color = Colors.grey;
        text = 'Menunggu';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
