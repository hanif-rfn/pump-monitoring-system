import 'dart:math';

class PressureCalculator {
  /// Faktor koreksi empiris lapangan:
  /// Dihitung dari rasio tekanan manometer analog riil (44 Psi)
  /// terhadap hasil kalkulasi murni kurva teoritis (~61.9 Psi).
  /// 44.0 / 61.93 ≈ 0.7105
  static const double DEFAULT_FAKTOR_KOREKSI = 0.9328;

  /// Menghitung estimasi tekanan air (Bar dan Psi) menggunakan
  /// pendekatan kurva karakteristik pompa sederhana + faktor penyesuaian.
  static Map<String, double> hitungTekanan({
    required double dayaListrikKw,   // Dari sensor PZEM (daya_kw fasa)
    required double teganganVolt,    // Dari sensor PZEM (tegangan_volt)
    required double arusAmpere,      // Dari sensor PZEM (arus_ampere)
    double dayaNominalKw = 3.7,   // Spesifikasi motor (misal 3.7 kW)
    double efisiensiMotor = 85.0,   // Spesifikasi motor (misal 85%)
    double efisiensiPompa = 75.0,   // Spesifikasi pompa (misal 75%)
    double konstantaA = 9.0,      // Penurunan head saat beban penuh (misal 9.0 meter)
    double konstantaB = 44.0,     // Shut-off head kurva katalog (misal 44.0 meter)
    double faktorKoreksi = DEFAULT_FAKTOR_KOREKSI, // Faktor penyesuaian lapangan (K)
    bool isTigaFasa = true,          // Set true jika PZEM membaca 1 fasa pada motor 3-fasa seimbang
  }) {
    // 1. Kondisi Motor Standby / OFF -> Tekanan 0
    if (teganganVolt < 50.0 || arusAmpere < 0.5 || dayaListrikKw <= 0.0) {
      return {
        'bar': 0.0,
        'psi': 0.0,
        'head_meter': 0.0,
      };
    }

    // 2. Normalisasi Daya Motor Total
    // Jika PZEM-004T dipasang di 1 fasa dari sistem 3-fasa seimbang,
    // total daya aktif motor adalah 3 x daya terukur PZEM.
    final double totalDayaAktifKw = isTigaFasa ? (dayaListrikKw * 3.0) : dayaListrikKw;
    final double pNominal = dayaNominalKw > 0 ? dayaNominalKw : 3.7;

    // 3. Rasio Pembebanan Fraksional (0.0 sampai 1.2)
    final double rasioBeban = (totalDayaAktifKw / pNominal).clamp(0.0, 1.2);

    // 4. Hitung Head Pompa Teoritis (H = b - a * X^2)
    // Saat beban ringan/shut-off (X ~ 0) -> Head mendekati b (44 meter)
    // Saat beban penuh (X = 1.0) -> Head menjadi (b - a) = (44 - 9 = 35 meter)
    final double b = konstantaB > 0 ? konstantaB : 44.0;
    final double a = konstantaA > 0 ? konstantaA : 9.0;
    
    double headTeoritis = b - (a * pow(rasioBeban, 2));
    if (headTeoritis < 0.0) headTeoritis = 0.0;

    // 5. Konversi Head Teoritis ke Tekanan Dasar (1 Bar ~ 10.2 meter air)
    double tekananBarTeoritis = headTeoritis / 10.2;

    // 6. Terapkan Faktor Penyesuaian Lapangan
    // Mengompensasi rugi-rugi gesekan pipa, fitting, dan deviasi no-load
    double tekananBarTerkoreksi = tekananBarTeoritis * faktorKoreksi;
    if (tekananBarTerkoreksi < 0.0) tekananBarTerkoreksi = 0.0;

    // 7. Konversi ke Satuan Psi (1 Bar = 14.5038 Psi)
    double tekananPsiTerkoreksi = tekananBarTerkoreksi * 14.5038;

    return {
      'bar': double.parse(tekananBarTerkoreksi.toStringAsFixed(2)),
      'psi': double.parse(tekananPsiTerkoreksi.toStringAsFixed(1)),
      'head_meter': double.parse(headTeoritis.toStringAsFixed(2)),
    };
  }

  /// Opsi Alternatif: Kalibrasi Linier Dua Titik (y = m * x + c)
  /// Gunakan ini jika ingin respons naik/turun tekanan lebih akurat terhadap jarum analog.
  static double hitungLinearDuaTitik({
    required double dayaAktifKw,
    double dayaTitik1 = 0.83,   // Daya saat katup terbuka normal
    double psiTitik1 = 44.0,    // Manometer saat katup terbuka normal
    double dayaTitik2 = 0.40,   // Daya saat katup ditutup sebagian
    double psiTitik2 = 52.0,    // Manometer saat katup ditutup sebagian
  }) {
    // Kemiringan garis (Slope m)
    final double m = (psiTitik2 - psiTitik1) / (dayaTitik2 - dayaTitik1);
    // Nilai offset (Intercept c)
    final double c = psiTitik1 - (m * dayaTitik1);

    double estimasiPsi = (m * dayaAktifKw) + c;
    if (estimasiPsi < 0.0) estimasiPsi = 0.0;
    return double.parse(estimasiPsi.toStringAsFixed(1));
  }
}