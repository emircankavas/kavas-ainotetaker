import SwiftUI

/// Metni harf harf açar (typewriter efekti). Canlı transkriptte gecikme hissini kırar
/// (meetily'nin streaming efekti yaklaşımından uyarlanmıştır).
struct TypewriterText: View {
    let text: String
    var charsPerSecond: Double = 90

    @State private var visible = 0

    var body: some View {
        Text(String(text.prefix(visible)))
            .task(id: text) {
                visible = 0
                let total = text.count
                guard total > 0 else { return }
                let step = max(1, Int(charsPerSecond / 30))
                let delay = UInt64(1_000_000_000 / 30)
                while visible < total {
                    try? await Task.sleep(nanoseconds: delay)
                    if Task.isCancelled { break }
                    visible = min(total, visible + step)
                }
            }
    }
}
