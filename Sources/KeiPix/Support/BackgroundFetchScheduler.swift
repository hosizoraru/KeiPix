#if os(iOS)
import BackgroundTasks
import Foundation

/// Schedules background feed refresh on iPadOS using BGTaskScheduler.
///
/// Registers a background app refresh task that runs periodically
/// to keep the feed content fresh. The system decides when to run
/// the task based on device usage patterns and battery state.
enum BackgroundFetchScheduler {
    static let taskIdentifier = "com.keipix.feed-refresh"

    /// Register the background task handler. Call once at app launch.
    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    /// Schedule the next background refresh.
    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1 hour

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background task scheduling may fail in debug/simulator
            KeiPixLog.general.info("Background fetch scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh immediately
        scheduleNextRefresh()

        let store = KeiPixStore()
        let taskTask = Task {
            await store.reloadCurrentFeed()
        }

        task.expirationHandler = {
            taskTask.cancel()
        }

        Task {
            await taskTask.value
            task.setTaskCompleted(success: true)
        }
    }
}
#endif
