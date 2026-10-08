import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_page.dart';
import 'alarm_page.dart';
import 'history_page.dart';
import '../widgets/custom_header.dart';
import '../widgets/custom_sidebar.dart';

class InputDataPage extends StatefulWidget {
  const InputDataPage({super.key});

  @override
  State<InputDataPage> createState() => _InputDataPageState();
}

class _InputDataPageState extends State<InputDataPage> {
  String selectedPump = 'pompa_1';

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('spesifikasi_pompa');
  StreamSubscription<DatabaseEvent>? _specSubscription;

  // Controller form input
  final TextEditingController _dayaController = TextEditingController();
  final TextEditingController _efisiensiMotorController = TextEditingController();
  final TextEditingController _efisiensiPompaController = TextEditingController();
  final TextEditingController _konstantaAController = TextEditingController();
  final TextEditingController _konstantaBController = TextEditingController();

  // Variabel penampung data spesifikasi saat ini
  double currentDaya = 0.0;
  double currentEfisiensiMotor = 0.0;
  double currentEfisiensiPompa = 0.0;
  double currentKonstantaA = 0.0;
  double currentKonstantaB = 0.0;

  @override
  void initState() {
    super.initState();
    _listenSpesifikasi();
  }

  void _listenSpesifikasi() {
    _specSubscription?.cancel();
    _specSubscription = _dbRef.child(selectedPump).onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          currentDaya = (data['daya_nominal_kw'] ?? 0.0).toDouble();
          currentEfisiensiMotor = (data['efisiensi_motor'] ?? 0.0).toDouble();
          currentEfisiensiPompa = (data['efisiensi_pompa'] ?? 0.0).toDouble();
          currentKonstantaA = (data['konstanta_a'] ?? 0.0).toDouble();
          currentKonstantaB = (data['konstanta_b'] ?? 0.0).toDouble();
        });
      }
    });
  }

  Future<void> _simpanSpesifikasi() async {
    final Map<String, dynamic> dataBaru = {
      'daya_nominal_kw': double.tryParse(_dayaController.text) ?? currentDaya,
      'efisiensi_motor': double.tryParse(_efisiensiMotorController.text) ?? currentEfisiensiMotor,
      'efisiensi_pompa': double.tryParse(_efisiensiPompaController.text) ?? currentEfisiensiPompa,
      'konstanta_a': double.tryParse(_konstantaAController.text) ?? currentKonstantaA,
      'konstanta_b': double.tryParse(_konstantaBController.text) ?? currentKonstantaB,
      'updated_at': ServerValue.timestamp,
    };

    await _dbRef.child(selectedPump).update(dataBaru);

    _dayaController.clear();
    _efisiensiMotorController.clear();
    _efisiensiPompaController.clear();
    _konstantaAController.clear();
    _konstantaBController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spesifikasi berhasil disimpan ke database!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _specSubscription?.cancel();
    _dayaController.dispose();
    _efisiensiMotorController.dispose();
    _efisiensiPompaController.dispose();
    _konstantaAController.dispose();
    _konstantaBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? const Drawer(child: CustomSidebar(activeMenu: 'input')) : null,
      // SafeArea membungkus body agar tidak menabrak status bar
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) const CustomSidebar(activeMenu: 'input'),
            Expanded(
              child: Column(
                children: [
                  CustomHeader(
                    title: 'Data Input',
                    selectedPump: selectedPump,
                    onPumpChanged: (newPump) {
                      setState(() {
                        selectedPump = newPump;
                      });
                      _listenSpesifikasi();
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
                            'Input Spesifikasi Motor',
                            style: GoogleFonts.montserrat(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Banner Tampilan Spesifikasi Aktif Saat Ini
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF1C40F), width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.info_outline, size: 18, color: Colors.black87),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Spesifikasi Aktif Saat Ini (${selectedPump == 'pompa_1' ? 'Motor Pump 1' : 'Motor Pump 2'}):',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: isMobile ? 12 : 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: isMobile ? 14 : 24,
                                  runSpacing: 8,
                                  children: [
                                    _buildInfoChip('Daya Nominal', '$currentDaya kW'),
                                    _buildInfoChip('Efisiensi Motor', '$currentEfisiensiMotor %'),
                                    _buildInfoChip('Efisiensi Pompa', '$currentEfisiensiPompa %'),
                                    _buildInfoChip('Konstanta a', '$currentKonstantaA'),
                                    _buildInfoChip('Konstanta b', '$currentKonstantaB'),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Form Baris 1: Daya, Efisiensi Motor, Efisiensi Pompa
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 700) {
                                return Column(
                                  children: [
                                    _buildInputField('Daya Motor', _dayaController, 'kW'),
                                    const SizedBox(height: 16),
                                    _buildInputField('Efisiensi Motor', _efisiensiMotorController, '%'),
                                    const SizedBox(height: 16),
                                    _buildInputField('Efisiensi Pompa', _efisiensiPompaController, '%'),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: _buildInputField('Daya Motor', _dayaController, 'kW')),
                                  const SizedBox(width: 20),
                                  Expanded(child: _buildInputField('Efisiensi Motor', _efisiensiMotorController, '%')),
                                  const SizedBox(width: 20),
                                  Expanded(child: _buildInputField('Efisiensi Pompa', _efisiensiPompaController, '%')),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Form Baris 2: Konstanta a & Konstanta b
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 700) {
                                return Column(
                                  children: [
                                    _buildInputField('Nilai Konstanta a*', _konstantaAController, ''),
                                    const SizedBox(height: 16),
                                    _buildInputField('Nilai Konstanta b*', _konstantaBController, ''),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: _buildInputField('Nilai Konstanta a*', _konstantaAController, '')),
                                  const SizedBox(width: 20),
                                  Expanded(child: _buildInputField('Nilai Konstanta b*', _konstantaBController, '')),
                                  const SizedBox(width: 20),
                                  const Spacer(),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 28),

                          Text(
                            '* Nilai konstanta a dan b diperoleh dari persamaan kuadratis kurva pabrik yang tertera pada datasheet',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          const SizedBox(height: 36),

                          ElevatedButton(
                            onPressed: _simpanSpesifikasi,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1C40F),
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Simpan Data',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
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

  Widget _buildInfoChip(String label, String value) {
    return RichText(
      text: TextSpan(
        text: '$label: ',
        style: GoogleFonts.montserrat(fontSize: 12, color: Colors.black54),
        children: [
          TextSpan(
            text: value,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String suffix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F1F1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black87),
            decoration: InputDecoration(
              border: InputBorder.none,
              suffixText: suffix.isNotEmpty ? suffix : null,
              suffixStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ),
      ],
    );
  }
}