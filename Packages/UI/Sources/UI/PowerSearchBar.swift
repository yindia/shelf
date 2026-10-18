import Core
import SwiftUI

/// Power Search filter row: a Filters menu (content type / app / date / pinboard)
/// plus removable visual tokens showing which filters are active.
struct PowerSearchBar: View {
    @ObservedObject var model: PanelViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filtersMenu
                tokens
                if !model.filters.isEmpty {
                    Button("Clear") { model.clearFilters() }
                        .font(Theme.footerFont).buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Theme.panelPadding)
            .frame(height: Theme.filterBarHeight)
        }
        .scrollClipDisabled()
        .frame(height: Theme.filterBarHeight)
    }

    private var filtersMenu: some View {
        Menu {
            Menu("Content Type") {
                ForEach(ClipKind.allCases, id: \.self) { kind in
                    Button { model.toggleKind(kind) } label: {
                        Label(kind.rawValue.capitalized,
                              systemImage: model.filters.kinds.contains(kind) ? "checkmark" : Theme.icon(for: kind))
                    }
                }
            }
            if !model.availableApps.isEmpty {
                Menu("Application") {
                    ForEach(model.availableApps, id: \.self) { app in
                        Button { model.toggleApp(app) } label: {
                            if model.filters.apps.contains(app) { Label(appName(app), systemImage: "checkmark") }
                            else { Text(appName(app)) }
                        }
                    }
                }
            }
            Menu("Date") {
                ForEach(DateFilter.allCases, id: \.self) { d in
                    Button { model.setDate(d) } label: {
                        if model.filters.date == d { Label(d.label, systemImage: "checkmark") } else { Text(d.label) }
                    }
                }
            }
            if !model.collections.isEmpty {
                Menu("Pinboard") {
                    ForEach(model.collections) { c in
                        Button { model.togglePinboardFilter(c.id) } label: {
                            if model.filters.pinboards.contains(c.id) { Label(c.name, systemImage: "checkmark") }
                            else { Text(c.name) }
                        }
                    }
                }
            }
        } label: {
            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                .font(Theme.footerFont).labelStyle(.titleAndIcon)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var tokens: some View {
        HStack(spacing: 6) {
            ForEach(Array(model.filters.kinds), id: \.self) { k in
                token(k.rawValue.capitalized, Theme.accent(for: k)) { model.toggleKind(k) }
            }
            ForEach(Array(model.filters.apps), id: \.self) { a in
                token(appName(a), .secondary) { model.toggleApp(a) }
            }
            ForEach(Array(model.filters.pinboards), id: \.self) { id in
                let c = model.collections.first { $0.id == id }
                token(c?.name ?? "Pinboard", Color(hex: c?.colorHex ?? "#8E8E93") ?? .gray) {
                    model.togglePinboardFilter(id)
                }
            }
            if model.filters.date != .any {
                token(model.filters.date.label, .secondary) { model.setDate(.any) }
            }
        }
    }

    private func token(_ label: String, _ color: Color, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(Theme.footerFont)
            Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(Theme.primaryText)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.22)))
        .onTapGesture(perform: remove)
    }

    private func appName(_ bundleID: String) -> String {
        SourceAppIcon.name(for: bundleID) ?? bundleID
    }
}
