import AppKit
import Core
import SwiftUI

/// Right-click menu for a card. All actions route through the shared view-model
/// paths (copy / activate / move / delete) — no duplicated logic.
struct CardContextMenu: View {
    let item: ClipItemModel
    let model: PanelViewModel
    @Binding var pendingDelete: ClipItemModel?

    private var fileURL: URL? {
        item.fileURLString.flatMap(URL.init(string:)).flatMap { $0.isFileURL ? $0 : nil }
    }
    private var isImage: Bool {
        item.data(for: UTIs.png) != nil || item.data(for: UTIs.jpeg) != nil || item.data(for: UTIs.tiff) != nil
    }

    /// Writes the image to a temp file and puts its file URL on the pasteboard
    /// so other apps receive it as a file (paste/drag as file).
    /// Rotate the image 90° clockwise and persist.
    private func rotate(_ item: ClipItemModel) {
        let uti = [UTIs.png, UTIs.tiff, UTIs.jpeg].first { item.data(for: $0) != nil }
        guard let uti, let data = item.data(for: uti), let image = NSImage(data: data),
              let png = image.rotated(byDegrees: 90).pngData else { return }
        model.replaceRepresentation(item, type: uti, data: png)
    }

    /// Share the item's content via the system share sheet.
    private func share(_ item: ClipItemModel) {
        var payload: [Any] = []
        if item.kind == .link, let url = item.linkURL { payload = [url] }
        else if let s = item.plainText { payload = [s] }
        else if let d = item.data(for: UTIs.png) ?? item.data(for: UTIs.jpeg) ?? item.data(for: UTIs.tiff),
                let img = NSImage(data: d) { payload = [img] }
        else if let s = item.fileURLString, let url = URL(string: s) { payload = [url] }
        guard !payload.isEmpty, let view = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: payload)
        picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
    }

    private func copyAsFile(_ item: ClipItemModel) {
        guard let data = item.data(for: UTIs.png) ?? item.data(for: UTIs.jpeg) ?? item.data(for: UTIs.tiff)
        else { return }
        let ext = item.data(for: UTIs.png) != nil ? "png" : (item.data(for: UTIs.jpeg) != nil ? "jpg" : "tiff")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Shelf-\(item.id).\(ext)")
        guard (try? data.write(to: url)) != nil else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([url as NSURL])
    }

    private var inUserCollection: Bool {
        guard let listID = item.listID else { return false }
        return listID != CollectionSeed.historyID
    }

    var body: some View {
        Button("Copy") { model.copy(item) }
        Button("Paste") { model.activate(item: item) }
        Button("Paste without Formatting") { model.activate(item: item, plainText: true) }
        if item.kind == .link, let url = item.linkURL {
            Button("Open") { NSWorkspace.shared.open(url) }
        }
        Button(item.isPinned ? "Unpin" : "Pin") { model.setPinned(item, pinned: !item.isPinned) }
        Button("Edit…") { model.editingItem = item }
        if isImage {
            Button("Rotate Right") { rotate(item) }
            Button("Copy as File") { copyAsFile(item) }
        }
        Button("Share…") { share(item) }

        // Jump to History: reveal the item in its collection with surrounding context.
        Button(inUserCollection ? "Show in Pinboard" : "Show in Clipboard") { model.jump(to: item) }
        Divider()

        Menu("Move to") {
            ForEach(model.collections) { collection in
                Button {
                    model.move(itemID: item.id, to: collection.id)
                } label: {
                    // Checkmark the current collection.
                    if collection.id == (item.listID ?? CollectionSeed.historyID) {
                        Label(collection.name, systemImage: "checkmark")
                    } else {
                        Text(collection.name)
                    }
                }
            }
        }

        if inUserCollection {
            Button("Remove from Collection") {
                model.move(itemID: item.id, to: CollectionSeed.historyID)
            }
        }

        if let fileURL {
            Divider()
            Button("Open") { NSWorkspace.shared.open(fileURL) }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
        }

        Divider()
        Button("Delete…", role: .destructive) { pendingDelete = item }
    }
}
