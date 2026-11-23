enum TransferStatus {
  pending,
  transferring,
  completed,
  failed,
  cancelled,
}

class TransferTask {
  final String id;
  final String fileName;
  final String? filePath;
  final int totalBytes;
  int transferredBytes;
  double speedMBps;
  TransferStatus status;
  final bool isIncoming;
  final String peerName;
  String? errorMessage;
  final DateTime startTime;

  TransferTask({
    required this.id,
    required this.fileName,
    this.filePath,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.speedMBps = 0.0,
    this.status = TransferStatus.pending,
    required this.isIncoming,
    required this.peerName,
    this.errorMessage,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  double get progress {
    if (totalBytes <= 0) return 0.0;
    final p = transferredBytes / totalBytes;
    return p > 1.0 ? 1.0 : (p < 0.0 ? 0.0 : p);
  }

  String get formattedSize => formatBytes(totalBytes);
  String get formattedTransferred => formatBytes(transferredBytes);

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
