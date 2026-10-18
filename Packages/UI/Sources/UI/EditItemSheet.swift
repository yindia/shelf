import Core
import SwiftUI

/// Rename a clip and, for text clips, edit the copied text in place.
struct EditItemSheet: View {
    let item: ClipItemModel
    let onSave: (_ title: String?, _ text: String?) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var text: String
    private let isTextEditable: Bool

    init(item: ClipItemModel,
         onSave: @escaping (_ title: String?, _ text: String?) -> Void,
         onCancel: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: item.userTitle ?? "")
        let editable = [.text, .richText, .html, .code, .link].contains(item.kind)
        self.isTextEditable = editable
        _text = State(initialValue: editable ? (item.plainText ?? "") : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Clip").font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(Theme.footerFont).foregroundStyle(.secondary)
                TextField("Optional name", text: $title).textFieldStyle(.roundedBorder)
            }

            if isTextEditable {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Text").font(Theme.footerFont).foregroundStyle(.secondary)
                    TextEditor(text: $text)
                        .font(Theme.bodyFont)
                        .frame(height: 140)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    onSave(title.trimmingCharacters(in: .whitespaces),
                           isTextEditable ? text : nil)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
