import UIKit
import CoreText

/// The emoji font is present on devices but can be missing from some simulator
/// runtimes, where every emoji renders as a tofu box. Probe the font once and
/// strip emoji presentations from user-provided strings when unusable.
enum EmojiSupport {
    static let isAvailable: Bool = {
        guard let uiFont = UIFont(name: "AppleColorEmoji", size: 12) else { return false }
        let font = uiFont as CTFont
        let probe = Array("🌱".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: probe.count)
        let resolved = probe.withUnsafeBufferPointer { buffer -> Bool in
            guard let base = buffer.baseAddress else { return false }
            return CTFontGetGlyphsForCharacters(font, base, &glyphs, buffer.count)
        }
        return resolved && glyphs.allSatisfy { $0 != 0 }
    }()

    static func sanitized(_ text: String) -> String {
        guard !isAvailable, !text.isEmpty else { return text }
        let scalars = text.unicodeScalars.filter { !$0.properties.isEmojiPresentation }
        return String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
