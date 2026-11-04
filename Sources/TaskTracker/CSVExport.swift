import Foundation
import SwiftUI
import AppKit

enum CSVExport {
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static func escape(_ s: String) -> String {
        if s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    private static func hm(_ t: TimeInterval) -> String {
        let m = Int((t / 60).rounded())
        return String(format: "%d:%02d", m / 60, m % 60)
    }

    /// Builds a CSV with one row per task, grouped day by day, plus a total row for each day.
    @MainActor
    static func build(store: TaskStore, from: Date, to: Date) -> (csv: String, count: Int) {
        let cal = Calendar.current
        var day = cal.startOfDay(for: min(from, to))
        let last = cal.startOfDay(for: max(from, to))

        var rows = [["Date", "Day", "Start", "End", "Duration (h:mm)", "Duration (min)", "Task", "Source"]]
        var count = 0
        while day <= last {
            let tasks = store.tasks(on: day)
            if !tasks.isEmpty {
                let date = dayFmt.string(from: day), weekday = weekdayFmt.string(from: day)
                for t in tasks {
                    let end = t.endedAt ?? t.startedAt
                    rows.append([
                        date, weekday,
                        timeFmt.string(from: t.startedAt), timeFmt.string(from: end),
                        hm(t.duration), String(Int((t.duration / 60).rounded())),
                        t.title, t.isCalendarEvent ? "Calendar" : "Task",
                    ])
                }
                let total = tasks.reduce(0) { $0 + $1.duration }
                rows.append([date, weekday, "", "", hm(total), String(Int((total / 60).rounded())), "Daily total", ""])
                count += tasks.count
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        let csv = rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        return (csv, count)
    }

    /// Writes to ~/Downloads, adding " (2)", " (3)"… instead of overwriting an existing file.
    static func save(_ csv: String, from: Date, to: Date) throws -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let base = "tasks_\(dayFmt.string(from: min(from, to)))_to_\(dayFmt.string(from: max(from, to)))"
        var url = downloads.appendingPathComponent(base + ".csv")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = downloads.appendingPathComponent("\(base) (\(n)).csv")
            n += 1
        }
        // UTF-8 BOM so Excel shows non-English characters correctly.
        try ("\u{FEFF}" + csv).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

struct ExportSection: View {
    @EnvironmentObject var store: TaskStore
    @State private var from = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
    @State private var to = Date()
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EXPORT TO CSV").font(.caption).foregroundStyle(.secondary)
            HStack {
                DatePicker("From", selection: $from, in: ...to, displayedComponents: .date)
                    .datePickerStyle(.field)
                DatePicker("To", selection: $to, in: from...Date(), displayedComponents: .date)
                    .datePickerStyle(.field)
                Spacer()
                Button {
                    export()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(isError ? .red : .secondary)
            }
        }
    }

    private func export() {
        let (csv, count) = CSVExport.build(store: store, from: from, to: to)
        guard count > 0 else {
            message = "No tasks in that date range."
            isError = true
            return
        }
        do {
            let url = try CSVExport.save(csv, from: from, to: to)
            message = "Saved \(count) tasks to Downloads/\(url.lastPathComponent)"
            isError = false
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            message = "Couldn't save the file: \(error.localizedDescription)"
            isError = true
        }
    }
}
