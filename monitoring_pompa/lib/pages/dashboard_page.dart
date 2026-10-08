import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'alarm_page.dart';
import 'input_data_page.dart';
import 'history_page.dart';
import '../widgets/custom_header.dart';
import '../utils/alarm_evaluator.dart';
import '../services/app_notification_service.dart';
import '../widgets/custom_sidebar.dart';
import '../utils/pressure_calculator.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('telemetry');
  final DatabaseReference _specRef = FirebaseDatabase.instance.ref('spesifikasi_pompa');

  String selectedPump = 'pompa_1'; 
  StreamSubscription<DatabaseEvent>? _telemetrySubscription;
  StreamSubscription<DatabaseEvent>? _specSubscription;

  // Stream Data Sensor Telemetri
  double arus = 0.0;
  double faktorDaya = 0.0;
  double tegangan = 0.0;
  double daya = 0.0;
  double suhu = 0.0;
  double tekanan = 0.0;

  // Parameter Spesifikasi Motor & Pompa (dari Data Input)
  double dayaNominal = 15.0;
  double efisiensiMotor = 85.0;
  double efisiensiPompa = 90.0;
  double konstantaA = 2.0;
  double konstantaB = 5.0;

  // Debounce & State Alarm
  DateTime? _lastLoggedTime;
  DateTime? _lastNotifiedTime;

  @override
  void initState() {
    super.initState();
    _listenMotorSpecs();
    _listenFirebase();
  }

  // Mendengarkan perubahan data input spesifikasi motor yang disimpan user
  void _listenMotorSpecs() {
    _specSubscription?.cancel();
    _specSubscription = _specRef.child(selectedPump).onValue.listen((DatabaseEvent event) {
      final specData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (specData != null && mounted) {
        setState(() {
          dayaNominal = (specData['daya_nominal_kw'] ?? 3.7).toDouble();
          efisiensiMotor = (specData['efisiensi_motor'] ?? 85.0).toDouble();
          efisiensiPompa = (specData['efisiensi_pompa'] ?? 75.0).toDouble();
          konstantaA = (specData['konstanta_a'] ?? 2.0).toDouble();
          konstantaB = (specData['konstanta_b'] ?? 45.0).toDouble();
        });
      }
    });
  }

  void _listenFirebase() {
    _telemetrySubscription?.cancel();

    _telemetrySubscription = _dbRef.child(selectedPump).onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && mounted) {
        final double newArus = (data['arus_ampere'] ?? 0.0).toDouble();
        final double newPf = (data['faktor_daya'] ?? 0.0).toDouble();
        final double newTegangan = (data['tegangan_volt'] ?? 0.0).toDouble();
        final double newDaya = (data['daya_kw'] ?? 0.0).toDouble();
        final double newSuhu = (data['suhu_celsius'] ?? 0.0).toDouble();

        // Hitung tekanan air secara real-time
        final double computedTekanan = PressureCalculator.hitungTekanan(
          dayaListrikKw: newDaya,
          teganganVolt: newTegangan,
          arusAmpere: newArus,
          dayaNominalKw: dayaNominal,
          efisiensiMotor: efisiensiMotor,
          efisiensiPompa: efisiensiPompa,
          konstantaA: konstantaA,
          konstantaB: konstantaB,
        )['bar'] ?? 0.0;

        _dbRef.child(selectedPump).update({
          'tekanan_bar': double.parse(computedTekanan.toStringAsFixed(2)),
          'tekanan_psi': double.parse((computedTekanan * 14.5038).toStringAsFixed(1)),
        });

        // 1. Evaluasi Alarm, Log Firebase, dan Notifikasi Desktop
        _checkAndLogAlarm(newTegangan, newArus, newSuhu, newPf);

        // 2. Perbarui Tampilan Dashboard
        setState(() {
          arus = newArus;
          faktorDaya = newPf;
          tegangan = newTegangan;
          daya = newDaya;
          suhu = newSuhu;
          tekanan = computedTekanan;
        });
      }
    });
  }

  void _checkAndLogAlarm(double v, double a, double t, double pfVal) {
    // Menggunakan arus perkiraan dari daya nominal (misal 15kW 3-fasa ~ 28A)
    double arusNominal = (dayaNominal > 0) ? (dayaNominal * 1000) / (1.732 * 380 * 0.85) : 10.0; 
    final bool isRunning = v > 50.0;

    final result = AlarmEvaluator.evaluate(
      tegangan: v,
      arus: a,
      suhu: t,
      pf: pfVal,
      arusNominal: arusNominal,
      isMotorRunning: isRunning,
    );

    if (result.level != 'Normal') {
      final now = DateTime.now();
      final String pumpTitle = selectedPump == 'pompa_1' ? 'Motor Pump 1' : 'Motor Pump 2';
      final String alertMessages = result.messages.join(' | ');

      // Trigger Notifikasi Desktop Chrome/Windows
      if (_lastNotifiedTime == null || now.difference(_lastNotifiedTime!).inSeconds > 15) {
        _lastNotifiedTime = now;
        AppNotificationService.showNotification(
          title: '🚨 PERINGATAN SISTEM: $pumpTitle',
          body: alertMessages,
        );
      }

      // Catat ke Firebase node /alarm_logs
      if (_lastLoggedTime == null || now.difference(_lastLoggedTime!).inSeconds > 30) {
        _lastLoggedTime = now;
        
        final logData = {
          'pompa': selectedPump,
          'waktu': DateFormat('dd-MM-yyyy HH:mm:ss').format(now),
          'keterangan': alertMessages,
          'status': result.level == 'Critical' ? 'Bahaya' : 'Peringatan',
          'timestamp': ServerValue.timestamp,
        };

        FirebaseDatabase.instance.ref('alarm_logs').push().set(logData);
      }
    }
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _specSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? const Drawer(child: CustomSidebar(activeMenu: 'dashboard')) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) const CustomSidebar(activeMenu: 'dashboard'),
            Expanded(
              child: Column(
                children: [
                  CustomHeader(
                    title: 'Dashboard',
                    selectedPump: selectedPump,
                    onPumpChanged: (newPump) {
                      setState(() {
                        selectedPump = newPump;
                      });
                      _listenMotorSpecs();
                      _listenFirebase();
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 20.0, left: 32.0, right: 32.0, bottom: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Real-Time Data',
                            style: GoogleFonts.montserrat(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // --- GANTI GRIDVIEW DENGAN STRUKTUR LAYOUT DI BAWAH INI ---
                          if (isMobile) ...[
                            // Tampilan Vertikal untuk Layar Mobile/HP
                            _buildMetricCard(
                              title: 'Arus Motor (Fasa R)',
                              value: arus.toStringAsFixed(1),
                              unit: 'A',
                              gradient: const [Color(0xFFE74C3C), Color(0xFFC0392B)],
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              title: 'Faktor Daya (Fasa R)',
                              value: faktorDaya.toStringAsFixed(2),
                              unit: '',
                              gradient: const [Color(0xFF5CD836), Color(0xFF42C01E)],
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              title: 'Tegangan Motor (Fasa R)',
                              value: tegangan.toStringAsFixed(0),
                              unit: 'V',
                              gradient: const [Color(0xFFF1C40F), Color(0xFFE6B800)],
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              title: 'Daya Motor',
                              value: daya.toStringAsFixed(0),
                              unit: 'kW',
                              gradient: const [Color(0xFF3248E6), Color(0xFF2436C2)],
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              title: 'Suhu Bodi Motor',
                              value: suhu.toStringAsFixed(1),
                              unit: '°',
                              gradient: const [Color(0xFF1DD1A1), Color(0xFF10AC84)],
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              title: 'Tekanan Air (Bar)',
                              value: tekanan.toStringAsFixed(1),
                              unit: 'Bar',
                              gradient: const [Color(0xFFD6308F), Color(0xFFC01F78)],
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              title: 'Tekanan Air (Psi)',
                              value: (tekanan * 14.5038).toStringAsFixed(0),
                              unit: 'Psi',
                              gradient: const [Color(0xFFE5A93C), Color(0xFFD29324)],
                            ),
                          ] else ...[
                            // Tampilan Desktop/Tablet Sesuai Gambar Desain
                            // Baris 1: Arus & Faktor Daya (2 Card)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Arus Motor (Fasa R)',
                                    value: arus.toStringAsFixed(1),
                                    unit: 'A',
                                    gradient: const [Color(0xFFE74C3C), Color(0xFFC0392B)],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Faktor Daya (Fasa R)',
                                    value: faktorDaya.toStringAsFixed(2),
                                    unit: '',
                                    gradient: const [Color(0xFF5CD836), Color(0xFF42C01E)],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Baris 2: Tegangan & Daya Motor (2 Card)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Tegangan Motor (Fasa R)',
                                    value: tegangan.toStringAsFixed(0),
                                    unit: 'V',
                                    gradient: const [Color(0xFFF1C40F), Color(0xFFE6B800)],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Daya Motor',
                                    value: daya.toStringAsFixed(0),
                                    unit: 'kW',
                                    gradient: const [Color(0xFF3248E6), Color(0xFF2436C2)],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Baris 3: Suhu, Tekanan (Bar), dan Tekanan (Psi) (3 Card)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Suhu Bodi Motor',
                                    value: suhu.toStringAsFixed(1),
                                    unit: '°',
                                    gradient: const [Color(0xFF1DD1A1), Color(0xFF10AC84)],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Tekanan Air (Bar)',
                                    value: tekanan.toStringAsFixed(1),
                                    unit: 'Bar',
                                    gradient: const [Color(0xFFD6308F), Color(0xFFC01F78)],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Tekanan Air (Psi)',
                                    value: (tekanan * 14.5038).toStringAsFixed(0),
                                    unit: 'Psi',
                                    gradient: const [Color(0xFFE5A93C), Color(0xFFD29324)],
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required List<Color> gradient,
  }) {
    final bool isMobile = MediaQuery.of(context).size.width < 800; //[cite: 5]

    return Container(
      height: isMobile ? 120 : 135, // Menjaga ketinggian kartu tetap proporsional
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight), //[cite: 5]
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))], //[cite: 5]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, //[cite: 5]
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end, //[cite: 5]
            crossAxisAlignment: CrossAxisAlignment.baseline, //[cite: 5]
            textBaseline: TextBaseline.alphabetic, //[cite: 5]
            children: [
              Text(
                value,
                style: GoogleFonts.lilex(
                  color: Colors.white, //[cite: 5]
                  fontSize: isMobile ? 36 : 46,
                  fontWeight: FontWeight.bold, //[cite: 5]
                ),
              ),
              const SizedBox(width: 6), //[cite: 5]
              Text(
                unit,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ), //[cite: 5]
            ],
          ),
        ],
      ),
    );
  }
}