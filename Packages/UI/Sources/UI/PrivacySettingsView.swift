import AppKit
import Core
import SwiftUI

/// Preferences → Privacy: control panel visibility during screen sharing and
/// whether confidential clipboard content is ignored.
struct PrivacySettingsView: View {
    @State var settings: PrivacySettings
    /// Embedded in the unified Settings window: commit live, no Done button/frame.
    var embedded: Bool = false
    let onCommit: (PrivacySettings) -> Void
    var onClose: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !embedded {
                Text("Privacy").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle("Show during screen sharing", isOn: $settings.showDuringScreenSharing)
                .toggleStyle(.switch)
            Text("When off, Shelf is hidden from screen recording, sharing, and screenshots, so clips don’t appear during calls or demos.")
                .font(Theme.footerFont).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("Ignore confidential content", isOn: $settings.ignoreConfidential)
                .toggleStyle(.switch)
            Text("Skip items apps mark as confidential (e.g. passwords from a password manager).")
                .font(Theme.footerFont).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Text("Keep history for")
                Spacer()
                Picker("", selection: $settings.retention) {
                    ForEach(RetentionWindow.allCases, id: \.self) { Text($0.label).tag($0) }
                }.labelsHidden().frame(width: 140)
            }
            Text("Older clips are cleared automatically. Pinned items and pinboards are always kept.")
                .font(Theme.footerFont).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Excluded apps")
                    Spacer()
                    Button("Add App…") { addApp() }
                }
                Text("Copies from these apps are never captured.")
                    .font(Theme.footerFont).foregroundStyle(.secondary)
                if settings.excludedApps.isEmpty {
                    Text("None").font(Theme.footerFont).foregroundStyle(.tertiary)
                } else {
                    FlowChips(ids: settings.excludedApps.sorted()) { settings.excludedApps.remove($0) }
                }
            }

            Divider()

            Toggle("Sync history across Macs with iCloud", isOn: $settings.iCloudSyncEnabled)
                .toggleStyle(.switch)
            Text("Mirrors your clipboard history to your other Macs via iCloud. Takes effect after you relaunch Shelf. Requires an iCloud-entitled build.")
                .font(Theme.footerFont).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !embedded {
                HStack {
                    Spacer()
                    Button("Done") { onCommit(settings); onClose() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(20)
        .frame(width: embedded ? nil : 400)
        .frame(maxWidth: embedded ? .infinity : nil, alignment: .leading)
        .onChange(of: settings) { if embedded { onCommit(settings) } }
    }

    /// Pick an app to exclude; resolves its bundle id from the chosen bundle.
    private func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier {
            settings.excludedApps.insert(id)
        }
    }
}

/// Removable app chips showing the app name for a bundle id.
private struct FlowChips: View {
    let ids: [String]
    let onRemove: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ids, id: \.self) { id in
                    HStack(spacing: 4) {
                        Text(SourceAppIcon.name(for: id) ?? id).font(Theme.footerFont)
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.primary.opacity(0.1)))
                    .onTapGesture { onRemove(id) }
                }
            }
        }
    }
}
