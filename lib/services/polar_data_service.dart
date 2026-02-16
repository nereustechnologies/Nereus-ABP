import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';

class PolarDataService {
  PolarDataService._();
  static final PolarDataService instance = PolarDataService._();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _hrCharacteristic;

  StreamSubscription<List<int>>? _hrSub;

  final StreamController<int> _hrController =
      StreamController<int>.broadcast();

  final StreamController<List<double>> _rrController =
      StreamController<List<double>>.broadcast();

  bool get isConnected => _connectedDevice != null;

  Stream<int> get heartRateStream => _hrController.stream;
  Stream<List<double>> get rrStream => _rrController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  // ==========================
  // Internal state storage
  // ==========================

  int _latestHr = 0;
  List<double> _latestRr = [];

  int get latestHr => _latestHr;
  List<double> get latestRr => List.unmodifiable(_latestRr);

  Map<String, dynamic> getLatest() {
    return {
      'hr': _latestHr,
      'rr': List.unmodifiable(_latestRr),
    };
  }

  void reset() {
    _latestHr = 0;
    _latestRr = [];
  }

  // ==========================
  // Connect
  // ==========================

  Future<void> connect(BluetoothDevice device) async {
    if (_connectedDevice != null) return;

    await device.connect(timeout: const Duration(seconds: 15));

    _connectedDevice = device;

    await _subscribeHeartRate(device);

    debugPrint("Connected to ${device.platformName}");
  }

  // ==========================
  // Disconnect
  // ==========================

  Future<void> disconnect() async {
    try {
      await _hrSub?.cancel();
      _hrSub = null;

      if (_hrCharacteristic != null) {
        await _hrCharacteristic!.setNotifyValue(false);
      }

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      debugPrint("Disconnected from device");
    } catch (e) {
      debugPrint("Disconnect error: $e");
    }

    _connectedDevice = null;
    _hrCharacteristic = null;
  }

  // ==========================
  // Discover + Subscribe
  // ==========================

  Future<void> _subscribeHeartRate(BluetoothDevice device) async {
    final services = await device.discoverServices();

    bool uuidMatches(Guid uuid, String short) {
      final u = uuid.toString().toLowerCase();
      return u == short.toLowerCase() || u.endsWith(short.toLowerCase());
    }

    BluetoothService? hrService;

    for (var s in services) {
      if (uuidMatches(s.uuid, "180d")) {
        hrService = s;
        break;
      }
    }

    if (hrService == null) {
      debugPrint("Heart Rate Service not found");
      return;
    }

    for (var c in hrService.characteristics) {
      if (uuidMatches(c.uuid, "2a37")) {
        _hrCharacteristic = c;
        break;
      }
    }

    if (_hrCharacteristic == null) {
      debugPrint("Heart Rate Characteristic not found");
      return;
    }

    await _hrCharacteristic!.setNotifyValue(true);

    _hrSub = _hrCharacteristic!.onValueReceived.listen((value) {
      final parsed = _parseHeartRate(value);
      final hr = parsed['hr'] as int;
      final rr = parsed['rr'] as List<double>;

      // Store latest
      _latestHr = hr;
      _latestRr = rr;

      // Emit streams
      _hrController.add(hr);
      _rrController.add(rr);

      if (rr.isNotEmpty) {
        debugPrint("❤️ HR: $hr bpm | RR: $rr");
      } else {
        debugPrint("❤️ HR: $hr bpm");
      }
    });

    debugPrint("Subscribed to Heart Rate notifications");
  }

  // ==========================
  // Parse
  // ==========================

  Map<String, dynamic> _parseHeartRate(List<int> data) {
    if (data.isEmpty) {
      return {'hr': 0, 'rr': <double>[]};
    }

    final flags = data[0];

    final hr16bit = (flags & 0x01) != 0;
    final rrPresent = (flags & 0x10) != 0;

    int offset = 1;
    int hr;

    if (hr16bit) {
      hr = data[offset] + (data[offset + 1] << 8);
      offset += 2;
    } else {
      hr = data[offset];
      offset += 1;
    }

    List<double> rrIntervals = [];

    if (rrPresent) {
      while (offset + 1 < data.length) {
        int rrRaw = data[offset] + (data[offset + 1] << 8);
        rrIntervals.add(rrRaw / 1024.0);
        offset += 2;
      }
    }

    return {
      'hr': hr,
      'rr': rrIntervals,
    };
  }

  // ==========================
  // Dispose
  // ==========================

  void dispose() {
    _hrSub?.cancel();
    _hrController.close();
    _rrController.close();
  }
}
