import AppKit
import Core
import Quartz

/// Presents file-backed items in `QLPreviewPanel` (Space to open, Esc closes).
/// Image blobs without a file URL are written to a temp file first.
public final class QuickLookPresenter: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var urls: [URL] = []

    public override init() { super.init() }

    /// True when this item can be previewed (file-backed media, or an image blob).
    public static func canPreview(_ item: ClipItemModel) -> Bool {
        if item.fileURLString?.hasPrefix("file:") == true { return true }
        return item.data(for: UTIs.png) != nil || item.data(for: UTIs.tiff) != nil
            || item.data(for: UTIs.jpeg) != nil
    }

    /// Opens Quick Look for the item, or closes the panel if already open.
    public func toggle(for item: ClipItemModel) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible { panel.orderOut(nil); return }
        guard let url = fileURL(for: item) else { return }
        urls = [url]
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    public func close() {
        QLPreviewPanel.shared()?.orderOut(nil)
    }

    private func fileURL(for item: ClipItemModel) -> URL? {
        if let s = item.fileURLString, let url = URL(string: s), url.isFileURL,
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        // Write an image blob to a temp file for preview.
        if let data = item.data(for: UTIs.png) ?? item.data(for: UTIs.jpeg) ?? item.data(for: UTIs.tiff) {
            let ext = item.data(for: UTIs.png) != nil ? "png" : (item.data(for: UTIs.jpeg) != nil ? "jpg" : "tiff")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("shelf-ql-\(item.id).\(ext)")
            try? data.write(to: url)
            return url
        }
        return nil
    }

    // MARK: QLPreviewPanelDataSource
    public func numberOfPreviewItems(in panel: QLPreviewPanel) -> Int { urls.count }
    public func previewPanel(_ panel: QLPreviewPanel, previewItemAt index: Int) -> QLPreviewItem {
        urls[index] as NSURL
    }
}
