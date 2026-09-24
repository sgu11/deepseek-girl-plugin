import AppKit

enum WhaleAction {
    case pressed
    case released
    case clickWhale
    case clickBubble
    case dragEnded(NSPoint)
    case showMenu(NSPoint)
}

final class WhalePanel: NSPanel {
    static let size = NSSize(width: 255, height: 228)
    private let bubble: NSView
    private let bubbleLabel: NSTextField
    private let imageView: NSImageView
    private var gesture: PetGesture?
    private var isMirrored = false
    var onAction: ((WhaleAction) -> Void)?
    var isDragging: Bool { gesture?.moved == true }
    var visualFrame: NSRect {
        NSRect(
            x: frame.minX + imageView.frame.minX,
            y: frame.minY + imageView.frame.minY,
            width: imageView.frame.width,
            height: imageView.frame.height
        )
    }

    override var canBecomeKey: Bool { true }

    init(assetURL: URL) {
        let root = NSView(frame: NSRect(origin: .zero, size: Self.size))
        root.wantsLayer = true

        imageView = NSImageView(frame: NSRect(x: 70, y: 0, width: 180, height: 180))
        imageView.image = NSImage(contentsOf: assetURL)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        root.addSubview(imageView)

        let bubbleFrame = NSRect(x: 29, y: 171, width: 221, height: 50)
        bubble = NSView(frame: bubbleFrame)
        bubble.wantsLayer = true
        bubble.layer?.backgroundColor = NSColor(
            calibratedRed: 0.971, green: 0.979, blue: 0.997, alpha: 0.98
        ).cgColor
        bubble.layer?.borderColor = NSColor(
            calibratedRed: 0.25, green: 0.36, blue: 0.59, alpha: 0.9
        ).cgColor
        bubble.layer?.borderWidth = 1.5
        bubble.layer?.cornerRadius = 15
        bubble.isHidden = true
        root.addSubview(bubble)

        bubbleLabel = NSTextField(labelWithString: "压力一只蓝色大肥鱼？")
        bubbleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        bubbleLabel.textColor = NSColor(calibratedRed: 0.12, green: 0.19, blue: 0.34, alpha: 1)
        bubbleLabel.alignment = .center
        bubbleLabel.usesSingleLineMode = true
        bubbleLabel.lineBreakMode = .byTruncatingTail
        let textHeight = bubbleLabel.fittingSize.height
        bubbleLabel.frame = NSRect(
            x: 10,
            y: floor((bubbleFrame.height - textHeight) / 2),
            width: bubbleFrame.width - 20,
            height: textHeight
        )
        bubble.addSubview(bubbleLabel)

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isMovable = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        contentView = root
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            let point = event.locationInWindow
            let target: PetGesture.Target
            if !bubble.isHidden && bubble.frame.contains(point) {
                target = .bubble
            } else if isWhaleHit(point) {
                target = .whale
            } else {
                super.sendEvent(event)
                return
            }
            gesture = PetGesture(
                target: target, mouseDown: NSEvent.mouseLocation, panelOrigin: frame.origin
            )
            if target == .whale { onAction?(.pressed) }
        case .leftMouseDragged:
            guard var active = gesture else { super.sendEvent(event); return }
            if let proposed = active.origin(at: NSEvent.mouseLocation) {
                let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
                setFrameOrigin(WindowPlacement.clamped(proposed, size: frame.size, to: visible))
            }
            gesture = active
        case .leftMouseUp:
            guard let active = gesture else { super.sendEvent(event); return }
            gesture = nil
            if active.target == .whale { onAction?(.released) }
            if active.moved {
                onAction?(.dragEnded(frame.origin))
            } else {
                onAction?(active.target == .whale ? .clickWhale : .clickBubble)
            }
        case .rightMouseDown:
            if isWhaleHit(event.locationInWindow) {
                onAction?(.showMenu(NSEvent.mouseLocation))
            } else {
                super.sendEvent(event)
            }
        default:
            super.sendEvent(event)
        }
    }

    func cancelAbandonedDragIfNeeded() {
        guard let active = gesture, NSEvent.pressedMouseButtons & 1 == 0 else { return }
        gesture = nil
        if active.moved { setFrameOrigin(active.panelOrigin) }
        if active.target == .whale { onAction?(.released) }
    }

    private func isWhaleHit(_ point: NSPoint) -> Bool {
        guard imageView.frame.contains(point), let image = imageView.image else { return false }
        let testPoint = isMirrored
            ? NSPoint(x: imageView.frame.minX + imageView.frame.maxX - point.x, y: point.y)
            : point
        return image.hitTest(
            NSRect(x: testPoint.x, y: testPoint.y, width: 1, height: 1),
            withDestinationRect: imageView.frame,
            context: nil,
            hints: nil,
            flipped: false
        )
    }

    func setMirrored(_ mirrored: Bool) {
        guard isMirrored != mirrored else { return }
        isMirrored = mirrored
        imageView.layer?.setAffineTransform(CGAffineTransform(scaleX: mirrored ? -1 : 1, y: 1))
    }

    func setBubble(_ text: String?) {
        bubble.isHidden = text == nil
        if let text { bubbleLabel.stringValue = text }
    }

    func setPressed(_ pressed: Bool) {
        let destination = pressed
            ? NSRect(x: 64, y: 0, width: 192, height: 168)
            : NSRect(x: 70, y: 0, width: 180, height: 180)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = pressed ? 0.1 : 0.23
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            imageView.animator().frame = destination
        }
    }
}
