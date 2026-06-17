import 'dart:async'; // For Timer and StreamSubscription
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // BLE package

class BLEService {
  // The BLE device we connect to
  BluetoothDevice? device;

  // BLE characteristic we read from
  BluetoothCharacteristic? characteristic;

  // Timer for periodic reads
  Timer? timer;

  // Subscription to scan results
  StreamSubscription<List<ScanResult>>? scanSub;

  // Name of the BLE device we are looking for
  final String deviceName;

  // UUID of the service we want
  final Guid serviceUUID;

  // UUID of the characteristic we want
  final Guid charUUID;

  // Callback to send read values back to the UI / caller
  void Function(String)? onValue;

  // Callback to notify UI about connection status
  void Function(bool connected)? onConnectionChanged;

  // Internal connection state
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void _setConnected(bool value) {
    _isConnected = value;
    onConnectionChanged?.call(value); // notify UI
  }

  BLEService({
    required this.deviceName,
    required this.serviceUUID,
    required this.charUUID,
  });

  /// Entry point: start scanning for BLE devices
  void start() async {
    log("Starting BLE scan");

    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
    );

    scanSub = FlutterBluePlus.scanResults.listen(_onScanResults);
  }

  Future<void> _onScanResults(List<ScanResult> results) async {
    for (final r in results) {
      log("Found device: ${r.device.name}");

      if (r.device.name == deviceName) {
        log("Matched target device");
        await _connectToDevice(r.device);
        break;
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice d) async {
    device = d;
    await FlutterBluePlus.stopScan();
    await scanSub?.cancel();

    log("Connecting to device");
    await device!.connect(autoConnect: false);

    device!.connectionState.listen((state) async {
      log("Connection state: $state");

      if (state == BluetoothConnectionState.connected) {
        _setConnected(true);
      }

      if (state == BluetoothConnectionState.disconnected) {
        _setConnected(false);
        log("Disconnected, restarting scan");
        start(); // reopen scan automatically
      }
    });

    _setConnected(true);
    log("Connected");

    await discover();
  }

  Future<void> discover() async {
    log("Discovering services");

    final services = await device!.discoverServices();

    for (final s in services) {
      log("Service found: ${s.uuid}");

      if (s.uuid == serviceUUID) {
        log("Matched service");

        for (final c in s.characteristics) {
          log("Characteristic found: ${c.uuid}");

          if (c.uuid == charUUID) {
            log("Matched characteristic");
            characteristic = c;

            await startNotifications();

            return;
          }
        }
      }
    }
  }

  Future<void> startNotifications() async {
    if (characteristic == null) return;

    log("Enabling notifications");
    await characteristic!.setNotifyValue(true);

    characteristic!.value.listen((raw) {
      final value = String.fromCharCodes(raw);
      log("Notification received: $value");
      onValue?.call(value);
    });
  }

  void dispose() {
    timer?.cancel();
    scanSub?.cancel();
    device?.disconnect();
    _setConnected(false);
  }

  void log(String msg) {
    print("BLE: $msg");
  }
}