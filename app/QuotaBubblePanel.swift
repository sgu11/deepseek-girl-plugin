import AppKit

/// The original speech bubble's expanded usage state, rendered in its place.
final class QuotaBubblePanel: NSPanel {
    private enum Palette {
        static let paper = NSColor(calibratedRed: 0.971, green: 0.979, blue: 0.997, alpha: 0.98)
        static let ink = NSColor(calibratedRed: 0.12, green: 0.19, blue: 0.34, alpha: 1)
        static let muted = NSColor(calibratedRed: 0.37, green: 0.44, blue: 0.58, alpha: 1)
        static let border = NSColor(calibratedRed: 0.25, green: 0.36, blue: 0.59, alpha: 0.9)
        static let track = NSColor(calibratedRed: 0.87, green: 0.90, blue: 0.96, alpha: 1)
        static let fill = NSColor(calibratedRed: 0.35, green: 0.49, blue: 0.74, alpha: 1)
    }

    private static let bubbleWidth: CGFloat = 221
    private let root: NSView
    private var renderKey = ""
    var onDismiss: (() -> Void)?

    override var canBecomeKey: Bool { true }

    init() {
        root = NSView(frame: NSRect(x: 0, y: 0, width: Self.bubbleWidth, height: 128))
        root.wantsLayer = true
        super.init(
            contentRect: root.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        contentView = root
        root.layer?.backgroundColor = Palette.paper.cgColor
        root.layer?.borderColor = Palette.border.cgColor
        root.layer?.borderWidth = 1.5
        root.layer?.cornerRadius = 15
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            onDismiss?()
        } else {
            super.sendEvent(event)
        }
    }

    func show(snapshot: QuotaSnapshot?, isRefreshing: Bool, message: String?,
              above whale: NSRect, in visible: NSRect, now: Date) {
        render(snapshot: snapshot, isRefreshing: isRefreshing, message: message, now: now)
        position(above: whale, in: visible)
        orderFrontRegardless()
    }

    func updateIfVisible(snapshot: QuotaSnapshot?, isRefreshing: Bool, message: String?,
                         above whale: NSRect, in visible: NSRect, now: Date) {
        guard isVisible else { return }
        render(snapshot: snapshot, isRefreshing: isRefreshing, message: message, now: now)
        position(above: whale, in: visible)
    }

    private func position(above whale: NSRect, in visible: NSRect) {
        setFrameOrigin(QuotaBubblePlacement.origin(
            bubbleSize: frame.size, above: whale, in: visible
        ))
    }

    private func render(snapshot: QuotaSnapshot?, isRefreshing: Bool,
                        message: String?, now: Date) {
        let minute = Int(now.timeIntervalSince1970 / 60)
        let key = "\(String(describing: snapshot))|\(isRefreshing)|\(minute)|\(message ?? "")"
        guard key != renderKey else { return }
        renderKey = key

        let windows = snapshot?.codexWindows(now: now) ?? []
        let height: CGFloat = windows.isEmpty ? 122 : 88 + CGFloat(windows.count) * 60
        setContentSize(NSSize(width: Self.bubbleWidth, height: height))
        root.subviews.forEach { $0.removeFromSuperview() }

        root.addSubview(makeLabel(message ?? "✦ Codex 잔여 한도", size: 16, weight: .semibold,
                                  color: Palette.ink,
                                  frame: NSRect(x: 12, y: height - 63,
                                                width: Self.bubbleWidth - 24, height: 43),
                                  alignment: .center, lines: 2))

        if windows.isEmpty {
            let status = snapshot?.statusText(now: now, isRefreshing: isRefreshing)
                ?? (isRefreshing ? "Codex 사용량 확인 중…" : "한도를 확인할 수 없습니다")
            root.addSubview(makeLabel(status, size: 11, weight: .medium,
                                      color: Palette.muted,
                                      frame: NSRect(x: 16, y: 14,
                                                    width: Self.bubbleWidth - 32, height: 34),
                                      alignment: .center, lines: 2))
        } else {
            for (index, window) in windows.enumerated() {
                addRow(window, index: index, height: height, now: now)
            }
        }
    }

    private func addRow(_ window: QuotaWindow, index: Int, height: CGFloat, now: Date) {
        let labelY = height - 97 - CGFloat(index) * 60
        root.addSubview(makeLabel("Codex · \(window.label)", size: 11, weight: .medium,
                                  color: Palette.ink,
                                  frame: NSRect(x: 16, y: labelY, width: 94, height: 18)))
        root.addSubview(makeLabel("\(window.remainingText) 남음", size: 12, weight: .semibold,
                                  color: Palette.ink,
                                  frame: NSRect(x: 105, y: labelY - 1,
                                                width: Self.bubbleWidth - 121, height: 20),
                                  alignment: .right))

        let trackWidth = Self.bubbleWidth - 32
        let track = NSView(frame: NSRect(x: 16, y: labelY - 12,
                                        width: trackWidth, height: 5))
        track.wantsLayer = true
        track.layer?.backgroundColor = Palette.track.cgColor
        track.layer?.cornerRadius = 2.5
        root.addSubview(track)
        let fillWidth = trackWidth * CGFloat(window.remainingPercent / 100)
        if fillWidth > 0 {
            let fill = NSView(frame: NSRect(x: 0, y: 0, width: fillWidth, height: 5))
            fill.wantsLayer = true
            fill.layer?.backgroundColor = Palette.fill.cgColor
            fill.layer?.cornerRadius = 2.5
            track.addSubview(fill)
        }

        let reset = window.resetText(now: now) ?? "재설정 시간 정보 없음"
        root.addSubview(makeLabel(reset, size: 10.5, weight: .regular,
                                  color: Palette.muted,
                                  frame: NSRect(x: 16, y: labelY - 35,
                                                width: trackWidth, height: 16)))
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight,
                           color: NSColor, frame: NSRect,
                           alignment: NSTextAlignment = .left, lines: Int = 1) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.frame = frame
        field.font = NSFont.systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = alignment
        field.usesSingleLineMode = lines == 1
        field.maximumNumberOfLines = lines
        field.lineBreakMode = lines == 1 ? .byTruncatingTail : .byWordWrapping
        if lines > 1 {
            let measured = (text as NSString).boundingRect(
                with: frame.size, options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: field.font!])
            let height = min(frame.height, ceil(measured.height) + 2)
            field.frame = NSRect(x: frame.minX, y: frame.minY + floor((frame.height - height) / 2),
                                 width: frame.width, height: height)
        }
        return field
    }
}
