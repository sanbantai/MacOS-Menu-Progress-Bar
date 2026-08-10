import AppKit
import SwiftUI

private let appTypographyScale: CGFloat = 2

private extension Font {
    static var appBody: Font {
        .system(size: NSFont.systemFontSize * appTypographyScale)
    }

    static func app(
        _ textStyle: NSFont.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        let pointSize = NSFont.preferredFont(forTextStyle: textStyle).pointSize * appTypographyScale
        return .system(size: pointSize, weight: weight, design: design)
    }
}

struct ContentView: View {
    private enum Tool: String, CaseIterable, Identifiable {
        case timer = "Timer"
        case checklist = "Checklist"
        case kanban = "Kanban"
        case notes = "Notes"

        var id: String { rawValue }
    }

    private enum ClearTarget {
        case checklist
        case kanban
        case notes

        var buttonTitle: String {
            switch self {
            case .checklist: return "Clear Checklist"
            case .kanban: return "Clear Kanban Board"
            case .notes: return "Clear Notes"
            }
        }

        var message: String {
            switch self {
            case .checklist: return "This will permanently delete every checklist item."
            case .kanban: return "This will permanently delete every Kanban card."
            case .notes: return "This will permanently delete every note."
            }
        }
    }

    @ObservedObject var model: ProgressModel
    @Namespace private var kanbanReorderNamespace
    @AppStorage("showTimerTool") private var showTimer = true
    @AppStorage("showChecklistTool") private var showChecklist = true
    @AppStorage("showKanbanTool") private var showKanban = true
    @AppStorage("showNotesTool") private var showNotes = true
    @State private var customHours = "0"
    @State private var customMinutes = "0"
    @State private var customSeconds = "0"
    @State private var draggedChecklistItemID: UUID?
    @State private var checklistDragLocation: CGPoint?
    @State private var checklistItemFrames: [UUID: CGRect] = [:]
    @State private var checklistTitleDraft = ""
    @State private var isEditingChecklistTitle = false
    @State private var isHoveringChecklistTitle = false
    @State private var draggedKanbanCardID: UUID?
    @State private var kanbanDragLocation: CGPoint?
    @State private var kanbanColumnFrames: [KanbanColumn: CGRect] = [:]
    @State private var kanbanCardFrames: [UUID: CGRect] = [:]
    @State private var draggedNoteID: UUID?
    @State private var noteDragLocation: CGPoint?
    @State private var noteFrames: [UUID: CGRect] = [:]
    @State private var newChecklistItem = ""
    @State private var newKanbanCard = ""
    @State private var newNote = ""
    @State private var pendingClearTarget: ClearTarget?
    @State private var selectedTool: Tool = .timer
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            header
            sectionSeparator

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

                toolControls
            }

            sectionSeparator
            footer
        }
        .padding(18)
        .frame(width: 640)
        .fixedSize(horizontal: false, vertical: true)
        .font(.appBody)
        .alert(
            "Are You Sure Buddy?",
            isPresented: Binding(
                get: { pendingClearTarget != nil },
                set: { if !$0 { pendingClearTarget = nil } }
            ),
            presenting: pendingClearTarget
        ) { target in
            Button(target.buttonTitle, role: .destructive) {
                clear(target)
            }
            Button("Cancel", role: .cancel) {
                pendingClearTarget = nil
            }
        } message: { target in
            Text(target.message)
        }
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
        Text("Built By Sanbantai™")
            .font(.app(.caption1, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    private var sectionSeparator: some View {
        Rectangle()
            .fill(.black)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private var timerControls: some View {
        VStack(alignment: .center, spacing: 10) {
            Label("Start a timer", systemImage: "timer")
                .font(.app(.headline, weight: .semibold))

            HStack(spacing: 8) {
                ForEach([5, 15, 60, 90], id: \.self) { minutes in
                    Button { selectDuration(minutes: minutes) } label: {
                        VStack(spacing: 2) {
                            Text("\(minutes)")
                                .font(.app(.title3, weight: .semibold))
                            Text("min")
                                .font(.app(.caption2))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 92, height: 82)
                        .background(
                            isSelectedDuration(minutes) ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTimerProgressActive)
                }
            }

            HStack(alignment: .bottom, spacing: 7) {
                durationField("Hours", text: $customHours)
                Text(":").font(.app(.title3, weight: .semibold)).padding(.bottom, 5)
                durationField("Minutes", text: $customMinutes)
                Text(":").font(.app(.title3, weight: .semibold)).padding(.bottom, 5)
                durationField("Seconds", text: $customSeconds)
            }
            .disabled(isTimerProgressActive)

            TimerGoButton(
                progress: model.progress,
                isActive: isTimerProgressActive,
                isPouring: isTimerProgressActive && !model.isPaused,
                isEnabled: parsedDurationSeconds != nil,
                action: startCustomTimer
            )

            if model.mode == .timer && model.hasSession {
                HStack(spacing: 12) {
                    if model.mode == .timer {
                        Button(model.isPaused ? "Resume" : "Pause") {
                            model.togglePause()
                        }
                        .buttonStyle(
                            TimerActionButtonStyle(
                                background: Color(red: 1, green: 0.48, blue: 0.18),
                                foreground: .black
                            )
                        )
                    }

                    Button("Stop", role: .destructive) {
                        model.stop()
                    }
                    .buttonStyle(
                        TimerActionButtonStyle(
                            background: .black,
                            foreground: .white
                        )
                    )
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: model.hasSession)
            }
        }
    }

    @ViewBuilder
    private var toolControls: some View {
        switch selectedTool {
        case .timer:
            timerControls
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
            HStack(spacing: 8) {
                if isEditingChecklistTitle {
                    TextField("Checklist title", text: $checklistTitleDraft)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                        .onSubmit(saveChecklistTitle)
                    Button(action: saveChecklistTitle) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.plain)
                    .disabled(cleanedChecklistTitle.isEmpty)
                    .help("Save title")
                    Button(action: cancelChecklistTitleEdit) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .help("Cancel")
                } else {
                    Label(model.checklistTitle, systemImage: "checklist")
                        .font(.app(.headline, weight: .semibold))
                    Button {
                        checklistTitleDraft = model.checklistTitle
                        isEditingChecklistTitle = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHoveringChecklistTitle ? 1 : 0)
                    .allowsHitTesting(isHoveringChecklistTitle)
                    .help("Edit checklist title")
                }
            }
            .onHover { isHoveringChecklistTitle = $0 }

            HStack {
                TextField("Add an item", text: $newChecklistItem)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
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
                        .font(.app(.caption1))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(model.checklistItems) { item in
                                ChecklistRow(
                                    item: item,
                                    isBeingDragged: draggedChecklistItemID == item.id,
                                    onDragChanged: { updateChecklistDrag(id: item.id, location: $0) },
                                    onDragEnded: { finishChecklistDrag(id: item.id, location: $0) },
                                    onToggle: { model.toggleChecklistItem(id: item.id) },
                                    onSave: { model.updateChecklistItem(id: item.id, text: $0) },
                                    onDelete: { model.deleteChecklistItem(id: item.id) }
                                )
                            }
                        }
                        .animation(
                            .spring(response: 0.36, dampingFraction: 0.78),
                            value: model.checklistItems.map(\.id)
                        )
                    }

                    if let draggedChecklistItemID,
                       let checklistDragLocation,
                       let item = model.checklistItems.first(where: { $0.id == draggedChecklistItemID }) {
                        Text(item.text)
                            .lineLimit(2)
                            .frame(width: 520, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                            .position(checklistDragLocation)
                            .allowsHitTesting(false)
                    }
                }
                .coordinateSpace(name: "checklistList")
                .onPreferenceChange(ChecklistItemFramePreferenceKey.self) { checklistItemFrames = $0 }
                .frame(height: checklistListHeight)

                Button("Clear checklist", role: .destructive) {
                    pendingClearTarget = .checklist
                }
                    .buttonStyle(.plain)
                    .font(.app(.caption1))
            }
        }
    }

    private var checklistListHeight: CGFloat {
        min(max(CGFloat(model.checklistItems.count) * 64, 64), 350)
    }

    private var kanbanControls: some View {
        VStack(alignment: .center, spacing: 10) {
            Label("Kanban board", systemImage: "rectangle.3.group")
                .font(.app(.headline, weight: .semibold))

            HStack {
                TextField("Add a card to Index", text: $newKanbanCard)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
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
                            reorderNamespace: kanbanReorderNamespace,
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
                        .font(.app(.caption1))
                        .lineLimit(3)
                        .frame(width: 170, alignment: .leading)
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
            .onPreferenceChange(KanbanCardFramePreferenceKey.self) {
                kanbanCardFrames = $0
            }
            .frame(height: kanbanBoardHeight)

            if !model.kanbanCards.isEmpty {
                Button("Clear board", role: .destructive) {
                    pendingClearTarget = .kanban
                }
                    .buttonStyle(.plain)
                    .font(.app(.caption1))
            }
        }
    }

    private var kanbanBoardHeight: CGFloat {
        let largestColumn = KanbanColumn.allCases
            .map { column in model.kanbanCards.lazy.filter { $0.column == column }.count }
            .max() ?? 0
        return min(max(CGFloat(largestColumn) * 110 + 70, 150), 430)
    }

    private var notesControls: some View {
        VStack(alignment: .center, spacing: 10) {
            Label("Quick notes", systemImage: "note.text")
                .font(.app(.headline, weight: .semibold))

            HStack {
                TextField("Capture a short note", text: $newNote)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
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
                        .font(.app(.caption1))
                        .foregroundStyle(.secondary)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(model.notes) { note in
                                NoteRow(
                                    note: note,
                                    isBeingDragged: draggedNoteID == note.id,
                                    onDragChanged: { updateNoteDrag(id: note.id, location: $0) },
                                    onDragEnded: { finishNoteDrag(id: note.id, location: $0) },
                                    onSave: { model.updateNote(id: note.id, text: $0) },
                                    onDelete: { model.deleteNote(id: note.id) }
                                )
                            }
                        }
                        .animation(
                            .spring(response: 0.36, dampingFraction: 0.78),
                            value: model.notes.map(\.id)
                        )
                    }

                    if let draggedNoteID,
                       let noteDragLocation,
                       let note = model.notes.first(where: { $0.id == draggedNoteID }) {
                        Text(note.text)
                            .lineLimit(2)
                            .frame(width: 520, alignment: .leading)
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                            .position(noteDragLocation)
                            .allowsHitTesting(false)
                    }
                }
                .coordinateSpace(name: "notesList")
                .onPreferenceChange(NoteFramePreferenceKey.self) { noteFrames = $0 }
                .frame(height: notesListHeight)

                Button("Clear notes", role: .destructive) {
                    pendingClearTarget = .notes
                }
                    .buttonStyle(.plain)
                    .font(.app(.caption1))
            }
        }
    }

    private var notesListHeight: CGFloat {
        min(max(CGFloat(model.notes.count) * 82, 82), 350)
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Visible tools")
                .font(.app(.headline, weight: .semibold))
            Text("Choose which tabs appear in The Papaya Project. Hidden tool data is kept.")
                .font(.app(.caption1))
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    settingsToolToggle("Timer", isOn: $showTimer)
                    settingsToolToggle("Checklist", isOn: $showChecklist)
                    settingsToolToggle("Kanban", isOn: $showKanban)
                    settingsToolToggle("Notes", isOn: $showNotes)
                }
                .toggleStyle(.switch)
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Settings is always available at the bottom, even when every tool is hidden.")
                .font(.app(.caption1))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 520, alignment: .topLeading)
    }

    private func settingsToolToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: isOn)
                .labelsHidden()
            Text(title)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noVisibleTools: some View {
        VStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("All tools are hidden")
                .font(.app(.headline, weight: .semibold))
            Button("Open Settings") { showingSettings = true }
        }
    }

    private var footer: some View {
        ZStack {
            Text("Data stays on this Mac")
                .foregroundStyle(.secondary)

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

                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.app(.caption1))
    }

    private func durationField(_ label: String, text: Binding<String>) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.app(.caption2))
                .foregroundStyle(.secondary)
            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(width: 90)
                .onSubmit(startCustomTimer)
        }
    }

    private var isTimerProgressActive: Bool {
        model.mode == .timer && model.hasSession
    }

    private func selectDuration(minutes: Int) {
        customHours = String(minutes / 60)
        customMinutes = String(minutes % 60)
        customSeconds = "0"
    }

    private func isSelectedDuration(_ minutes: Int) -> Bool {
        parsedDurationSeconds == minutes * 60
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

    private func clear(_ target: ClearTarget) {
        switch target {
        case .checklist:
            model.clearChecklist()
        case .kanban:
            model.clearKanban()
        case .notes:
            model.clearNotes()
        }
        pendingClearTarget = nil
    }

    private var cleanedChecklistTitle: String {
        checklistTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveChecklistTitle() {
        guard !cleanedChecklistTitle.isEmpty else { return }
        model.updateChecklistTitle(cleanedChecklistTitle)
        checklistTitleDraft = model.checklistTitle
        isEditingChecklistTitle = false
    }

    private func cancelChecklistTitleEdit() {
        checklistTitleDraft = model.checklistTitle
        isEditingChecklistTitle = false
    }

    private func updateChecklistDrag(id: UUID, location: CGPoint) {
        draggedChecklistItemID = id
        checklistDragLocation = location
    }

    private func finishChecklistDrag(id: UUID, location: CGPoint) {
        let destinationID = model.checklistItems
            .filter { $0.id != id }
            .first { checklistItemFrames[$0.id].map { location.y < $0.midY } ?? false }?
            .id
        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            model.moveChecklistItem(id: id, before: destinationID)
        }
        draggedChecklistItemID = nil
        checklistDragLocation = nil
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
            let destinationID = model.kanbanCards
                .filter { $0.id != id && $0.column == destination }
                .first { kanbanCardFrames[$0.id].map { location.y < $0.midY } ?? false }?
                .id
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                model.moveKanbanCard(id: id, to: destination, before: destinationID)
            }
        }
        draggedKanbanCardID = nil
        kanbanDragLocation = nil
    }

    private func addNote() {
        model.addNote(newNote)
        newNote = ""
    }

    private func updateNoteDrag(id: UUID, location: CGPoint) {
        draggedNoteID = id
        noteDragLocation = location
    }

    private func finishNoteDrag(id: UUID, location: CGPoint) {
        let destinationID = model.notes
            .filter { $0.id != id }
            .first { noteFrames[$0.id].map { location.y < $0.midY } ?? false }?
            .id
        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            model.moveNote(id: id, before: destinationID)
        }
        draggedNoteID = nil
        noteDragLocation = nil
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

private struct TimerActionButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.caption1, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .frame(minWidth: 104)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(foreground.opacity(0.2), lineWidth: 1.5)
            }
            .shadow(
                color: background.opacity(configuration.isPressed ? 0.12 : 0.28),
                radius: configuration.isPressed ? 2 : 7,
                y: configuration.isPressed ? 1 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(
                .spring(response: 0.22, dampingFraction: 0.68),
                value: configuration.isPressed
            )
    }
}

private struct TimerGoButton: View {
    let progress: Double
    let isActive: Bool
    let isPouring: Bool
    let isEnabled: Bool
    let action: () -> Void

    private let papayaOrange = Color(red: 1, green: 0.48, blue: 0.18)
    private let papayaHighlight = Color(red: 1, green: 0.67, blue: 0.3)

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isActive ? "Squeezing Your Papayas.." : "Papaya Juice?")
                .font(.app(.caption1, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            PapayaGrinderView(
                isRunning: isPouring,
                color: papayaOrange,
                highlight: papayaHighlight
            )
            .frame(width: 150, height: 88)
            .allowsHitTesting(false)

            Button {
                guard !isActive, isEnabled else { return }
                action()
            } label: {
                ZStack {
                    PapayaGlassShape()
                        .fill(.black.opacity(0.92))

                    if isActive {
                        PapayaJuiceView(
                            progress: CGFloat(clampedProgress),
                            isPouring: isPouring,
                            color: papayaOrange,
                            highlight: papayaHighlight
                        )
                        .clipShape(PapayaGlassShape())
                    }

                    PapayaGlassShape()
                        .stroke(.black, lineWidth: 4)

                    PapayaGlassShape()
                        .stroke(.white.opacity(0.72), lineWidth: 1.5)

                    VStack {
                        Capsule()
                            .fill(.black)
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.78), lineWidth: 1.5)
                            }
                            .frame(width: 110, height: 8)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, -2)

                    Text(isActive ? "\(Int((clampedProgress * 100).rounded()))%" : "GO!")
                        .font(.app(.headline, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .frame(width: 116, height: 128)
                .contentShape(PapayaGlassShape())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isActive && isEnabled)
            .opacity(isActive || isEnabled ? 1 : 0.45)
            .accessibilityLabel(isActive ? "Timer progress" : "Start timer")
            .accessibilityValue(isActive ? "\(Int((clampedProgress * 100).rounded())) percent" : "")
        }
    }
}

private struct PapayaGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topInset: CGFloat = 5
        let sideInset: CGFloat = 17
        let bottomCorner: CGFloat = 12

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - sideInset, y: rect.maxY - bottomCorner))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - sideInset - bottomCorner, y: rect.maxY),
            control: CGPoint(x: rect.maxX - sideInset, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + sideInset + bottomCorner, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + sideInset, y: rect.maxY - bottomCorner),
            control: CGPoint(x: rect.minX + sideInset, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

private struct PapayaGrinderView: View {
    let isRunning: Bool
    let color: Color
    let highlight: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isRunning)) { timeline in
            PapayaGrinderFrame(
                time: CGFloat(timeline.date.timeIntervalSinceReferenceDate),
                isRunning: isRunning,
                color: color,
                highlight: highlight
            )
        }
    }
}

private struct PapayaGrinderFrame: View {
    let time: CGFloat
    let isRunning: Bool
    let color: Color
    let highlight: Color

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let chamberRect = CGRect(x: centerX - 45, y: 25, width: 90, height: 42)
            let chamber = RoundedRectangle(cornerRadius: 13).path(in: chamberRect)
            context.fill(chamber, with: .color(.black))
            context.stroke(chamber, with: .color(.white.opacity(0.16)), lineWidth: 1.5)

            var hopper = Path()
            hopper.move(to: CGPoint(x: centerX - 52, y: 1))
            hopper.addLine(to: CGPoint(x: centerX + 52, y: 1))
            hopper.addLine(to: CGPoint(x: centerX + 26, y: 29))
            hopper.addLine(to: CGPoint(x: centerX - 26, y: 29))
            hopper.closeSubpath()
            context.fill(
                hopper,
                with: .linearGradient(
                    Gradient(colors: [.black.opacity(0.76), .black]),
                    startPoint: CGPoint(x: centerX, y: 0),
                    endPoint: CGPoint(x: centerX, y: 30)
                )
            )
            context.stroke(hopper, with: .color(.white.opacity(0.14)), lineWidth: 1.5)

            drawPapayas(in: &context, size: size, centerX: centerX)
            drawRoller(
                in: &context,
                center: CGPoint(x: centerX - 19, y: 47),
                angle: time * 8.5,
                clockwise: true
            )
            drawRoller(
                in: &context,
                center: CGPoint(x: centerX + 19, y: 47),
                angle: time * 8.5,
                clockwise: false
            )
            drawCrushedFruit(in: &context, centerX: centerX)
            drawOutlet(in: &context, size: size, centerX: centerX)
        }
    }

    private func drawPapayas(
        in context: inout GraphicsContext,
        size: CGSize,
        centerX: CGFloat
    ) {
        if isRunning {
            for index in 0..<3 {
                let cycle = fraction(time * 0.42 + CGFloat(index) * 0.33)
                let entryOffset = CGFloat(index - 1) * 22
                let fallProgress = min(cycle / 0.5, 1)
                let gravityProgress = fallProgress * fallProgress
                let crushProgress = min(max((cycle - 0.5) / 0.2, 0), 1)
                let destructionProgress = min(max((cycle - 0.62) / 0.38, 0), 1)
                let x = centerX + entryOffset * (1 - gravityProgress)
                let y = -10 + gravityProgress * 47 + crushProgress * 10
                let compressionBulge = sin(crushProgress * .pi) * 0.72
                let widthScale = (1 + compressionBulge) * (1 - crushProgress * 0.74)
                let heightScale = 1 - crushProgress * 0.9
                let fadeIn = min(cycle / 0.035, 1)
                let opacity = fadeIn * pow(1 - crushProgress, 1.5)
                drawPapaya(
                    in: &context,
                    center: CGPoint(x: x, y: y),
                    width: 17 * widthScale,
                    height: 21 * heightScale,
                    opacity: Double(opacity)
                )

                if destructionProgress > 0 {
                    drawPapayaFragments(
                        in: &context,
                        center: CGPoint(x: centerX, y: 47),
                        progress: destructionProgress,
                        seed: index
                    )
                }
            }
        } else {
            drawPapaya(
                in: &context,
                center: CGPoint(x: centerX, y: 12),
                width: 18,
                height: 22,
                opacity: 1
            )
        }
    }

    private func drawPapaya(
        in context: inout GraphicsContext,
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        opacity: Double
    ) {
        let fruitRect = CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
        context.opacity = opacity
        context.fill(
            Path(ellipseIn: fruitRect),
            with: .linearGradient(
                Gradient(colors: [highlight, color]),
                startPoint: CGPoint(x: fruitRect.minX, y: fruitRect.minY),
                endPoint: CGPoint(x: fruitRect.maxX, y: fruitRect.maxY)
            )
        )
        let leafRect = CGRect(x: center.x - 2.5, y: fruitRect.minY - 2, width: 5, height: 4)
        context.fill(Path(ellipseIn: leafRect), with: .color(Color.green.opacity(0.8)))
        context.opacity = 1
    }

    private func drawPapayaFragments(
        in context: inout GraphicsContext,
        center: CGPoint,
        progress: CGFloat,
        seed: Int
    ) {
        for fragment in 0..<14 {
            let angle = CGFloat(fragment) * (.pi * 2 / 14) + CGFloat(seed) * 0.47
            let speed = 12 + CGFloat((fragment * 7 + seed * 3) % 13)
            let x = center.x + cos(angle) * speed * progress
            let y = center.y
                + sin(angle) * speed * progress
                + 28 * progress * progress
            let size = max(4.8 * (1 - progress) + CGFloat(fragment % 3), 1.2)
            let fragmentRect = CGRect(
                x: x - size / 2,
                y: y - size / 2,
                width: size * 1.35,
                height: size
            )
            context.opacity = Double((1 - progress) * 0.95)
            context.fill(
                RoundedRectangle(cornerRadius: size * 0.35).path(in: fragmentRect),
                with: .color(fragment.isMultiple(of: 3) ? highlight : color)
            )
        }

        for seedIndex in 0..<7 {
            let angle = CGFloat(seedIndex) * (.pi * 2 / 7) + CGFloat(seed) * 0.31
            let distance = (10 + CGFloat(seedIndex)) * progress
            let point = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance + 24 * progress * progress
            )
            let seedPath = Path(
                ellipseIn: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2.8)
            )
            context.fill(seedPath, with: .color(Color(red: 0.2, green: 0.07, blue: 0.03)))
        }
        context.opacity = 1
    }

    private func drawRoller(
        in context: inout GraphicsContext,
        center: CGPoint,
        angle: CGFloat,
        clockwise: Bool
    ) {
        let radius: CGFloat = 15
        let roller = Path(
            ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
        context.fill(roller, with: .color(Color.white.opacity(0.16)))
        context.stroke(roller, with: .color(Color.white.opacity(0.38)), lineWidth: 1.5)

        let direction: CGFloat = clockwise ? 1 : -1
        for spoke in 0..<6 {
            let spokeAngle = angle * direction + CGFloat(spoke) * .pi / 3
            var line = Path()
            line.move(to: center)
            line.addLine(
                to: CGPoint(
                    x: center.x + cos(spokeAngle) * (radius - 3),
                    y: center.y + sin(spokeAngle) * (radius - 3)
                )
            )
            context.stroke(line, with: .color(highlight.opacity(0.82)), lineWidth: 2.3)
        }
    }

    private func drawCrushedFruit(in context: inout GraphicsContext, centerX: CGFloat) {
        guard isRunning else { return }
        for piece in 0..<7 {
            let cycle = fraction(time * 2.8 + CGFloat(piece) * 0.14)
            let diameter = max(7 * (1 - cycle), 1.5)
            let x = centerX + sin(time * 5 + CGFloat(piece) * 1.7) * 7 * (1 - cycle)
            let y = 45 + cycle * 24
            let pulpRect = CGRect(
                x: x - diameter / 2,
                y: y - diameter / 2,
                width: diameter * 1.25,
                height: diameter
            )
            context.opacity = Double(1 - cycle * 0.55)
            context.fill(
                RoundedRectangle(cornerRadius: diameter * 0.35).path(in: pulpRect),
                with: .color(piece.isMultiple(of: 2) ? highlight : color)
            )
        }
        context.opacity = 1
    }

    private func drawOutlet(
        in context: inout GraphicsContext,
        size: CGSize,
        centerX: CGFloat
    ) {
        var nozzle = Path()
        nozzle.move(to: CGPoint(x: centerX - 13, y: 65))
        nozzle.addLine(to: CGPoint(x: centerX + 13, y: 65))
        nozzle.addLine(to: CGPoint(x: centerX + 5, y: 79))
        nozzle.addLine(to: CGPoint(x: centerX - 5, y: 79))
        nozzle.closeSubpath()
        context.fill(nozzle, with: .color(.black))

        guard isRunning else { return }
        let streamRect = CGRect(x: centerX - 3.5, y: 77, width: 7, height: size.height - 77 + 2)
        context.fill(
            RoundedRectangle(cornerRadius: 3).path(in: streamRect),
            with: .linearGradient(
                Gradient(colors: [highlight, color]),
                startPoint: CGPoint(x: streamRect.minX, y: streamRect.minY),
                endPoint: CGPoint(x: streamRect.maxX, y: streamRect.minY)
            )
        )
    }

    private func fraction(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }
}

private struct PapayaJuiceView: View {
    var progress: CGFloat
    let isPouring: Bool
    let color: Color
    let highlight: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            PapayaJuiceFrame(
                progress: progress,
                time: CGFloat(timeline.date.timeIntervalSinceReferenceDate),
                isPouring: isPouring,
                color: color,
                highlight: highlight
            )
        }
        .animation(.linear(duration: 1.0 / 30.0), value: progress)
    }
}

private struct PapayaJuiceFrame: View, Animatable {
    var progress: CGFloat
    let time: CGFloat
    let isPouring: Bool
    let color: Color
    let highlight: Color

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let fillProgress = min(max(progress, 0), 1)
            let baseSurfaceY = size.height * (1 - fillProgress)
            let motionScale: CGFloat = isPouring ? 1 : 0.18
            let slosh = sin(time * (isPouring ? 1.8 : 0.65)) * 2.4 * motionScale
            let ripple = sin(time * 3.1) * 1.1 * motionScale
            let impactPulse = isPouring ? 3.8 + abs(sin(time * 5.2)) * 2.2 : 0
            let leftY = baseSurfaceY + slosh
            let centerY = baseSurfaceY + impactPulse
            let rightY = baseSurfaceY - slosh
            let centerX = size.width / 2 + sin(time * 3.7) * 1.2

            var juice = Path()
            juice.move(to: CGPoint(x: 0, y: size.height))
            juice.addLine(to: CGPoint(x: 0, y: leftY))
            juice.addCurve(
                to: CGPoint(x: centerX, y: centerY),
                control1: CGPoint(x: size.width * 0.18, y: baseSurfaceY - ripple),
                control2: CGPoint(x: size.width * 0.38, y: centerY - 1.5)
            )
            juice.addCurve(
                to: CGPoint(x: size.width, y: rightY),
                control1: CGPoint(x: size.width * 0.62, y: centerY - 1.5),
                control2: CGPoint(x: size.width * 0.82, y: baseSurfaceY + ripple)
            )
            juice.addLine(to: CGPoint(x: size.width, y: size.height))
            juice.closeSubpath()
            context.fill(
                juice,
                with: .linearGradient(
                    Gradient(colors: [highlight, color]),
                    startPoint: CGPoint(x: 0, y: baseSurfaceY),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            var surface = Path()
            surface.move(to: CGPoint(x: 0, y: leftY))
            surface.addCurve(
                to: CGPoint(x: centerX, y: centerY),
                control1: CGPoint(x: size.width * 0.18, y: baseSurfaceY - ripple),
                control2: CGPoint(x: size.width * 0.38, y: centerY - 1.5)
            )
            surface.addCurve(
                to: CGPoint(x: size.width, y: rightY),
                control1: CGPoint(x: size.width * 0.62, y: centerY - 1.5),
                control2: CGPoint(x: size.width * 0.82, y: baseSurfaceY + ripple)
            )
            context.stroke(surface, with: .color(highlight.opacity(0.8)), lineWidth: 1.5)

            drawBubbles(
                in: &context,
                size: size,
                surfaceY: baseSurfaceY,
                fillProgress: fillProgress
            )

            if isPouring, baseSurfaceY > 3 {
                drawStream(in: &context, size: size, centerX: centerX, surfaceY: centerY)
                drawSplash(in: &context, size: size, centerX: centerX, surfaceY: centerY)
            }
        }
    }

    private func drawStream(
        in context: inout GraphicsContext,
        size: CGSize,
        centerX: CGFloat,
        surfaceY: CGFloat
    ) {
        let topHalfWidth: CGFloat = 3.2
        let bottomHalfWidth: CGFloat = 4.5
        var stream = Path()
        stream.move(to: CGPoint(x: centerX - topHalfWidth, y: -2))
        stream.addCurve(
            to: CGPoint(x: centerX - bottomHalfWidth, y: surfaceY + 2),
            control1: CGPoint(x: centerX - 1.8, y: surfaceY * 0.35),
            control2: CGPoint(x: centerX - 5, y: surfaceY * 0.72)
        )
        stream.addLine(to: CGPoint(x: centerX + bottomHalfWidth, y: surfaceY + 2))
        stream.addCurve(
            to: CGPoint(x: centerX + topHalfWidth, y: -2),
            control1: CGPoint(x: centerX + 5, y: surfaceY * 0.72),
            control2: CGPoint(x: centerX + 1.8, y: surfaceY * 0.35)
        )
        stream.closeSubpath()
        context.fill(
            stream,
            with: .linearGradient(
                Gradient(colors: [highlight, color]),
                startPoint: CGPoint(x: centerX - 5, y: 0),
                endPoint: CGPoint(x: centerX + 5, y: 0)
            )
        )

        var shine = Path()
        shine.move(to: CGPoint(x: centerX - 1.5, y: 1))
        shine.addLine(to: CGPoint(x: centerX - 2.4, y: max(surfaceY - 2, 1)))
        context.stroke(shine, with: .color(.white.opacity(0.24)), lineWidth: 1)
    }

    private func drawSplash(
        in context: inout GraphicsContext,
        size: CGSize,
        centerX: CGFloat,
        surfaceY: CGFloat
    ) {
        let baseCycle = fraction(time * 1.75)
        for index in 0..<4 {
            let cycle = fraction(baseCycle + CGFloat(index) * 0.21)
            let direction: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let spread = 7 + cycle * (9 + CGFloat(index) * 1.5)
            let arc = sin(cycle * .pi) * (8 + CGFloat(index % 2) * 3)
            let diameter = max(3.4 - cycle * 1.8, 1.4)
            let point = CGPoint(
                x: centerX + direction * spread,
                y: surfaceY - arc + cycle * 2
            )
            guard point.y > 0, point.y < size.height else { continue }
            let drop = Path(
                ellipseIn: CGRect(
                    x: point.x - diameter / 2,
                    y: point.y - diameter / 2,
                    width: diameter,
                    height: diameter * 1.25
                )
            )
            context.opacity = Double(1 - cycle)
            context.fill(drop, with: .color(highlight))
            context.opacity = 1
        }
    }

    private func drawBubbles(
        in context: inout GraphicsContext,
        size: CGSize,
        surfaceY: CGFloat,
        fillProgress: CGFloat
    ) {
        guard fillProgress > 0.05 else { return }
        let liquidHeight = size.height - surfaceY
        for index in 0..<5 {
            let speed = 0.11 + CGFloat(index) * 0.012
            let cycle = fraction(time * speed + CGFloat(index) * 0.19)
            let diameter = 3 + CGFloat(index % 3) * 1.3
            let travel = max(liquidHeight - diameter - 5, 0)
            let x = size.width * (0.17 + CGFloat(index) * 0.16)
                + sin(time * 0.8 + CGFloat(index)) * 2
            let y = size.height - diameter - cycle * travel
            let bubble = Path(
                ellipseIn: CGRect(
                    x: x - diameter / 2,
                    y: y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
            )
            context.opacity = Double((1 - cycle) * 0.32)
            context.fill(bubble, with: .color(.white))
            context.opacity = 1
        }
    }

    private func fraction(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }
}

private struct ChecklistRow: View {
    let item: ChecklistItem
    let isBeingDragged: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    let onToggle: () -> Void
    let onSave: (String) -> Void
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var draftText: String

    init(
        item: ChecklistItem,
        isBeingDragged: Bool,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping (CGPoint) -> Void,
        onToggle: @escaping () -> Void,
        onSave: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.isBeingDragged = isBeingDragged
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onToggle = onToggle
        self.onSave = onSave
        self.onDelete = onDelete
        _draftText = State(initialValue: item.text)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .named("checklistList"))
                        .onChanged { onDragChanged($0.location) }
                        .onEnded { onDragEnded($0.location) }
                )
                .help("Drag to reorder")

            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("Checklist item", text: $draftText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
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
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ChecklistItemFramePreferenceKey.self,
                    value: [item.id: proxy.frame(in: .named("checklistList"))]
                )
            }
        }
        .onHover { isHovering = $0 }
        .opacity(isBeingDragged ? 0.2 : 1)
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

private struct ChecklistItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct KanbanColumnView: View {
    let column: KanbanColumn
    let cards: [KanbanCard]
    let reorderNamespace: Namespace.ID
    let draggedCardID: UUID?
    let isDropTargeted: Bool
    let onDragChanged: (UUID, CGPoint) -> Void
    let onDragEnded: (UUID, CGPoint) -> Void
    let onSave: (UUID, String) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Text(column.rawValue)
                    .font(.app(.caption1, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer(minLength: 0)
                    Text("\(cards.count)")
                        .font(.app(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if cards.isEmpty {
                Text("Empty")
                    .font(.app(.caption2))
                    .foregroundStyle(.tertiary)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(cards) { card in
                            KanbanCardView(
                                card: card,
                                reorderNamespace: reorderNamespace,
                                isBeingDragged: draggedCardID == card.id,
                                onDragChanged: { onDragChanged(card.id, $0) },
                                onDragEnded: { onDragEnded(card.id, $0) },
                                onSave: { onSave(card.id, $0) },
                                onDelete: { onDelete(card.id) }
                            )
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                        }
                    }
                    .animation(
                        .spring(response: 0.42, dampingFraction: 0.76),
                        value: cards.map(\.id)
                    )
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

private struct KanbanCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct KanbanCardView: View {
    let card: KanbanCard
    let reorderNamespace: Namespace.ID
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
        reorderNamespace: Namespace.ID,
        isBeingDragged: Bool,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping (CGPoint) -> Void,
        onSave: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.card = card
        self.reorderNamespace = reorderNamespace
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
                    .multilineTextAlignment(.center)
                    .font(.app(.caption1))
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
                    .font(.app(.caption1))
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
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: KanbanCardFramePreferenceKey.self,
                    value: [card.id: proxy.frame(in: .named("kanbanBoard"))]
                )
            }
        }
        .onHover { isHovering = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .matchedGeometryEffect(id: card.id, in: reorderNamespace)
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
    let isBeingDragged: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    let onSave: (String) -> Void
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var draftText: String

    init(
        note: QuickNote,
        isBeingDragged: Bool,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping (CGPoint) -> Void,
        onSave: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.note = note
        self.isBeingDragged = isBeingDragged
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onSave = onSave
        self.onDelete = onDelete
        _draftText = State(initialValue: note.text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .named("notesList"))
                        .onChanged { onDragChanged($0.location) }
                        .onEnded { onDragEnded($0.location) }
                )
                .help("Drag to reorder")

            if isEditing {
                TextField("Note", text: $draftText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
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
                        .font(.app(.subheadline))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.app(.caption2))
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
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: NoteFramePreferenceKey.self,
                    value: [note.id: proxy.frame(in: .named("notesList"))]
                )
            }
        }
        .onHover { isHovering = $0 }
        .opacity(isBeingDragged ? 0.2 : 1)
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

private struct NoteFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
