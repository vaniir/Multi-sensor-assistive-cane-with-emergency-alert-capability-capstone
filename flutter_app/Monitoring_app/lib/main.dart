import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // ✅ IMPORTANT (Guid fix)
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ble_code.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activity Monitor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _AppBar(),
      body: StatusScreen(),
    );
  }
}

// ===== AppBar =====
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1F1F1F),
      centerTitle: true,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart, color: Color.fromARGB(255, 41, 167, 189)),
          SizedBox(width: 8),
          Text(
            "Guardian Monitor",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ===== Status Screen =====
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  // ===== Dashboard values =====
  String caneStatus = "Disconnected";
  String bleStatus = "Disconnected";
  String activityStatus = "Idle";
  String lastUpdateSeconds = "0";

  // ===== Fall detection =====
  bool fallDialogVisible = false;
  bool lastFallState = false;

  BLEService? ble;

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _startBLE();
  }

  // ===== Notifications =====
  void _initNotifications() {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings =
        InitializationSettings(android: androidSettings);

    notifications.initialize(initSettings,
        onDidReceiveNotificationResponse: (response) async {
      if (response.payload != null) {
        final uri = Uri.parse(response.payload!);
        await launchUrl(uri);
      }
    });
  }

  // ===== BLE Setup =====
  Future<void> _startBLE() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect
    ].request();

    ble = BLEService(
      deviceName: "GatewayDevice",
      serviceUUID: Guid("12345678-1234-1234-1234-1234567890ab"),
      charUUID: Guid("abcd1234-5678-90ab-cdef-1234567890ab"),
    );

    ble?.onValue = _onBLEData;

    ble?.onConnectionChanged = (connected) {
      setState(() {
        bleStatus = connected ? "Connected" : "Disconnected";
      });
    };

    ble?.start();
  }

  // ===== BLE Data Handler =====
  void _onBLEData(String data) {
    final parts = data.split(",");

    final lat = parts.isNotEmpty ? parts[0] : "--";
    final lon = parts.length > 1 ? parts[1] : "--";
    final fallStatus = parts.length > 2 ? parts[2] : "nofall";
    final activity = parts.length > 3 ? parts[3] : "--";
    final lastUpdate = parts.length > 4 ? parts[4] : "0";
    final caneConn = parts.length > 5 ? parts[5] : "Disconnected";

    final fallNow = fallStatus == "fall";

    setState(() {
      activityStatus = (bleStatus == "Connected" && displayCaneStatus() == "Connected")
      ? activity : "Unknown";
      lastUpdateSeconds = lastUpdate;
      caneStatus = caneConn;
    });

    if (fallNow && !lastFallState) {
      _triggerFallAlert(lat, lon);
    }

    lastFallState = fallNow;
  }

  // ===== Helpers =====
  String displayCaneStatus() {
    if (bleStatus != "Connected") return "Unknown";
    return caneStatus;
  }

  String formatLastUpdate(String secondsStr) {
    final seconds = int.tryParse(secondsStr) ?? 0;

    if (seconds < 60) {
      return "$seconds s";
    } else {
      final minutes = (seconds / 60).toStringAsFixed(1);
      return "$minutes min";
    }
  }

  // ===== Fall Alert =====
  void _triggerFallAlert(String lat, String lon) {
    _sendNotification(lat, lon);

    if (!fallDialogVisible) {
      fallDialogVisible = true;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("⚠️ Fall Detected"),
          content: Text("Location:\n$lat , $lon"),
          backgroundColor: Colors.red[900],
          titleTextStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Colors.white),
        ),
      ).then((_) {
        fallDialogVisible = false;
      });
    }
  }

  void _sendNotification(String lat, String lon) async {
    final url = "https://www.google.com/maps?q=$lat,$lon";

    const androidDetails = AndroidNotificationDetails(
      'fall_channel',
      'Fall Alerts',
      channelDescription: 'Fall detection alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await notifications.show(
      0,
      "⚠️ Fall Detected",
      "Tap to view location",
      details,
      payload: url,
    );
  }

  @override
  void dispose() {
    ble?.dispose();
    super.dispose();
  }

  // ===== UI =====
  Widget _tile(IconData icon, String label, String value) {
    return Card(
      color: const Color(0xFF1F1F1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: const Color(0xFF29A7BD)),
            const SizedBox(height: 20),
            Text(label, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _tile(Icons.usb, "Cane Connection", displayCaneStatus()),
          _tile(Icons.bluetooth, "BLE Connection", bleStatus),
          _tile(Icons.directions_walk, "Activity Status", activityStatus),
          _tile(Icons.timer, "Last Update",
              formatLastUpdate(lastUpdateSeconds)),
        ],
      ),
    );
  }
}