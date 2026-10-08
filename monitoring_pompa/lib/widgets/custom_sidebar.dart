import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pages/dashboard_page.dart';
import '../pages/alarm_page.dart';
import '../pages/input_data_page.dart';
import '../pages/history_page.dart';

class CustomSidebar extends StatefulWidget {
  final String activeMenu; // 'dashboard', 'alarm', 'input', 'history'

  const CustomSidebar({
    super.key,
    required this.activeMenu,
  });

  @override
  State<CustomSidebar> createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar> {
  late Timer _timer;
  String _timeString = '';
  String _dateString = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    if (mounted) {
      setState(() {
        _timeString = DateFormat('HH : mm : ss').format(now);
        _dateString = DateFormat('EEEE, dd - MM - yyyy', 'id_ID').format(now);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _navigateTo(Widget page) {
    // 1. Tutup drawer jika sedang terbuka di layar HP
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    // 2. Buka halaman baru
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => page,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFDEAA3),
            Color(0xFFFEF6D7),
          ],
        ),
        color: Color(0xFFF1C40F),
      ),
      // SafeArea membungkus Column agar logo dan teks tidak terpotong status bar
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 21),

            // Header Logo & Judul
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/ic.png', width: 26, height: 26, fit: BoxFit.contain),
                const SizedBox(width: 8),
                Text(
                  'Pump Monitoring System',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Menu Navigasi
            _buildSidebarItem(
              imagePath: 'assets/dashboard.png',
              title: 'Dashboard',
              isActive: widget.activeMenu == 'dashboard',
              onTap: widget.activeMenu == 'dashboard'
                  ? null
                  : () => _navigateTo(const DashboardPage()),
            ),
            _buildSidebarItem(
              imagePath: 'assets/alarm.png',
              title: 'Alarm',
              isActive: widget.activeMenu == 'alarm',
              onTap: widget.activeMenu == 'alarm'
                  ? null
                  : () => _navigateTo(const AlarmPage()),
            ),
            _buildSidebarItem(
              imagePath: 'assets/input.png',
              title: 'Data Input',
              isActive: widget.activeMenu == 'input',
              onTap: widget.activeMenu == 'input'
                  ? null
                  : () => _navigateTo(const InputDataPage()),
            ),
            _buildSidebarItem(
              imagePath: 'assets/history.png',
              title: 'History',
              isActive: widget.activeMenu == 'history',
              onTap: widget.activeMenu == 'history'
                  ? null
                  : () => _navigateTo(const HistoryPage()),
            ),

            const Spacer(),

            // Banner Jam & Tanggal Terbawah
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.transparent,
              child: Column(
                children: [
                  Text(
                    _dateString.isEmpty ? "Jum'at, 18 - 09 - 2026" : _dateString,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeString.isEmpty ? '00 : 00 : 00' : _timeString,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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

  Widget _buildSidebarItem({
    required String imagePath,
    required String title,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: Colors.black, width: 2.0)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Image.asset(imagePath, width: 20, height: 20),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}