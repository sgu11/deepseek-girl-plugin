import AppKit
import Darwin
import Foundation

final class Companion: NSObject, NSApplicationDelegate {
    private let completionText = "压力一只蓝色大肥鱼？"
    private struct StoredPosition: Codable {
        let x: Double
        let y: Double
        let anchor: SnapAnchor?
    }

    private let dataURL: URL
    private let assetURL: URL
    private let events: CompletionEventStore
    private let positionURL: URL
    private let settingsStore: PetSettingsStore
    private let quota: QuotaMonitor
    private let sounds: PetSoundPlayer
    private var lockDescriptor: Int32 = -1
    private var panel: WhalePanel!
    private var quotaBubble: QuotaBubblePanel!
    private var settings = PetSettings()
    private var sequence = BubbleSequence()
    private var systemBubbleUntil = Date.distantPast
    private var manualBubbleUntil = Date.distantPast
    private var manualBubbleText: String?
    private var quotaBubbleUntil = Date.distantPast
    private var lastWindowCheck = Date.distantPast
    private var lastHost: NSRect?
    private var offset = NSPoint.zero
    private var anchor = SnapAnchor(horizontal: nil, vertical: nil)

    init(dataURL: URL, assetURL: URL) {
        self.dataURL = dataURL
        self.assetURL = assetURL
        events = CompletionEventStore(dataURL: dataURL)
        positionURL = dataURL.appendingPathComponent("position.json")
        settingsStore = PetSettingsStore(dataURL: dataURL)
        quota = QuotaMonitor(
            dataURL: dataURL,
            pluginRoot: assetURL.deletingLastPathComponent().deletingLastPathComponent()
        )
        sounds = PetSoundPlayer(assetURL: assetURL)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireSingletonLock() else { NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.accessory)
        loadPosition()
        settings = settingsStore.load()
        panel = WhalePanel(assetURL: assetURL)
        panel.onAction = { [weak self] action in self?.handle(action) }
        quotaBubble = QuotaBubblePanel()
        quotaBubble.onDismiss = { [weak self] in
            guard let self else { return }
            self.quotaBubbleUntil = .distantPast
            self.quotaBubble.orderOut(nil)
            self.updateBubble()
        }
        tick()
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func acquireSingletonLock() -> Bool {
        try? FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: dataURL.path
        )
        let path = dataURL.appendingPathComponent("companion.lock").path
        lockDescriptor = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        return lockDescriptor >= 0 && flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0
    }

    private func loadPosition() {
        guard let data = try? Data(contentsOf: positionURL),
              let stored = try? JSONDecoder().decode(StoredPosition.self, from: data),
              stored.x.isFinite, stored.y.isFinite,
              abs(stored.x) < 10_000, abs(stored.y) < 10_000 else { return }
        offset = NSPoint(x: stored.x, y: stored.y)
        anchor = stored.anchor ?? SnapAnchor(horizontal: nil, vertical: nil)
    }

    private func savePosition() {
        let stored = StoredPosition(x: offset.x, y: offset.y, anchor: anchor.isEmpty ? nil : anchor)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: positionURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: positionURL.path
        )
    }

    private func handle(_ action: WhaleAction) {
        switch action {
        case .pressed:
            panel.setPressed(true)
            sounds.playPress()
        case .released:
            panel.setPressed(false)
            sounds.playRelease()
        case .clickWhale:
            if settings.bubblesEnabled && Date() >= systemBubbleUntil {
                manualBubbleText = sequence.tapWhale(messages: settings.clickMessages)
                manualBubbleUntil = Date().addingTimeInterval(5)
            }
            showQuotaBubble()
        case .clickBubble:
            if Date() < systemBubbleUntil {
                systemBubbleUntil = .distantPast
            } else {
                manualBubbleText = sequence.tapBubble(messages: settings.clickMessages)
                manualBubbleUntil = manualBubbleText == nil ? .distantPast : Date().addingTimeInterval(5)
            }
        case .dragEnded(let origin):
            guard let host = CodexWindowLocator.locate() ?? lastHost else { return }
            if settings.snapEnabled {
                let result = CodexWindowLocator.snapped(origin, host: host, panelSize: WhalePanel.size)
                anchor = result.anchor
                panel.setFrameOrigin(result.origin)
            } else {
                anchor = SnapAnchor(horizontal: nil, vertical: nil)
            }
            offset = CodexWindowLocator.offset(
                for: panel.frame.origin, host: host, panelSize: WhalePanel.size
            )
            panel.setMirrored(anchor.horizontal == .left)
            savePosition()
        case .showMenu(let point):
            showMenu(at: point)
        }
        updateBubble()
        updateQuotaBubble(now: Date())
    }

    private func currentBubbleText(now: Date) -> String? {
        guard settings.bubblesEnabled else { return nil }
        if now < systemBubbleUntil { return completionText }
        if now < manualBubbleUntil { return manualBubbleText }
        return nil
    }

    private func updateBubble(now: Date = Date()) {
        panel.setBubble(now < quotaBubbleUntil ? nil : currentBubbleText(now: now))
    }

    private func showMenu(at point: NSPoint) {
        let menu = NSMenu(title: "鲸鱼娘")
        let bubbles = NSMenuItem(title: "点击泡泡", action: #selector(toggleBubbles), keyEquivalent: "")
        bubbles.target = self
        bubbles.state = settings.bubblesEnabled ? .on : .off
        menu.addItem(bubbles)
        let edit = NSMenuItem(title: "编辑点击泡泡…", action: #selector(editBubbles), keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)
        let snap = NSMenuItem(title: "边缘吸附", action: #selector(toggleSnap), keyEquivalent: "")
        snap.target = self
        snap.state = settings.snapEnabled ? .on : .off
        menu.addItem(snap)
        menu.addItem(.separator())
        let quotaItem = NSMenuItem(title: "Codex 订阅余量", action: nil, keyEquivalent: "")
        let quotaMenu = NSMenu(title: "Codex 订阅余量")
        for row in quota.snapshot?.menuRows(now: Date()) ?? ["读取中…"] {
            let item = NSMenuItem(title: row, action: nil, keyEquivalent: "")
            item.isEnabled = false
            quotaMenu.addItem(item)
        }
        quotaMenu.addItem(.separator())
        let showQuota = NSMenuItem(title: "在气泡中显示用量", action: #selector(showQuotaBubble), keyEquivalent: "")
        showQuota.target = self
        quotaMenu.addItem(showQuota)
        let refreshQuota = NSMenuItem(title: "刷新余量", action: #selector(refreshQuota), keyEquivalent: "")
        refreshQuota.target = self
        quotaMenu.addItem(refreshQuota)
        menu.addItem(quotaItem)
        menu.setSubmenu(quotaMenu, for: quotaItem)
        guard let contentView = panel.contentView else { return }
        let windowPoint = panel.convertPoint(fromScreen: point)
        menu.popUp(positioning: nil, at: contentView.convert(windowPoint, from: nil), in: contentView)
    }

    @objc private func toggleBubbles() {
        settings.bubblesEnabled.toggle()
        settingsStore.save(settings)
        updateBubble()
        updateQuotaBubble(now: Date())
    }

    @objc private func refreshQuota() {
        quota.refreshIfDue(minimumInterval: 0)
    }

    @objc private func showQuotaBubble() {
        quota.refreshIfDue(minimumInterval: 60)
        let now = Date()
        quotaBubbleUntil = now.addingTimeInterval(5)
        updateBubble(now: now)
        let visible = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? panel.frame
        quotaBubble.show(snapshot: quota.snapshot, isRefreshing: quota.isRefreshing,
                         message: currentBubbleText(now: now),
                         above: panel.visualFrame, in: visible, now: now)
    }

    private func updateQuotaBubble(now: Date) {
        guard now < quotaBubbleUntil, panel.isVisible else {
            quotaBubble.orderOut(nil)
            return
        }
        let visible = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? panel.frame
        quotaBubble.updateIfVisible(snapshot: quota.snapshot, isRefreshing: quota.isRefreshing,
                                    message: currentBubbleText(now: now),
                                    above: panel.visualFrame, in: visible, now: now)
    }

    @objc private func toggleSnap() {
        settings.snapEnabled.toggle()
        if !settings.snapEnabled {
            anchor = SnapAnchor(horizontal: nil, vertical: nil)
            panel.setMirrored(false)
            if let host = lastHost {
                offset = CodexWindowLocator.offset(for: panel.frame.origin, host: host,
                                                   panelSize: WhalePanel.size)
                savePosition()
            }
        }
        settingsStore.save(settings)
    }

    @objc private func editBubbles() {
        let alert = NSAlert()
        alert.messageText = "编辑点击泡泡"
        alert.informativeText = "用 | 分隔不同泡泡。点击鲸鱼显示第一条，点击泡泡显示下一条。"
        let field = NSTextField(string: settings.clickMessages.joined(separator: " | "))
        field.frame = NSRect(x: 0, y: 0, width: 360, height: 28)
        alert.accessoryView = field
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let messages = field.stringValue.split(separator: "|", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !messages.isEmpty else { return }
        settings.clickMessages = Array(messages.prefix(20))
        settingsStore.save(settings)
        sequence.reset()
        manualBubbleUntil = .distantPast
        updateBubble()
        updateQuotaBubble(now: Date())
    }

    private func tick() {
        if events.takeRecentCompletion() {
            sequence.reset()
            systemBubbleUntil = Date().addingTimeInterval(5)
            sounds.playCompletion()
            quota.refreshIfDue(minimumInterval: 60)
        }
        quota.refreshIfDue()
        panel.cancelAbandonedDragIfNeeded()
        let now = Date()
        updateBubble(now: now)
        if now.timeIntervalSince(lastWindowCheck) < 0.5 {
            updateQuotaBubble(now: now)
            return
        }
        lastWindowCheck = now
        guard let host = CodexWindowLocator.locate() else {
            lastHost = nil
            panel.orderOut(nil)
            quotaBubble.orderOut(nil)
            return
        }
        if lastHost != host && !panel.isDragging {
            panel.setFrameOrigin(CodexWindowLocator.panelOrigin(
                for: host, panelSize: WhalePanel.size, offset: offset,
                anchor: settings.snapEnabled ? anchor : SnapAnchor(horizontal: nil, vertical: nil)
            ))
            panel.setMirrored(settings.snapEnabled && anchor.horizontal == .left)
            lastHost = host
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
        updateQuotaBubble(now: now)
    }
}
