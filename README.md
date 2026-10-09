# kavas-ainotetaker

Online toplantı ses kaydı → **Qwen3-ASR-1.7B** (API) ile transkript → **LLM** ile toplantı özeti.
**macOS** için native **Swift + SwiftUI** masaüstü uygulaması.

## Nedir?

Zoom / Google Meet / Microsoft Teams gibi online toplantılarda konuşulan sesi (sistem sesi +
mikrofon) kaydeder, kaydı bir ASR API'sine göndererek yazıya döker ve yazıdan **kararlar +
aksiyonlar + özet** içeren paylaşılabilir bir toplantı notu üretir.

```
Toplantı sesi → [kayıt: ScreenCaptureKit + mikrofon] → [Qwen3-ASR API] → transkript → [LLM] → toplantı özeti (md)
```

## Stack

- **Dil/UI:** Swift 6 + SwiftUI (native macOS)
- **Ses yakalama:** ScreenCaptureKit (sistem sesi) + AVAudioEngine (mikrofon)
- **ASR:** Qwen3-ASR-1.7B, OpenAI-uyumlu `/v1/audio/transcriptions` üzerinden
- **Özet:** OpenAI-uyumlu `/v1/chat/completions`
- **Endpoint + API token:** uygulamanın **Ayarlar** menüsünden (token'lar Keychain'de)
- **Proje üretimi:** XcodeGen (`project.yml` → `.xcodeproj`)

## Durum

🚧 **Tasarım aşaması.** Bkz. [REQUIREMENTS.md](REQUIREMENTS.md) — gereksinim, mimari ve faz planı.
Onay sonrası fazlar hâlinde kodlanacak.

## Lisans

TBD
