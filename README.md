# Kavas AI NoteTaker

Online toplantı ses kaydı → **Qwen3-ASR** (API) ile transkript → **LLM** ile toplantı özeti.
**macOS** için native **Swift + SwiftUI** masaüstü uygulaması.

## Nedir?

Bir online toplantıda **seçtiğin uygulamanın sesini** (ör. Zoom, Teams) ve **mikrofonu**
kaydeder, kaydı bir ASR API'sine göndererek yazıya döker ve yazıdan **kararlar + aksiyonlar +
özet** içeren paylaşılabilir bir toplantı notu üretir. Ayrıca ses/video dosyalarını içe aktarıp
aynı hattan geçirebilir.

```
[Seçili uygulama sesi + mikrofon] → [kayıt] → [ASR API] → transkript → [LLM] → özet (md)
```

## Özellikler

- **Seçili uygulamanın sesi** (Core Audio process tap, macOS 14.2+) **+ mikrofon** kaydı
- **Yaklaşık canlı transkript** (VAD sessizlik sınırlı artımlı ASR) + typewriter efekti
- **ASR:** Qwen3-ASR-1.7B, OpenAI-uyumlu `/v1/audio/transcriptions`
- **Özet:** OpenAI-uyumlu `/v1/chat/completions` (varsayılan `deepseek-v4.1-flash`), Türkçe, map-reduce
- **Ses/video içe aktarma** — videodan ses ayıklanır (AVFoundation)
- **Toplantı listesi + detay** (transkript / özet panelleri), `transcript.txt` / `summary.md` çıktıları
- Endpoint + API anahtarları **Ayarlar**'dan; anahtarlar **Keychain**'de; "Test Et" ile bağlantı kontrolü

## Stack

- **Dil/UI:** Swift 6 + SwiftUI (native macOS 14.2+)
- **Ses:** Core Audio process tap + AVAudioEngine (kayıt), AVFoundation (mikstenirme / içe aktarma)
- **Proje üretimi:** XcodeGen (`project.yml` → `.xcodeproj`)
- **CI:** GitHub Actions (macOS runner) — derleme + release `.app`

## Kurulum

### Hazır `.app` (önerilen)
1. [Releases](../../releases) sayfasından `KavasAINoteTaker-vX.Y.Z.zip` indir ve aç.
2. İmzasız build olduğu için Gatekeeper karantinasını kaldır:
   ```bash
   xattr -dr com.apple.quarantine KavasAINoteTaker.app
   ```
3. Uygulamayı çalıştır. İlk kayıtta **Sistem Ses Kaydı** ve **Mikrofon** izni istenir.
4. **Ayarlar (⌘,)** → ASR ve LLM endpoint/anahtar/model bilgilerini gir, "Test Et" ile doğrula.

### Kaynaktan derleme
```bash
brew install xcodegen
xcodegen generate
open KavasAINoteTaker.xcodeproj      # Xcode ile çalıştır
# veya:
xcodebuild -project KavasAINoteTaker.xcodeproj -scheme KavasAINoteTaker \
  -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## Kullanım

- **Kayıt:** sol şeritteki kırmızı mikrofon düğmesi. Kayıt bitince transkript + özet otomatik üretilir (ayardan kapatılabilir).
- **İçe aktarma:** sol şeritteki mavi ⤓ düğmesi → ses/video seç.
- **Geçmiş:** **Toplantılar** bölümü; seçili toplantının transkript ve özetini gösterir.

## Veri düzeni

```
~/Documents/KavasAINoteTaker/meetings/<tarih>/
├─ app.caf / mic.caf / mixed.wav
├─ transcript.json / transcript.txt
├─ summary.md
└─ meta.json
```

## Lisans

MIT
