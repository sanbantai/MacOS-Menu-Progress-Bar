import Foundation

struct ChecklistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var isCompleted: Bool

    init(id: UUID = UUID(), text: String, isCompleted: Bool = false) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
    }
}

enum KanbanColumn: String, CaseIterable, Codable, Hashable, Identifiable {
    case index = "Index"
    case wip = "WIP"
    case done = "Done"

    var id: String { rawValue }
}

struct KanbanCard: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var column: KanbanColumn

    init(id: UUID = UUID(), text: String, column: KanbanColumn = .index) {
        self.id = id
        self.text = text
        self.column = column
    }
}

struct QuickNote: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

@MainActor
final class ProgressModel: ObservableObject {
    enum Mode: String {
        case timer
        case checklist
        case kanban
    }

    @Published private(set) var mode: Mode = .timer
    @Published private(set) var title = "Ready"
    @Published private(set) var startDate: Date?
    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining: TimeInterval?
    @Published private(set) var checklistTitle = "Your checklist"
    @Published private(set) var checklistItems: [ChecklistItem] = []
    @Published private(set) var kanbanCards: [KanbanCard] = []
    @Published private(set) var notes: [QuickNote] = []
    private let defaults = UserDefaults.standard

    init() {
        restoreTimer()
        restoreChecklistTitle()
        restoreChecklist()
        restoreKanban()
        restoreNotes()
        if defaults.string(forKey: "activeMode") == Mode.checklist.rawValue, !checklistItems.isEmpty {
            mode = .checklist
        } else if defaults.string(forKey: "activeMode") == Mode.kanban.rawValue, !kanbanCards.isEmpty {
            mode = .kanban
        }
    }

    var isRunning: Bool {
        mode == .timer && endDate != nil && pausedRemaining == nil
    }
    var isPaused: Bool { pausedRemaining != nil }
    var hasSession: Bool {
        switch mode {
        case .checklist:
            return !checklistItems.isEmpty
        case .kanban:
            return !kanbanCards.isEmpty
        case .timer:
            return endDate != nil || pausedRemaining != nil
        }
    }

    var completedChecklistCount: Int {
        checklistItems.lazy.filter(\.isCompleted).count
    }

    var nextUncompletedChecklistItem: ChecklistItem? {
        checklistItems.first { !$0.isCompleted }
    }

    var isChecklistComplete: Bool {
        !checklistItems.isEmpty && completedChecklistCount == checklistItems.count
    }

    var completedKanbanCount: Int {
        kanbanCards.lazy.filter { $0.column == .done }.count
    }

    var nextKanbanCard: KanbanCard? {
        kanbanCards.first { $0.column == .wip } ?? kanbanCards.first { $0.column == .index }
    }

    var isKanbanComplete: Bool {
        !kanbanCards.isEmpty && completedKanbanCount == kanbanCards.count
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
        switch mode {
        case .checklist:
            return Double(completedChecklistCount) / Double(checklistItems.count)
        case .kanban:
            return Double(completedKanbanCount) / Double(kanbanCards.count)
        case .timer:
            return min(max(1 - remaining / totalDuration, 0), 1)
        }
    }

    var accessibilityText: String {
        guard hasSession else { return "The Papaya Project, ready" }
        if mode == .checklist {
            return "Checklist, \(Int(progress * 100)) percent complete, \(completedChecklistCount) of \(checklistItems.count) items complete"
        }
        if mode == .kanban {
            return "Kanban, \(Int(progress * 100)) percent complete, \(completedKanbanCount) of \(kanbanCards.count) cards done"
        }
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
        mode = .timer
        title = name
        startDate = Date()
        endDate = Date().addingTimeInterval(duration)
        pausedRemaining = nil
        saveTimer()
        objectWillChange.send()
    }

    func togglePause() {
        guard mode == .timer else { return }
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
        mode = .timer
        title = "Ready"
        startDate = nil
        endDate = nil
        pausedRemaining = nil
        clearSavedTimer()
        defaults.set(Mode.timer.rawValue, forKey: "activeMode")
        objectWillChange.send()
    }

    func addChecklistItem(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        checklistItems.append(ChecklistItem(text: cleaned))
        activateChecklist()
        saveChecklist()
    }

    func toggleChecklistItem(id: UUID) {
        guard let index = checklistItems.firstIndex(where: { $0.id == id }) else { return }
        checklistItems[index].isCompleted.toggle()
        activateChecklist()
        saveChecklist()
    }

    func updateChecklistItem(id: UUID, text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              let index = checklistItems.firstIndex(where: { $0.id == id }) else { return }
        checklistItems[index].text = cleaned
        saveChecklist()
    }

    func updateChecklistTitle(_ title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        checklistTitle = cleaned
        defaults.set(cleaned, forKey: "checklistTitle")
    }

    func moveChecklistItem(id: UUID, before destinationID: UUID?) {
        guard let sourceIndex = checklistItems.firstIndex(where: { $0.id == id }) else { return }
        let item = checklistItems.remove(at: sourceIndex)
        if let destinationID,
           let destinationIndex = checklistItems.firstIndex(where: { $0.id == destinationID }) {
            checklistItems.insert(item, at: destinationIndex)
        } else {
            checklistItems.append(item)
        }
        saveChecklist()
    }

    func deleteChecklistItem(id: UUID) {
        checklistItems.removeAll { $0.id == id }
        if checklistItems.isEmpty, mode == .checklist {
            mode = .timer
            defaults.set(Mode.timer.rawValue, forKey: "activeMode")
        }
        saveChecklist()
    }

    func clearChecklist() {
        checklistItems.removeAll()
        if mode == .checklist {
            mode = .timer
            defaults.set(Mode.timer.rawValue, forKey: "activeMode")
        }
        saveChecklist()
    }

    func activateChecklist() {
        guard !checklistItems.isEmpty else { return }
        mode = .checklist
        defaults.set(Mode.checklist.rawValue, forKey: "activeMode")
        objectWillChange.send()
    }

    func addKanbanCard(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        kanbanCards.append(KanbanCard(text: cleaned))
        activateKanban()
        saveKanban()
    }

    func moveKanbanCard(id: UUID, to column: KanbanColumn, before destinationID: UUID? = nil) {
        guard let sourceIndex = kanbanCards.firstIndex(where: { $0.id == id }) else { return }
        var card = kanbanCards.remove(at: sourceIndex)
        card.column = column
        if let destinationID,
           let destinationIndex = kanbanCards.firstIndex(where: { $0.id == destinationID }) {
            kanbanCards.insert(card, at: destinationIndex)
        } else if let lastIndex = kanbanCards.lastIndex(where: { $0.column == column }) {
            kanbanCards.insert(card, at: kanbanCards.index(after: lastIndex))
        } else {
            kanbanCards.append(card)
        }
        activateKanban()
        saveKanban()
    }

    func updateKanbanCard(id: UUID, text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              let index = kanbanCards.firstIndex(where: { $0.id == id }) else { return }
        kanbanCards[index].text = cleaned
        saveKanban()
    }

    func deleteKanbanCard(id: UUID) {
        kanbanCards.removeAll { $0.id == id }
        if kanbanCards.isEmpty, mode == .kanban {
            mode = .timer
            defaults.set(Mode.timer.rawValue, forKey: "activeMode")
        }
        saveKanban()
    }

    func clearKanban() {
        kanbanCards.removeAll()
        if mode == .kanban {
            mode = .timer
            defaults.set(Mode.timer.rawValue, forKey: "activeMode")
        }
        saveKanban()
    }

    func activateKanban() {
        guard !kanbanCards.isEmpty else { return }
        mode = .kanban
        defaults.set(Mode.kanban.rawValue, forKey: "activeMode")
        objectWillChange.send()
    }

    func addNote(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        notes.insert(QuickNote(text: cleaned), at: 0)
        saveNotes()
    }

    func updateNote(id: UUID, text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].text = cleaned
        saveNotes()
    }

    func moveNote(id: UUID, before destinationID: UUID?) {
        guard let sourceIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes.remove(at: sourceIndex)
        if let destinationID,
           let destinationIndex = notes.firstIndex(where: { $0.id == destinationID }) {
            notes.insert(note, at: destinationIndex)
        } else {
            notes.append(note)
        }
        saveNotes()
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        saveNotes()
    }

    func clearNotes() {
        notes.removeAll()
        saveNotes()
    }

    func activateTimerIfAvailable() {
        guard endDate != nil || pausedRemaining != nil else { return }
        mode = .timer
        defaults.set(mode.rawValue, forKey: "activeMode")
        objectWillChange.send()
    }

    @discardableResult
    func tick() -> Bool {
        guard isRunning, remaining <= 0 else {
            objectWillChange.send()
            return false
        }
        stop()
        return true
    }

    private func saveTimer() {
        defaults.set(mode.rawValue, forKey: "mode")
        defaults.set(mode.rawValue, forKey: "timerMode")
        defaults.set(mode.rawValue, forKey: "activeMode")
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
        if savedEnd > Date() || savedPaused != nil {
            mode = Mode(rawValue: defaults.string(forKey: "timerMode") ?? defaults.string(forKey: "mode") ?? "timer") ?? .timer
            title = defaults.string(forKey: "title") ?? "Focus timer"
            startDate = savedStart
            endDate = savedEnd
            pausedRemaining = savedPaused
        }
    }

    private func clearSavedTimer() {
        ["mode", "title", "startDate", "endDate", "pausedRemaining"].forEach(defaults.removeObject(forKey:))
    }

    private func saveChecklist() {
        if let data = try? JSONEncoder().encode(checklistItems) {
            defaults.set(data, forKey: "checklistItems")
        }
    }

    private func restoreChecklistTitle() {
        checklistTitle = defaults.string(forKey: "checklistTitle") ?? "Your checklist"
    }

    private func restoreChecklist() {
        guard let data = defaults.data(forKey: "checklistItems"),
              let items = try? JSONDecoder().decode([ChecklistItem].self, from: data) else { return }
        checklistItems = items
    }

    private func saveKanban() {
        if let data = try? JSONEncoder().encode(kanbanCards) {
            defaults.set(data, forKey: "kanbanCards")
        }
    }

    private func restoreKanban() {
        guard let data = defaults.data(forKey: "kanbanCards"),
              let cards = try? JSONDecoder().decode([KanbanCard].self, from: data) else { return }
        kanbanCards = cards
    }

    private func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            defaults.set(data, forKey: "quickNotes")
        }
    }

    private func restoreNotes() {
        guard let data = defaults.data(forKey: "quickNotes"),
              let savedNotes = try? JSONDecoder().decode([QuickNote].self, from: data) else { return }
        notes = savedNotes
    }
}
