import SwiftUI
import TokiCore

/// Category for a timed entry; a separate category turns the entry into separate time.
struct CategoryPicker: View {
    @Environment(AppStore.self) private var store
    @Binding var entry: TimeEntry

    var body: some View {
        Picker("Kategorie", selection: Binding(get: { entry.categoryID }, set: { id in
            if let category = store.category(id) {
                entry.assign(category)
            } else {
                entry.categoryID = nil
                entry.kind = .work
            }
        })) {
            Text("Keine").tag(UUID?.none)
            ForEach(store.settings.categories) { category in
                Text(category.name).tag(UUID?.some(category.id))
            }
        }
        .accessibilityIdentifier("entryCategory")
    }
}
