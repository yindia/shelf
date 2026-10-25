import Core
import SwiftUI

/// Apple System Settings-style window: a sidebar of panes + a scrollable detail.
/// New settings are added by adding a `Pane` case and a `detail` branch — no new
/// windows or menu items per setting.
public struct SettingsView: View {
    @ObservedObject private var model: PanelViewModel
    @State private var pane: Pane = .general

    public init(model: PanelViewModel) {
        self.model = model
    }

    enum Pane: String, CaseIterable, Identifiable {
        case general = "General"
        case categories = "Categories"
        case privacy = "Privacy"
        case about = "About"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general: "gearshape"
            case .categories: "square.grid.2x2"
            case .privacy: "hand.raised"
            case .about: "info.circle"
            }
        }
    }

    public var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { pane in
                Label(pane.rawValue, systemImage: pane.icon).tag(pane)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            ScrollView {
                detail
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(pane.rawValue)
        }
        .frame(minWidth: 720, minHeight: 460)
    }

    @ViewBuilder private var detail: some View {
        switch pane {
        case .general:
            GeneralSettingsView()
        case .categories:
            AutoCategorizationSettingsView(
                rules: model.autoRules,
                collections: model.collections,
                embedded: true,
                onCommit: { model.commitRules($0) }
            )
        case .privacy:
            PrivacySettingsView(
                settings: model.privacy,
                embedded: true,
                onCommit: { model.commitPrivacy($0) }
            )
        case .about:
            AboutSettingsView()
        }
    }
}

/// Keyboard shortcuts + basic usage (read-only for now).
private struct GeneralSettingsView: View {
    private let shortcuts: [(String, String)] = [
        ("Show the shelf", "⇧⌘V"),
        ("Search clipboard", "⌃⌘V"),
        ("Paste item 1–9", "⌘1 … ⌘9"),
        ("New text item", "⌘N"),
        ("Quick Look selected", "Space"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts").font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { index, pair in
                    HStack {
                        Text(pair.0)
                        Spacer()
                        Text(pair.1).foregroundStyle(.secondary).monospaced()
                    }
                    .padding(.vertical, 8)
                    if index < shortcuts.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(0.04)))
            Spacer()
        }
        .padding(20)
    }
}

/// App identity, version, and links.
private struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shelf").font(.title2.weight(.semibold))
                    Text("Version \(version)").foregroundStyle(.secondary)
                }
            }
            Text("Your clipboard, with superpowers. Open source under the MIT License.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/yindia/shelf")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/yindia/shelf/issues")!)
            }
            Spacer()
        }
        .padding(20)
    }
}
