import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/polar_data_service.dart';

class PolarConnectOverlay extends StatefulWidget {
  const PolarConnectOverlay({super.key});

  @override
  State<PolarConnectOverlay> createState() => _PolarConnectOverlayState();
}

class _PolarConnectOverlayState extends State<PolarConnectOverlay> {
  List<ScanResult> scanResults = [];
  bool scanning = false;

  StreamSubscription<List<ScanResult>>? scanSub;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  // ==========================
  // Permissions
  // ==========================

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // ==========================
  // Scanning
  // ==========================

  Future<void> _startScan() async {
    await _requestPermissions();

    if (!mounted) return;

    setState(() {
      scanning = true;
      scanResults.clear();
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
    );

    scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;

      setState(() {
        scanResults = results
            .where((r) => r.device.platformName.isNotEmpty)
            .toList();
      });
    });

    await Future.delayed(const Duration(seconds: 5));

    await FlutterBluePlus.stopScan();
    await scanSub?.cancel();
    scanSub = null;

    if (!mounted) return;

    setState(() {
      scanning = false;
    });
  }

  // ==========================
  // Connect
  // ==========================

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
      await scanSub?.cancel();
      scanSub = null;

      await PolarDataService.instance.connect(device);

      if (!mounted) return;

      // Close overlay and return success
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("❌ Polar connect error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to connect: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ==========================
  // Dispose
  // ==========================

  @override
  void dispose() {
    scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  // ==========================
  // UI
  // ==========================

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              "Connect Polar Device",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 16),

            if (scanning)
              const Text(
                "Scanning...",
                style: TextStyle(color: Colors.white60),
              ),

            const SizedBox(height: 12),

            SizedBox(
              height: 250,
              child: scanResults.isEmpty
                  ? const Center(
                      child: Text(
                        "No devices found",
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: scanResults.length,
                      itemBuilder: (context, index) {
                        final result = scanResults[index];

                        return ListTile(
                          title: Text(
                            result.device.platformName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            result.device.remoteId.toString(),
                            style: const TextStyle(color: Colors.white38),
                          ),
                          onTap: () => _connectToDevice(result.device),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: scanning ? null : _startScan,
              child: const Text("Rescan"),
            ),
          ],
        ),
      ),
    );
  }
}
