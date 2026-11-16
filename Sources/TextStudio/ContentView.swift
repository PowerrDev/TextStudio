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
import SwiftData

enum EditorMode: String, CaseIterable, Identifiable {
    case edit = "Edit", split = "Split", preview = "Preview"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .edit: "pencil"
        case .split: "rectangle.split.2x1"
        case .preview: "eye"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var selection: Note?
    @State private var search = ""

    @AppStorage("editorMode") private var mode: EditorMode = .split

    @Environment(\.colorScheme) private var scheme

    private var filtered: [Note] {
        guard !search.isEmpty else { return notes }
        return notes.filter { $0.body.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(filtered) { note in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title).font(.headline).lineLimit(1)
                        HStack {
                            Text(note.updatedAt, format: .dateTime.month().day().hour().minute())
                            Text(note.snippet).lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(note)
                    .contextMenu {
                        Button("Delete", role: .destructive) { delete(note) }
                    }
                }
                .onDelete { offsets in
                    offsets.map { filtered[$0] }.forEach(delete)
                }
            }
            .searchable(text: $search, placement: .sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
            .toolbar {
                ToolbarItem {
                    Button(action: addNote) { Label("New Note", systemImage: "square.and.pencil") }
                }
            }
            .onDeleteCommand {
                if let selection { delete(selection) }
            }
        } detail: {
            if let note = selection {
                NoteDetailView(note: note, mode: mode)
                    .id(note.persistentModelID)
            } else {
                ContentUnavailableView("No Note Selected", systemImage: "note.text",
                                       description: Text("Press ⌘N to create a note."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Mode", selection: $mode) {
                    ForEach(EditorMode.allCases) { m in
                        Label(m.rawValue, systemImage: m.icon).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(selection == nil)
            }
        }
        .tint(Palette.forScheme(scheme).accent)
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in addNote() }
        .onAppear { if selection == nil { selection = notes.first } }
    }

    private func addNote() {
        let note = Note(body: "# New note\n\n")
        context.insert(note)
        try? context.save()
        search = ""
        selection = note
    }

    private func delete(_ note: Note) {
        if selection == note { selection = nil }
        context.delete(note)
        try? context.save()
    }
}

struct NoteDetailView: View {
    @Bindable var note: Note
    let mode: EditorMode
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @AppStorage("fontSize") private var fontSize = Prefs.defaultFontSize
    @AppStorage("tintOpacity") private var tintOpacity = 0.55

    @State private var pinchStart: Double?

    var body: some View {
        let palette = Palette.forScheme(scheme)
        HStack(spacing: 0) {
            if mode != .preview {
                TextEditor(text: $note.body)
                    .font(Fonts.mono(fontSize))
                    .foregroundStyle(palette.text)
                    .lineSpacing(fontSize * 0.25)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if mode == .split {
                Rectangle().fill(palette.secondary.opacity(0.25)).frame(width: 1)
            }

            if mode != .edit {
                ScrollView {
                    MarkdownView(text: note.body, fontSize: fontSize, palette: palette)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tint(palette.accent)
        .background {
            ZStack {
                FrostedBackground(material: scheme == .dark ? .hudWindow : .underWindowBackground)
                palette.background.opacity(tintOpacity)
            }
            .ignoresSafeArea()
        }

        /* Trackpad pinch to zoom */
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let start = pinchStart ?? fontSize
                    pinchStart = start
                    fontSize = Prefs.clamp((start * value.magnification).rounded())
                }
                .onEnded { _ in pinchStart = nil }
        )
        .navigationTitle(note.title)
        .onChange(of: note.body) {
            note.updatedAt = .now
            try? context.save()
        }
    }
}
