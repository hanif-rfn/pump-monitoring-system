import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard_page.dart';
import 'alarm_page.dart';
import 'input_data_page.dart';
import '../widgets/custom_header.dart';
import '../widgets/custom_sidebar.dart';
import '../utils/pressure_calculator.dart';

class HistoryPoint {
  final DateTime time;
  final double value;

  HistoryPoint({required this.time, required this.value});
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String selectedPump = 'pompa_1';

  // Data titik riwayat untuk masing-masing parameter
  List<HistoryPoint> _arusPoints = [];
  List<HistoryPoint> _pfPoints = [];
  List<HistoryPoint> _teganganPoints = [];
  List<HistoryPoint> _dayaPoints = [];
  List<HistoryPoint> _suhuPoints = [];
  List<HistoryPoint> _tekananPoints = [];

  StreamSubscription<DatabaseEvent>? _historySubscription;

  @override
  void initState() {
    super.initState();
    _listenHistory();
  }

  void _listenHistory() {
    _historySubscription?.cancel();

    // Mengambil 20 data rekaman terakhir
    _historySubscription = FirebaseDatabase.instance
        .ref('history/$selectedPump')
        .orderByChild('timestamp')
        .limitToLast(20)
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      final List<HistoryPoint> arus = [];
      final List<HistoryPoint> pf = [];
      final List<HistoryPoint> tegangan = [];
      final List<HistoryPoint> daya = [];
      final List<HistoryPoint> suhu = [];
      final List<HistoryPoint> tekanan = [];

      if (data != null) {
        // Urutkan key data berdasarkan timestamp
        final sortedEntries = data.entries.toList()
          ..sort((a, b) {
            final tA = (a.value['timestamp'] ?? 0) as int;
            final tB = (b.value['timestamp'] ?? 0) as int;
            return tA.compareTo(tB);
          });

        for (var entry in sortedEntries) {
          final item = Map<dynamic, dynamic>.from(entry.value);
          final int ts = (item['timestamp'] ?? 0) as int;
          final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ts);

          // 1. Ekstrak data mentah
          double histArus = (item['arus'] ?? 0.0).toDouble();
          double histPf = (item['faktor_daya'] ?? item['pf'] ?? 0.0).toDouble();
          double histTegangan = (item['tegangan'] ?? 220.0).toDouble();
          double histDaya = (item['daya'] ?? 0.0).toDouble();
          double histSuhu = (item['suhu'] ?? 0.0).toDouble();

          // 2. Kalkulasi estimasi tekanan jika field 'tekanan' belum tersimpan di database
          double histTekanan = 0.0;
          if (item['tekanan_bar'] != null) {
            histTekanan = (item['tekanan_bar']).toDouble();
          } else if (item['tekanan'] != null) {
            histTekanan = (item['tekanan']).toDouble();
          } else {
            // Ambil nilai ['bar'] dari Map hasil hitungTekanan
            final calcResult = PressureCalculator.hitungTekanan(
              dayaListrikKw: histDaya,
              teganganVolt: histTegangan,
              arusAmpere: histArus,
              dayaNominalKw: 3.7,
              efisiensiMotor: 85.0,
              efisiensiPompa: 75.0,
              konstantaA: 9.0,
              konstantaB: 44.0,
            );
            histTekanan = (calcResult['bar'] ?? 0.0).toDouble();
          }

          // 3. Masukkan ke dalam masing-masing list grafik
          arus.add(HistoryPoint(time: dt, value: histArus));
          pf.add(HistoryPoint(time: dt, value: histPf));
          tegangan.add(HistoryPoint(time: dt, value: histTegangan));
          daya.add(HistoryPoint(time: dt, value: histDaya));
          suhu.add(HistoryPoint(time: dt, value: histSuhu));
          tekanan.add(HistoryPoint(time: dt, value: histTekanan));
        }
      }

      if (mounted) {
        setState(() {
          _arusPoints = arus;
          _pfPoints = pf;
          _teganganPoints = tegangan;
          _dayaPoints = daya;
          _suhuPoints = suhu;
          _tekananPoints = tekanan;
        });
      }
    });
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? const Drawer(child: CustomSidebar(activeMenu: 'history')) : null,
      // BUNGKUS DENGAN SafeArea AGAR TIDAK MENABRAK STATUS BAR / NOTIFIKASI
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) const CustomSidebar(activeMenu: 'history'),
            Expanded(
              child: Column(
                children: [
                  CustomHeader(
                    title: 'History',
                    selectedPump: selectedPump,
                    onPumpChanged: (newPump) {
                      setState(() {
                        selectedPump = newPump;
                      });
                      _listenHistory();
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      // KECILKAN PADDING TOP DARI 20.0 MENJADI 12.0 (KHUSUS MOBILE)
                      padding: EdgeInsets.only(
                        top: isMobile ? 12.0 : 20.0,
                        left: isMobile ? 16.0 : 32.0,
                        right: isMobile ? 16.0 : 32.0,
                        bottom: 24.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trendline',
                            style: GoogleFonts.montserrat(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          // JARAK DIPERCEPAT DARI 20 KE 10
                          const SizedBox(height: 10),

                          // Grid 6 Kartu Trendline Dinamis
                          GridView.count(
                            crossAxisCount: isMobile ? 1 : 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: isMobile ? 12 : 20,
                            mainAxisSpacing: isMobile ? 12 : 20,
                            childAspectRatio: isMobile ? 1.6 : 2.0,
                            children: [
                              _TrendlineCard(
                                title: 'Arus Motor (A)',
                                unit: 'A',
                                points: _arusPoints,
                                gradient: const [Color(0xFFE74C3C), Color(0xFFC0392B)],
                              ),
                              _TrendlineCard(
                                title: 'Faktor Daya (PF)',
                                unit: '',
                                points: _pfPoints,
                                gradient: const [Color(0xFF2ECC71), Color(0xFF27AE60)],
                              ),
                              _TrendlineCard(
                                title: 'Tegangan Motor (V)',
                                unit: 'V',
                                points: _teganganPoints,
                                gradient: const [Color(0xFFD4AC0D), Color(0xFFB7950B)],
                              ),
                              _TrendlineCard(
                                title: 'Daya Motor (kW)',
                                unit: 'kW',
                                points: _dayaPoints,
                                gradient: const [Color(0xFF34495E), Color(0xFF2C3E50)],
                              ),
                              _TrendlineCard(
                                title: 'Suhu Bodi Motor (°C)',
                                unit: '°C',
                                points: _suhuPoints,
                                gradient: const [Color(0xFF1ABC9C), Color(0xFF16A085)],
                              ),
                              _TrendlineCard(
                                title: 'Tekanan Air (Bar)',
                                unit: 'Bar',
                                points: _tekananPoints,
                                gradient: const [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                              ),
                            ],
                          ),
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
}

class _TrendlineCard extends StatelessWidget {
  final String title;
  final String unit;
  final List<HistoryPoint> points;
  final List<Color> gradient;

  const _TrendlineCard({
    required this.title,
    required this.unit,
    required this.points,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final latestVal = points.isNotEmpty ? points.last.value.toStringAsFixed(1) : '--';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$latestVal $unit',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: points.isEmpty
                ? Center(
                    child: Text(
                      'Menunggu data riwayat...',
                      style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 11),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white24,
                          strokeWidth: 0.8,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (val, meta) => Text(
                              val < 10 ? val.toStringAsFixed(1) : val.toStringAsFixed(0),
                              style: const TextStyle(color: Colors.white70, fontSize: 9),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            interval: (points.length > 4 ? (points.length / 4).floor().toDouble() : 1),
                            getTitlesWidget: (val, meta) {
                              int idx = val.toInt();
                              if (idx >= 0 && idx < points.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    DateFormat('HH:mm').format(points[idx].time),
                                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          left: BorderSide(color: Colors.white70, width: 1.5),
                          bottom: BorderSide(color: Colors.white70, width: 1.5),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: Colors.white,
                          barWidth: 2.2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}