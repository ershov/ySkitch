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
    let sizeLabel = NSTextField(labelWithString: "")
    let zoomLabel = NSTextField(labelWithString: "")

    var onActualSize: (() -> Void)?
    var onFit: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onZoomIn: (() -> Void)?

    private let separator = NSView()

    init() {
        actualSizeButton = NSButton(title: "1:1", target: nil, action: nil)
        fitButton = NSButton(title: "Fit", target: nil, action: nil)
        zoomOutButton = NSButton(title: "−", target: nil, action: nil)
        zoomInButton = NSButton(title: "+", target: nil, action: nil)
        super.init(frame: .zero)

        configure(actualSizeButton, #selector(actualSize), "Actual Size (⌘0)")
        configure(fitButton, #selector(fit), "Zoom to Fit (⌘9)")
        configure(zoomOutButton, #selector(zoomOut), "Zoom Out (⌘-)")
        configure(zoomInButton, #selector(zoomIn), "Zoom In (⌘+)")

        sizeLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        sizeLabel.textColor = .secondaryLabelColor
        sizeLabel.lineBreakMode = .byTruncatingTail
        sizeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        zoomLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        zoomLabel.textColor = .secondaryLabelColor
        zoomLabel.alignment = .center

        let controls = NSStackView(views: [actualSizeButton, fitButton, zoomOutButton, zoomLabel, zoomInButton])
        controls.spacing = 6
        for view in [sizeLabel, dragHandle, controls, separator] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        separator.wantsLayer = true

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            zoomLabel.widthAnchor.constraint(equalToConstant: 52),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
            sizeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            sizeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            dragHandle.centerXAnchor.constraint(equalTo: centerXAnchor),
            dragHandle.centerYAnchor.constraint(equalTo: centerYAnchor),
            sizeLabel.trailingAnchor.constraint(lessThanOrEqualTo: dragHandle.leadingAnchor, constant: -8),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            controls.centerYAnchor.constraint(equalTo: centerYAnchor),
            controls.leadingAnchor.constraint(greaterThanOrEqualTo: dragHandle.trailingAnchor, constant: 8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
    }

    func update(canvasSize: CGSize, scale: CGFloat) {
        sizeLabel.stringValue = StatusText.size(canvas: canvasSize, scale: scale)
    }

    func update(magnification: CGFloat) {
        zoomLabel.stringValue = StatusText.zoom(magnification)
    }

    private func configure(_ button: NSButton, _ action: Selector, _ toolTip: String) {
        button.target = self
        button.action = action
        button.bezelStyle = .accessoryBarAction
        button.controlSize = .regular
        button.toolTip = toolTip
    }

    @objc private func actualSize() { onActualSize?() }
    @objc private func fit() { onFit?() }
    @objc private func zoomOut() { onZoomOut?() }
    @objc private func zoomIn() { onZoomIn?() }
}
