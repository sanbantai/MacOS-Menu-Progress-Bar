import Foundation

@MainActor
final class ProgressModel: ObservableObject {
    static let completionDisplayDuration: TimeInterval = 10

    @Published private(set) var title = "Ready"
    @Published private(set) var startDate: Date?
    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining: TimeInterval?
    @Published private(set) var completionVisibleUntil: Date?
    @Published private(set) var isCompletionSoundEnabled = true

    private let defaults = UserDefaults.standard
    private let legacyDefaultsDomain = "local.menuprogress.app"
    private let legacyMigrationKey = "didMigrateMenuProgressDefaults"

    init() {
        if defaults.object(forKey: "completionSoundEnabled") != nil {
            isCompletionSoundEnabled = defaults.bool(forKey: "completionSoundEnabled")
        }
        migrateLegacyDefaultsIfNeeded()
        restoreTimer()
    }

    var isRunning: Bool {
        endDate != nil && pausedRemaining == nil
    }

    var isPaused: Bool {
        pausedRemaining != nil
    }

    var hasSession: Bool {
        endDate != nil || pausedRemaining != nil
    }

    var isShowingCompletion: Bool {
        guard let completionVisibleUntil else { return false }
        return completionVisibleUntil > Date()
    }

    var totalDuration: TimeInterval {
        guard let startDate, let endDate else { return 0 }
        return max(endDate.timeIntervalSince(startDate), 1)
    }

    var remaining: TimeInterval {
        if let pausedRemaining { return max(pausedRemaining, 0) }
        guard let endDate else { return 0 }
        return max(endDate.timeIntervalSinceNow, 0)
    }

    var progress: Double {
        guard hasSession else { return 0 }
        return min(max(1 - remaining / totalDuration, 0), 1)
    }

    var displayProgress: Double {
        isShowingCompletion ? 1 : progress
    }

    var accessibilityText: String {
        if isShowingCompletion {
            return "The Squeeze, timer complete"
        }
        guard hasSession else { return "The Squeeze, ready" }
        return "\(title), \(Int(progress * 100)) percent complete, \(longRemaining) remaining"
    }

    var shortRemaining: String {
        let seconds = Int(remaining.rounded(.up))
        if seconds >= 3600 {
            return String(format: "%d:%02d", seconds / 3600, (seconds % 3600) / 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var longRemaining: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = remaining >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: remaining) ?? "0 min"
    }

    func startTimer(minutes: Int, name: String = "Focus timer") {
        startTimer(seconds: max(1, minutes) * 60, name: name)
    }

    func startTimer(seconds: Int, name: String = "Focus timer") {
        let duration = TimeInterval(max(1, seconds))
        let now = Date()
        title = name
        startDate = now
        endDate = now.addingTimeInterval(duration)
        pausedRemaining = nil
        completionVisibleUntil = nil
        saveTimer()
        objectWillChange.send()
    }

    func togglePause() {
        if let pausedRemaining {
            let duration = totalDuration
            let elapsed = max(duration - pausedRemaining, 0)
            startDate = Date().addingTimeInterval(-elapsed)
            endDate = Date().addingTimeInterval(pausedRemaining)
            self.pausedRemaining = nil
        } else if endDate != nil {
            pausedRemaining = remaining
        }
        saveTimer()
        objectWillChange.send()
    }

    func stop() {
        resetTimer()
        completionVisibleUntil = nil
        objectWillChange.send()
    }

    func toggleCompletionSound() {
        isCompletionSoundEnabled.toggle()
        defaults.set(isCompletionSoundEnabled, forKey: "completionSoundEnabled")
    }

    @discardableResult
    func tick(notifyObservers: Bool = true) -> Bool {
        let now = Date()

        if let completionVisibleUntil, completionVisibleUntil <= now {
            self.completionVisibleUntil = nil
        }

        guard isRunning else { return false }
        guard let endDate, endDate <= now else {
            if notifyObservers {
                objectWillChange.send()
            }
            return false
        }

        resetTimer()
        completionVisibleUntil = now.addingTimeInterval(Self.completionDisplayDuration)
        objectWillChange.send()
        return true
    }

    private func resetTimer() {
        title = "Ready"
        startDate = nil
        endDate = nil
        pausedRemaining = nil
        clearSavedTimer()
    }

    private func migrateLegacyDefaultsIfNeeded() {
        guard !defaults.bool(forKey: legacyMigrationKey) else { return }
        if let legacyDefaults = defaults.persistentDomain(forName: legacyDefaultsDomain) {
            for (key, value) in legacyDefaults where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: legacyMigrationKey)
    }

    private func saveTimer() {
        defaults.set(title, forKey: "title")
        defaults.set(startDate, forKey: "startDate")
        defaults.set(endDate, forKey: "endDate")
        if let pausedRemaining {
            defaults.set(pausedRemaining, forKey: "pausedRemaining")
        } else {
            defaults.removeObject(forKey: "pausedRemaining")
        }
    }

    private func restoreTimer() {
        guard let savedStart = defaults.object(forKey: "startDate") as? Date,
              let savedEnd = defaults.object(forKey: "endDate") as? Date else { return }
        let savedPaused = defaults.object(forKey: "pausedRemaining") as? Double
        guard savedEnd > Date() || savedPaused != nil else {
            clearSavedTimer()
            return
        }
        title = defaults.string(forKey: "title") ?? "Focus timer"
        startDate = savedStart
        endDate = savedEnd
        pausedRemaining = savedPaused
    }

    private func clearSavedTimer() {
        [
            "mode",
            "timerMode",
            "activeMode",
            "title",
            "startDate",
            "endDate",
            "pausedRemaining"
        ].forEach(defaults.removeObject(forKey:))
    }
}
