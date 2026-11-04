import Foundation
import Combine

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var activeTask: TaskRecord?
    @Published private(set) var todayTasks: [TaskRecord] = []
    @Published var now = Date()

    @Published var includeCalendar: Bool {
        didSet {
            UserDefaults.standard.set(includeCalendar, forKey: "includeCalendar")
            if includeCalendar && calendar.access == .notDetermined {
                Task { await calendar.requestAccess() }
            }
            refreshToday()
        }
    }

    let db = Database()
    let calendar = CalendarService()
    private var timer: AnyCancellable?

    init() {
        includeCalendar = UserDefaults.standard.bool(forKey: "includeCalendar")
        activeTask = db.activeTask()
        refreshToday()
        calendar.onChange = { [weak self] in self?.refreshToday() }

        // Tick every second so the elapsed time in the popup stays live.
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                let dayChanged = !Calendar.current.isDate(date, inSameDayAs: self.now)
                let minuteChanged = Int(date.timeIntervalSince1970 / 60) != Int(self.now.timeIntervalSince1970 / 60)
                self.now = date
                // Re-check each minute so meetings appear as soon as they end.
                if dayChanged || (minuteChanged && self.includeCalendar) { self.refreshToday() }
            }
    }

    func start(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if activeTask != nil { end() } // starting a new task ends the current one
        activeTask = db.startTask(title: trimmed)
        now = Date()
    }

    func end() {
        guard let id = activeTask?.dbID else { return }
        db.endTask(id: id)
        activeTask = nil
        refreshToday()
    }

    func discardActive() {
        guard let id = activeTask?.dbID else { return }
        db.deleteTask(id: id)
        activeTask = nil
    }

    func delete(_ task: TaskRecord) {
        guard let id = task.dbID else { return }
        db.deleteTask(id: id)
        refreshToday()
    }

    func refreshToday() {
        let updated = tasks(on: Date())
        if updated != todayTasks { todayTasks = updated }
    }

    /// Completed tasks plus (optionally) finished calendar events for a day, oldest first.
    func tasks(on day: Date) -> [TaskRecord] {
        var items = db.completedTasks(on: day)
        if includeCalendar { items += calendar.events(on: day) }
        return items.sorted { $0.startedAt < $1.startedAt }
    }
}

enum Fmt {
    static func duration(_ t: TimeInterval) -> String {
        let s = Int(max(0, t))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    static func shortDuration(_ t: TimeInterval) -> String {
        let s = Int(max(0, t))
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}
