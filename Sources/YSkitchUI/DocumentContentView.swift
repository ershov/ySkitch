import AppKit

@MainActor
final class DocumentContentView: NSView {
    let scrollView: CanvasScrollView
    let statusBar: StatusBarView
    let toolbarSlot = NSView()

    init(scrollView: CanvasScrollView, statusBar: StatusBarView, toolbar: NSView, toolbarWidth: CGFloat) {
        self.scrollView = scrollView
        self.statusBar = statusBar
        super.init(frame: .zero)

        for view in [toolbarSlot, scrollView, statusBar] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbarSlot.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: toolbarSlot.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: toolbarSlot.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: toolbarSlot.topAnchor),
            toolbar.bottomAnchor.constraint(equalTo: toolbarSlot.bottomAnchor),
            statusBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            toolbarSlot.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbarSlot.topAnchor.constraint(equalTo: topAnchor),
            toolbarSlot.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            toolbarSlot.widthAnchor.constraint(equalToConstant: toolbarWidth),
            scrollView.leadingAnchor.constraint(equalTo: toolbarSlot.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
