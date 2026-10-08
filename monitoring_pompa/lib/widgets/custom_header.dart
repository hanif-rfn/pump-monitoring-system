import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../pages/login_page.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomHeader extends StatefulWidget {
  final String title;
  final String selectedPump;
  final ValueChanged<String>? onPumpChanged;

  const CustomHeader({
    super.key,
    required this.title,
    required this.selectedPump,
    this.onPumpChanged,
  });

  @override
  State<CustomHeader> createState() => _CustomHeaderState();
}

class _CustomHeaderState extends State<CustomHeader> {
  bool _isEspConnected = false;
  int _lastSeenTimestamp = 0;
  StreamSubscription<DatabaseEvent>? _heartbeatSub;
  Timer? _checkerTimer;

  @override
  void initState() {
    super.initState();
    _listenEspHeartbeat();
    // Cek setiap 3 detik apakah ESP32 masih aktif mengirim data
    _checkerTimer = Timer.periodic(const Duration(seconds: 3), (_) => _evaluateConnection());
  }

  @override
  void didUpdateWidget(covariant CustomHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jika dropdown pompa berganti, pantau ESP pompa yang baru
    if (oldWidget.selectedPump != widget.selectedPump) {
      _listenEspHeartbeat();
    }
  }

  void _listenEspHeartbeat() {
    _heartbeatSub?.cancel();
    _heartbeatSub = FirebaseDatabase.instance
        .ref('telemetry/${widget.selectedPump}/last_seen')
        .onValue
        .listen((event) {
      final val = event.snapshot.value;
      if (val is int) {
        _lastSeenTimestamp = val;
        _evaluateConnection();
      }
    });
  }

  void _evaluateConnection() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Toleransi timeout: 10 detik (10.000 ms)
    final bool isAlive = _lastSeenTimestamp > 0 && (nowMs - _lastSeenTimestamp) < 10000;

    if (mounted && _isEspConnected != isAlive) {
      setState(() {
        _isEspConnected = isAlive;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _heartbeatSub?.cancel();
    _checkerTimer?.cancel();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  final bool isMobile = MediaQuery.of(context).size.width < 800;

  return Container(
    height: 70,
    padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 8,
          spreadRadius: -4,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        // Tombol buka menu drawer khusus di HP
        if (isMobile)
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),

        Text(
          widget.title,
          style: GoogleFonts.montserrat(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),

        // Dropdown Pemilihan Pompa
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isDense: true,
              value: widget.selectedPump,
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
              style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
              onChanged: (String? newValue) {
                if (newValue != null && widget.onPumpChanged != null) {
                  widget.onPumpChanged!(newValue);
                }
              },
              items: const [
                DropdownMenuItem(value: 'pompa_1', child: Text('Pump 1')),
                DropdownMenuItem(value: 'pompa_2', child: Text('Pump 2')),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Indikator Status & Profil
        Row(
          children: [
            Icon(
              Icons.circle,
              color: _isEspConnected ? Colors.green : Colors.black54,
              size: 9,
            ),
            const SizedBox(width: 4),
            // Teks status disembunyikan di HP agar hemat ruang
            if (!isMobile)
              Text(
                _isEspConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  fontSize: 11,
                  color: _isEspConnected ? Colors.green : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.logout, size: 18, color: Colors.black54),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
      ],
    ),
  );
}
}