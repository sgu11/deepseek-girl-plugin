import AppKit

enum WhaleAction {
    case pressed
    case released
    case clickWhale
    case clickBubble
    case dragEnded(NSPoint)
    case showMenu(NSPoint)
}

private final class PetImageView: NSImageView {
    var mirrored = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard mirrored else { super.draw(dirtyRect); return }
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        super.draw(bounds)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class WhalePanel: NSPanel {
    static let size = NSSize(width: 255, height: 228)
    private static let restingImageFrame = NSRect(x: 70, y: 0, width: 180, height: 180)
    // Alpha bounds of the bundled 610×610 sprite: x=45...610, y=10...610.
    // Preserve its original scale while ignoring transparent image padding.
    static func attachmentBounds(mirrored: Bool) -> NSRect {
        NSRect(x: mirrored ? 70 : 70 + 180 * 45 / 610,
               y: 0, width: 180 * 565 / 610, height: 180 * 600 / 610)
    }
    private let petClipView: NSView
    private let hostMask = CALayer()
    private let bubble: NSView
    private let bubbleLabel: NSTextField
    private let imageView: PetImageView
    private var gesture: PetGesture?
    private(set) var isMirrored = false
    var onAction: ((WhaleAction) -> Void)?
    var isDragging: Bool { gesture?.moved == true }
    // Follow the pet's position, never its press/release deformation.
    var bubbleAnchorFrame: NSRect {
        Self.restingImageFrame.offsetBy(dx: frame.minX, dy: frame.minY)
    }

    override var canBecomeKey: Bool { true }

    init(assetURL: URL) {
        let root = NSView(frame: NSRect(origin: .zero, size: Self.size))
        root.wantsLayer = true

        petClipView = NSView(frame: root.bounds)
        petClipView.wantsLayer = true
        root.addSubview(petClipView)
        hostMask.backgroundColor = NSColor.white.cgColor
        hostMask.cornerCurve = .continuous
        hostMask.masksToBounds = true

        imageView = PetImageView(frame: Self.restingImageFrame)
        imageView.image = NSImage(contentsOf: assetURL)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        petClipView.addSubview(imageView)

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

        bubbleLabel = NSTextField(labelWithString: "이 통통한 고래를 닦달한다고?")
        bubbleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        bubbleLabel.textColor = NSColor(calibratedRed: 0.12, green: 0.19, blue: 0.34, alpha: 1)
        bubbleLabel.alignment = .center
        bubbleLabel.usesSingleLineMode = false
        bubbleLabel.maximumNumberOfLines = 2
        bubbleLabel.lineBreakMode = .byWordWrapping
        let textHeight: CGFloat = 42
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
                petClipView.layer?.mask = nil
                setFrameOrigin(WindowPlacement.clamped(proposed, size: frame.size, to: visible,
                    attachment: Self.attachmentBounds(mirrored: isMirrored)))
                placeBubble()
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
        if petClipView.layer?.mask != nil {
            let maskPoint = NSPoint(x: point.x - hostMask.frame.minX, y: point.y - hostMask.frame.minY)
            let shape = NSBezierPath(roundedRect: hostMask.bounds,
                                    xRadius: hostMask.cornerRadius, yRadius: hostMask.cornerRadius)
            guard shape.contains(maskPoint) else { return false }
        }
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
        imageView.mirrored = mirrored
    }

    func updateAttachment(host: NSRect?, anchor: SnapAnchor, cornerRadius: CGFloat) {
        guard let host, !anchor.isEmpty, !isDragging else {
            petClipView.layer?.mask = nil
            placeBubble()
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hostMask.frame = host.offsetBy(dx: -frame.minX, dy: -frame.minY)
        hostMask.cornerRadius = min(cornerRadius, min(host.width, host.height) / 2)
        petClipView.layer?.mask = hostMask
        CATransaction.commit()
        placeBubble()
    }

    private func placeBubble() {
        let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
        // Transparent panel margins may extend offscreen when the visible sprite
        // touches the display edge. Keep the entire bubble inside both bounds.
        let available = frame.intersection(visible)
        let width = min(221, available.width)
        bubble.setFrameSize(NSSize(width: width, height: 50))
        let textWidth = max(0, width - 20)
        let measured = (bubbleLabel.stringValue as NSString).boundingRect(
            with: NSSize(width: textWidth, height: 42),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: bubbleLabel.font!])
        let textHeight = min(42, ceil(measured.height) + 2)
        bubbleLabel.frame = NSRect(x: 10, y: floor((50 - textHeight) / 2),
                                  width: textWidth, height: textHeight)
        let preferred = NSPoint(x: frame.minX + 250 - width, y: frame.minY + 171)
        var origin = preferred
        if origin.y + bubble.frame.height > visible.maxY {
            origin.y = min(frame.minY + 120, visible.maxY - bubble.frame.height - 8)
        }
        origin = WindowPlacement.clamped(origin, size: bubble.frame.size, to: available)
        bubble.setFrameOrigin(NSPoint(x: origin.x - frame.minX, y: origin.y - frame.minY))
    }

    func setBubble(_ text: String?) {
        bubble.isHidden = text == nil
        if let text { bubbleLabel.stringValue = text }
        placeBubble()
    }

    func setPressed(_ pressed: Bool) {
        let destination = pressed
            ? NSRect(x: 64, y: 0, width: 192, height: 168)
            : Self.restingImageFrame
        NSAnimationContext.runAnimationGroup { context in
            context.duration = pressed ? 0.1 : 0.23
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            imageView.animator().frame = destination
        }
    }
}
