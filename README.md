# Task Tracker (macOS menu bar app)

Log what you're working on from the menu bar. Each finished task is saved to a local SQLite database.

## Build & run
```
./build.sh            # builds build/TaskTracker.app
open build/TaskTracker.app
./build.sh --install  # also copies to /Applications
```
To start it at login, go to System Settings → General → Login Items and add TaskTracker.

## Usage
- Click the checklist icon in the menu bar, type a task, press Return (or click **Start**).
- While a task is running, the menu bar icon changes to an hourglass. Click **End Task** when you're done.
- **Done Today** lists today's finished tasks and the total time.
- **View History…** opens a window where you can pick any day and see its tasks. Right-click a task to delete it, or use **Copy Day as Text**.

## Data
`~/Library/Application Support/TaskTracker/tasks.sqlite`, table `tasks(id, title, started_at, ended_at)`. Timestamps are Unix seconds.
