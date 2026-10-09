import SwiftUI

/// Hakkında bölümü.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 46))
                .foregroundStyle(Theme.record)
            Text("Kavas AI NoteTaker").font(.title.bold())
            Text("Sürüm 0.1.1").font(.callout).foregroundStyle(.secondary)
            Text("Online toplantı sesini kaydeder, Qwen3-ASR ile yazıya döker ve LLM ile özetler.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Spacer().frame(height: 8)
            Text("© 2026 Emircan Kavas").font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
