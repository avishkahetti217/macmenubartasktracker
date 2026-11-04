import Foundation
import Combine

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var activeTask: TaskRecord?
    @Published private(set) var todayTasks: [TaskRecord] = []
    @Published var now = Date()

    let db = Database()
    private var timer: AnyCancellable?

    init() {
        activeTask = db.activeTask()
        refreshToday()
        // Tick every second so the elapsed time in the menu bar stays live.
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                let dayChanged = !Calendar.current.isDate(date, inSameDayAs: self.now)
                self.now = date
                if dayChanged { self.refreshToday() }
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
        guard let task = activeTask else { return }
        db.endTask(id: task.id)
        activeTask = nil
        refreshToday()
    }

    func discardActive() {
        guard let task = activeTask else { return }
        db.deleteTask(id: task.id)
        activeTask = nil
    }

    func delete(_ task: TaskRecord) {
        db.deleteTask(id: task.id)
        refreshToday()
    }

    func refreshToday() {
        todayTasks = db.completedTasks(on: Date())
    }

    func tasks(on day: Date) -> [TaskRecord] {
        db.completedTasks(on: day)
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
