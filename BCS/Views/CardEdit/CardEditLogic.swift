import Foundation

enum CardEditLogic {
    /// Returns the draft with the review flag cleared on every field whose value the user changed.
    /// Unchanged flagged fields stay flagged (spec §4: saving a field clears its own flag).
    static func applyingEdits(original: BusinessCard, draft: BusinessCard) -> BusinessCard {
        var result = draft
        func clearIfChanged(_ field: inout ContactField, from old: ContactField) {
            if field.value != old.value { field.reviewReason = nil }
        }
        clearIfChanged(&result.name, from: original.name)
        clearIfChanged(&result.company, from: original.company)
        clearIfChanged(&result.email, from: original.email)
        clearIfChanged(&result.address, from: original.address)
        for i in result.phones.indices {
            if let old = original.phones.first(where: { $0.id == result.phones[i].id }) {
                clearIfChanged(&result.phones[i].field, from: old.field)
            } else {
                result.phones[i].field.reviewReason = nil
            }
        }
        return result
    }
}
