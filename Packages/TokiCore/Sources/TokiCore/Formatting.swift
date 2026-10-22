import Foundation

public enum HoursFormat {
    /// `+12h 30m`, `-0h 30m`, `0h 00m` — rounded to the minute like myTime.
    public static func signed(_ seconds: Int) -> String {
        let minutes = Int((Double(seconds) / 60).rounded())
        if minutes == 0 { return "0h 00m" }
        return (minutes > 0 ? "+" : "-") + hm(abs(minutes))
    }

    public static func plain(_ seconds: Int) -> String {
        hm(Int((Double(abs(seconds)) / 60).rounded()))
    }

    /// Time of day `08:30`; values past midnight wrap.
    public static func clock(_ seconds: Int) -> String {
        let minutes = Int((Double(seconds) / 60).rounded()) % (24 * 60)
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Decimal hours with a German comma, e.g. `8,50`.
    public static func decimal(_ seconds: Int) -> String {
        String(format: "%.2f", Double(seconds) / 3600).replacingOccurrences(of: ".", with: ",")
    }

    /// Day counts: `38`, `1,5`.
    public static func days(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    private static func hm(_ minutes: Int) -> String {
        String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
}
