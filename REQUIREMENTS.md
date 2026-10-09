# kavas-ainotetaker — Gereksinim ve Teknik Harita

Online toplantı sesini kaydeden, kaydı **Qwen3-ASR-1.7B** modeline API üzerinden vererek
transkript çıkaran ve transkriptten **LLM ile toplantı özeti** üreten **macOS masaüstü uygulaması**.

> Durum: **Taslak / onay bekliyor.** Onaydan sonra fazlar hâlinde kodlanacak.

---

## 1. Hedef

Zoom / Google Meet / Microsoft Teams / Discord gibi online toplantılarda konuşmayı
kaydedip; kararlara ve aksiyonlara atıf yapabilen, paylaşılabilir bir **toplantı notu**
(özet + transkript + aksiyon listesi) üretmek.

```
[Toplantı] --ses--> [kayıt] --ASR--> [transkript] --LLM--> [özet + kararlar + aksiyonlar]
```

---

## 2. Hedef Platform ve Dil Kararı

**Platform:** macOS (Apple Silicon Mac — Mac16,1).
**Dil:** **Swift + SwiftUI** (native).

### Neden Swift?

İşin en kritik parçası **sistem sesini yakalamak**. macOS'ta bunun doğru yolu Apple'ın
kendi framework'üdür (**ScreenCaptureKit**). Bunlar Objective-C/Swift API'leri; Python'dan
`pyobjc` ile kullanmak kırılgan (ScreenCaptureKit ses yakalama PyObjC'de bilinen hatalı
durumda) ve `.app` paketleme / izinler (ekran kaydı, mikrofon) / imzalama Python'da sancılı.

| İhtiyaç | Swift + SwiftUI | Python (pyobjc) |
|---|---|---|
| Sistem sesi (ScreenCaptureKit/Core Audio taps) | birinci sınıf | kırılgan köprü |
| GUI + Settings scene | yerleşik | ayrı framework |
| İzinler (ekran kaydı/mikrofon), entitlements | standart | elle uğraş |
| `.app` dağıtımı, imzalama, notarization | standart | PyInstaller/py2app sancısı |
| API çağrıları (URLSession) | birkaç satır | requests |

Alternatifler: Rust+Tauri (cross-platform ama macOS ses yakalama yine objc köprüsü),
Electron (macOS-only işe göre gereksiz ağır). Native Swift seçildi.

---

## 3. Ses Yakalama (Capture)

**Yöntem: ScreenCaptureKit** (macOS 13+). Yerleşik — ek kurulum yok.
- Sistem sesi (karşı taraf) → **ScreenCaptureKit** `SCStream` audio output.
- Kendi sesimiz → **AVAudioEngine** (mikrofon) — ayrı akış.
- İki kaynağı **ayrı kanal** olarak kaydetmek (konuşmacı ayrımının doğal temeli), gerekirse
  export'ta mikslemek.

Notlar:
- İlk çalıştırmada **Screen Recording** ve **Microphone** izni istenir (System Settings →
  Privacy & Security). Uygulama izin durumunu kontrol edip yönlendirmeli.
- SCStream sesi tüm sistem çıktısını içerir → toplantı dışı ses (bildirim, müzik) kayda
  karışabilir. Azaltmak için: toplantı sırasında "sessize al" hatırlatması + ileride
  Core Audio process taps ile sadece toplantı uygulamasına hedefleme (Faz 6).
- Kayıt formatı: **CAF/WAV, 16 kHz mono** (ASR standart giriş) — ham kayıt 48 kHz tutulup
  ASR öncesi dönüştürülür.

---

## 4. ASR Katmanı (Qwen3-ASR-1.7B, API)

**Model:** Qwen3-ASR-1.7B (52+ dil, **Türkçe dahil**; konuşma + şarkı, offline/streaming).

**İstemci:** `ASRClient` protokolü + tek somut uygulama:
**OpenAI-uyumlu `/v1/audio/transcriptions`** istemcisi (`URLSession` multipart upload).

```swift
protocol ASRClient {
    func transcribe(fileURL: URL, language: String?) async throws -> Transcript
}
// OpenAICompatASRClient(baseURL, apiKey, model: "qwen3-asr")  // vLLM/qwen-asr-serve
```

Neden OpenAI-uyumlu: Qwen3-ASR-1.7B'yi `qwen-asr-serve` veya `vllm serve` ile (NVIDIA GPU'lu
herhangi bir sunucuda/sağlayıcıda) ayağa kaldırdığında aynı şekilde çalışır; **endpoint + token
kullanıcının Settings'inden** gelir. (DashScope'un `qwen3-asr-flash` servisi ayrı/async bir
API'dir; gerekirse Faz 4'te ayrı adapter eklenir.)

**Uzun toplantı yönetimi:** API'lerde (özellikle bulut) süre limitleri var → kaydı **VAD ile
sessizlikte parçala**, parçaları **paralel** gönder, metinleri sırayla birleştir
(Qwen3-ASR-Toolkit mantığı). Self-host'ta limit esnek ama yine parçalamak güvenli.

Çıktı: `transcript.json` — parça metinleri (+ varsa zaman damgaları, dil).

---

## 5. Özetleme Katmanı (LLM)

Transkripti yapılandırılmış toplantı notuna çevirir. **OpenAI-uyumlu `/v1/chat/completions`**
istemcisi (`URLSession`); **model / endpoint / token ayarlardan**.

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
- **Atıf (grounding):** özet transkriptteki içeriğe dayanır; uydurma yok. Modelden her madde
  için transkriptteki referansı da vermesi istenir.

---

## 6. Ayarlar (Settings) — zorunlu

SwiftUI **Settings** sahnesi. Uygulama ilk açılışta buradan yapılandırılır:

| Ayar | Açıklama |
|---|---|
| **ASR endpoint** | OpenAI-uyumlu base_url (`http://host:8000/v1`) |
| **ASR API token** | Bearer token — **Keychain'de** saklanır |
| **ASR model adı** | ör. `qwen3-asr` / `Qwen/Qwen3-ASR-1.7B` |
| **LLM endpoint** | OpenAI-uyumlu base_url |
| **LLM API token** | Bearer token — **Keychain** |
| **LLM model adı** | ör. `deepseek-chat` / `gpt-4o` |
| **Dil** | ASR dil ipucu (auto / tr / en …) |
| **Kayıt klasörü** | kayıtların ve çıktıların yeri |
| **Kaynak** | sistem sesi / mikrofon / ikisi |

Token alanları **güvenli (SecureField)**, Keychain'de saklanır; `.env`/plaintext yok.
Bağlantı "Test Et" butonu (endpoint erişilebilirlik + model listesi kontrolü).

---

## 7. Mimari (Swift proje yapısı)

```
kavas-ainotetaker/
├─ project.yml                      # XcodeGen girdisi (.xcodeproj üretir)
├─ KavasAINoteTaker.entitlements    # mic + network
├─ Info.plist                       # izin açıklamaları (NSMicrophoneUsageDescription)
├─ KavasAINoteTaker/
│  ├─ App/
│  │  ├─ KavasAINoteTakerApp.swift  # @main, WindowGroup + Settings scene
│  │  └─ AppState.swift             # @Observable, akış durumu
│  ├─ Capture/
│  │  ├─ SystemAudioCapture.swift   # ScreenCaptureKit SCStream → PCM dosya
│  │  ├─ MicrophoneCapture.swift    # AVAudioEngine → PCM dosya
│  │  ├─ CaptureCoordinator.swift   # kaynağı seç, birlikte başlat/durdur
│  │  └─ AudioFile.swift            # CAF/WAV yazma, 48k→16k dönüştürme
│  ├─ ASR/
│  │  ├─ ASRClient.swift            # protocol
│  │  ├─ OpenAICompatASRClient.swift
│  │  └─ Chunking.swift             # VAD ile parçalama + birleştirme
│  ├─ Summary/
│  │  ├─ LLMClient.swift            # protocol
│  │  └─ OpenAICompatLLMClient.swift# map-reduce özet, şablon
│  ├─ Storage/
│  │  ├─ SettingsStore.swift        # AppStorage + Keychain (token)
│  │  ├─ Keychain.swift
│  │  └─ MeetingStore.swift         # kayıt klasörü + metadata
│  ├─ Pipeline/
│  │  └─ TranscriptionPipeline.swift# kayıt→ASR→özet orkestrasyon
│  └─ Views/
│     ├─ MainView.swift             # kaydet/dur, toplantı listesi
│     ├─ MeetingDetailView.swift    # transkript + özet sekmeleri
│     └─ SettingsView.swift         # §6
├─ Tests/KavasAINoteTakerTests/
└─ docs/ARCHITECTURE.md
```

**Araçlar:** XcodeGen (`project.yml` → `.xcodeproj`, tekrarlanabilir), Swift 6, SwiftUI,
ScreenCaptureKit, AVFoundation, Swift Concurrency (async/await). Gizli veri: Keychain.
Dağıtım: Xcode ile imzalı `.app` (ops. notarization).

---

## 8. Veri / Dosya Düzeni

```
~/Documents/KavasAINoteTaker/meetings/
└─ 2026-10-09_14-30_Toplanti/
   ├─ system.caf            # ham sistem sesi
   ├─ mic.caf               # ham mikrofon (varsa)
   ├─ mixed.wav             # 16 kHz mono, ASR'a giden
   ├─ transcript.json       # parçalar + metin + dil
   ├─ transcript.txt
   ├─ summary.md            # nihai, paylaşılabilir çıktı
   └─ meta.json             # süre, model, endpoint, tarih
```

---

## 9. Fazlar (uygulama sırası)

- **Faz 0 — İskelet:** XcodeGen `project.yml`, app + Settings scaffolding, entitlements/Info.plist,
  boş SwiftUI penceresi; `xcodebuild` ile derlenir. *(onaydan sonra)*
- **Faz 1 — Ses yakalama:** ScreenCaptureKit sistem sesi + mikrofon kaydı, WAV yazma,
  izin kontrolü, basit kaydet/dur UI.
- **Faz 2 — ASR hattı:** OpenAI-uyumlu transkript istemcisi + chunking → `transcript.json`.
  Golden test: kısa Türkçe kayıt.
- **Faz 3 — Özetleme:** LLM istemcisi + map-reduce özet → `summary.md`.
- **Faz 4 — Ayar & UX:** Settings (endpoint/token/model, Keychain, Test Et), toplantı listesi,
  detay görünümü, ilerleme/hatalar.
- **Faz 5 — Realtime (ops.):** WebSocket/streaming ile canlı transkript.
- **Faz 6 — Diarization & hedefleme (ops.):** konuşmacı ayrımı (mic/sistem kanalı doğal ayrım),
  Core Audio process taps ile sadece toplantı uygulamasını yakalama.

---

## 10. Açık Sorular

1. **ASR endpoint'i hangisi olacak?** (a) kendi NVIDIA sunucunda `qwen-asr-serve`/vLLM,
   (b) bir sağlayıcının OpenAI-uyumlu ucu, (c) DashScope `qwen3-asr-flash` (ayrı adapter gerekir).
2. **Ses kaynağı:** sistem sesi / mikrofon / ikisi (önerilen: ikisi).
3. **Özet LLM'i:** hangi model/endpoint?
4. **Dağıtım:** sadece kendi Mac'inde mi, yoksa imzalı/notarized dağıtım da olacak mı?

---

## 11. Gizlilik / Uyarı

Toplantı kaydı ve transkript **kişisel veri** içerir (KVKK/GDPR). Ses bulut bir ASR'ye
gidiyorsa üçüncü tarafa aktarılır. Kayıt öncesi katılımcı onayı ve saklama politikası
netleştirilmeli. Bu, endpoint seçimini (self-host vs bulut) doğrudan etkiler.
