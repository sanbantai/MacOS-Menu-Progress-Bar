import AppKit
import SwiftUI

@main
struct MenuProgressApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = ProgressModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var timer: Timer?
    private var checklistWasComplete = false
    private var kanbanWasComplete = false
    private let completionSound = NSSound(
        contentsOfFile: "/System/Library/Sounds/Glass.aiff",
        byReference: true
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 260)
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: .leftMouseUp)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.toolTip = "Menu Progress"

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 430, height: 620)
        popover.contentViewController = NSHostingController(rootView: ContentView(model: model))

        checklistWasComplete = model.isChecklistComplete
        kanbanWasComplete = model.isKanbanComplete
        updateStatusItem()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItem()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.refreshCalendarIfAuthorized()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateStatusItem() {
        let timedSessionCompleted = model.tick()
        let checklistIsComplete = model.isChecklistComplete
        let kanbanIsComplete = model.isKanbanComplete
        if timedSessionCompleted
            || (checklistIsComplete && !checklistWasComplete)
            || (kanbanIsComplete && !kanbanWasComplete) {
            completionSound?.stop()
            completionSound?.play()
        }
        checklistWasComplete = checklistIsComplete
        kanbanWasComplete = kanbanIsComplete

        statusItem.button?.image = progressBarImage(
            progress: model.progress,
            active: model.hasSession,
            label: "There ain't no grave"
        )
        statusItem.button?.setAccessibilityLabel(model.accessibilityText)
    }

    private func progressBarImage(progress: Double, active: Bool, label: String) -> NSImage {
        let width: CGFloat = 252
        let height: CGFloat = 18
        let barHeight: CGFloat = 18
        let barRect = NSRect(x: 0, y: (height - barHeight) / 2, width: width, height: barHeight)
        let image = NSImage(size: NSSize(width: width, height: height))
        let clampedProgress = min(max(progress, 0), 1)
        let filledWidth = active ? width * clampedProgress : 0
        let filledRect = NSRect(x: 0, y: barRect.minY, width: filledWidth, height: barHeight)
        let racingGreen = NSColor(srgbRed: 0, green: 0.651, blue: 0.318, alpha: 1)

        image.lockFocus()
        let track = NSBezierPath(roundedRect: barRect, xRadius: 9, yRadius: 9)
        NSColor.black.setFill()
        track.fill()
        NSColor.white.setStroke()
        track.lineWidth = 1.5
        track.stroke()

        if active, filledWidth > 0 {
            NSGraphicsContext.current?.saveGraphicsState()
            track.addClip()
            NSColor.white.setFill()
            NSBezierPath(rect: filledRect).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let displayLabel = label.uppercased()
        let fontSize: CGFloat = displayLabel.hasSuffix("%") ? 13 : 11
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .black)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: racingGreen,
            .paragraphStyle: paragraphStyle
        ]
        let attributedLabel = NSAttributedString(string: displayLabel, attributes: baseAttributes)
        let textHeight = ceil(attributedLabel.size().height)
        let textRect = NSRect(
            x: 6,
            y: floor(barRect.midY - textHeight / 2),
            width: width - 12,
            height: textHeight
        )
        attributedLabel.draw(in: textRect)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
