import Foundation
import Observation

/// Drives a single ugoira animation: ownership of the playback `Task`,
/// frame index, transport state, and the `LoadState` machine. Lives in
/// the model layer so the inspector pane and the standalone window
/// viewer can share one source of truth instead of each hand-rolling
/// the same set of `@State` flags.
///
/// **Why a class.** SwiftUI `@State`-only ownership scattered
/// `animation`, `currentFrameIndex`, `isPlaying`, and `playbackTask`
/// across the view, which made the play loop fight the view lifecycle
/// — a `task(id:)` reset would clobber the loop without cancelling the
/// task, leaking it. An `@Observable` reference type lets the loop own
/// its own `Task` and publish frame updates back to the view through
/// the macros while we keep the view declarative.
///
/// **Why `@MainActor`.** The view binds directly to `currentFrameIndex`
/// and `isPlaying`. Pinning to the main actor avoids hop-on-every-frame
/// overhead (the playback loop already runs on the main run loop where
/// SwiftUI lives) and keeps the public surface ergonomic — call sites
/// don't need `await`.
@MainActor
@Observable
final class UgoiraPlayer {
    enum LoadState {
        case idle
        case loading
        case ready(UgoiraAnimation)
        case failed(String)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var currentFrameIndex: Int = 0
    private(set) var isPlaying: Bool = false

    /// Speed change mid-playback should kick in immediately instead of
    /// waiting out the current frame's authored delay. We re-arm the
    /// playback task so the next sleep uses the new cadence.
    var playbackSpeed: UgoiraPlaybackSpeed = .normal {
        didSet {
            guard oldValue != playbackSpeed, isPlaying else { return }
            restart()
        }
    }

    private var playbackTask: Task<Void, Never>?

    // MARK: - Computed accessors

    var animation: UgoiraAnimation? {
        if case .ready(let value) = loadState { return value }
        return nil
    }

    var frameCount: Int { animation?.frameCount ?? 0 }
    var hasContent: Bool { animation != nil }

    var isLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(let message) = loadState { return message }
        return nil
    }

    var totalDurationSeconds: Double {
        guard let animation else { return 0 }
        return Double(animation.totalDurationMilliseconds) / 1000.0
    }

    var totalDurationLabel: String {
        totalDurationSeconds.formatted(.number.precision(.fractionLength(1))) + "s"
    }

    var positionSummary: String {
        guard frameCount > 0 else { return "—" }
        return "\(currentFrameIndex + 1) / \(frameCount) · \(totalDurationLabel)"
    }

    // MARK: - State transitions

    func reset() {
        cancelTask()
        loadState = .idle
        currentFrameIndex = 0
        isPlaying = false
    }

    func beginLoading() {
        cancelTask()
        isPlaying = false
        currentFrameIndex = 0
        loadState = .loading
    }

    func reportFailure(_ message: String) {
        cancelTask()
        isPlaying = false
        loadState = .failed(message)
    }

    func install(_ animation: UgoiraAnimation, autoplay: Bool = true) {
        cancelTask()
        loadState = .ready(animation)
        currentFrameIndex = 0
        isPlaying = false
        if autoplay {
            play()
        }
    }

    // MARK: - Transport

    func play() {
        guard let animation, animation.frameCount > 0, isPlaying == false else { return }
        startTask(for: animation)
    }

    func pause() {
        cancelTask()
        isPlaying = false
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func seek(to frame: Int) {
        guard frameCount > 0 else { return }
        let clamped = max(0, min(frame, frameCount - 1))
        guard clamped != currentFrameIndex else { return }
        currentFrameIndex = clamped
        // Re-anchor the loop on the new frame so the next sleep matches
        // that frame's authored delay; otherwise the user's seek would
        // wait out the previous frame's residual delay before advancing.
        if isPlaying {
            restart()
        }
    }

    // MARK: - Private

    private func restart() {
        guard let animation else { return }
        cancelTask()
        startTask(for: animation)
    }

    private func startTask(for animation: UgoiraAnimation) {
        isPlaying = true
        // The loop runs inline with `[weak self]` instead of calling a
        // method on `self`. That matters because invoking a method on
        // `self` would re-introduce a strong reference for the duration
        // of the call, preventing the player from ever deinitialising
        // while the task is alive — and since the task is what owns the
        // sleep timer, that would create a leak the moment the host
        // view forgets to call `pause()` on disappear. With weak access
        // re-tested each iteration, the next sleep wake-up exits
        // cleanly once the view drops its `@State` reference.
        playbackTask = Task { @MainActor [weak self] in
            while Task.isCancelled == false {
                guard let strongSelf = self else { return }
                let speed = strongSelf.playbackSpeed
                let frameIndex = min(strongSelf.currentFrameIndex, animation.frameCount - 1)
                let scaledMilliseconds = speed.adjustedDelayMilliseconds(animation.frames[frameIndex].delayMilliseconds)
                try? await Task.sleep(for: .milliseconds(scaledMilliseconds))
                guard Task.isCancelled == false, let advancing = self else { return }
                advancing.currentFrameIndex = (advancing.currentFrameIndex + 1) % animation.frameCount
            }
        }
    }

    private func cancelTask() {
        playbackTask?.cancel()
        playbackTask = nil
    }
}
