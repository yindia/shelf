import SwiftUI

/// Create a new plain-text clip (⌘N / New Text Item).
struct NewTextItemSheet: View {
    let onCreate: (String) -> Void
    let onCancel: () -> Void
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Text Item").font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: $text)
                .font(Theme.bodyFont)
                .frame(height: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Create") { onCreate(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
