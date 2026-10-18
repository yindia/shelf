import Core
import SwiftUI

/// Settings for opt-in auto-categorization. Master switch (default OFF) plus a
/// per-rule toggle and destination. Kind rules are built in; text-pattern rules
/// can be added. Clipboard History always shows everything regardless.
struct AutoCategorizationSettingsView: View {
    @State var rules: AutoCategorizationRules
    let collections: [Collection]
    let onCommit: (AutoCategorizationRules) -> Void
    let onClose: () -> Void

    @State private var newPattern = ""
    @State private var newPatternCollection: UUID

    init(rules: AutoCategorizationRules, collections: [Collection],
         onCommit: @escaping (AutoCategorizationRules) -> Void, onClose: @escaping () -> Void) {
        _rules = State(initialValue: rules)
        self.collections = collections
        self.onCommit = onCommit
        self.onClose = onClose
        _newPatternCollection = State(initialValue: collections.first { !$0.isDefault }?.id
            ?? collections.first?.id ?? CollectionSeed.historyID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Auto-Categorization").font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("File new clips into collections automatically", isOn: $rules.enabled)
                .toggleStyle(.switch)

            Text("When off, every clip goes to Clipboard History. History always shows all clips.")
                .font(Theme.footerFont).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach($rules.rules) { $rule in
                        ruleRow($rule)
                    }
                }
            }
            .frame(height: 170)

            patternAdder

            HStack {
                Spacer()
                Button("Done") { onCommit(rules); onClose() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 440)
        .disabled(false)
    }

    private func ruleRow(_ rule: Binding<AutoRule>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: rule.enabled).labelsHidden().disabled(!rules.enabled)
            Text(describe(rule.wrappedValue.match))
                .font(Theme.bodyFont)
                .frame(width: 180, alignment: .leading)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            collectionPicker(selection: rule.collectionID)
            Spacer()
        }
        .opacity(rules.enabled ? 1 : 0.5)
    }

    private var patternAdder: some View {
        HStack(spacing: 8) {
            TextField("Text pattern (regex)", text: $newPattern)
                .textFieldStyle(.roundedBorder)
            collectionPicker(selection: $newPatternCollection)
            Button("Add Rule") {
                guard !newPattern.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                rules.rules.append(AutoRule(enabled: rules.enabled,
                                            match: .textPattern(newPattern),
                                            collectionID: newPatternCollection))
                newPattern = ""
            }
            .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func collectionPicker(selection: Binding<UUID>) -> some View {
        Picker("", selection: selection) {
            ForEach(collections) { Text($0.name).tag($0.id) }
        }
        .labelsHidden()
        .frame(width: 150)
    }

    private func describe(_ match: RuleMatch) -> String {
        switch match {
        case .kind(let k): "Kind is \(k.rawValue.capitalized)"
        case .textPattern(let p): "Text matches /\(p)/"
        }
    }
}
