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
    private var kanbanWasComplete = false
    private var timerCompletionIsVisible = false
    private let completionSound = NSSound(
        contentsOfFile: "/System/Library/Sounds/Glass.aiff",
        byReference: true
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        installBundledAppIcon()
        statusItem = NSStatusBar.system.statusItem(withLength: 260)
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: .leftMouseUp)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.toolTip = "The Squeeze"

        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(rootView: ContentView(model: model))
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController

        kanbanWasComplete = model.isKanbanComplete
        updateStatusItem()
        timer = Timer.scheduledTimer(
            timeInterval: 1.0 / 20.0,
            target: self,
            selector: #selector(refreshStatusItem),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = 1.0 / 100.0
    }

    private func installBundledAppIcon() {
        guard let iconURL = Bundle.main.url(forResource: "TheSqueezeIcon", withExtension: "png"),
              let icon = NSImage(contentsOf: iconURL) else { return }
        NSApp.applicationIconImage = icon
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func refreshStatusItem() {
        updateStatusItem()
    }

    private func updateStatusItem() {
        let timedSessionCompleted = model.tick(notifyObservers: popover.isShown)
        let kanbanIsComplete = model.isKanbanComplete
        if timedSessionCompleted
            || (kanbanIsComplete && !kanbanWasComplete) {
            completionSound?.stop()
            completionSound?.play()
        }
        if timedSessionCompleted {
            timerCompletionIsVisible = true
        } else if model.hasSession {
            timerCompletionIsVisible = false
        }
        kanbanWasComplete = kanbanIsComplete

        let currentTaskIsComplete = model.mode == .kanban && kanbanIsComplete
        let displayCompleted = timerCompletionIsVisible || currentTaskIsComplete

        statusItem.button?.image = autoreleasepool {
            progressBarImage(
                progress: displayCompleted ? 1 : model.progress,
                active: displayCompleted || model.hasSession,
                completed: displayCompleted
            )
        }
        statusItem.button?.setAccessibilityLabel(model.accessibilityText)
    }

    private func progressBarImage(
        progress: Double,
        active: Bool,
        completed: Bool
    ) -> NSImage {
        let width: CGFloat = 252
        let height: CGFloat = 18
        let barHeight: CGFloat = 18
        let barRect = NSRect(x: 0, y: (height - barHeight) / 2, width: width, height: barHeight)
        let image = NSImage(size: NSSize(width: width, height: height))
        let clampedProgress = min(max(progress, 0), 1)
        let filledWidth = active ? width * clampedProgress : 0
        let filledRect = NSRect(x: 0, y: barRect.minY, width: filledWidth, height: barHeight)
        let papayaOrange = NSColor(srgbRed: 1, green: 0.48, blue: 0.18, alpha: 1)
        let completionGreen = NSColor(srgbRed: 0.12, green: 0.72, blue: 0.32, alpha: 1)

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
            (completed ? completionGreen : papayaOrange).setFill()
            NSBezierPath(rect: filledRect).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }

        let phrases = ["Sanbantai", "Papaya", "Back To Work!"]
        let phraseDuration: TimeInterval = 4.8
        let elapsed = Date().timeIntervalSinceReferenceDate
        let phraseIndex = Int(elapsed / phraseDuration) % phrases.count
        let localPhase = CGFloat(elapsed.truncatingRemainder(dividingBy: phraseDuration) / phraseDuration)
        let revealLinear = min(localPhase / 0.58, 1)
        let reveal = revealLinear * revealLinear * (3 - 2 * revealLinear)
        let fadeLinear = min(max((localPhase - 0.82) / 0.18, 0), 1)
        let opacity = 1 - fadeLinear * fadeLinear * (3 - 2 * fadeLinear)
        let font = NSFont(name: "Snell Roundhand", size: 14)
            ?? NSFont(name: "Apple Chancery", size: 13)
            ?? NSFont.systemFont(ofSize: 13, weight: .medium)
        let glow = NSShadow()
        glow.shadowColor = NSColor.white.withAlphaComponent(0.16)
        glow.shadowBlurRadius = 1.5
        glow.shadowOffset = .zero
        let handwriting = NSAttributedString(
            string: phrases[phraseIndex],
            attributes: [
                .font: font,
                .foregroundColor: NSColor.white.withAlphaComponent(opacity * 0.92),
                .shadow: glow
            ]
        )
        let handwritingSize = handwriting.size()
        let handwritingOrigin = NSPoint(
            x: floor(barRect.midX - handwritingSize.width / 2),
            y: floor(barRect.midY - handwritingSize.height / 2)
        )
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(
            rect: NSRect(
                x: handwritingOrigin.x,
                y: handwritingOrigin.y - 2,
                width: handwritingSize.width * reveal,
                height: handwritingSize.height + 4
            )
        ).addClip()
        handwriting.draw(at: handwritingOrigin)
        NSGraphicsContext.current?.restoreGraphicsState()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
