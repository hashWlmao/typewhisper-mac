import Foundation

struct CorrectionSuggestion: Identifiable {
    let id = UUID()
    let original: String
    let replacement: String
}

final class TextDiffService {
    func extractCorrections(original: String, edited: String) -> [CorrectionSuggestion] {
        let originalWords = original.split(separator: " ").map(String.init)
        let editedWords = edited.split(separator: " ").map(String.init)

        // Skip if too different (massive rewrite)
        let maxLen = max(originalWords.count, editedWords.count)
        guard maxLen > 0 else { return [] }

        let diff = editedWords.difference(from: originalWords)

        let removals = diff.compactMap { change -> (offset: Int, element: String)? in
            if case .remove(let offset, let element, _) = change {
                return (offset, element)
            }
            return nil
        }
        let insertions = diff.compactMap { change -> (offset: Int, element: String)? in
            if case .insert(let offset, let element, _) = change {
                return (offset, element)
            }
            return nil
        }

        // If more than 50% changed, treat as rewrite
        let changeCount = removals.count + insertions.count
        if changeCount > maxLen { return [] }

        var suggestions: [CorrectionSuggestion] = []
        var usedInsertions = Set<Int>()

        for removal in removals {
            // Find nearest insertion within 3 positions
            var bestMatch: (index: Int, distance: Int)?
            for (i, insertion) in insertions.enumerated() {
                guard !usedInsertions.contains(i) else { continue }
                let distance = abs(removal.offset - insertion.offset)
                if distance <= 3 {
                    if bestMatch == nil || distance < bestMatch!.distance {
                        bestMatch = (i, distance)
                    }
                }
            }

            if let match = bestMatch {
                let insertion = insertions[match.index]
                usedInsertions.insert(match.index)

                // Skip punctuation-only changes
                let origClean = removal.element.filter { $0.isLetter || $0.isNumber }
                let replClean = insertion.element.filter { $0.isLetter || $0.isNumber }
                if origClean.lowercased() == replClean.lowercased() { continue }

                suggestions.append(CorrectionSuggestion(
                    original: removal.element,
                    replacement: insertion.element
                ))
            }
        }

        return suggestions
    }
}
