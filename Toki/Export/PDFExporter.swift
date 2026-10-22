import UIKit
import TokiCore

/// A4 report in the layout of myTime's PDF exports: header with job, period, overtime account and
/// remaining vacation; one row per day; period totals. Credits appear in the event column.
enum PDFExporter {
    private static let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin: CGFloat = 36
    private static let rowHeight: CGFloat = 15
    /// Column titles and x positions.
    private static let columns: [(String, CGFloat)] = [
        (String(localized: "Datum"), 0), (String(localized: "Soll"), 70), (String(localized: "Ist"), 115),
        (String(localized: "Überst."), 160), (String(localized: "Zeiten"), 210), (String(localized: "Ereignis"), 300),
        (String(localized: "Notiz"), 400),
    ]

    @MainActor
    static func make(title: String, days: [DayRecord], store: AppStore, periodEnd: LocalDate) -> Data {
        let heading = String(localized: "Toki") + " · " + store.settings.jobName
        let account = OvertimeAccount.total(days: store.sortedDays, settings: store.settings, through: periodEnd)
        let vacation = HoursFormat.days(store.vacationBalance(on: periodEnd))
        let accounts = String(localized: "Überstundenkonto: \(HoursFormat.signed(account))   Resturlaub: \(vacation) d")
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            var y: CGFloat = 0
            func newPage() {
                context.beginPage()
                y = margin
                draw(heading, at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 16))
                y += 22
                draw(title, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 12))
                draw(accounts, at: CGPoint(x: margin + 250, y: y), font: .systemFont(ofSize: 10))
                y += 24
                for (name, x) in columns {
                    draw(name, at: CGPoint(x: margin + x, y: y), font: .boldSystemFont(ofSize: 9))
                }
                y += rowHeight + 2
            }
            newPage()
            for day in days {
                for line in rows(for: day, store: store) {
                    if y > page.height - margin - rowHeight * 3 { newPage() }
                    for (index, text) in line.enumerated() {
                        let width = index + 1 < columns.count ? columns[index + 1].1 - columns[index].1 - 4 : page.width - 2 * margin - columns[index].1
                        draw(text, at: CGPoint(x: margin + columns[index].1, y: y), font: .systemFont(ofSize: 9), width: width,
                             color: day.date.isWeekend && index == 0 ? .systemOrange : .black)
                    }
                    y += rowHeight
                }
            }
            y += 6
            let worked = days.reduce(0) { $0 + Calculator.worked($1) }
            let target = days.reduce(0) { $0 + Calculator.effectiveTarget($1) }
            let overtime = OvertimeAccount.sum(days)
            let credits = days.filter { $0.credit != nil }.count
            let vacation = Calculator.count(.vacation, in: days)
            let totals = String(localized: "Summe: Soll \(HoursFormat.plain(target)) · Ist \(HoursFormat.plain(worked)) · Überstunden \(HoursFormat.signed(overtime)) · Urlaub \(vacation) d · Gutschriften \(credits) d")
            draw(totals, at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 10))
        }
    }

    @MainActor
    private static func rows(for day: DayRecord, store: AppStore) -> [[String]] {
        let date = "\(DateText.weekdayShort(day.date)) \(day.date.german)"
        let dayValues = [HoursFormat.plain(Calculator.effectiveTarget(day)), HoursFormat.plain(Calculator.worked(day)),
                         HoursFormat.signed(Calculator.overtime(day))]
        var result: [[String]] = []
        for (index, entry) in day.entries.enumerated() {
            let times: String
            if let start = entry.startSeconds, let end = entry.endSeconds {
                times = "\(HoursFormat.clock(start))–\(HoursFormat.clock(end))"
                    + (entry.breakSeconds > 0 ? " (\(HoursFormat.plain(entry.breakSeconds)))" : "")
            } else {
                times = ""
            }
            let event = entry.kind == .work ? (store.category(entry.categoryID)?.name ?? "")
                : entry.kind == .separateTime ? "\(store.category(entry.categoryID)?.name ?? entry.kind.localizedName) (getrennt)"
                : entry.kind.localizedName
            result.append((index == 0 ? [date] + dayValues : ["", "", "", ""]) + [times, event, entry.note])
        }
        if let credit = day.credit {
            let creditRow = [String(localized: "Urlaubstag-Gutschrift +1"), credit.note]
            result.append((result.isEmpty ? [date] + dayValues : ["", "", "", ""]) + [""] + creditRow)
        }
        return result
    }

    private static func draw(_ text: String, at point: CGPoint, font: UIFont, width: CGFloat = 520, color: UIColor = .black) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: CGRect(x: point.x, y: point.y, width: width, height: font.lineHeight + 2),
                                withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }
}
