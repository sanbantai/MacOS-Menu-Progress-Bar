import AppKit
import SwiftUI

struct ContentView: View {
    private enum Tool: String, CaseIterable, Identifiable {
        case timer = "Timer"
        case checklist = "Checklist"
        case kanban = "Kanban"
        case notes = "Notes"

        var id: String { rawValue }
    }

    @ObservedObject var model: ProgressModel
    @AppStorage("showTimerTool") private var showTimer = true
    @AppStorage("showChecklistTool") private var showChecklist = true
    @AppStorage("showKanbanTool") private var showKanban = true
    @AppStorage("showNotesTool") private var showNotes = true
    @State private var customHours = "0"
    @State private var customMinutes = "0"
    @State private var customSeconds = "0"
    @State private var draggedKanbanCardID: UUID?
    @State private var kanbanDragLocation: CGPoint?
    @State private var kanbanColumnFrames: [KanbanColumn: CGRect] = [:]
    @State private var newChecklistItem = ""
    @State private var newKanbanCard = ""
    @State private var newNote = ""
    @State private var selectedTool: Tool = .timer
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            header

            if showingSettings {
                settingsControls
            } else if visibleTools.isEmpty {
                noVisibleTools
            } else {
                Picker("Mode", selection: $selectedTool) {
                    ForEach(visibleTools) { tool in
                        Text(tool.rawValue).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                .onChange(of: selectedTool) { activate($0) }

                if model.hasSession {
                    activeSession
                    Divider()
                }

                toolControls
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(18)
        .frame(width: 430, height: 620)
        .onAppear {
            selectInitialTool()
        }
        .onChange(of: showTimer) { _ in ensureVisibleSelection() }
        .onChange(of: showChecklist) { _ in ensureVisibleSelection() }
        .onChange(of: showKanban) { _ in ensureVisibleSelection() }
        .onChange(of: showNotes) { _ in ensureVisibleSelection() }
    }

    private var visibleTools: [Tool] {
        Tool.allCases.filter {
            switch $0 {
            case .timer: return showTimer
            case .checklist: return showChecklist
            case .kanban: return showKanban
            case .notes: return showNotes
            }
        }
    }

    private var header: some View {
        VStack(spacing: 5) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("Menu Progress")
                .font(.title2.weight(.semibold))
            Text("Keep time visible without watching the clock.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var activeSession: some View {
        VStack(alignment: .center, spacing: 10) {
            VStack(spacing: 3) {
                if model.mode == .checklist {
                    Text("Checklist").font(.headline)
                    Text("\(model.completedChecklistCount) of \(model.checklistItems.count) items complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.mode == .kanban {
                    Text("Kanban").font(.headline)
                    Text("\(model.completedKanbanCount) of \(model.kanbanCards.count) cards done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.title).font(.headline).lineLimit(1)
                    Text(model.mode == .calendar ? "Calendar event" : (model.isPaused ? "Paused" : "Timer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.shortRemaining)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                }
            }
            LabeledProgressBar(progress: model.progress)
            if model.mode == .timer || model.mode == .calendar {
                HStack {
                    if model.mode == .timer {
                        Button(model.isPaused ? "Resume" : "Pause") { model.togglePause() }
                    }
                    Button("Stop", role: .destructive) { model.stop() }
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var timerControls: some View {
        VStack(alignment: .center, spacing: 10) {
            Label("Start a timer", systemImage: "timer")
                .font(.headline)
            HStack(spacing: 8) {
                ForEach([5, 15, 60, 90], id: \.self) { minutes in
                    Button { model.startTimer(minutes: minutes) } label: {
                        VStack(spacing: 2) {
                            Text("\(minutes)")
                                .font(.title3.weight(.semibold))
                            Text("min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 58, height: 58)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .bottom, spacing: 7) {
                durationField("Hours", text: $customHours)
                Text(":").font(.title3.weight(.semibold)).padding(.bottom, 5)
                durationField("Minutes", text: $customMinutes)
                Text(":").font(.title3.weight(.semibold)).padding(.bottom, 5)
                durationField("Seconds", text: $customSeconds)
                Button("Start") { startCustomTimer() }
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedDurationSeconds == nil)
                    .padding(.bottom, 1)
            }
        }
    }

    @ViewBuilder
    private var toolControls: some View {
        switch selectedTool {
        case .timer:
            timerControls
            Divider()
            calendarControls
        case .checklist:
            checklistControls
        case .kanban:
            kanbanControls
        case .notes:
            notesControls
        }
    }

    private var checklistControls: some View {
        VStack(alignment: .center, spacing: 12) {
            Label("Your checklist", systemImage: "checklist")
                .font(.headline)

            HStack {
                TextField("Add an item", text: $newChecklistItem)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addChecklistItem)
                Button("Add") { addChecklistItem() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newChecklistItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if model.checklistItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.square")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Add tasks and the menu-bar progress will fill as you complete them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.checklistItems) { item in
                            ChecklistRow(
                                item: item,
                                onToggle: { model.toggleChecklistItem(id: item.id) },
                                onSave: { model.updateChecklistItem(id: item.id, text: $0) },
                                onDelete: { model.deleteChecklistItem(id: item.id) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 230)

                Button("Clear checklist", role: .destructive) { model.clearChecklist() }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var kanbanControls: some View {
        VStack(alignment: .center, spacing: 10) {
            Label("Kanban board", systemImage: "rectangle.3.group")
                .font(.headline)

            HStack {
                TextField("Add a card to Index", text: $newKanbanCard)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addKanbanCard)
                Button("Add") { addKanbanCard() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newKanbanCard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ZStack(alignment: .topLeading) {
                HStack(alignment: .top, spacing: 7) {
                    ForEach(KanbanColumn.allCases) { column in
                        KanbanColumnView(
                            column: column,
                            cards: model.kanbanCards.filter { $0.column == column },
                            draggedCardID: draggedKanbanCardID,
                            isDropTargeted: kanbanDropColumn == column,
                            onDragChanged: updateKanbanDrag,
                            onDragEnded: finishKanbanDrag,
                            onSave: { id, text in model.updateKanbanCard(id: id, text: text) },
                            onDelete: { model.deleteKanbanCard(id: $0) }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                if let draggedKanbanCardID,
                   let kanbanDragLocation,
                   let card = model.kanbanCards.first(where: { $0.id == draggedKanbanCardID }) {
                    Text(card.text)
                        .font(.caption)
                        .lineLimit(3)
                        .frame(width: 104, alignment: .leading)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                        }
                        .position(kanbanDragLocation)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "kanbanBoard")
            .onPreferenceChange(KanbanColumnFramePreferenceKey.self) {
                kanbanColumnFrames = $0
            }
            .frame(maxHeight: 285)

            if !model.kanbanCards.isEmpty {
                Button("Clear board", role: .destructive) { model.clearKanban() }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var notesControls: some View {
        VStack(alignment: .center, spacing: 10) {
            Label("Quick notes", systemImage: "note.text")
                .font(.headline)

            HStack {
                TextField("Capture a short note", text: $newNote)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addNote)
                Button("Save") { addNote() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if model.notes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Short notes you save will stay on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(model.notes) { note in
                            NoteRow(
                                note: note,
                                onSave: { model.updateNote(id: note.id, text: $0) },
                                onDelete: { model.deleteNote(id: note.id) }
                            )
                        }
                    }
                }

                Button("Clear notes", role: .destructive) { model.clearNotes() }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Visible tools", systemImage: "slider.horizontal.3")
                .font(.headline)
            Text("Choose which tabs appear in Menu Progress. Hidden tool data is kept.")
                .font(.caption)
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(spacing: 12) {
                    Toggle(isOn: $showTimer) { Label("Timer", systemImage: "timer") }
                    Toggle(isOn: $showChecklist) { Label("Checklist", systemImage: "checklist") }
                    Toggle(isOn: $showKanban) { Label("Kanban", systemImage: "rectangle.3.group") }
                    Toggle(isOn: $showNotes) { Label("Notes", systemImage: "note.text") }
                }
                .toggleStyle(.switch)
                .padding(5)
            }

            Text("Settings is always available at the bottom, even when every tool is hidden.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 340, maxHeight: .infinity, alignment: .topLeading)
    }

    private var noVisibleTools: some View {
        VStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("All tools are hidden")
                .font(.headline)
            Button("Open Settings") { showingSettings = true }
        }
        .frame(maxHeight: .infinity)
    }

    private var calendarControls: some View {
        VStack(alignment: .center, spacing: 9) {
            HStack {
                Label("Calendar", systemImage: "calendar")
                    .font(.headline)
                if model.calendarAuthorized {
                    Button {
                        model.refreshCalendar()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh calendar")
                }
            }

            if model.calendarAuthorized {
                Text(model.calendarMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !model.calendarEvents.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(model.calendarEvents) { event in
                                Button { model.track(event: event) } label: {
                                    EventRow(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 142)
                    Button("Track event happening now") { model.trackCurrentEvent() }
                        .controlSize(.small)
                }
            } else {
                Text(model.calendarMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Connect Calendar") { model.requestCalendarAccess() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                showingSettings.toggle()
                if !showingSettings { ensureVisibleSelection() }
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(showingSettings ? Color.accentColor : .secondary)

            Spacer()
            Text("Data stays on this Mac")
                .foregroundStyle(.secondary)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func durationField(_ label: String, text: Binding<String>) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(width: 58)
                .onSubmit(startCustomTimer)
        }
    }

    private var parsedDurationSeconds: Int? {
        guard let hours = durationPart(customHours, maximum: 24),
              let minutes = durationPart(customMinutes, maximum: 59),
              let seconds = durationPart(customSeconds, maximum: 59) else { return nil }
        let total = hours * 3600 + minutes * 60 + seconds
        guard (1...86_400).contains(total) else { return nil }
        return total
    }

    private func durationPart(_ text: String, maximum: Int) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return 0 }
        guard let value = Int(cleaned), (0...maximum).contains(value) else { return nil }
        return value
    }

    private func startCustomTimer() {
        guard let seconds = parsedDurationSeconds else { return }
        model.startTimer(seconds: seconds)
    }

    private func addChecklistItem() {
        model.addChecklistItem(newChecklistItem)
        newChecklistItem = ""
    }

    private func addKanbanCard() {
        model.addKanbanCard(newKanbanCard)
        newKanbanCard = ""
    }

    private var kanbanDropColumn: KanbanColumn? {
        guard let location = kanbanDragLocation else { return nil }
        return KanbanColumn.allCases.first { kanbanColumnFrames[$0]?.contains(location) == true }
    }

    private func updateKanbanDrag(id: UUID, location: CGPoint) {
        draggedKanbanCardID = id
        kanbanDragLocation = location
    }

    private func finishKanbanDrag(id: UUID, location: CGPoint) {
        if let destination = KanbanColumn.allCases.first(where: {
            kanbanColumnFrames[$0]?.contains(location) == true
        }) {
            model.moveKanbanCard(id: id, to: destination)
        }
        draggedKanbanCardID = nil
        kanbanDragLocation = nil
    }

    private func addNote() {
        model.addNote(newNote)
        newNote = ""
    }

    private func activate(_ tool: Tool) {
        switch tool {
        case .timer:
            model.activateTimerIfAvailable()
        case .checklist:
            model.activateChecklist()
        case .kanban:
            model.activateKanban()
        case .notes:
            break
        }
    }

    private func selectInitialTool() {
        if model.mode == .checklist, showChecklist {
            selectedTool = .checklist
        } else if model.mode == .kanban, showKanban {
            selectedTool = .kanban
        } else {
            ensureVisibleSelection()
        }
    }

    private func ensureVisibleSelection() {
        guard !visibleTools.contains(selectedTool), let first = visibleTools.first else { return }
        selectedTool = first
        activate(first)
    }
}

private struct LabeledProgressBar: View {
    let progress: Double

    private let racingGreen = Color(red: 0, green: 0.651, blue: 0.318)

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Capsule()
                    .fill(.black)

                HStack(spacing: 0) {
                    Capsule()
                        .fill(.white)
                        .frame(width: geometry.size.width * clampedProgress)
                    Spacer(minLength: 0)
                }

                Text("\(Int(clampedProgress * 100))%")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(racingGreen)
            }
            .overlay {
                Capsule()
                    .stroke(.white, lineWidth: 1.5)
            }
        }
        .frame(height: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent complete")
    }
}

private struct ChecklistRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    let onSave: (String) -> Void
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var draftText: String

    init(
        item: ChecklistItem,
        onToggle: @escaping () -> Void,
        onSave: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.onToggle = onToggle
        self.onSave = onSave
        self.onDelete = onDelete
        _draftText = State(initialValue: item.text)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("Checklist item", text: $draftText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveEdit)
                Button(action: saveEdit) {
                    Image(systemName: "checkmark")
                }
                .disabled(cleanedDraft.isEmpty)
                .help("Save changes")
                Button(action: cancelEdit) {
                    Image(systemName: "xmark")
                }
                .help("Cancel")
            } else {
                Text(item.text)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    draftText = item.text
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
                .opacity(isHovering ? 1 : 0)
                .allowsHitTesting(isHovering)
                .help("Edit item")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .help("Delete item")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering = $0 }
    }

    private var cleanedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveEdit() {
        guard !cleanedDraft.isEmpty else { return }
        onSave(cleanedDraft)
        draftText = cleanedDraft
        isEditing = false
    }

    private func cancelEdit() {
        draftText = item.text
        isEditing = false
    }
}

private struct KanbanColumnView: View {
    let column: KanbanColumn
    let cards: [KanbanCard]
    let draggedCardID: UUID?
    let isDropTargeted: Bool
    let onDragChanged: (UUID, CGPoint) -> Void
    let onDragEnded: (UUID, CGPoint) -> Void
    let onSave: (UUID, String) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(column.rawValue)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text("\(cards.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Divider()

            if cards.isEmpty {
                Text("Empty")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(cards) { card in
                            KanbanCardView(
                                card: card,
                                isBeingDragged: draggedCardID == card.id,
                                onDragChanged: { onDragChanged(card.id, $0) },
                                onDragEnded: { onDragEnded(card.id, $0) },
                                onSave: { onSave(card.id, $0) },
                                onDelete: { onDelete(card.id) }
                            )
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: KanbanColumnFramePreferenceKey.self,
                    value: [column: proxy.frame(in: .named("kanbanBoard"))]
                )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(isDropTargeted ? Color.accentColor : .clear, lineWidth: 2)
        }
    }
}

private struct KanbanColumnFramePreferenceKey: PreferenceKey {
    static var defaultValue: [KanbanColumn: CGRect] = [:]

    static func reduce(
        value: inout [KanbanColumn: CGRect],
        nextValue: () -> [KanbanColumn: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct KanbanCardView: View {
    let card: KanbanCard
    let isBeingDragged: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    let onSave: (String) -> Void
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var draftText: String

    init(
        card: KanbanCard,
        isBeingDragged: Bool,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping (CGPoint) -> Void,
        onSave: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.card = card
        self.isBeingDragged = isBeingDragged
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onSave = onSave
        self.onDelete = onDelete
        _draftText = State(initialValue: card.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if isEditing {
                TextField("Card", text: $draftText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit(saveEdit)
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button(action: cancelEdit) {
                        Image(systemName: "xmark")
                    }
                    .help("Cancel")
                    Button(action: saveEdit) {
                        Image(systemName: "checkmark")
                    }
                    .disabled(cleanedDraft.isEmpty)
                    .help("Save changes")
                }
            } else {
                Text(card.text)
                    .font(.caption)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 7) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                    Button {
                        draftText = card.text
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(isHovering)
                    .help("Edit card")
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .help("Delete card")
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(8)
        .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
        .onHover { isHovering = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .opacity(isBeingDragged ? 0.2 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("kanbanBoard"))
                .onChanged { onDragChanged($0.location) }
                .onEnded { onDragEnded($0.location) }
        )
    }

    private var cleanedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveEdit() {
        guard !cleanedDraft.isEmpty else { return }
        onSave(cleanedDraft)
        draftText = cleanedDraft
        isEditing = false
    }

    private func cancelEdit() {
        draftText = card.text
        isEditing = false
    }
}

private struct NoteRow: View {
    let note: QuickNote
    let onSave: (String) -> Void
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var draftText: String

    init(note: QuickNote, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.note = note
        self.onSave = onSave
        self.onDelete = onDelete
        _draftText = State(initialValue: note.text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isEditing {
                TextField("Note", text: $draftText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveEdit)
                Button(action: saveEdit) {
                    Image(systemName: "checkmark")
                }
                .disabled(cleanedDraft.isEmpty)
                .help("Save changes")
                Button(action: cancelEdit) {
                    Image(systemName: "xmark")
                }
                .help("Cancel")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.text)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Button {
                    draftText = note.text
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
                .opacity(isHovering ? 1 : 0)
                .allowsHitTesting(isHovering)
                .help("Edit note")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .help("Delete note")
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering = $0 }
    }

    private var cleanedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveEdit() {
        guard !cleanedDraft.isEmpty else { return }
        onSave(cleanedDraft)
        draftText = cleanedDraft
        isEditing = false
    }

    private func cancelEdit() {
        draftText = note.text
        isEditing = false
    }
}

private struct EventRow: View {
    let event: CalendarEventItem

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color(nsColor: event.calendarColor))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(event.startDate.formatted(date: .omitted, time: .shortened))–\(event.endDate.formatted(date: .omitted, time: .shortened)) · \(event.calendarName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "play.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
