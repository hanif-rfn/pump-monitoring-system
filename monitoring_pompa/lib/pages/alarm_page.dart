import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dashboard_page.dart';
import 'login_page.dart';
import 'input_data_page.dart';
import 'history_page.dart';
import '../widgets/custom_header.dart';
import '../widgets/custom_sidebar.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  String selectedPump = 'pompa_1';

  final List<Map<String, String>> _alarmLogs = [];
  StreamSubscription<DatabaseEvent>? _alarmSubscription;

  @override
  void initState() {
    super.initState();
    _listenAlarmLogs();
  }

  void _listenAlarmLogs() {
    _alarmSubscription?.cancel();
    _alarmSubscription = FirebaseDatabase.instance
        .ref('alarm_logs')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      final List<Map<String, String>> loadedLogs = [];

      if (data != null) {
        data.forEach((key, value) {
          final item = Map<dynamic, dynamic>.from(value);
          if (item['pompa'] == selectedPump) {
            loadedLogs.add({
              'waktu': item['waktu']?.toString() ?? '',
              'keterangan': item['keterangan']?.toString() ?? '',
              'status': item['status']?.toString() ?? '',
            });
          }
        });
        loadedLogs.sort((a, b) => (b['waktu'] ?? '').compareTo(a['waktu'] ?? ''));
      }

      if (mounted) {
        setState(() {
          _alarmLogs.clear();
          _alarmLogs.addAll(loadedLogs);
        });
      }
    });
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? const Drawer(child: CustomSidebar(activeMenu: 'alarm')) : null,
      // SafeArea membungkus body agar tidak menabrak status bar
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar (Tampil di Layar Desktop/Web)
            if (!isMobile) const CustomSidebar(activeMenu: 'alarm'),
            // Area Konten Utama
            Expanded(
              child: Column(
                children: [
                  CustomHeader(
                    title: 'Alarm',
                    selectedPump: selectedPump,
                    onPumpChanged: (newPump) {
                      setState(() {
                        selectedPump = newPump;
                      });
                      _listenAlarmLogs();
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: isMobile ? 16.0 : 32.0,
                        right: isMobile ? 16.0 : 32.0,
                        top: isMobile ? 12.0 : 20.0,
                        bottom: 24.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daftar Riwayat Alarm',
                            style: GoogleFonts.montserrat(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Tabel Riwayat Alarm
                          _buildAlarmTable(isMobile),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmTable(bool isMobile) {
    if (_alarmLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Tidak ada riwayat anomali pada pompa ini.',
          style: GoogleFonts.montserrat(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: isMobile ? 480 : 580),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade400, width: 1),
            columnWidths: {
              0: FixedColumnWidth(isMobile ? 130 : 160), // Penyesuaian lebar kolom waktu
              1: const FlexColumnWidth(),               // Keterangan fleksibel
              2: FixedColumnWidth(isMobile ? 95 : 120),  // Penyesuaian kolom status
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header Tabel
              TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE047),
                ),
                children: [
                  _buildTableCell('Waktu', isHeader: true, isMobile: isMobile),
                  _buildTableCell('Keterangan Anomali', isHeader: true, isMobile: isMobile),
                  _buildTableCell('Status', isHeader: true, isMobile: isMobile),
                ],
              ),

              // Isi Data Baris Tabel
              ..._alarmLogs.asMap().entries.map((entry) {
                final int index = entry.key;
                final Map<String, String> log = entry.value;
                final bool isEven = index % 2 == 1;

                return TableRow(
                  decoration: BoxDecoration(
                    color: isEven ? const Color(0xFFFEF9C3) : Colors.white,
                  ),
                  children: [
                    _buildTableCell(log['waktu'] ?? '', isMobile: isMobile),
                    _buildTableCell(log['keterangan'] ?? '', isMobile: isMobile),
                    _buildTableCell(log['status'] ?? '', isMobile: isMobile),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isMobile = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 10.0 : 14.0,
        horizontal: isMobile ? 10.0 : 16.0,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: isHeader ? (isMobile ? 12 : 14) : (isMobile ? 11 : 13),
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
}