# kavas-ainotetaker

Online toplantı ses kaydı → **Qwen3-ASR-1.7B** (API) ile transkript → **LLM** ile toplantı özeti.

## Nedir?

Zoom / Google Meet / Microsoft Teams gibi online toplantılarda konuşulan sesi kaydeder,
bu kaydı bir ASR (otomatik konuşma tanıma) API'sine göndererek yazıya döker ve yazıdan
**kararlar + aksiyonlar + özet** içeren paylaşılabilir bir toplantı notu üretir.

```
Toplantı sesi → [kayıt] → [Qwen3-ASR API] → transkript → [LLM] → toplantı özeti (md)
```

## Durum

🚧 **Tasarım aşaması.** Bkz. [REQUIREMENTS.md](REQUIREMENTS.md) — gereksinim, mimari ve
faz planı. Onay sonrası kodlama aşamalı ilerleyecek.

## Kurulum (ön taslak)

```bash
python -m venv .venv && source .venv/Scripts/activate   # Windows (git-bash)
pip install -e ".[dev]"
cp .env.example .env   # anahtarları doldur
```

## Lisans

TBD
