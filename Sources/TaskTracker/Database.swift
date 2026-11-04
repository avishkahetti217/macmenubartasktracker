import Foundation
import SQLite3

struct TaskRecord: Identifiable, Equatable {
    enum Source: Equatable {
        case manual(dbID: Int64)
        case calendar(eventID: String, calendarName: String)
    }

    let source: Source
    var title: String
    var startedAt: Date
    var endedAt: Date?

    var id: String {
        switch source {
        case .manual(let dbID): return "db-\(dbID)"
        case .calendar(let eventID, _): return "cal-\(eventID)-\(startedAt.timeIntervalSince1970)"
        }
    }

    /// Row id in SQLite; nil for calendar events.
    var dbID: Int64? {
        if case .manual(let id) = source { return id }
        return nil
    }

    var isCalendarEvent: Bool { dbID == nil }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

/// Thin wrapper around SQLite. Data lives in
/// ~/Library/Application Support/TaskTracker/tasks.sqlite
final class Database {
    private var db: OpaquePointer?
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    let path: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TaskTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        path = support.appendingPathComponent("tasks.sqlite")

        if sqlite3_open(path.path, &db) != SQLITE_OK {
            fatalError("Unable to open database at \(path.path)")
        }
        exec("""
            CREATE TABLE IF NOT EXISTS tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL
            );
            CREATE INDEX IF NOT EXISTS idx_tasks_started ON tasks(started_at);
            """)
    }

    deinit { sqlite3_close(db) }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            print("SQLite error: \(String(cString: err!))")
            sqlite3_free(err)
        }
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("SQLite prepare error: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        return stmt
    }

    @discardableResult
    func startTask(title: String, at date: Date = Date()) -> TaskRecord? {
        guard let stmt = prepare("INSERT INTO tasks (title, started_at) VALUES (?, ?)") else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, date.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
        return TaskRecord(source: .manual(dbID: sqlite3_last_insert_rowid(db)), title: title, startedAt: date, endedAt: nil)
    }

    func endTask(id: Int64, at date: Date = Date()) {
        guard let stmt = prepare("UPDATE tasks SET ended_at = ? WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
        sqlite3_bind_int64(stmt, 2, id)
        sqlite3_step(stmt)
    }

    func deleteTask(id: Int64) {
        guard let stmt = prepare("DELETE FROM tasks WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
    }

    /// The task that has been started but not yet ended, if any.
    func activeTask() -> TaskRecord? {
        query("SELECT id, title, started_at, ended_at FROM tasks WHERE ended_at IS NULL ORDER BY started_at DESC LIMIT 1").first
    }

    /// Completed tasks that started on the given calendar day (local time).
    func completedTasks(on day: Date) -> [TaskRecord] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return query(
            "SELECT id, title, started_at, ended_at FROM tasks WHERE ended_at IS NOT NULL AND started_at >= ? AND started_at < ? ORDER BY started_at ASC",
            [start.timeIntervalSince1970, end.timeIntervalSince1970]
        )
    }

    private func query(_ sql: String, _ params: [Double] = []) -> [TaskRecord] {
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() { sqlite3_bind_double(stmt, Int32(i + 1), p) }
        var rows: [TaskRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ended: Date? = sqlite3_column_type(stmt, 3) == SQLITE_NULL
                ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            rows.append(TaskRecord(
                source: .manual(dbID: sqlite3_column_int64(stmt, 0)),
                title: String(cString: sqlite3_column_text(stmt, 1)),
                startedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                endedAt: ended
            ))
        }
        return rows
    }
}
