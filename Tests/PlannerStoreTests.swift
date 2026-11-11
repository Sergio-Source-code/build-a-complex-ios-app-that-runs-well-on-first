import XCTest
@testable import App

final class PlannerStoreTests: XCTestCase {
    @MainActor
    func testFirstLaunchSeedsOnceAndPersistsChanges() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = PlannerStore(storageURL: url)
        XCTAssertEqual(store.tasks.count, 7)
        XCTAssertEqual(store.habits.count, 3)
        XCTAssertTrue(store.sessions.isEmpty)
        let task = try XCTUnwrap(store.tasks.first)
        store.deleteTask(task)
        let reloaded = PlannerStore(storageURL: url)
        XCTAssertEqual(reloaded.tasks.count, 6)
        XCTAssertFalse(reloaded.tasks.contains { $0.id == task.id })
        XCTAssertNil(reloaded.storageMessage)
    }

    @MainActor
    func testTaskAndHabitChangesSurviveRelaunch() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = PlannerStore(storageURL: url)
        store.resetAll(includeExamples: false)
        let task = PlannerTask(title: "Write a first draft", project: .work, priority: .high)
        store.saveTask(task)
        store.toggleTask(task)
        store.addHabit(title: "Read", target: "10 pages", symbol: "book.closed.fill")
        let habit = try XCTUnwrap(store.habits.first)
        store.toggleHabit(habit)
        let reloaded = PlannerStore(storageURL: url)
        XCTAssertTrue(try XCTUnwrap(reloaded.tasks.first).isComplete)
        XCTAssertTrue(try XCTUnwrap(reloaded.habits.first).isComplete(on: Date()))
        XCTAssertEqual(reloaded.tasks.count, 1)
    }

    @MainActor
    func testExpiredFocusIsRecordedExactlyOnceOnRelaunch() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let task = PlannerTask(title: "Deep work")
        let snapshot = PlannerSnapshot(
            tasks: [task], habits: [], sessions: [],
            focus: FocusState(durationMinutes: 25, remainingSeconds: 1500, endDate: Date().addingTimeInterval(-5), hasStarted: true, taskID: task.id)
        )
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url)
        let store = PlannerStore(storageURL: url)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.minutes, 25)
        XCTAssertEqual(store.sessions.first?.taskTitle, "Deep work")
        XCTAssertNil(store.focus.endDate)
        XCTAssertFalse(store.focus.hasStarted)
        store.reconcileFocus()
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(PlannerStore(storageURL: url).sessions.count, 1)
    }

    @MainActor
    func testPausedFocusSurvivesRelaunch() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = PlannerStore(storageURL: url)
        store.setFocusDuration(15)
        store.startFocus()
        store.pauseFocus()
        let reloaded = PlannerStore(storageURL: url)
        XCTAssertTrue(reloaded.focus.hasStarted)
        XCTAssertNil(reloaded.focus.endDate)
        XCTAssertGreaterThan(reloaded.remainingFocus(), 890)
        XCTAssertLessThanOrEqual(reloaded.remainingFocus(), 900)
        XCTAssertTrue(reloaded.sessions.isEmpty)
    }

    @MainActor
    func testCorruptFileIsNotOverwritten() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("not valid JSON".utf8)
        try original.write(to: url)
        let store = PlannerStore(storageURL: url)
        XCTAssertNotNil(store.storageMessage)
        store.saveTask(PlannerTask(title: "Unsaved task"))
        XCTAssertEqual(try Data(contentsOf: url), original)
        store.resetAll(includeExamples: false)
        XCTAssertTrue(PlannerStore(storageURL: url).tasks.isEmpty)
        XCTAssertNil(PlannerStore(storageURL: url).storageMessage)
    }

    func testStreakAllowsTodayToBeUnfinished() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        let twoDaysAgo = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -2, to: today))
        var habit = Habit(title: "Walk", symbol: "figure.walk", target: "20 minutes")
        habit.completedDays = [Habit.dayKey(yesterday), Habit.dayKey(twoDaysAgo)]
        XCTAssertEqual(habit.streak(on: today), 2)
        habit.completedDays.insert(Habit.dayKey(today))
        XCTAssertEqual(habit.streak(on: today), 3)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("planner.json")
    }
}
