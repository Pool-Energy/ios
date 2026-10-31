import Foundation

enum Fmt {
    private static let byteUnits = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"]

    static func bytes(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "0 B" }
        var size = value
        var index = 0
        while size >= 1024, index < byteUnits.count - 1 {
            size /= 1024
            index += 1
        }
        let digits = index >= 3 ? 2 : (index == 0 ? 0 : 1)
        return "\(String(format: "%.\(digits)f", size)) \(byteUnits[index])"
    }

    static func xch(_ mojos: Double) -> String {
        let value = mojos / 1_000_000_000_000
        if value >= 100 {
            return String(format: "%.2f", value)
        }
        if value >= 1 {
            return String(format: "%.4f", value)
        }
        return String(format: "%.6f", value)
    }

    /// Formats a minute count the way the dashboard does: two largest units.
    static func duration(minutes: Double) -> String {
        duration(seconds: minutes * 60)
    }

    static func duration(seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "—" }
        let total = Int(seconds.rounded())
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let mins = (total % 3_600) / 60

        if days > 0 {
            return hours > 0 ? "\(days) d \(hours) h" : "\(days) d"
        }
        if hours > 0 {
            return mins > 0 ? "\(hours) h \(mins) min" : "\(hours) h"
        }
        if mins > 0 {
            return "\(mins) min"
        }
        return "\(total) s"
    }

    static func percent(_ value: Double, digits: Int = 2) -> String {
        String(format: "%.\(digits)f%%", value)
    }

    static func number(_ value: Double, digits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func price(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    static func shortHash(_ value: String, prefix: Int = 8, suffix: Int = 6) -> String {
        guard value.count > prefix + suffix + 3 else { return value }
        return "\(value.prefix(prefix))…\(value.suffix(suffix))"
    }

    static func date(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        if let date = isoDate(iso) {
            return dateFormatter.string(from: date)
        }
        return iso
    }

    static func dateTime(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        if let date = isoDate(iso) {
            return dateTimeFormatter.string(from: date)
        }
        return iso
    }

    static func epoch(_ timestamp: Double, withTime: Bool = true) -> String {
        guard timestamp > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: timestamp)
        return (withTime ? dateTimeFormatter : dateFormatter).string(from: date)
    }

    static func relative(seconds: Double) -> String {
        guard seconds > 0, seconds.isFinite else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: Date(timeIntervalSinceNow: -seconds), relativeTo: Date())
    }

    private static let isoFormatters: [ISO8601DateFormatter] = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return [withFraction, plain]
    }()

    private static func isoDate(_ value: String) -> Date? {
        for formatter in isoFormatters {
            if let date = formatter.date(from: value) { return date }
        }
        // The stats endpoint returns naive timestamps ("2026-10-28T19:44:07").
        for pattern in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
