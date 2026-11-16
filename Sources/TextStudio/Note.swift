/*
 * TextStudio
 *
 * Copyright (c) 2026 Power
 *
 * MIT License
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@Model
final class Note {
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String] = []
    var folder: Folder?

    init(body: String = "", tags: [String] = [], folder: Folder? = nil) {
        self.body = body
        self.createdAt = .now
        self.updatedAt = .now
        self.tags = tags
        self.folder = folder
    }

    /** First non-empty line, stripped of leading markdown heading markers. */
    var title: String {
        let line = body.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let trimmed = line.drop(while: { $0 == "#" || $0 == " " })

        return trimmed.isEmpty ? "Untitled" : String(trimmed)
    }

    /** Second non-empty line, used as a snippet in the sidebar. */
    var snippet: String {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: true)

        return lines.count > 1 ? String(lines[1]) : ""
    }

    // MARK: Tags

    /** Lowercased, without a leading `#`, whitespace collapsed to `-`. Nil if empty. */
    static func normalizeTag(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "#" })
            .lowercased()
        let tag = s.split(whereSeparator: \.isWhitespace).joined(separator: "-")

        return tag.isEmpty ? nil : tag
    }

    func addTag(_ raw: String) {
        guard let tag = Self.normalizeTag(raw), !tags.contains(tag) else { return }
        tags.append(tag)
        updatedAt = .now
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updatedAt = .now
    }

    // MARK: Duplicate

    /** The body with " copy" appended to its first non-empty (title) line. */
    var duplicatedBody: String {
        var lines = body.components(separatedBy: "\n")

        if let i = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            lines[i] += " copy"
        }

        return lines.joined(separator: "\n")
    }
}

@Model
final class Folder {
    var name: String
    var createdAt: Date
    /** Deleting a folder keeps its notes; they just lose their folder. */
    @Relationship(deleteRule: .nullify, inverse: \Note.folder) var notes: [Note]? = []

    init(name: String) {
        self.name = name
        self.createdAt = .now
    }
}

/** Drag payload for moving a note onto a folder in the sidebar. */
struct NoteRef: Codable, Transferable {
    let id: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .textStudioNote)
    }
}

extension UTType {
    static let textStudioNote = UTType(exportedAs: "local.textstudio.note")
}
