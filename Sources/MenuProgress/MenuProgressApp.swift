import AppKit
import Carbon
import SwiftUI

extension Notification.Name {
    static let selectToolShortcut = Notification.Name("selectToolShortcut")
}

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
    private var globalHotKey: EventHotKeyRef?
    private var globalHotKeyHandler: EventHandlerRef?
    private var localKeyMonitor: Any?
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
        button.toolTip = "The Squeeze — ⌃⇧S"

        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(rootView: ContentView(model: model))
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController

        installGlobalHotKey()
        installToolShortcutMonitor()

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
        if let globalHotKey {
            UnregisterEventHotKey(globalHotKey)
        }
        if let globalHotKeyHandler {
            RemoveEventHandler(globalHotKeyHandler)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
        updateStatusItem()
    }

    private func installGlobalHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let appDelegate = Unmanaged<AppDelegate>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                appDelegate.togglePopover()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &globalHotKeyHandler
        )

        let hotKeyID = EventHotKeyID(signature: 0x53515A45, id: 1) // "SQZE"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(controlKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &globalHotKey
        )
    }

    private func installToolShortcutMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let relevantFlags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard relevantFlags == .control,
                  let key = event.charactersIgnoringModifiers,
                  let shortcut = Int(key),
                  (1...3).contains(shortcut) else { return event }

            NotificationCenter.default.post(
                name: .selectToolShortcut,
                object: nil,
                userInfo: ["shortcut": shortcut]
            )
            return nil
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

        let timerHasProgress = model.mode == .timer && model.hasSession
        let displayTimerProgress = timerCompletionIsVisible || timerHasProgress
        let displayedProgress = timerCompletionIsVisible ? 1 : model.progress

        statusItem.button?.image = autoreleasepool {
            progressBarImage(
                progress: displayedProgress,
                active: displayTimerProgress
            )
        }
        statusItem.button?.setAccessibilityLabel(
            timerHasProgress ? model.accessibilityText : "The Squeeze, ready"
        )
    }

    private func progressBarImage(
        progress: Double,
        active: Bool
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

        image.lockFocus()
        let track = NSBezierPath(roundedRect: barRect, xRadius: 9, yRadius: 9)
        NSColor.black.setFill()
        track.fill()
        NSColor.white.setStroke()
        track.lineWidth = 1.5
        track.stroke()

        let elapsed = Date().timeIntervalSinceReferenceDate
        if !active {
            drawBarberPole(
                in: barRect,
                elapsed: elapsed,
                baseColor: .white,
                firstBandColor: papayaOrange,
                secondBandColor: .black
            )
        }

        if active, filledWidth > 0 {
            NSGraphicsContext.current?.saveGraphicsState()
            track.addClip()
            papayaOrange.setFill()
            NSBezierPath(rect: filledRect).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }

        NSColor.white.setStroke()
        track.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func drawBarberPole(
        in barRect: NSRect,
        elapsed: TimeInterval,
        baseColor: NSColor,
        firstBandColor: NSColor,
        secondBandColor: NSColor
    ) {
        let track = NSBezierPath(roundedRect: barRect, xRadius: 9, yRadius: 9)
        NSGraphicsContext.current?.saveGraphicsState()
        track.addClip()

        baseColor.setFill()
        NSBezierPath(rect: barRect).fill()

        let bandWidth: CGFloat = 18
        let cycleWidth = bandWidth * 4
        let slant = barRect.height
        let phase = CGFloat(elapsed * 30).truncatingRemainder(dividingBy: cycleWidth)
        var cycleStart = barRect.minX - cycleWidth - slant + phase
        while cycleStart < barRect.maxX + slant {
            drawBarberBand(
                from: cycleStart,
                width: bandWidth,
                slant: slant,
                in: barRect,
                color: firstBandColor
            )
            drawBarberBand(
                from: cycleStart + bandWidth * 2,
                width: bandWidth,
                slant: slant,
                in: barRect,
                color: secondBandColor
            )
            cycleStart += cycleWidth
        }

        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawBarberBand(
        from x: CGFloat,
        width: CGFloat,
        slant: CGFloat,
        in rect: NSRect,
        color: NSColor
    ) {
        let band = NSBezierPath()
        band.move(to: NSPoint(x: x, y: rect.minY))
        band.line(to: NSPoint(x: x + width, y: rect.minY))
        band.line(to: NSPoint(x: x + width + slant, y: rect.maxY))
        band.line(to: NSPoint(x: x + slant, y: rect.maxY))
        band.close()
        color.setFill()
        band.fill()
    }
}
