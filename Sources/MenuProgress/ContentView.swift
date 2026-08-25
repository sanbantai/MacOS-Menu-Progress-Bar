import AppKit
import SwiftUI

private extension Font {
    static func app(
        _ textStyle: NSFont.TextStyle,
        weight: Font.Weight = .regular
    ) -> Font {
        let pointSize = NSFont.preferredFont(forTextStyle: textStyle).pointSize * 1.25
        return .system(size: pointSize, weight: weight)
    }
}

struct ContentView: View {
    private let contentWidth: CGFloat = 464

    private enum DurationField: Hashable {
        case hours
        case minutes
        case seconds
    }

    @ObservedObject var model: ProgressModel
    @State private var customHours = ""
    @State private var customMinutes = ""
    @State private var customSeconds = ""
    @FocusState private var focusedDurationField: DurationField?

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("The Squeeze")
                .font(.app(.headline, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .onTapGesture(perform: dismissDurationFocus)

            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .onTapGesture(perform: dismissDurationFocus)

            timerControls

            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .onTapGesture(perform: dismissDurationFocus)

            footer
        }
        .frame(width: contentWidth, alignment: .center)
        .padding(18)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissDurationFocus)
        }
    }

    private var timerControls: some View {
        VStack(alignment: .center, spacing: 14) {
            TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: !model.isRunning)) { _ in
                VStack(alignment: .center, spacing: 10) {
                    Text(timerStatusText)
                        .font(.app(.title3, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(model.isShowingCompletion ? Color.green : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .center)

                    TimerProgressBar(
                        progress: model.displayProgress,
                        fillColor: model.isShowingCompletion ? .green : papayaOrange,
                        showsFill: model.hasSession || model.isShowingCompletion
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onTapGesture(perform: dismissDurationFocus)

            Grid(horizontalSpacing: 8, verticalSpacing: 14) {
                GridRow(alignment: .bottom) {
                    durationField("Hours", text: $customHours, field: .hours)
                    durationSeparator
                    durationField("Minutes", text: $customMinutes, field: .minutes)
                    durationSeparator
                    durationField("Seconds", text: $customSeconds, field: .seconds)
                }

                if !model.hasSession {
                    GridRow {
                        gridPlaceholder
                        gridPlaceholder
                        startTimerButton
                        gridPlaceholder
                        gridPlaceholder
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: .center)
            .disabled(model.hasSession)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissDurationFocus)
            }

            if model.hasSession {
                HStack(spacing: 12) {
                    Button(model.isPaused ? "Resume" : "Pause") {
                        dismissDurationFocus()
                        model.togglePause()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(papayaOrange)
                    .foregroundStyle(.black)

                    Button("Stop", role: .destructive) {
                        dismissDurationFocus()
                        model.stop()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(width: contentWidth, alignment: .center)
    }

    private var timerStatusText: String {
        if model.isShowingCompletion {
            return "Complete"
        }
        if model.hasSession {
            return model.isPaused
                ? "Paused — \(model.shortRemaining) remaining"
                : model.shortRemaining
        }
        return "∞"
    }

    private var footer: some View {
        ZStack {
            Text("Data stays on this Mac")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .onTapGesture(perform: dismissDurationFocus)

            HStack {
                Button {
                    dismissDurationFocus()
                    model.toggleCompletionSound()
                } label: {
                    Image(systemName: model.isCompletionSoundEnabled ? "bell.fill" : "bell.slash.fill")
                        .foregroundStyle(model.isCompletionSoundEnabled ? Color.secondary : Color.red)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .focusable(false)
                .help(model.isCompletionSoundEnabled ? "Completion sound on" : "Completion sound off")
                .accessibilityLabel(
                    model.isCompletionSoundEnabled ? "Turn completion sound off" : "Turn completion sound on"
                )

                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .font(.app(.caption1))
        .frame(width: contentWidth)
    }

    private var papayaOrange: Color {
        Color(red: 1, green: 0.48, blue: 0.18)
    }

    private var durationSeparator: some View {
        Text(":")
            .font(.app(.title3, weight: .semibold))
            .padding(.bottom, 5)
            .onTapGesture(perform: dismissDurationFocus)
    }

    private var gridPlaceholder: some View {
        Color.clear
            .frame(height: 0)
            .gridCellUnsizedAxes(.horizontal)
    }

    private var startTimerButton: some View {
        Button {
            startCustomTimer()
        } label: {
            Text("Start Timer")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .frame(width: 93.6)
        .offset(x: 0.8)
        .tint(papayaOrange)
        .foregroundStyle(.black)
        .disabled(parsedDurationSeconds == nil)
    }

    private func durationField(
        _ label: String,
        text: Binding<String>,
        field: DurationField
    ) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.app(.caption2))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .center)
                .onTapGesture(perform: dismissDurationFocus)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(width: 92)
                .focused($focusedDurationField, equals: field)
                .onSubmit(startCustomTimer)
        }
        .frame(width: 92, alignment: .center)
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
        guard !model.hasSession, let seconds = parsedDurationSeconds else { return }
        dismissDurationFocus()
        model.startTimer(seconds: seconds)
    }

    private func dismissDurationFocus() {
        focusedDurationField = nil
    }
}

private struct TimerProgressBar: View {
    let progress: Double
    let fillColor: Color
    let showsFill: Bool

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black)

                if showsFill, clampedProgress > 0 {
                    Rectangle()
                        .fill(fillColor)
                        .frame(width: proxy.size.width * clampedProgress)
                        .clipShape(Capsule())
                }
            }
            .overlay {
                Capsule()
                    .stroke(.white, lineWidth: 1.5)
            }
        }
        .frame(height: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer progress")
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100)) percent")
    }
}
