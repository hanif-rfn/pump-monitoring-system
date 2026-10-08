// import library sesuai kebutuhan
#include <Arduino.h>
#include <WiFi.h>
#include <FirebaseESP32.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <PZEM004Tv30.h>
#include <esp_wifi.h>

// konfigurasi wifi dan firebase
#define WIFI_SSID "BFI-AP"
#define WIFI_PASSWORD "N0tR4nd0m1z3d."

#define FIREBASE_HOST "https://ta-monitoring-pompa-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define FIREBASE_AUTH "DzODTCZrgG0B9Fb4HlN0HJf26gr1a1k05b74mMuR"
FirebaseData firebaseData;
FirebaseAuth auth;
FirebaseConfig config;

// pendefinisian indikator led koneksi wifi
#define LED_WIFI 2
#define PIN_BOOT_BUTTON 0

// mapping pin sensor suhu dan pengalamatan masing2 sensor
#define ONE_WIRE_BUS 4
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature ds18b20(&oneWire);

DeviceAddress addrMotor1 = {0x28, 0xEC, 0xB6, 0xB3, 0x00, 0x00, 0x00, 0x80};
DeviceAddress addrMotor2 = {0x28, 0x9A, 0xC4, 0xB3, 0x00, 0x00, 0x00, 0x44};

// variabel penampung nilai suhu valid terakhir
float suhu1 = 0.0;
float suhu2 = 0.0;

// mapping pin PZEM-004T 1 dan 2
PZEM004Tv30 pzem1(Serial2, 16, 17);
PZEM004Tv30 pzem2(Serial1, 26, 27);

// Faktor kalibrasi arus (dibandingkan dengan tang ampere)
const float CAL_CURRENT_1 = 5.25 / 4.7;
const float CAL_CURRENT_2 = 5.4 / 5.015;

// timer pengiriman data PZEM-004T setiap 3 detik
unsigned long previousMillis = 0;
const long interval = 3000;

// timer logging riwayat setiap 5 menit
unsigned long prevHistoryMillis = 0;
const long historyInterval = 300000;

// variabel untuk blinking led indikator koneksi wifi
unsigned long prevLedBlinkMillis = 0;

void setup()
{
  Serial.begin(115200);

  pinMode(LED_WIFI, OUTPUT);
  digitalWrite(LED_WIFI, LOW);

  pinMode(PIN_BOOT_BUTTON, INPUT_PULLUP);

  // inisialisasi DS18B20, resolusi 10 bit, dan mode non-blocking
  ds18b20.begin();

  ds18b20.setResolution(addrMotor1, 10);
  ds18b20.setResolution(addrMotor2, 10);
  
  ds18b20.setWaitForConversion(false);
  ds18b20.requestTemperatures();

  if (digitalRead(PIN_BOOT_BUTTON) == LOW)
  {
    Serial.println("\n>> [MANUAL RESET] Tombol BOOT ditekan!");
    Serial.println(">> Membersihkan cache Wi-Fi lama di NVS...");
    WiFi.disconnect(true, true); // Parameter true kedua = hapus NVS
    delay(1000);
    Serial.println(">> Cache bersih, melanjutkan koneksi baru.");
  }

  //setup wifi supaya tahan noise tinggi di ruangan pompa
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
  esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Menghubungkan ke Wi-Fi");

  int retryCounter = 0;
  const int MAX_RETRY = 100;

  // logika ketika wifi belum connect, indikator led biru berkedip, dan manjer ketika wifi connect
  while (WiFi.status() != WL_CONNECTED)
  {
    digitalWrite(LED_WIFI, HIGH);
    delay(150);
    digitalWrite(LED_WIFI, LOW);
    delay(150);
    Serial.print(".");

    retryCounter++;
    // Jika lewat dari 30 detik belum terhubung, restart otomatis
    if (retryCounter >= MAX_RETRY)
    {
      Serial.println("\n>> [TIMEOUT] Wi-Fi gagal terhubung dalam 30 detik!");
      Serial.println(">> Merestart ESP32 secara mandiri...");
      ESP.restart(); // Memaksa ESP32 reboot untuk meminta IP ulang ke router
    }
  }

  digitalWrite(LED_WIFI, HIGH);
  Serial.println("\nTerhubung ke Wi-Fi!");
  Serial.print("IP Address ESP32: ");
  Serial.println(WiFi.localIP());

  // konfigurasi koneksi ke firebase
  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&config, &auth);

  // Nonaktifkan reconnect bawaan library yang blocking
  Firebase.reconnectWiFi(false);

  Serial.println("Monitoring Pompa IoT Siap!\n");
}

void loop()
{
  unsigned long currentMillis = millis();

  // monitor status koneksi wifi, jika terputus maka led indikator berkedip dan mencoba reconnect
  if (WiFi.status() == WL_CONNECTED)
  {
    digitalWrite(LED_WIFI, HIGH);
  }
  else
  {
    if (currentMillis - prevLedBlinkMillis >= 500)
    {
      prevLedBlinkMillis = currentMillis;
      digitalWrite(LED_WIFI, !digitalRead(LED_WIFI));
      WiFi.reconnect();
    }
  }

  // siklus telemetri data
  if (currentMillis - previousMillis >= interval)
  {
    previousMillis = currentMillis;

    // ================= PEMBACAAN PZEM-004T #1 =================
    float tegangan1 = pzem1.voltage();
    float rawArus1 = 0.0;
    float pf1 = 1.0;
    float powerWatt1 = 0.0;

    if (!isnan(tegangan1) && tegangan1 > 0.0)
    {
      rawArus1 = pzem1.current();
      powerWatt1 = pzem1.power(); // Baca daya aktif riil (Watt) langsung dari PZEM
      pf1 = pzem1.pf();           // Baca PF dari PZEM

      if (isnan(rawArus1)) rawArus1 = 0.0;
      if (isnan(powerWatt1)) powerWatt1 = 0.0;
    }
    else
    {
      tegangan1 = 0.0;
    }

    // 1. Hitung arus terkalibrasi lebih dulu
    float arus1 = rawArus1 * CAL_CURRENT_1;

    // 2. Tentukan daya motor (kW): gunakan hasil baca PZEM jika valid
    float daya1 = 0.0;
    if (powerWatt1 > 0.0) {
      daya1 = powerWatt1 / 1000.0;
    } else {
      // Fallback jika powerWatt bernilai 0 tapi ada arus mengalir
      daya1 = (tegangan1 * arus1 * 0.85) / 1000.0;
    }

    // 3. Evaluasi PF (apakah valid dari sensor atau perlu dihitung dari P/(V*I))
    if (isnan(pf1) || pf1 <= 0.0)
    {
      if (tegangan1 > 0.0 && arus1 > 0.1) {
        pf1 = (daya1 * 1000.0) / (tegangan1 * arus1);
        if (pf1 > 1.0) pf1 = 0.98;
      } else {
        pf1 = 0.0;
      }
    }

    // jeda 10 ms untuk background task wifi
    vTaskDelay(10 / portTICK_PERIOD_MS);

    // ================= PEMBACAAN PZEM-004T #2 =================
    float tegangan2 = pzem2.voltage();
    float rawArus2 = 0.0;
    float pf2 = 1.0;
    float powerWatt2 = 0.0;

    if (!isnan(tegangan2) && tegangan2 > 0.0)
    {
      rawArus2 = pzem2.current();
      powerWatt2 = pzem2.power();
      pf2 = pzem2.pf();

      if (isnan(rawArus2)) rawArus2 = 0.0;
      if (isnan(powerWatt2)) powerWatt2 = 0.0;
    }
    else
    {
      tegangan2 = 0.0;
    }

    float arus2 = rawArus2 * CAL_CURRENT_2;

    float daya2 = 0.0;
    if (powerWatt2 > 0.0) {
      daya2 = powerWatt2 / 1000.0;
    } else {
      daya2 = (tegangan2 * arus2 * 0.85) / 1000.0;
    }

    if (isnan(pf2) || pf2 <= 0.0)
    {
      if (tegangan2 > 0.0 && arus2 > 0.1) {
        pf2 = (daya2 * 1000.0) / (tegangan2 * arus2);
        if (pf2 > 1.0) pf2 = 0.98;
      } else {
        pf2 = 0.0;
      }
    }

    vTaskDelay(10 / portTICK_PERIOD_MS);

    // pembacaan DS18B20 sesuai alamat
    float bacaSuhu1 = ds18b20.getTempC(addrMotor1);
    float bacaSuhu2 = ds18b20.getTempC(addrMotor2);

    if (bacaSuhu1 != DEVICE_DISCONNECTED_C && bacaSuhu1 > -50.0 && bacaSuhu1 < 125.0)
    {
      suhu1 = bacaSuhu1;
    }
    else
    {
      Serial.println(">> [WARN] Sensor Suhu 1 (Motor 1) Disconnected / CRC Error!");
    }

    if (bacaSuhu2 != DEVICE_DISCONNECTED_C && bacaSuhu2 > -50.0 && bacaSuhu2 < 125.0)
    {
      suhu2 = bacaSuhu2;
    }
    else
    {
      Serial.println(">> [WARN] Sensor Suhu 2 (Motor 2) Disconnected / CRC Error!");
    }

    ds18b20.requestTemperatures();

    // tampilan data di serial monitor ketika esp tersambung via USB
    Serial.println("================== MOTOR 1 ==================");
    Serial.printf("Tegangan : %.1f V | Arus : %.2f A (Raw: %.2f A)\n", tegangan1, arus1, rawArus1);
    Serial.printf("Daya     : %.2f kW | PF  : %.2f\n", daya1, pf1);
    Serial.printf("Suhu     : %.1f °C\n", suhu1);

    Serial.println("------------------ MOTOR 2 ------------------");
    Serial.printf("Tegangan : %.1f V | Arus : %.2f A (Raw: %.2f A)\n", tegangan2, arus2, rawArus2);
    Serial.printf("Daya     : %.2f kW | PF  : %.2f\n", daya2, pf2);
    Serial.printf("Suhu     : %.1f °C\n", suhu2);

    // pengiriman data ke firebase
    if (WiFi.status() == WL_CONNECTED)
    {
      FirebaseJson jsonPompa1;
      jsonPompa1.set("tegangan_volt", tegangan1);
      jsonPompa1.set("arus_ampere", arus1);
      jsonPompa1.set("daya_kw", daya1);
      jsonPompa1.set("faktor_daya", pf1);
      jsonPompa1.set("suhu_celsius", suhu1);
      jsonPompa1.set("last_seen/.sv", "timestamp");
      Firebase.updateNode(firebaseData, "/telemetry/pompa_1", jsonPompa1);

      FirebaseJson jsonPompa2;
      jsonPompa2.set("tegangan_volt", tegangan2);
      jsonPompa2.set("arus_ampere", arus2);
      jsonPompa2.set("daya_kw", daya2);
      jsonPompa2.set("faktor_daya", pf2);
      jsonPompa2.set("suhu_celsius", suhu2);
      jsonPompa2.set("last_seen/.sv", "timestamp");

      if (Firebase.updateNode(firebaseData, "/telemetry/pompa_2", jsonPompa2))
      {
        Serial.println(">> Firebase: Telemetri Pompa 1 & 2 Berhasil!");
      }
      else
      {
        Serial.print(">> Firebase Error: ");
        Serial.println(firebaseData.errorReason());
      }
      Serial.println("=============================================\n");

      // logging riwayat berkala (tiap 5 menit)
      // logging riwayat berkala (tiap 5 menit)
      if (currentMillis - prevHistoryMillis >= historyInterval)
      {
        prevHistoryMillis = currentMillis;

        // Riwayat Pompa 1
        FirebaseJson hist1;
        hist1.set("arus", arus1);
        hist1.set("tegangan", tegangan1); // <-- Tambahkan ini
        hist1.set("daya", daya1);
        hist1.set("faktor_daya", pf1); // <-- Tambahkan ini
        hist1.set("suhu", suhu1);
        hist1.set("timestamp/.sv", "timestamp");
        Firebase.pushJSON(firebaseData, "/history/pompa_1", hist1);

        // Riwayat Pompa 2
        FirebaseJson hist2;
        hist2.set("arus", arus2);
        hist2.set("tegangan", tegangan2); // <-- Tambahkan ini
        hist2.set("daya", daya2);
        hist2.set("faktor_daya", pf2); // <-- Tambahkan ini
        hist2.set("suhu", suhu2);
        hist2.set("timestamp/.sv", "timestamp");
        Firebase.pushJSON(firebaseData, "/history/pompa_2", hist2);

        Serial.println(">> [HISTORY] Snapshot berkala lengkap tersimpan ke /history!\n");
      }
    }
    else
    {
      Serial.println(">> [SKIP] Wi-Fi terputus, mengabaikan push Firebase...");
    }
  }

  yield();
}