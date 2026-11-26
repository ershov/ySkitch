import AppKit
import YSkitchCore

@MainActor
final class StatusBarView: NSView {
    static let height: CGFloat = 40

    let dragHandle = DragHandleView()
    let actualSizeButton: NSButton
    let fitButton: NSButton
    let zoomOutButton: NSButton
    let zoomInButton: NSButton
    let infoLabel = NSTextField(labelWithString: "")
    let scaleButton = NSPopUpButton(frame: .zero, pullsDown: false)
    let zoomButton = ZoomButton()

    var onActualSize: (() -> Void)?
    var onFit: ((Bool) -> Void)?
    var onZoomOut: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomTo: ((CGFloat) -> Void)?
    var onScaleChange: ((CGFloat) -> Void)?

    private let separator = NSView()
    private let controls: NSStackView
    private static let inset: CGFloat = 14
    private static let handleGap: CGFloat = 8
    private static let labelGap: CGFloat = 4
    private var shownScale: CGFloat?
    private var shownMagnification: CGFloat = 1
    private var zoomPanel: ZoomSliderPanel?

    init() {
        actualSizeButton = NSButton(title: "1:1", target: nil, action: nil)
        fitButton = NSButton(title: "Fit", target: nil, action: nil)
        zoomOutButton = NSButton(title: "−", target: nil, action: nil)
        zoomInButton = NSButton(title: "+", target: nil, action: nil)
        controls = NSStackView(views: [actualSizeButton, fitButton, zoomOutButton, zoomButton, zoomInButton])
        super.init(frame: .zero)

        configure(actualSizeButton, #selector(actualSize), "Actual Size (⌘0). Two-finger double-tap toggles Fit / 100 %")
        configure(fitButton, #selector(fit), "Zoom to Fit (⌘9) — keeps fitting until you zoom. Two-finger double-tap toggles Fit / 100 %")
        fitButton.setButtonType(.pushOnPushOff)
        configure(zoomOutButton, #selector(zoomOut), "Zoom Out (⌘-) · ⌘-scroll down")
        configure(zoomInButton, #selector(zoomIn), "Zoom In (⌘+) · ⌘-scroll up")

        infoLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.lineBreakMode = .byTruncatingTail
        infoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scaleButton.isBordered = false
        scaleButton.font = infoLabel.font
        scaleButton.contentTintColor = .secondaryLabelColor
        scaleButton.toolTip = "Output Scale"
        scaleButton.target = self
        scaleButton.action = #selector(scaleSelected)
        scaleButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        scaleButton.setContentHuggingPriority(.required, for: .horizontal)
        configure(zoomButton, nil, "Zoom — double-click the slider for 100 %")
        zoomButton.showsBorderOnlyWhileMouseInside = true
        zoomButton.onPress = { [weak self] in self?.openZoomSlider($0) }

        controls.spacing = 6
        for view in [infoLabel, scaleButton, dragHandle, controls, separator] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        separator.wantsLayer = true

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            zoomButton.widthAnchor.constraint(equalToConstant: 52),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
            infoLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
            infoLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            dragHandle.centerXAnchor.constraint(equalTo: centerXAnchor),
            dragHandle.centerYAnchor.constraint(equalTo: centerYAnchor),
            scaleButton.leadingAnchor.constraint(equalTo: infoLabel.trailingAnchor, constant: Self.labelGap),
            scaleButton.firstBaselineAnchor.constraint(equalTo: infoLabel.firstBaselineAnchor),
            scaleButton.trailingAnchor.constraint(lessThanOrEqualTo: dragHandle.leadingAnchor, constant: -Self.handleGap),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.inset),
            controls.centerYAnchor.constraint(equalTo: centerYAnchor),
            controls.leadingAnchor.constraint(greaterThanOrEqualTo: dragHandle.trailingAnchor, constant: Self.handleGap),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The drag handle is centered, so each half must fit the wider side; the info label truncates.
    var minimumWidth: CGFloat {
        let side = max(Self.labelGap + scaleButton.fittingSize.width, controls.fittingSize.width)
        return 2 * (DragHandleView.size.width / 2 + Self.handleGap + side + Self.inset)
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
    }

    func update(info: String) {
        infoLabel.stringValue = info
    }

    /// Lists `Document.scaleChoices`, plus `scale` when it is not one of them.
    func update(scale: CGFloat) {
        guard scale != shownScale else { return }
        shownScale = scale
        let scales = Document.scaleChoices.contains(scale) ? Document.scaleChoices : Document.scaleChoices + [scale]
        scaleButton.removeAllItems()
        for choice in scales {
            scaleButton.addItem(withTitle: StatusText.scale(choice))
            scaleButton.lastItem?.representedObject = NSNumber(value: Double(choice))
        }
        selectShownScale()
    }

    private func selectShownScale() {
        guard let shownScale else { return }
        scaleButton.selectItem(at: scaleButton.indexOfItem(withRepresentedObject: NSNumber(value: Double(shownScale))))
    }

    func update(magnification: CGFloat) {
        shownMagnification = magnification
        zoomButton.attributedTitle = NSAttributedString(
            string: StatusText.zoom(magnification),
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
    }

    private func openZoomSlider(_ event: NSEvent) {
        guard let window, zoomPanel == nil else { return }
        let panel = ZoomSliderPanel(magnification: shownMagnification)
        panel.onZoom = { [weak self] in self?.onZoomTo?($0) }
        panel.onDismiss = { [weak self] in self?.zoomPanel = nil }
        zoomPanel = panel
        panel.present(over: zoomButton, in: window)
        panel.track(with: event)
    }

    private func configure(_ button: NSButton, _ action: Selector?, _ toolTip: String) {
        button.target = self
        button.action = action
        button.bezelStyle = .accessoryBarAction
        button.controlSize = .regular
        button.toolTip = toolTip
    }

    @objc private func actualSize() { onActualSize?() }
    @objc private func fit() { onFit?(fitButton.state == .on) }
    @objc private func zoomOut() { onZoomOut?() }
    @objc private func zoomIn() { onZoomIn?() }

    @objc private func scaleSelected() {
        guard let scale = (scaleButton.selectedItem?.representedObject as? NSNumber).map({ CGFloat($0.doubleValue) })
        else { return }
        onScaleChange?(scale)
        // A refused change keeps the document's scale selected.
        selectShownScale()
    }
}

/// Reports the press instead of firing an action, so the slider can track the same mouse gesture.
@MainActor
final class ZoomButton: NSButton {
    var onPress: ((NSEvent) -> Void)?

    init() {
        super.init(frame: .zero)
        title = ""
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func mouseDown(with event: NSEvent) { onPress?(event) }
}
