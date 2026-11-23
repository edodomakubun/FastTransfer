class DeviceInfo {
  final String id;
  final String name;
  final String address;
  final int port;
  final String os;
  final DateTime lastSeen;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.os,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'port': port,
      'os': os,
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json, String remoteAddress) {
    return DeviceInfo(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Perangkat Tak Dikenal',
      address: remoteAddress,
      port: (json['port'] as num?)?.toInt() ?? 8080,
      os: json['os'] as String? ?? 'Unknown',
      lastSeen: DateTime.now(),
    );
  }

  DeviceInfo copyWith({
    String? id,
    String? name,
    String? address,
    int? port,
    String? os,
    DateTime? lastSeen,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      os: os ?? this.os,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
