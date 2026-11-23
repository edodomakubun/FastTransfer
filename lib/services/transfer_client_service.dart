import 'dart:async';
import 'dart:io';
import '../models/device_info.dart';
import '../models/transfer_task.dart';

class TransferClientService {
  final String myDeviceName;
  static const int chunkSize = 512 * 1024; // 512 KB buffer chunk untuk kecepatan maksimal

  TransferClientService({required this.myDeviceName});

  /// Mengirim file dengan pure stream socket untuk mencapai >10 MB/s hingga 80+ MB/s
  Future<void> sendFile({
    required DeviceInfo targetDevice,
    required File file,
    required String taskId,
    required void Function(TransferTask task) onProgress,
  }) async {
    final fileName = file.uri.pathSegments.last;
    final totalBytes = await file.length();

    final task = TransferTask(
      id: taskId,
      fileName: fileName,
      filePath: file.path,
      totalBytes: totalBytes,
      isIncoming: false,
      peerName: targetDevice.name,
      status: TransferStatus.transferring,
    );
    onProgress(task);

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse(
        'http://${targetDevice.address}:${targetDevice.port}/upload'
        '?filename=${Uri.encodeComponent(fileName)}'
        '&size=$totalBytes'
        '&sender=${Uri.encodeComponent(myDeviceName)}'
        '&taskId=$taskId',
      );

      final request = await client.postUrl(uri);

      // Optimasi Kritis untuk Kecepatan Tinggi:
      // 1. Matikan bufferOutput agar data tidak tertahan di RAM dan langsung disemprot ke TCP socket
      request.bufferOutput = false;
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
      request.headers.set(HttpHeaders.contentLengthHeader, totalBytes.toString());

      int sentBytes = 0;
      int bytesInWindow = 0;
      DateTime lastSampleTime = DateTime.now();

      // Alirkan chunk langsung dari disk ke jaringan
      final stream = file.openRead();
      await for (final chunk in stream) {
        request.add(chunk);
        sentBytes += chunk.length;
        bytesInWindow += chunk.length;

        final now = DateTime.now();
        final elapsedMs = now.difference(lastSampleTime).inMilliseconds;

        // Hitung throughput real-time setiap 250ms
        if (elapsedMs >= 250) {
          final speedBytesPerSec = (bytesInWindow / (elapsedMs / 1000.0));
          task.speedMBps = speedBytesPerSec / (1024 * 1024);
          task.transferredBytes = sentBytes;
          onProgress(task);

          bytesInWindow = 0;
          lastSampleTime = now;
        }
      }

      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        task.status = TransferStatus.completed;
        task.transferredBytes = totalBytes;
        task.speedMBps = 0.0;
        onProgress(task);
      } else {
        throw Exception('Penerima menolak transfer (HTTP ${response.statusCode})');
      }
    } catch (e) {
      task.status = TransferStatus.failed;
      task.errorMessage = e.toString();
      task.speedMBps = 0.0;
      onProgress(task);
    } finally {
      client?.close(force: true);
    }
  }
}
