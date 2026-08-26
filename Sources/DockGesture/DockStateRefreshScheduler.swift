import Foundation

@MainActor
final class DockStateRefreshScheduler: NSObject {
    enum Pace {
        case fast
        case slow

        var interval: TimeInterval {
            switch self {
            case .fast: 1.0 / 30.0
            case .slow: 0.5
            }
        }
    }

    var onRefresh: (() -> Pace)?

    private var timer: Timer?
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        refreshAndSchedule()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func requestImmediateRefresh() {
        guard isRunning else { return }
        timer?.invalidate()
        timer = nil
        refreshAndSchedule()
    }

    @objc private func timerDidFire() {
        timer = nil
        refreshAndSchedule()
    }

    private func refreshAndSchedule() {
        guard isRunning else { return }
        let pace = onRefresh?() ?? .slow
        let nextTimer = Timer(
            timeInterval: pace.interval,
            target: self,
            selector: #selector(timerDidFire),
            userInfo: nil,
            repeats: false
        )
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }
}
