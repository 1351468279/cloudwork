class DevicePair {
  final String deviceId;
  final String deviceName;
  final String publicKey;
  final String relayUrl;
  final List<String> localIps;
  final int port;
  final int pairedAt;

  DevicePair({
    required this.deviceId,
    required this.deviceName,
    required this.publicKey,
    required this.relayUrl,
    required this.localIps,
    required this.port,
    required this.pairedAt,
  });

  factory DevicePair.fromJson(Map<String, dynamic> json) {
    return DevicePair(
      deviceId: json['device_id'] ?? '',
      deviceName: json['device_name'] ?? 'Host',
      publicKey: json['pub_key'] ?? '',
      relayUrl: json['relay_url'] ?? '',
      localIps: (json['local_ips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      port: json['port'] ?? 9288,
      pairedAt: json['ts'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'pub_key': publicKey,
      'relay_url': relayUrl,
      'local_ips': localIps,
      'port': port,
      'ts': pairedAt,
    };
  }
}
