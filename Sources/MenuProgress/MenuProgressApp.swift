import AppKit
import Carbon
import QuartzCore
import SwiftUI

@MainActor
private final class StatusProgressBarView: NSView {
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.addSublayer(trackLayer)
        trackLayer.addSublayer(fillLayer)

        trackLayer.backgroundColor = NSColor.black.cgColor
        trackLayer.borderColor = NSColor.white.cgColor
        trackLayer.borderWidth = 1.5
        trackLayer.cornerRadius = frameRect.height / 2
        trackLayer.masksToBounds = true
        fillLayer.backgroundColor = NSColor.clear.cgColor
        updateLayerGeometry()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        updateLayerGeometry()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func showIdle() {
        setStaticProgress(0, color: .clear)
    }

    func showRunning(progress: Double, remaining: TimeInterval) {
        let clampedProgress = min(max(progress, 0), 1)
        fillLayer.removeAllAnimations()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillLayer.backgroundColor = NSColor(
            srgbRed: 1,
            green: 0.48,
            blue: 0.18,
            alpha: 1
        ).cgColor
        fillLayer.transform = CATransform3DIdentity
        CATransaction.commit()

        let animation = CABasicAnimation(keyPath: "transform.scale.x")
        animation.fromValue = clampedProgress
        animation.toValue = 1
        animation.duration = max(remaining, 0.001)
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = true
        fillLayer.add(animation, forKey: "timerProgress")
    }

    func showPaused(progress: Double) {
        setStaticProgress(
            progress,
            color: NSColor(srgbRed: 1, green: 0.48, blue: 0.18, alpha: 1)
        )
    }

    func showComplete() {
        setStaticProgress(1, color: .systemGreen)
    }

    private func setStaticProgress(_ progress: Double, color: NSColor) {
        fillLayer.removeAllAnimations()
        let clampedProgress = min(max(progress, 0), 1)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillLayer.backgroundColor = color.cgColor
        fillLayer.transform = CATransform3DMakeScale(clampedProgress, 1, 1)
        CATransaction.commit()
    }

    private func updateLayerGeometry() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = bounds
        trackLayer.cornerRadius = bounds.height / 2
        fillLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        fillLayer.bounds = trackLayer.bounds
        fillLayer.position = CGPoint(x: 0, y: trackLayer.bounds.midY)
        CATransaction.commit()
    }
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
    private enum BarState: Equatable {
        case idle
        case running(endDate: Date)
        case paused(progress: Double)
        case complete
    }

    private let model = ProgressModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var timer: Timer?
    private var globalHotKey: EventHotKeyRef?
    private var globalHotKeyHandler: EventHandlerRef?
    private var lastRenderedBarState: BarState?
    private var lastAccessibilityText: String?
    private let statusProgressBar = StatusProgressBarView(
        frame: NSRect(x: 4, y: 0, width: 252, height: 18)
    )
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
        button.toolTip = "The Squeeze — ⌃⇧S"
        statusProgressBar.frame.origin.y = floor((button.bounds.height - statusProgressBar.frame.height) / 2)
        statusProgressBar.autoresizingMask = [.minYMargin, .maxYMargin]
        button.addSubview(statusProgressBar)

        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(rootView: ContentView(model: model))
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController

        installGlobalHotKey()

        updateStatusItem()
        let refreshTimer = Timer(
            timeInterval: 1.0 / 120.0,
            target: self,
            selector: #selector(refreshStatusItem),
            userInfo: nil,
            repeats: true
        )
        refreshTimer.tolerance = 0
        RunLoop.main.add(refreshTimer, forMode: .common)
        timer = refreshTimer
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

    @objc private func refreshStatusItem() {
        updateStatusItem()
    }

    private func updateStatusItem() {
        if model.tick(notifyObservers: false), model.isCompletionSoundEnabled {
            completionSound?.stop()
            completionSound?.play()
        }

        let barState: BarState
        if model.isShowingCompletion {
            barState = .complete
        } else if model.isPaused {
            barState = .paused(progress: model.progress)
        } else if let endDate = model.endDate {
            barState = .running(endDate: endDate)
        } else {
            barState = .idle
        }

        if barState != lastRenderedBarState {
            switch barState {
            case .idle:
                statusProgressBar.showIdle()
            case .running:
                statusProgressBar.showRunning(
                    progress: model.progress,
                    remaining: model.remaining
                )
            case .paused(let progress):
                statusProgressBar.showPaused(progress: progress)
            case .complete:
                statusProgressBar.showComplete()
            }
            lastRenderedBarState = barState
        }

        let accessibilityText = model.accessibilityText
        if accessibilityText != lastAccessibilityText {
            statusItem.button?.setAccessibilityLabel(accessibilityText)
            lastAccessibilityText = accessibilityText
        }
    }

}
