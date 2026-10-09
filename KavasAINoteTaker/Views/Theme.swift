import SwiftUI

/// meetily tarzı arayüz için tasarım sabitleri.
enum Theme {
    /// Kayıt kırmızısı (#DC3545).
    static let record = Color(red: 0.86, green: 0.21, blue: 0.27)
    /// Seçili öğe arka planı (#E7F1FF).
    static let selection = Color(red: 0.906, green: 0.945, blue: 1.0)
    /// Vurgu mavisi.
    static let accent = Color(red: 0.0, green: 0.48, blue: 1.0)
    /// Kart arka planı.
    static let card = Color(nsColor: .controlBackgroundColor)

    static let railWidth: CGFloat = 64
    static let cardCorner: CGFloat = 12
    static let contentMaxWidth: CGFloat = 760
}
