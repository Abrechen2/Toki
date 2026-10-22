import SwiftUI
import TokiCore

/// "Mehr → Kategorien": labels for work entries, e.g. "Schweiz" for time abroad that is paid separately.
struct CategoriesView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: EntryCategory?
    @State private var deleting: EntryCategory?

    var body: some View {
        List {
            Section {
                if store.settings.categories.isEmpty {
                    Text("Noch keine Kategorien").foregroundStyle(Theme.secondaryText)
                }
                ForEach(store.settings.categories) { category in
                    Button { editing = category } label: {
                        HStack {
                            CategoryBadge(category: category)
                            Spacer()
                            Text(category.countsAsWorkTime ? "zählt mit" : "getrennt")
                                .font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Löschen", role: .destructive) { deleting = category }
                    }
                }
                Button {
                    editing = EntryCategory(name: "", colorIndex: store.settings.categories.count, countsAsWorkTime: false)
                } label: {
                    Label("Kategorie hinzufügen", systemImage: "plus")
                }
                .accessibilityIdentifier("addCategory")
            } footer: {
                Text("Kategorien kennzeichnen Arbeitszeiten, z. B. „Schweiz“ für Einsätze, die getrennt bezahlt werden. Im Export kannst du eine Kategorie mit Summe ausgeben.")
            }
        }
        .navigationTitle("Kategorien")
        .sheet(item: $editing) { category in
            CategoryEditor(category: category, isNew: store.category(category.id) == nil)
        }
        .alert("Kategorie löschen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                if let deleting { store.deleteCategory(deleting.id) }
            }
        } message: {
            Text("Die \(deleting.map { store.entryCount(in: $0.id) } ?? 0) Einträge behalten ihre Zeiten und bleiben, wie sie gerechnet werden; nur die Kennzeichnung entfällt.")
        }
    }
}

private struct CategoryEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var category: EntryCategory
    let isNew: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Schweiz", text: $category.name)
                        .accessibilityIdentifier("categoryName")
                    HStack(spacing: 10) {
                        ForEach(Theme.categoryColors.indices, id: \.self) { index in
                            Button { category.colorIndex = index } label: {
                                Circle()
                                    .fill(Theme.categoryColors[index])
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(.white, lineWidth: category.colorIndex == index ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Farbe \(index + 1)")
                        }
                    }
                }
                Section {
                    Toggle("Zählt zur normalen Arbeitszeit", isOn: $category.countsAsWorkTime)
                        .accessibilityIdentifier("categoryCounts")
                } footer: {
                    Text(category.countsAsWorkTime
                         ? "Die Zeiten zählen ganz normal für Soll und Überstunden und sind nur gekennzeichnet."
                         : "Die Zeiten laufen getrennt: Sie zählen nicht für Soll, Ist und Überstunden. Ein Tag nur mit solchen Zeiten zählt, als wärst du nicht da gewesen.")
                }
            }
            .navigationTitle(isNew ? "Neue Kategorie" : "Kategorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        category.name = category.name.trimmingCharacters(in: .whitespaces)
                        store.saveCategory(category)
                        store.showToast(String(localized: "Gespeichert"))
                        dismiss()
                    }
                    .disabled(category.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("saveCategory")
                }
            }
        }
    }
}

/// Coloured label used in lists and entries.
struct CategoryBadge: View {
    let category: EntryCategory

    var body: some View {
        Text(category.name)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.categoryColor(category.colorIndex).opacity(0.25), in: Capsule())
            .foregroundStyle(Theme.categoryColor(category.colorIndex))
    }
}
