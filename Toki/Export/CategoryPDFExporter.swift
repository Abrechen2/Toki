import UIKit
import TokiCore

/// A4 list of one category's entries in a period (e.g. work in Switzerland) with the total,
/// to hand in for separate payment.
enum CategoryPDFExporter {
    private static let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin: CGFloat = 40
    private static let rowHeight: CGFloat = 16
    private static let columns: [(String, CGFloat)] = [
        (String(localized: "Datum"), 0), (String(localized: "Beginn–Ende"), 95), (String(localized: "Pause"), 185),
        (String(localized: "Stunden"), 235), (String(localized: "Notiz"), 295),
    ]

    @MainActor
    static func make(report: CategoryReport, category: EntryCategory, period: String, store: AppStore) -> Data {
        let heading = "\(category.name) – \(String(localized: "Arbeitszeit"))"
        let job = store.settings.jobName
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            var y: CGFloat = 0
            func newPage() {
                context.beginPage()
                y = margin
                draw(heading, x: margin, y: y, font: .boldSystemFont(ofSize: 18))
                y += 26
                draw([job, period].filter { !$0.isEmpty }.joined(separator: " · "), x: margin, y: y, font: .systemFont(ofSize: 11))
                y += 26
                for (name, x) in columns { draw(name, x: margin + x, y: y, font: .boldSystemFont(ofSize: 10)) }
                y += rowHeight + 4
            }
            newPage()
            for row in report.rows {
                if y > page.height - margin - rowHeight * 3 { newPage() }
                let times = [row.startSeconds, row.endSeconds].compactMap { $0 }.map(HoursFormat.clock).joined(separator: "–")
                let values = ["\(DateText.weekdayShort(row.date)) \(row.date.display)", times,
                              row.breakSeconds > 0 ? HoursFormat.plain(row.breakSeconds) : "–",
                              HoursFormat.plain(row.durationSeconds), row.note]
                for (index, value) in values.enumerated() {
                    let width = index + 1 < columns.count ? columns[index + 1].1 - columns[index].1 - 6 : page.width - 2 * margin - columns[index].1
                    draw(value, x: margin + columns[index].1, y: y, font: .systemFont(ofSize: 10), width: width)
                }
                y += rowHeight
            }
            y += 10
            let count = report.rows.count == 1 ? String(localized: "1 Eintrag") : String(localized: "\(report.rows.count) Einträge")
            draw(String(localized: "Summe: \(HoursFormat.plain(report.totalSeconds)) (\(HoursFormat.decimal(report.totalSeconds)) h), \(count)"),
                 x: margin, y: y, font: .boldSystemFont(ofSize: 11))
        }
    }

    private static func draw(_ text: String, x: CGFloat, y: CGFloat, font: UIFont, width: CGFloat = 515) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: font.lineHeight + 2),
                                withAttributes: [.font: font, .foregroundColor: UIColor.black, .paragraphStyle: style])
    }
}
