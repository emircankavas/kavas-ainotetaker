# kavas-ainotetaker — Gereksinim ve Teknik Harita

Online toplantı sesini kaydeden, kaydı **Qwen3-ASR-1.7B** modeline API üzerinden vererek
transkript çıkaran ve transkriptten **LLM ile toplantı özeti** üreten **macOS masaüstü uygulaması**.

> Durum: **Faz 0 (iskelet) tamam.** Ayrıntılı faz planı için §9.

---

## 1. Hedef

Zoom / Google Meet / Microsoft Teams / Discord gibi online toplantılarda **seçtiğin
uygulamanın sesini** ve **mikrofonu** kaydedip; kararlara ve aksiyonlara atıf yapabilen,
paylaşılabilir bir **toplantı notu** (özet + transkript + aksiyon listesi) üretmek.

```
[Seçili uygulama sesi + mikrofon] --kayıt--> [ASR API] --transkript--> [LLM API] --> toplantı özeti
```

---

## 2. Kararlar (onaylanmış)

| Konu | Karar |
|---|---|
| **Platform** | macOS (kendi Mac'i — Apple Silicon, Mac16,1). Şimdilik sadece orada çalışır. |
| **Dil / UI** | **Swift 6 + SwiftUI** (native). |
| **Ses kaynağı** | **Seçilen uygulamanın sesi** (per-process) **+ mikrofon**. |
| **Ses yakalama tekniği** | **Core Audio process tap (`CATap`)** — macOS 14.2+, per-process. |
| **ASR** | **Qwen3-ASR-1.7B**, sağlayıcının OpenAI-uyumlu ucu. |
| **Özet LLM** | **deepseek-v4.1-flash**, endpoint + API key'i kullanıcı verir. |
| **Model adları** | **Ayarlar'dan düzenlenebilir** — aynı sağlayıcının farklı modeli yazılabilir. |
| **Endpoint & token** | Uygulamanın **Ayarlar** menüsünden; token'lar Keychain'de. |
| **Dağıtım** | Sadece kullanıcının Mac'i (imzalama/notarization gerekmez). |
| **CI / repo** | Repo **public**; derleme doğrulaması **GitHub Actions macOS runner** ile. |

---

## 3. Ses Yakalama (Capture)

**Yöntem: Core Audio process tap (`CATapDescription` + `AudioHardwareCreateProcessTap` +
aggregate device).** macOS 14.2+.

- **Seçilen uygulama sesi:** Kullanıcı çalışan bir uygulamayı (ör. Zoom) seçer → PID,
  `kAudioHardwarePropertyTranslatePIDToProcessObject` ile `AudioObjectID`'ye çevrilir → tap
  oluşturulur → private aggregate device üzerinden IO proc ile PCM alınır.
- **Mikrofon:** `AVAudioEngine` girişi → ayrı akış.
- İki kaynak **ayrı kanal** kaydedilir (uygulama sesi = karşı taraf, mikrofon = sen);
  ASR öncesi istenirse mikslenir.

### İzinler
- **`NSAudioCaptureUsageDescription`** Info.plist'te gerekir. İlk kayıtta sistem
  "System Audio Recording Only" izni ister (macOS 14.2+).
- **Screen Recording izninden ayrı** ve daha hafif bir TCC servisidir (`kTCCServiceAudioCapture`).
- Public API'de izin sorgusu yok → tap oluşturmayı deneyip hata üzerinden izin UX'i.
- Mikrofon için **`NSMicrophoneUsageDescription`**.

### Teknik notlar
- Aggregate device **yalnızca tap içermeli** (fiziksel çıkış subdevice'ı eklenmez) —
  çıkış cihazı değişince (kulaklık/AirPods) tap kendi hızında akmaya devam eder.
  `kAudioSubTapDriftCompensationKey: true`.
- IO proc realtime thread'de çalışır → allocation/lock/`Task{}` yasak; yazma diske/ring buffer'a.
- Kayıt formatı: ham **CAF/WAV 48 kHz**; ASR öncesi **16 kHz mono**'ya dönüştürülür.

---

## 4. ASR Katmanı (Qwen3-ASR-1.7B, API)

**İstemci:** `ASRClient` protokolü + `OpenAICompatASRClient` — OpenAI-uyumlu
**`/v1/audio/transcriptions`** (multipart, `URLSession`).

```swift
protocol ASRClient {
    func transcribe(fileURL: URL, language: String?) async throws -> Transcript
}
// OpenAICompatASRClient(baseURL, apiKey, model)  // hepsi Settings'ten
```

- **Endpoint, API key, model adı** Ayarlar'dan gelir (sağlayıcının ucu).
- Qwen3-ASR'ın eklediği `language X\n` ön eki temizlenir.
- **Uzun toplantı:** VAD ile sessizlikte parçala → paralel gönder → sırayla birleştir.

---

## 5. Özetleme Katmanı (LLM)

**Model (varsayılan):** **deepseek-v4.1-flash** (Ayarlar'dan değiştirilebilir).
**İstemci:** `LLMClient` protokolü + `OpenAICompatLLMClient` — `/v1/chat/completions`.

Çıktı şablonu (Türkçe): Toplantı Özeti · Konuşulanlar · Kararlar · Aksiyonlar (tablo) ·
Açık Sorular/Riskler. Uzunluk için map-reduce; atıflı (grounded), uydurma yok.

---

## 6. Ayarlar (Settings) — zorunlu

| Ayar | Açıklama |
|---|---|
| **ASR endpoint** | OpenAI-uyumlu base_url |
| **ASR API token** | Bearer token — **Keychain** |
| **ASR model adı** | serbest metin — aynı sağlayıcının farklı modeli yazılabilir |
| **LLM endpoint** | OpenAI-uyumlu base_url |
| **LLM API token** | Bearer token — **Keychain** |
| **LLM model adı** | serbest metin, varsayılan `deepseek-v4.1-flash` |
| **Dil** | ASR dil ipucu (auto / tr / en …) |
| **Kayıt klasörü** | kayıtların ve çıktıların yeri |
| **Ses kaynağı** | seçili uygulama / mikrofon / ikisi |

Token'lar SecureField + Keychain. "Test Et" butonu (endpoint/model listesi) — Faz 4.

---

## 7. Mimari (Swift proje yapısı)

```
kavas-ainotetaker/
├─ project.yml                      # XcodeGen → .xcodeproj
├─ KavasAINoteTaker.entitlements
├─ Info.plist                       # NSAudioCaptureUsageDescription, NSMicrophoneUsageDescription
├─ .github/workflows/build.yml      # macOS CI (xcodegen + xcodebuild)
├─ KavasAINoteTaker/
│  ├─ App/            KavasAINoteTakerApp.swift, AppState.swift
│  ├─ Capture/        AudioProcessList, ProcessTapCapture, MicrophoneCapture, CaptureCoordinator, AudioFile
│  ├─ ASR/            ASRClient, OpenAICompatASRClient, Chunking
│  ├─ Summary/        LLMClient, OpenAICompatLLMClient
│  ├─ Storage/        SettingsStore, Keychain, MeetingStore
│  ├─ Pipeline/       TranscriptionPipeline
│  └─ Views/          MainView, MeetingDetailView, SettingsView
└─ docs/ARCHITECTURE.md
```

---

## 8. Veri / Dosya Düzeni

```
~/Documents/KavasAINoteTaker/meetings/
└─ 2026-10-09_14-30_Zoom_Toplanti/
   ├─ app.caf · mic.caf · mixed.wav
   ├─ transcript.json · transcript.txt
   ├─ summary.md
   └─ meta.json
```

---

## 9. Fazlar

- **Faz 0 — İskelet:** ✅ XcodeGen, app + Settings, entitlements/Info.plist, Keychain,
  boş çalışan SwiftUI penceresi, GitHub Actions CI.
- **Faz 1 — Ses yakalama:** uygulama listesi + seçim; CATap per-process kayıt + mikrofon; WAV; izin UX'i.
- **Faz 2 — ASR hattı:** ✅ 16 kHz mono miks (AVAudioConverter) → VAD chunking → OpenAI-uyumlu
  transkript istemcisi (paralel) → `transcript.json` + `transcript.txt`.
- **Faz 3 — Özetleme:** ✅ OpenAI-uyumlu LLM istemcisi + map-reduce → `summary.md` + arayüzde önizleme.
- **Faz 4 — Ayar & UX:** ✅ Endpoint "Test Et" (model listesi), NavigationSplitView toplantı listesi +
  detay (özet/transkript sekmeleri), meta.json, ilerleme/hata gösterimi.
- **Faz 5 — Realtime (ops.):** ✅ Kayıt sırasında "yaklaşık canlı" transkript (periyodik artımlı
  ASR gönderimi) + ayardan aç/kapa. *(Gerçek streaming protokolü değil; batch uçla çalışır.)*

---

## 10. Gizlilik / Uyarı

Toplantı kaydı ve transkript **kişisel veri** içerir (KVKK/GDPR). ASR ve özet **bulut
uçlarına** gider. Kayıt öncesi katılımcı onayı ve saklama politikası netleştirilmeli.
