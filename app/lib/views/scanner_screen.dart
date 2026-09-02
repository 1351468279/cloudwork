import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/device_pair.dart';

class ScannerScreen extends StatefulWidget {
  final Function(DevicePair) onPairSuccess;

  const ScannerScreen({super.key, required this.onPairSuccess});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _ipController = TextEditingController(text: '192.168.0.251:9288');
  bool _isManualMode = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(rawValue);
          final pair = DevicePair.fromJson(data);
          _hasScanned = true;
          widget.onPairSuccess(pair);
          Navigator.pop(context);
          break;
        } catch (e) {
          // If not standard JSON, try treating as direct IP:port or WS URL
          _hasScanned = true;
          final pair = DevicePair(
            deviceId: 'manual_device',
            deviceName: '电脑主机',
            publicKey: '',
            relayUrl: rawValue,
            localIps: [rawValue],
            port: 9288,
            pairedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
          widget.onPairSuccess(pair);
          Navigator.pop(context);
          break;
        }
      }
    }
  }

  void _submitManual() {
    final text = _ipController.text.trim();
    if (text.isEmpty) return;

    var host = text;
    var port = 9288;
    if (text.contains(':')) {
      final parts = text.split(':');
      host = parts[0];
      port = int.tryParse(parts[1]) ?? 9288;
    }

    final pair = DevicePair(
      deviceId: 'manual_ip_device',
      deviceName: '我的电脑',
      publicKey: '',
      relayUrl: 'ws://$host:$port/ws',
      localIps: [host],
      port: port,
      pairedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    widget.onPairSuccess(pair);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('配对连接电脑', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isManualMode ? Icons.qr_code_scanner : Icons.edit),
            tooltip: _isManualMode ? '切换到摄像头扫码' : '手动输入 IP',
            onPressed: () {
              setState(() {
                _isManualMode = !_isManualMode;
              });
            },
          ),
        ],
      ),
      body: _isManualMode ? _buildManualView() : _buildScannerView(),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleBarcode,
        ),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF58A6FF), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xCC161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              children: [
                const Text(
                  '请对准电脑终端中显示的动态二维码',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => setState(() => _isManualMode = true),
                  child: const Text('摄像头无法对焦？点击手动输入 IP ➔', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('手动输入电脑 IP 地址', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            '输入终端中提示的局域网 IP（例如 192.168.0.251:9288）完成直连：',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ipController,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 15),
            decoration: InputDecoration(
              labelText: '电脑 IP 与端口',
              labelStyle: const TextStyle(color: Color(0xFF8B949E)),
              hintText: '192.168.0.251:9288',
              hintStyle: const TextStyle(color: Color(0xFF484F58)),
              filled: true,
              fillColor: const Color(0xFF161B22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitManual,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF58A6FF),
                foregroundColor: const Color(0xFF0D1117),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('🔗 连接电脑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.qr_code_scanner, size: 16),
              label: const Text('返回扫码模式'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B949E)),
              onPressed: () => setState(() => _isManualMode = false),
            ),
          ),
        ],
      ),
    );
  }
}
