# kavas-ainotetaker — Gereksinim ve Teknik Harita

Online toplantı sesini kaydeden, kaydı **Qwen3-ASR-1.7B** modeline API üzerinden vererek
transkript çıkaran ve transkriptten **LLM ile toplantı özeti** üreten **macOS masaüstü uygulaması**.

> Durum: **Taslak / onay bekliyor.** Onaydan sonra fazlar hâlinde kodlanacak.

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
| **Endpoint & token** | Uygulamanın **Ayarlar** menüsünden girilir; token'lar Keychain'de. |
| **Dağıtım** | Sadece kullanıcının Mac'i (imzalama/notarization gerekmez, local `.app`). |

> **Not (dil seçimi):** İşin en kritik parçası per-process sistem sesi yakalamadır ve
> macOS'ta bunun doğru yolu Apple'ın Core Audio / ScreenCaptureKit framework'leridir
> (Obj-C/Swift). Python'da `pyobjc` ile kırılgan, izinler ve `.app` paketleme sancılıdır.
> Bu yüzden native **Swift** seçildi.

---

## 3. Ses Yakalama (Capture)

**Yöntem: Core Audio process tap (`CATapDescription` + `AudioHardwareCreateProcessTap` +
aggregate device).** macOS 14.2+.

- **Seçilen uygulama sesi:** Kullanıcı çalışan bir uygulamayı (ör. Zoom) seçer →
  PID, `kAudioHardwarePropertyTranslatePIDToProcessObject` ile `AudioObjectID`'ye çevrilir →
  o process için tap oluşturulur → private aggregate device üzerinden IO proc ile PCM alınır.
- **Mikrofon:** `AVAudioEngine` girişi → ayrı akış.
- İki kaynak **ayrı kanal** olarak kaydedilir (konuşmacı ayrımının doğal temeli: uygulama sesi
  = karşı taraf, mikrofon = sen). ASR öncesi istenirse mikslenir.

### İzinler
- **`NSAudioCaptureUsageDescription`** Info.plist'te gerekir. İlk kayıtta sistem
  "System Audio Recording Only" izni ister (macOS 14.2+).
- **Not:** Bu, **Screen Recording izninden ayrı** ve daha hafif bir TCC servisidir
  (`kTCCServiceAudioCapture`). Screen Recording izni *gerektirmez*.
- Public API'de "ses kaydı izni var mı?" diye sorgulayan bir fonksiyon yok → tap
  oluşturmayı deneyip hata üzerinden izin UX'ine yönlendirme yapılır.
- Mikrofon için **`NSMicrophoneUsageDescription`**.

### Teknik notlar
- Aggregate device **yalnızca tap içermeli** (fiziksel çıkış subdevice'ı eklenmez) — çıkış
  cihazı değişince (kulaklık/AirPods) tap kendi hızında akmaya devam eder.
  `kAudioSubTapDriftCompensationKey: true`.
- IO proc realtime thread'de çalışır → allocation/lock/`Task{}` yasak; yazma diske ya da
  ring buffer'a kuyruklanmalı.
- Kayıt formatı: ham **CAF/WAV 48 kHz**; ASR öncesi **16 kHz mono**'ya dönüştürülür.
- **ScreenCaptureKit alternatifi:** uygulama seçmek için `SCContentFilter` de kullanılabilir
  ama ekran kaydı izni + görüntü oturumu gerektirdiğinden CATap tercih edildi.

---

## 4. ASR Katmanı (Qwen3-ASR-1.7B, API)

**Model:** Qwen3-ASR-1.7B (52+ dil, **Türkçe dahil**).
**İstemci:** `ASRClient` protokolü + `OpenAICompatASRClient` — OpenAI-uyumlu
**`/v1/audio/transcriptions`** (multipart, `URLSession`).

```swift
protocol ASRClient {
    func transcribe(fileURL: URL, language: String?) async throws -> Transcript
}
// OpenAICompatASRClient(baseURL, apiKey, model)  // baseURL+key Settings'ten
```

- **Endpoint, API key, model adı** Ayarlar'dan gelir (sağlayıcının ucu).
- Dönen metindeki Qwen3-ASR'ın eklediği `language X\n` ön ekini sunucu/adapter temizler;
  gerekirse istemci tarafında da temizlenir.
- **Uzun toplantı yönetimi:** kaydı **VAD ile sessizlikte parçala**, parçaları **paralel**
  gönder, metinleri sırayla birleştir (Qwen3-ASR-Toolkit mantığı).
- Çıktı: `transcript.json` — parça metinleri (+ varsa zaman damgaları, dil).

---

## 5. Özetleme Katmanı (LLM)

**Model:** **deepseek-v4.1-flash** (endpoint + key kullanıcıdan).
**İstemci:** `LLMClient` protokolü + `OpenAICompatLLMClient` — OpenAI-uyumlu
**`/v1/chat/completions`** (`URLSession`).

Çıktı şablonu (Türkçe):

```
## Toplantı Özeti
- Kısa özet (2-4 cümle)
- Katılımcılar (varsa)

## Konuşulanlar
- madde madde, transkript bölümüne atıfla

## Kararlar
- ✅ ...

## Aksiyonlar
| İş | Sorumlu | Vade | Atıf |

## Açık Sorular / Riskler
```

- **Uzunluk yönetimi:** uzun transkript → parçalı özet (map-reduce).
- **Atıf (grounding):** özet transkriptteki içeriğe dayanır; uydurma yok.

---

## 6. Ayarlar (Settings) — zorunlu

SwiftUI **Settings** sahnesi. İlk açılışta yapılandırılır:

| Ayar | Açıklama |
|---|---|
| **ASR endpoint** | OpenAI-uyumlu base_url |
| **ASR API token** | Bearer token — **Keychain** |
| **ASR model adı** | ör. `qwen3-asr` / `Qwen/Qwen3-ASR-1.7B` |
| **LLM endpoint** | OpenAI-uyumlu base_url |
| **LLM API token** | Bearer token — **Keychain** |
| **LLM model adı** | `deepseek-v4.1-flash` (varsayılan) |
| **Dil** | ASR dil ipucu (auto / tr / en …) |
| **Kayıt klasörü** | kayıtların ve çıktıların yeri |
| **Ses kaynağı** | seçili uygulama / mikrofon / ikisi |
| **Varsayılan uygulama** | kayıt başlarken önerilecek uygulama (ör. Zoom) |

Token alanları **SecureField** + **Keychain**; `.env`/plaintext yok. "Test Et" butonu
(endpoint erişilebilirlik + model listesi).

---

## 7. Mimari (Swift proje yapısı)

```
kavas-ainotetaker/
├─ project.yml                      # XcodeGen → .xcodeproj
├─ KavasAINoteTaker.entitlements    # mic + network; audio-capture (gerekirse)
├─ Info.plist                       # NSAudioCaptureUsageDescription, NSMicrophoneUsageDescription
├─ KavasAINoteTaker/
│  ├─ App/
│  │  ├─ KavasAINoteTakerApp.swift  # @main, WindowGroup + Settings scene
│  │  └─ AppState.swift             # @Observable, akış durumu
│  ├─ Capture/
│  │  ├─ AudioProcessList.swift     # çalışan sesli uygulamaları listele (pid→AudioObjectID)
│  │  ├─ ProcessTapCapture.swift    # CATap + aggregate device → PCM
│  │  ├─ MicrophoneCapture.swift    # AVAudioEngine → PCM
│  │  ├─ CaptureCoordinator.swift   # kaynağı seç, birlikte başlat/durdur
│  │  └─ AudioFile.swift            # CAF/WAV yazma, 48k→16k dönüşüm
│  ├─ ASR/
│  │  ├─ ASRClient.swift            # protocol
│  │  ├─ OpenAICompatASRClient.swift
│  │  └─ Chunking.swift             # VAD ile parçalama + birleştirme
│  ├─ Summary/
│  │  ├─ LLMClient.swift            # protocol
│  │  └─ OpenAICompatLLMClient.swift# map-reduce özet + şablon
│  ├─ Storage/
│  │  ├─ SettingsStore.swift        # AppStorage + Keychain
│  │  ├─ Keychain.swift
│  │  └─ MeetingStore.swift         # kayıt klasörü + metadata
│  ├─ Pipeline/
│  │  └─ TranscriptionPipeline.swift# kayıt→ASR→özet orkestrasyon
│  └─ Views/
│     ├─ MainView.swift             # uygulama seç, kaydet/dur, toplantı listesi
│     ├─ MeetingDetailView.swift    # transkript + özet sekmeleri
│     └─ SettingsView.swift         # §6
├─ Tests/KavasAINoteTakerTests/
└─ docs/ARCHITECTURE.md
```

**Araçlar:** XcodeGen, Swift 6, SwiftUI, Core Audio (AudioToolbox/CoreAudio),
AVFoundation, Swift Concurrency. Gizli veri: Keychain.

---

## 8. Veri / Dosya Düzeni

```
~/Documents/KavasAINoteTaker/meetings/
└─ 2026-10-09_14-30_Zoom_Toplanti/
   ├─ app.caf               # seçili uygulamanın ham sesi
   ├─ mic.caf               # ham mikrofon
   ├─ mixed.wav             # 16 kHz mono, ASR'a giden
   ├─ transcript.json       # parçalar + metin + dil
   ├─ transcript.txt
   ├─ summary.md            # nihai, paylaşılabilir çıktı
   └─ meta.json             # süre, uygulama, model, endpoint, tarih
```

---

## 9. Fazlar (uygulama sırası)

- **Faz 0 — İskelet:** XcodeGen `project.yml`, app + Settings scaffolding, entitlements/Info.plist,
  boş SwiftUI penceresi; `xcodebuild` ile derlenir.
- **Faz 1 — Ses yakalama:** çalışan uygulama listesi + seçim; CATap ile per-process kayıt +
  mikrofon kaydı; WAV yazma; izin UX'i; basit kaydet/dur UI.
- **Faz 2 — ASR hattı:** OpenAI-uyumlu transkript istemcisi + chunking → `transcript.json`.
  Golden test: kısa Türkçe kayıt.
- **Faz 3 — Özetleme:** deepseek-v4.1-flash istemcisi + map-reduce özet → `summary.md`.
- **Faz 4 — Ayar & UX:** Settings (endpoint/token/model, Keychain, Test Et), toplantı listesi,
  detay görünümü, ilerleme/hatalar.
- **Faz 5 — Realtime (ops.):** streaming ile canlı transkript.
- **Faz 6 — Diarization (ops.):** uygulama sesi vs mikrofon kanallarını kullanarak konuşmacı ayrımı.

---

## 10. Gizlilik / Uyarı

Toplantı kaydı ve transkript **kişisel veri** içerir (KVKK/GDPR). ASR ve özet **bulut
uçlarına** gider (kullanıcının verdiği endpoint'ler). Kayıt öncesi katılımcı onayı ve
saklama politikası netleştirilmeli.
