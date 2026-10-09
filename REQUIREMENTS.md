# kavas-ainotetaker — Gereksinim ve Teknik Harita

Online toplantılarda sesi kaydeden, kaydı **Qwen3-ASR-1.7B** modeline API üzerinden
vererek transkript çıkaran ve bu transkriptten **LLM ile toplantı özeti** üreten uygulama.

> Durum: **Taslak / onay bekliyor.** Onaydan sonra aşamalı olarak kodlanacak.

---

## 1. Hedef

Katıldığımız online toplantılarda (Zoom / Google Meet / Teams / Discord vb.) konuşmayı
kaydedip; konuşmacıya, kararlara ve aksiyonlara atıf yapabilen, paylaşılabilir bir
**toplantı notu** (özet + transkript + aksiyon listesi) üretmek.

Tipik akış:

```
[Toplantı] --ses--> [Kayıt] --ASR--> [Transkript] --LLM--> [Özet + Kararlar + Aksiyonlar]
```

---

## 2. Ortam Kısıtları (mevcut makine)

| Bileşen | Durum | Etki |
|---|---|---|
| GPU | **AMD Radeon RX 6800 XT (16 GB)** — NVIDIA yok | Yerel vLLM/CUDA ile ASR çalıştırılamaz (Windows'ta ROCm yok) → **hosted API kullanılacak** |
| CPU/RAM | — | ASR lokal CPU'da çok yavaş olur; API tercih edilir |
| Python | 3.14.7 (global) | Proje için ayrı venv (3.12 önerilir) |
| ffmpeg | Kurulu (n9.0.1) | Ses çözme/dönüştürme/kırpma için hazır |
| OS | Windows 11 | Ses yakalama için WASAPI loopback |
| Disk (D:) | 15 TB boş | Yeterli |

**Sonuç:** ASR'yi hosted API üzerinden yapmak hem bu makine için doğru, hem de
kullanıcının istediği "api üzerinden" yaklaşımına uygun.

---

## 3. Ses Yakalama (Audio Capture)

Toplantı sesini iki olası kaynaktan alma:

1. **Sistem sesi (WASAPI loopback)** — "Siz ne duyuyorsanız onu kaydet". Windows'ta
   `PyAudioWPatch` ile hoparlör/kulaklık çıkışını kaydeder. Karşı tarafın sesini alır.
2. **Mikrofon** — kendi sesimizi alır.
3. **(Opsiyonel) Mikrofon + sistem sesi miks** — toplantı kayıtları için en doğrusu
   (iki akışı ayrı kanal olarak kaydedip sonra mikslemek, konuşmacı ayrımının temeli).

Kararlar:
- Kayıt formatı: **WAV 16 kHz mono** (ASR standart giriş formatı) — kayıt sırasında
  da mikslemek için iki kaynak ayrı WAV olarak tutulur, işleme öncesi ffmpeg ile miks.
- Uzun toplantılar için **chunk'lama** (VAD ile sessizlikte bölme) — API süre limitini
  aşmamak ve paralel işlemek için.
- Kayıt sırasında cihaz seçimi ve seviye göstergesi (ileriki UI aşamasında).

---

## 4. ASR Katmanı (Qwen3-ASR-1.7B, API)

İki backend soyutlaması (`ASRBackend` arayüzü), aynı arayüzü konuşur:

### 4a. `DashScopeBackend` (öncelikli — gateway'siz, doğrudan bulut)
Alibaba Cloud Model Studio / DashScope API. Model: **`qwen3-asr-flash`** (Qwen3-ASR-1.7B
tabanlı, 52+ dil, **Türkçe dahil**). İki biçim desteklenir:
- **Senkron:** dosya/URL gönder, metni al.
- **Realtime (WebSocket):** PCM stream gönder, canlı transkript al (isteğe bağlı, Faz 3).

SDK: `pip install dashscope`. Auth: `DASHSCOPE_API_KEY`.
Not: 3 dk'lık süre limiti → VAD ile parçalama + paralel çağrı (Qwen3-ASR-Toolkit
mantığı yeniden kullanılır).

### 4b. `OpenAICompatBackend` (esnek — self-host veya proxy)
OpenAI `/v1/audio/transcriptions` uyumlu **her** uç nokta (ör. başka makinede/GPU'da
`qwen-asr-serve` ile ayağa kaldırılan Qwen3-ASR-1.7B, ya da Kalavai/Ollama tarzı proxy).
Tek satır `base_url` değişikliğiyle seçilir. `openai` Python SDK'sı kullanılır.

```python
# Örnek: OpenAICompatBackend
from openai import OpenAI
client = OpenAI(base_url=cfg.base_url, api_key=cfg.api_key or "EMPTY")
r = client.audio.transcriptions.create(model="qwen3-asr", file=open("meeting.wav","rb"))
print(r.text)
```

**Yerel 1.7B'yi çalıştırmak istenirse** (bu makinede değil): CUDA'lı bir NVIDIA makinede
`qwen-asr-serve Qwen/Qwen3-ASR-1.7B --host 0.0.0.0 --port 8000`, ardından
`OpenAICompatBackend(base_url="http://<host>:8000/v1")`.

---

## 5. Özetleme Katmanı (LLM)

Transkripti, yapılandırılmış bir toplantı notuna çevirir. Çıktı şablonu:

```
## Toplantı Özeti
- Kısa özet (2-4 cümle)
- Katılımcılar (varsa / diarization sonrası)

## Gündem / Konuşulanlar
- madde madde, transkriptteki zaman damgasına atıfla

## Kararlar
- ✅ ...

## Aksiyonlar
| İş | Sorumlu | Vade | Atıf |
|---|---|---|---|

## Açık Sorular / Riskler
- ...
```

- **Sağlayıcı-agnostik `LLMBackend`**: OpenAI uyumlu chat completions (deepseek, openai,
  yerel vb.). Config'ten seçilir.
- **Uzunluk yönetimi:** uzun transkript → parçalı özet (map-reduce) + dil (Türkçe) korunur.
- **Atıf:** her madde transkriptin ilgili bölümüne referans verebilir (zaman damgası).
- `grounded-citations` yaklaşımı benimsenir: uydurma yok, transkriptte olmayan bilgi eklenmez.

---

## 6. Mimari (paket yapısı)

```
kavas-ainotetaker/
├─ pyproject.toml
├─ README.md
├─ REQUIREMENTS.md            # bu doküman
├─ .env.example               # DASHSCOPE_API_KEY, LLM_API_KEY ...
├─ src/kavas_ainotetaker/
│  ├─ config.py               # pydantic-settings ile config + .env
│  ├─ audio/
│  │  ├─ capture.py           # WASAPI loopback + mic (PyAudioWPatch / sounddevice)
│  │  ├─ devices.py           # cihaz listeleme/seçme
│  │  └─ preprocess.py        # ffmpeg: resample 16k mono, miks, VAD ile chunk
│  ├─ asr/
│  │  ├─ base.py              # ASRBackend arayüzü
│  │  ├─ dashscope_backend.py # qwen3-asr-flash
│  │  └─ openai_backend.py    # OpenAI uyumlu (self-host/proxy)
│  ├─ summarize/
│  │  ├─ base.py              # LLMBackend arayüzü
│  │  └─ llm.py               # map-reduce özet + şablon
│  ├─ pipeline.py             # kayıt→ASR→özet orkestrasyon
│  ├─ storage.py              # kayıt klasörü + sqlite metadata + çıktılar
│  └─ cli.py                  # typer CLI (kaydet / işle / list)
├─ tests/
└─ docs/ARCHITECTURE.md
```

**Teknoloji seçimleri:** Python 3.12 · `typer` (CLI) · `pydantic-settings` (config) ·
`dashscope` (ASR) · `openai` (LLM/uyumlu ASR) · `PyAudioWPatch` + `sounddevice` (capture) ·
`ffmpeg` (preprocess) · `soundfile`/`numpy` (VAD) · `sqlite3` (metadata) ·
`pytest` (test).

---

## 7. Veri / Dosya Düzeni

```
data/
└─ meetings/
   └─ 2026-10-09_14-30_topla/
      ├─ mic.wav
      ├─ system.wav
      ├─ mixed.wav
      ├─ transcript.json      # segmentler + zaman damgaları + dil
      ├─ transcript.txt
      ├─ summary.md           # nihai çıktı (paylaşılabilir)
      └─ meta.json            # süre, model, maliyet/token, backend
└─ app.db                     # toplantı listesi + durum
```

---

## 8. Fazlar (uygulama sırası)

- **Faz 0 — İskelet:** repo, pyproject, config, CLI stub, README/REQUIREMENTS. *(bu adım)*
- **Faz 1 — ASR hattı:** dosya → preprocess (ffmpeg) → `DashScopeBackend` → transkript.json.
  Golden test: kısa bir Türkçe kayıt.
- **Faz 2 — Özetleme:** transkript → LLM → summary.md (Türkçe, atıflı).
- **Faz 3 — Kayıt:** WASAPI loopback + mic canlı kayıt + otomatik pipeline tetikleme.
- **Faz 4 — CLI/UX:** `ainote record|process|list|show`, ilerleme çıktısı.
- **Faz 5 — (ops.) UI & realtime:** masaüstü UI veya web panel; WebSocket realtime transkript.
- **Faz 6 — (ops.) Diarization:** konuşmacı ayrımı (mikrofon/sistem kanal ayrımı ile doğal,
  ya da bir embedding modeli).

---

## 9. Karar Bekleyen Sorular

1. **ASR sağlayıcısı:** DashScope `qwen3-asr-flash` (bulut, en kolay) mı, yoksa
   **kendi GPU'lu sunucunda self-host Qwen3-ASR-1.7B** (OpenAI uyumlu uç) mı?
2. **Ses kaynağı:** sadece sistem sesi mi, sadece mikrofon mu, yoksa **ikisi miks** mi?
3. **Özet LLM sağlayıcısı:** hangi modeli kullanacaksın (OpenAI-uyumlu herhangi biri)?
4. **Arayüz:** önce **CLI** mi, yoksa doğrudan **masaüstü/web UI** mı?

---

## 10. Gizlilik / Uyarı

Toplantı kaydı ve transkript **kişisel veri** içerir (KVKK/GDPR). Bulut ASR kullanılırsa
ses üçüncü tarafa gider. Kayıt öncesi katılımcı onayı ve veri saklama politikası
netleştirilmeli. Bu madde tasarım kararlarını (self-host vs bulut) doğrudan etkiler.
