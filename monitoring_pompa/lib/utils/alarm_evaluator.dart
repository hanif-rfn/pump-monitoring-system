class AlarmStatus {
  final String level; // 'Normal', 'Warning', 'Critical'
  final List<String> messages;

  AlarmStatus({required this.level, required this.messages});
}

class AlarmEvaluator {
  static AlarmStatus evaluate({
    required double tegangan,
    required double arus,
    required double suhu,
    required double pf,
    required double arusNominal,
    bool isMotorRunning = true,
  }) {
    List<String> warnings = [];
    List<String> criticals = [];

    // 1. Evaluasi Suhu (°C) - Tetap aktif untuk memantau motor standby/cooling down
    if (suhu > 70.0) {
      criticals.add('[CRITICAL] Overheat : ${suhu.toStringAsFixed(1)}°C');
    } else if (suhu >= 55.0) {
      warnings.add('[WARNING] Overheat : ${suhu.toStringAsFixed(1)}°C');
    }

    // 2. Evaluasi Parameter Listrik - HANYA AKTIF JIKA TEGANGAN MENGALIR PASKA KONTAKTOR
    // Jika motor mati/standby, tegangan paska kontaktor akan 0V (< 50V)
    if (isMotorRunning) {
      // Evaluasi Kualitas Tegangan (Hanya dicek saat kontaktor aktif)
      if (tegangan < 190.0) {
        criticals.add('[CRITICAL] Undervoltage : ${tegangan.toStringAsFixed(1)}V');
      } else if (tegangan > 245.0) {
        criticals.add('[CRITICAL] Overvoltage : ${tegangan.toStringAsFixed(1)}V');
      } else if (tegangan < 200.0) {
        warnings.add('[WARNING] Undervoltage : ${tegangan.toStringAsFixed(1)}V');
      } else if (tegangan > 240.0) {
        warnings.add('[WARNING] Overvoltage : ${tegangan.toStringAsFixed(1)}V');
      }

      // Evaluasi Power Factor (PF)
      if (arus > 0.5) {
        if (pf < 0.50) {
          criticals.add('[CRITICAL] PF Sangat Rendah : ${pf.toStringAsFixed(2)}');
        } else if (pf <= 0.75) {
          warnings.add('[WARNING] PF Rendah : ${pf.toStringAsFixed(2)}');
        }
      }

      // Evaluasi Arus (A) terhadap Arus Nominal
      if (arusNominal > 0) {
        if (arus > 1.3 * arusNominal) {
          criticals.add('[CRITICAL] Overcurrent Ekstrem : ${arus.toStringAsFixed(2)}A');
        } else if (arus < 0.1) {
          criticals.add('[CRITICAL] Arus Drop saat Bertegangan : ${arus.toStringAsFixed(2)}A');
        } else if (arus > 1.15 * arusNominal) {
          // Peringatan jika melebihi service factor standar motor (+15%)
          warnings.add('[WARNING] Overcurrent : ${arus.toStringAsFixed(2)}A');
        } else if (arus < 0.5 * arusNominal && arus > 0.5) {
          // Ambang batas diturunkan ke 50% untuk mendeteksi dry-run atau kehilangan beban nyata
          warnings.add('[WARNING] Potensial Dry Run   : ${arus.toStringAsFixed(2)}A');
        }
      }
    }

    if (criticals.isNotEmpty) {
      return AlarmStatus(level: 'Critical', messages: criticals);
    } else if (warnings.isNotEmpty) {
      return AlarmStatus(level: 'Warning', messages: warnings);
    }

    return AlarmStatus(
      level: 'Normal',
      messages: [isMotorRunning ? 'Kondisi Operasional Normal' : 'Motor Standby / OFF'],
    );
  }
}