# kavas-ainotetaker

Online toplantı ses kaydı → **Qwen3-ASR-1.7B** (API) ile transkript → **LLM** ile toplantı özeti.
**macOS** için native **Swift + SwiftUI** masaüstü uygulaması.

## Nedir?

Bir online toplantıda **seçtiğin uygulamanın sesini** (ör. Zoom) ve **mikrofonu** kaydeder,
kaydı bir ASR API'sine göndererek yazıya döker ve yazıdan **kararlar + aksiyonlar + özet**
içeren paylaşılabilir bir toplantı notu üretir.

```
[Seçili uygulama sesi + mikrofon] → [kayıt] → [Qwen3-ASR API] → transkript → [LLM] → özet (md)
```

## Stack

- **Dil/UI:** Swift 6 + SwiftUI (native macOS)
- **Ses yakalama:** Core Audio **process tap** (seçili uygulamanın sesi, macOS 14.2+) + **AVAudioEngine** (mikrofon)
- **ASR:** **Qwen3-ASR-1.7B**, OpenAI-uyumlu `/v1/audio/transcriptions` üzerinden
- **Özet:** **deepseek-v4.1-flash**, OpenAI-uyumlu `/v1/chat/completions` üzerinden
- **Endpoint + API token:** uygulamanın **Ayarlar** menüsünden (token'lar Keychain'de)
- **Proje üretimi:** XcodeGen (`project.yml` → `.xcodeproj`)

## Durum

🚧 **Tasarım aşaması.** Bkz. [REQUIREMENTS.md](REQUIREMENTS.md) — gereksinim, mimari ve faz planı.
Onay sonrası fazlar hâlinde kodlanacak. Şimdilik yalnızca kendi Mac'te çalışacak.

## Lisans

TBD
