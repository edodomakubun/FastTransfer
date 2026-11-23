import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/transfer_task.dart';

class FileServerService {
  final int port;
  final String deviceName;
  HttpServer? _server;

  final void Function(TransferTask task)? onTaskUpdated;

  FileServerService({
    this.port = 8080,
    required this.deviceName,
    this.onTaskUpdated,
  });

  Future<int> start() async {
    // Coba bind port yang diminta, jika sibuk cari port bebas
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } catch (_) {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }

    _server!.listen(_handleRequest);
    return _server!.port;
  }

  Future<Directory> getDownloadDirectory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final fastTransferDir = Directory(p.join(downloads.path, 'FastTransfer'));
        if (!await fastTransferDir.exists()) {
          await fastTransferDir.create(recursive: true);
        }
        return fastTransferDir;
      }
    }
    // Android / iOS
    final appDir = await getApplicationDocumentsDirectory();
    final receivedDir = Directory(p.join(appDir.path, 'ReceivedFiles'));
    if (!await receivedDir.exists()) {
      await receivedDir.create(recursive: true);
    }
    return receivedDir;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Izinkan CORS untuk kompatibilitas
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/ping' && request.method == 'GET') {
      request.response.statusCode = HttpStatus.ok;
      request.response.write('PONG: $deviceName');
      await request.response.close();
      return;
    }

    if (path == '/upload' && request.method == 'POST') {
      await _handleIncomingFileStream(request);
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  /// Penanganan transfer streaming berkecepatan tinggi (>10 MB/s - 80+ MB/s)
  /// Menggunakan direct stream piping tanpa menampung buffer di RAM
  Future<void> _handleIncomingFileStream(HttpRequest request) async {
    final query = request.uri.queryParameters;
    final fileName = Uri.decodeComponent(query['filename'] ?? 'file_${DateTime.now().millisecondsSinceEpoch}');
    final totalBytes = int.tryParse(query['size'] ?? '0') ?? 0;
    final senderName = query['sender'] ?? 'Remote Device';
    final taskId = query['taskId'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    final downloadDir = await getDownloadDirectory();
    final targetPath = p.join(downloadDir.path, fileName);
    final targetFile = File(targetPath);

    final task = TransferTask(
      id: taskId,
      fileName: fileName,
      filePath: targetPath,
      totalBytes: totalBytes,
      isIncoming: true,
      peerName: senderName,
      status: TransferStatus.transferring,
    );

    onTaskUpdated?.call(task);

    IOSink? sink;
    try {
      sink = targetFile.openWrite(mode: FileMode.writeOnly);

      int receivedBytes = 0;
      int bytesInWindow = 0;
      DateTime lastSampleTime = DateTime.now();

      // Listen stream data secara langsung dari TCP socket
      await for (final chunk in request) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        bytesInWindow += chunk.length;

        final now = DateTime.now();
        final elapsedMs = now.difference(lastSampleTime).inMilliseconds;

        // Hitung kecepatan transfer secara real-time setiap 250ms
        if (elapsedMs >= 250) {
          final speedBytesPerSec = (bytesInWindow / (elapsedMs / 1000.0));
          task.speedMBps = speedBytesPerSec / (1024 * 1024);
          task.transferredBytes = receivedBytes;
          onTaskUpdated?.call(task);

          bytesInWindow = 0;
          lastSampleTime = now;
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      task.transferredBytes = receivedBytes;
      task.status = TransferStatus.completed;
      task.speedMBps = 0.0;
      onTaskUpdated?.call(task);

      request.response.statusCode = HttpStatus.ok;
      request.response.write('SUCCESS');
      await request.response.close();
    } catch (e) {
      if (sink != null) {
        await sink.close();
      }
      task.status = TransferStatus.failed;
      task.errorMessage = e.toString();
      onTaskUpdated?.call(task);

      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('ERROR: $e');
      await request.response.close();
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
