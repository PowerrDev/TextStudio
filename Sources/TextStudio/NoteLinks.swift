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

import SwiftUI
import AppKit

/**
 * Links between notes. In a note, `[[Title]]` (or `[[Title|shown text]]`) links
 * to the note with that title. `textstudio://note/<id>` links to a note by its
 * stable id and also opens the app from outside (browser, terminal, Claude).
 */
enum NoteLink {
    static let scheme = "textstudio"

    enum Target: Equatable {
        case id(UUID)
        case title(String)
    }

    static func url(for note: Note) -> URL? {
        note.uid.map { URL(string: "\(scheme)://note/\($0.uuidString)")! }
    }

    static func url(title: String) -> URL {
        var c = URLComponents()
        c.scheme = scheme
        c.host = "open"
        c.queryItems = [URLQueryItem(name: "title", value: title)]
        return c.url!
    }

    static func wikiLink(for note: Note) -> String { "[[\(note.title)]]" }

    static func target(of url: URL) -> Target? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        switch url.host?.lowercased() {
        case "note":
            return UUID(uuidString: url.lastPathComponent).map(Target.id)
        case "open":
            let title = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "title" }?.value
            return title.map { Target.title($0) }
        default:
            return nil
        }
    }

    /** Key used to compare titles: trimmed, case-insensitive. */
    static func key(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /** The note with this title; the most recently edited one if several match. */
    static func resolve(_ title: String, in notes: [Note]) -> Note? {
        let k = key(title)
        return notes.filter { key($0.title) == k }.max { $0.updatedAt < $1.updatedAt }
    }

    static func resolve(_ id: UUID, in notes: [Note]) -> Note? {
        notes.first { $0.uid == id }
    }

    // MARK: Preview

    private static let wiki = try! NSRegularExpression(pattern: #"\[\[([^\[\]|\n]+)(?:\|([^\[\]\n]+))?\]\]"#)

    /**
     * Rewrites `[[Title]]` / `[[Title|text]]` as Markdown links to
     * `textstudio://open?title=…`, leaving inline code spans untouched.
     */
    static func expandWikiLinks(_ s: String) -> String {
        guard s.contains("[[") else { return s }

        /* Even segments are outside backticks. */
        return s.components(separatedBy: "`").enumerated().map { i, part in
            guard i % 2 == 0 else { return part }
            let ns = part as NSString
            var out = ""
            var last = 0

            for m in wiki.matches(in: part, range: NSRange(location: 0, length: ns.length)) {
                let title = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { continue }
                let shown = m.range(at: 2).location != NSNotFound
                    ? ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
                    : title

                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                /* Parentheses are encoded so they can't end the link destination early. */
                let dest = url(title: title).absoluteString
                    .replacingOccurrences(of: "(", with: "%28")
                    .replacingOccurrences(of: ")", with: "%29")
                out += "[\(escape(shown))](\(dest))"
                last = NSMaxRange(m.range)
            }

            return out + ns.substring(from: last)
        }.joined(separator: "`")
    }

    /** Backslash-escapes characters that would otherwise be read as Markdown. */
    private static func escape(_ s: String) -> String {
        var out = ""
        for c in s {
            if "\\`*_[]~<>".contains(c) { out.append("\\") }
            out.append(c)
        }
        return out
    }

    // MARK: Editor

    /** The focused Markdown editor in the key window, if any. */
    @MainActor
    static func focusedEditor() -> NSTextView? {
        guard let tv = NSApp.keyWindow?.firstResponder as? NSTextView,
              !tv.isFieldEditor, tv.delegate is MarkdownEditor.Coordinator else { return nil }
        return tv
    }

    /** Replaces `range` in the editor with `text`, with undo, and syncs the note. */
    @MainActor
    static func insert(_ text: String, into tv: NSTextView, at range: NSRange) {
        let length = (tv.string as NSString).length
        let safe = NSMaxRange(range) <= length ? range : NSRange(location: length, length: 0)

        if tv.shouldChangeText(in: safe, replacementString: text) {
            tv.replaceCharacters(in: safe, with: text)
            tv.didChangeText()
            tv.setSelectedRange(NSRange(location: safe.location + (text as NSString).length, length: 0))
        }
    }

    @MainActor
    static func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}

/** Where a picked link goes: the editor's selection when the picker opened, or the note's end. */
struct LinkInsertTarget: Identifiable {
    let id = UUID()
    let note: Note
    let editor: NSTextView?
    let range: NSRange
}

/** Searchable list of notes; picking one inserts a `[[Title]]` link. */
struct NoteLinkPicker: View {
    let notes: [Note]
    let exclude: Note?
    let onPick: (Note) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var highlighted: Note?

    private var matches: [Note] {
        let others = notes.filter { $0 != exclude }
        guard !query.isEmpty else { return others }
        return others.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Link to Note").font(.headline)
            TextField("Search notes", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if let n = highlighted ?? matches.first { pick(n) } }

            List(matches, selection: $highlighted) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title).lineLimit(1)
                    if let folder = note.folder {
                        Label(folder.name, systemImage: "folder").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(note)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { pick(note) }
            }
            .frame(minHeight: 240)
            .overlay {
                if matches.isEmpty { Text("No matching notes").foregroundStyle(.secondary) }
            }

            HStack {
                Text("Double-click or press Return to insert").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Insert") { if let n = highlighted ?? matches.first { pick(n) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(matches.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420, height: 380)
    }

    private func pick(_ note: Note) {
        dismiss()
        onPick(note)
    }
}
