import Core
import SwiftUI

/// Preferences → Privacy: control panel visibility during screen sharing and
/// whether confidential clipboard content is ignored.
struct PrivacySettingsView: View {
    @State var settings: PrivacySettings
    let onCommit: (PrivacySettings) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy").font(.headline).frame(maxWidth: .infinity, alignment: .leading)

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

            HStack {
                Spacer()
                Button("Done") { onCommit(settings); onClose() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 400)
    }
}
