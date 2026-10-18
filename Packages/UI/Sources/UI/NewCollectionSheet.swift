import SwiftUI

/// New-collection flow: name field + color picker + icon picker.
/// Consistent ~20pt internal padding; all labels share one leading margin.
struct NewCollectionSheet: View {
    /// `(name, colorHex, iconSymbol)`.
    let onCreate: (String, String, String) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var colorHex = Self.palette[0]
    @State private var icon = Self.icons[0]

    /// Tunable choices offered in the picker.
    static let palette = ["#E24B6E", "#F28F30", "#E7B61C", "#20B36F", "#3379F2", "#8C57E0", "#8E8E93"]
    static let icons = ["tray", "link", "note.text", "chevron.left.forwardslash.chevron.right",
                        "photo", "star", "tag", "folder", "bookmark", "paintpalette"]

    private let iconColumns = Array(repeating: GridItem(.fixed(30), spacing: 10), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Collection")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            section("Color") {
                HStack(spacing: 8) {
                    ForEach(Self.palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2 : 0))
                            .contentShape(Circle())
                            .onTapGesture { colorHex = hex }
                    }
                }
            }

            section("Icon") {
                // Grid wraps within the dialog width so it never overflows/clips.
                LazyVGrid(columns: iconColumns, alignment: .leading, spacing: 8) {
                    ForEach(Self.icons, id: \.self) { symbol in
                        Image(systemName: symbol)
                            .font(.system(size: 15))
                            .frame(width: 30, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill((Color(hex: colorHex) ?? .gray).opacity(icon == symbol ? 0.25 : 0.08))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { icon = symbol }
                    }
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Create") { onCreate(name.trimmingCharacters(in: .whitespaces), colorHex, icon) }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 340, alignment: .leading)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.footerFont)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
