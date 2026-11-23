import YSkitchCore

@MainActor
final class DocumentModel {
    var document: Document {
        didSet { onChange?() }
    }

    var onChange: (() -> Void)?

    init(document: Document) {
        self.document = document
    }
}
