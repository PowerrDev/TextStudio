import Foundation
import SwiftData

@Model
final class Note {
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(body: String = "") {
        self.body = body
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// First non-empty line, stripped of leading markdown heading markers.
    var title: String {
        let line = body.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let trimmed = line.drop(while: { $0 == "#" || $0 == " " })
        return trimmed.isEmpty ? "Untitled" : String(trimmed)
    }

    /// Second non-empty line, used as a snippet in the sidebar.
    var snippet: String {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
        return lines.count > 1 ? String(lines[1]) : ""
    }
}
