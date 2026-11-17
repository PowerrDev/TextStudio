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

/** What the note list is showing. */
enum SidebarItem: Hashable {
    case all
    case folder(Folder)
    case tag(String)
}

/** Text-entry alerts for naming folders and tags. */
enum NamePrompt {
    case newFolder
    case renameFolder(Folder)
    case renameTag(String)
    case saveTemplate(Note)

    var title: String {
        switch self {
        case .newFolder: "New Folder"
        case .renameFolder: "Rename Folder"
        case .renameTag: "Rename Tag"
        case .saveTemplate: "Save as Template"
        }
    }

    var confirm: String {
        switch self {
        case .newFolder: "Create"
        case .saveTemplate: "Save"
        default: "Rename"
        }
    }

    var initial: String {
        switch self {
        case .newFolder: ""
        case .renameFolder(let f): f.name
        case .renameTag(let t): t
        case .saveTemplate(let n): n.title
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @Query private var tagColors: [TagColor]
    @Query(sort: \NoteTemplate.name) private var userTemplates: [NoteTemplate]

    @State private var customColor: CustomColorTarget?
    @State private var sidebar: SidebarItem? = .all
    @State private var selection: Note?
    @State private var search = ""
    @State private var prompt: NamePrompt?
    @State private var promptText = ""
    @State private var linkTarget: LinkInsertTarget?

    @AppStorage("editorMode") private var mode: EditorMode = .split
    @AppStorage("showNoteList") private var showNoteList = true
    @AppStorage("theme") private var theme: AppTheme = .dark

    @Environment(\.colorScheme) private var scheme

    /** `initialSelection` opens that note in the very first render instead of a second pass. */
    init(initialSelection: Note? = nil) {
        _selection = State(initialValue: initialSelection)
    }

    /** Every tag in use with its note count, alphabetical. */
    private var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]

        for note in notes { for tag in note.tags { counts[tag, default: 0] += 1 } }
        return counts
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .map { (tag: $0.key, count: $0.value) }
    }

    private var tagHexes: [String: Int] {
        Dictionary(tagColors.map { ($0.tag, $0.hex) }, uniquingKeysWith: { a, _ in a })
    }

    private func tagColor(_ tag: String) -> Color {
        tagHexes[tag].map { Color(hex: UInt32($0)) } ?? theme.palette(scheme).accent
    }

    private func pickCustomColor(_ tag: String) {
        customColor = CustomColorTarget(tag: tag, initial: tagColor(tag))
    }

    private var templates: [TemplateItem] {
        TemplateItem.builtIns + userTemplates.map(TemplateItem.init)
    }

    /** Titles of every note, for telling working `[[links]]` from broken ones. */
    private var linkTargets: Set<String> {
        Set(notes.map { NoteLink.key($0.title) })
    }

    private var scoped: [Note] {
        switch sidebar ?? .all {
        case .all: notes
        case .folder(let f): notes.filter { $0.folder == f }
        case .tag(let t): notes.filter { $0.tags.contains(t) }
        }
    }

    private var filtered: [Note] {
        guard !search.isEmpty else { return scoped }
        let tagQuery = search.hasPrefix("#") ? String(search.dropFirst()) : search

        return scoped.filter { note in
            note.body.localizedCaseInsensitiveContains(search)
                || (!tagQuery.isEmpty && note.tags.contains { $0.localizedCaseInsensitiveContains(tagQuery) })
        }
    }

    private var listTitle: String {
        switch sidebar ?? .all {
        case .all: "All Notes"
        case .folder(let f): f.name
        case .tag(let t): "#" + t
        }
    }

    /** Three columns, or two when the note list is hidden. */
    @ViewBuilder
    private var splitView: some View {
        if showNoteList {
            NavigationSplitView {
                sidebarList
            } content: {
                noteList
            } detail: {
                detail
            }
        } else {
            NavigationSplitView {
                sidebarList
            } detail: {
                detail
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let note = selection {
            NoteDetailView(note: note, mode: mode, allTags: tagCounts.map(\.tag), tagHexes: tagHexes,
                           linkTargets: linkTargets)
                .id(note.persistentModelID)
        } else {
            ContentUnavailableView("No Note Selected", systemImage: "note.text",
                                   description: Text("Press ⌘N to create a note."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .themeTint()
        }
    }

    var body: some View {
        splitView
        .windowGlass()
        /* Let the frosted panes show through behind the toolbar instead of its opaque bar. */
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation { showNoteList.toggle() }
                } label: {
                    Label(showNoteList ? "Hide Note List" : "Show Note List",
                          systemImage: "list.bullet.rectangle")
                }
                .help(showNoteList ? "Hide Note List (⌥⌘L)" : "Show Note List (⌥⌘L)")
            }

            ToolbarItem(placement: .primaryAction) {
                Picker("Mode", selection: $mode) {
                    ForEach(EditorMode.allCases) { m in
                        Label(m.rawValue, systemImage: m.icon).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(selection == nil)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let selection { PDFExporter.export(selection) }
                } label: {
                    Label("Export as PDF", systemImage: "arrow.down.doc")
                }
                .help("Export as PDF (⇧⌘E)")
                .disabled(selection == nil)
            }
        }
        .tint(theme.palette(scheme).accent)
        .focusedSceneValue(\.noteActions, NoteActions(
            newNote: addNote,
            newFolder: { ask(.newFolder) },
            toggleNoteList: { withAnimation { showNoteList.toggle() } },
            noteListVisible: showNoteList,
            duplicate: selection.map { note in { duplicate(note) } },
            exportPDF: selection.map { note in { PDFExporter.export(note) } },
            templates: templates,
            newFromTemplate: { addNote(body: $0.expanded()) },
            saveAsTemplate: selection.map { note in { ask(.saveTemplate(note)) } },
            deleteTemplate: deleteTemplate,
            insertLink: selection.map { note in { beginInsertLink(into: note) } },
            copyServerURL: selection.flatMap { note in NoteServer.url(for: note).map { url in { NoteLink.copy(url) } } }
        ))
        /* Clicking a note link in the preview opens that note. */
        .environment(\.openURL, OpenURLAction { url in
            follow(url) ? .handled : .systemAction
        })
        .onOpenURL { _ = follow($0) }
        .sheet(item: $linkTarget) { target in
            NoteLinkPicker(notes: notes, exclude: target.note) { picked in
                insertLink(to: picked, at: target)
            }
        }
        .alert(prompt?.title ?? "", isPresented: Binding(
            get: { prompt != nil },
            set: { if !$0 { prompt = nil } }
        ), presenting: prompt) { p in
            TextField("Name", text: $promptText)
            Button(p.confirm) { apply(p) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $customColor) { target in
            CustomTagColorSheet(tag: target.tag, color: target.initial)
        }
        .onAppear {
            if selection == nil { selection = notes.first }
        }
        .onChange(of: sidebar) {
            if let selection, filtered.contains(selection) { return }
            selection = filtered.first
        }
    }

    // MARK: - Columns

    private var sidebarList: some View {
        List(selection: nativeSidebarSelection) {
            Label("All Notes", systemImage: "tray.full")
                .badge(notes.count)
                .tag(SidebarItem.all)
                .dropDestination(for: NoteRef.self) { refs, _ in move(refs, to: nil) }

            Section {
                ForEach(folders) { folder in
                    Label(folder.name, systemImage: "folder")
                        .badge(notes.filter { $0.folder == folder }.count)
                        .tag(SidebarItem.folder(folder))
                        .dropDestination(for: NoteRef.self) { refs, _ in move(refs, to: folder) }
                        .contextMenu {
                            Button("Rename…") { ask(.renameFolder(folder)) }
                            Button("Delete Folder", role: .destructive) { deleteFolder(folder) }
                        }
                }
            } header: {
                HStack {
                    Text("Folders")
                    Spacer()
                    Button { ask(.newFolder) } label: { Image(systemName: "plus") }
                        .buttonStyle(.borderless)
                        .help("New Folder (⇧⌘N)")
                }
            }

            if !tagCounts.isEmpty {
                Section("Tags") {
                    ForEach(tagCounts, id: \.tag) { item in
                        tagRow(item.tag, count: item.count)
                            .contextMenu {
                                TagColorMenu(tag: item.tag, current: tagHexes[item.tag]) {
                                    pickCustomColor(item.tag)
                                }

                                Button("Rename…") { ask(.renameTag(item.tag)) }
                                Button("Remove from All Notes", role: .destructive) { deleteTag(item.tag) }
                            }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .themeTint()
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 300)
    }

    /**
     * Tag rows draw their own highlight in the tag's color, so they stay out of
     * the List's native (accent-colored) selection.
     */
    private var nativeSidebarSelection: Binding<SidebarItem?> {
        Binding(
            get: { if case .tag = sidebar { return nil } else { return sidebar } },
            set: { if let new = $0 { sidebar = new } }
        )
    }

    private func tagRow(_ tag: String, count: Int) -> some View {
        let selected = sidebar == .tag(tag)
        let color = tagColor(tag)

        return HStack {
            Label {
                Text(tag)
            } icon: {
                Image(systemName: "number")
                    .foregroundStyle(selected ? .white : color)
            }

            Spacer()
            Text("\(count)")
                .monospacedDigit()
                .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.secondary)
        }
        .foregroundStyle(selected ? Color.white : Color.primary)
        .contentShape(Rectangle())
        /*
         * The row background spans the full row height, like the native highlight;
         * the horizontal inset matches the native highlight's rounded shape.
         */
        .listRowBackground(
            RoundedRectangle(cornerRadius: 5)
                .fill(selected ? color : .clear)
                .padding(.horizontal, 10)
        )
        .onTapGesture { sidebar = .tag(tag) }
    }

    private var noteList: some View {
        List(selection: $selection) {
            ForEach(filtered) { note in
                noteRow(note)
                    .tag(note)
                    .draggable(NoteRef(id: note.persistentModelID))
                    .contextMenu { noteMenu(note) }
            }
            .onDelete { offsets in
                offsets.map { filtered[$0] }.forEach(delete)
            }
        }
        .scrollContentBackground(.hidden)
        .themeTint()
        .toolbarBackground(.hidden, for: .windowToolbar)
        .searchable(text: $search, placement: .sidebar)
        .navigationTitle(listTitle)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
        .toolbar {
            ToolbarItem {
                Menu {
                    ForEach(templates) { t in
                        Button(t.name) { addNote(body: t.expanded()) }
                    }
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                } primaryAction: {
                    addNote()
                }
                .help("New Note (⌘N) — hold for templates")
            }
        }
        .onDeleteCommand {
            if let selection { delete(selection) }
        }
    }

    private func noteRow(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title).font(.headline).lineLimit(1)
            HStack {
                Text(note.updatedAt, format: .dateTime.month().day().hour().minute())
                Text(note.snippet).lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !note.tags.isEmpty || (note.folder != nil && sidebar == .all) {
                HStack(spacing: 6) {
                    if let folder = note.folder, sidebar == .all {
                        Label(folder.name, systemImage: "folder")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(note.tags, id: \.self) { tag in
                        Text("#" + tag).foregroundStyle(tagColor(tag))
                    }
                }
                .font(.caption2)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func noteMenu(_ note: Note) -> some View {
        Button("Duplicate") { duplicate(note) }
        Menu("Move to Folder") {
            Button("No Folder") { note.folder = nil; save() }
                .disabled(note.folder == nil)
            if !folders.isEmpty { Divider() }
            ForEach(folders) { folder in
                Button(folder.name) { note.folder = folder; save() }
                    .disabled(note.folder == folder)
            }
        }

        Menu("Copy Link") {
            Button("Wiki Link  [[\(note.title)]]") { NoteLink.copy(NoteLink.wikiLink(for: note)) }
            if let url = NoteLink.url(for: note) {
                Button("App Link") { NoteLink.copy("[\(note.title)](\(url.absoluteString))") }
            }
            if let url = NoteServer.url(for: note) {
                Button("URL for Claude Code") { NoteLink.copy(url) }
            }
        }
        Button("Save as Template…") { ask(.saveTemplate(note)) }
        Button("Export as PDF…") { PDFExporter.export(note) }
        Divider()
        Button("Delete", role: .destructive) { delete(note) }
    }

    // MARK: - Notes

    private func addNote() { addNote(body: "# New note\n\n") }

    private func addNote(body: String) {
        var tags: [String] = []
        var folder: Folder?

        switch sidebar ?? .all {
        case .all: break
        case .folder(let f): folder = f
        case .tag(let t): tags = [t]
        }

        let note = Note(body: body, tags: tags, folder: folder)
        context.insert(note)
        save()
        search = ""
        selection = note
    }

    private func duplicate(_ note: Note) {
        let copy = Note(body: note.duplicatedBody, tags: note.tags, folder: note.folder)
        context.insert(copy)
        save()
        selection = copy
    }

    private func delete(_ note: Note) {
        if selection == note { selection = nil }
        context.delete(note)
        save()
    }

    /** Selects a note, widening the list if the current folder, tag or search hides it. */
    private func reveal(_ note: Note) {
        if !filtered.contains(note) {
            search = ""
            if !scoped.contains(note) { sidebar = .all }
        }
        selection = note
    }

    /**
     * Opens a `textstudio://` link. A `[[Title]]` link to a note that doesn't
     * exist yet creates it, in the current folder.
     */
    private func follow(_ url: URL) -> Bool {
        guard let target = NoteLink.target(of: url) else { return false }

        switch target {
        case .id(let id):
            if let note = NoteLink.resolve(id, in: notes) { reveal(note) } else { NSSound.beep() }
        case .title(let title):
            if let note = NoteLink.resolve(title, in: notes) {
                reveal(note)
            } else {
                let note = Note(body: "# \(title)\n\n", folder: selection?.folder)
                context.insert(note)
                save()
                reveal(note)
            }
        }

        return true
    }

    private func beginInsertLink(into note: Note) {
        let editor = NoteLink.focusedEditor()
        linkTarget = LinkInsertTarget(note: note, editor: editor,
                                      range: editor?.selectedRange() ?? NSRange(location: NSNotFound, length: 0))
    }

    private func insertLink(to picked: Note, at target: LinkInsertTarget) {
        let link = NoteLink.wikiLink(for: picked)

        if let editor = target.editor, editor.window != nil, target.range.location != NSNotFound {
            editor.window?.makeFirstResponder(editor)
            NoteLink.insert(link, into: editor, at: target.range)
        } else {
            let body = target.note.body
            target.note.body = body + (body.hasSuffix("\n") || body.isEmpty ? "" : "\n") + link + "\n"
            save()
        }
    }

    private func move(_ refs: [NoteRef], to folder: Folder?) -> Bool {
        let moved = refs.compactMap { context.model(for: $0.id) as? Note }
        moved.forEach { $0.folder = folder }
        save()
        return !moved.isEmpty
    }

    // MARK: - Folders & tags

    private func ask(_ p: NamePrompt) {
        promptText = p.initial
        prompt = p
    }

    private func apply(_ p: NamePrompt) {
        let name = promptText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch p {
        case .newFolder:
            guard !name.isEmpty else { return }
            let folder = Folder(name: name)
            context.insert(folder)
            sidebar = .folder(folder)

        case .renameFolder(let folder):
            guard !name.isEmpty else { return }
            folder.name = name

        case .renameTag(let old):
            guard let new = Note.normalizeTag(name), new != old else { return }
            for note in notes where note.tags.contains(old) {
                note.tags = note.tags.reduce(into: []) { result, t in
                    let t = t == old ? new : t

                    if !result.contains(t) { result.append(t) }
                }
            }

            TagColor.rename(old, to: new, in: context)
            if sidebar == .tag(old) { sidebar = .tag(new) }

        case .saveTemplate(let note):
            guard !name.isEmpty else { return }
            if let existing = userTemplates.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                existing.body = note.body
            } else {
                context.insert(NoteTemplate(name: name, body: note.body))
            }
        }

        save()
    }

    private func deleteFolder(_ folder: Folder) {
        if sidebar == .folder(folder) { sidebar = .all }
        context.delete(folder)   /* notes are kept (nullify) */
        save()
    }

    private func deleteTag(_ tag: String) {
        for note in notes where note.tags.contains(tag) { note.tags.removeAll { $0 == tag } }
        TagColor.set(tag, hex: nil, in: context)
        if sidebar == .tag(tag) { sidebar = .all }
        save()
    }

    private func deleteTemplate(_ id: String) {
        guard let t = userTemplates.first(where: { TemplateItem($0).id == id }) else { return }
        context.delete(t)
        save()
    }

    private func save() { try? context.save() }
}

struct NoteDetailView: View {
    @Bindable var note: Note
    let mode: EditorMode
    let allTags: [String]
    let tagHexes: [String: Int]
    let linkTargets: Set<String>
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @AppStorage("fontSize") private var fontSize = Prefs.defaultFontSize
    @AppStorage("theme") private var theme: AppTheme = .dark

    @State private var pinchStart: Double?
    @State private var pendingSave: Task<Void, Never>?
    /**
     * What the editor shows. Typing goes here, not into `note.body`: the note list,
     * sidebar and link index all read every note's body, so writing it per keystroke
     * re-lays out the whole window and makes typing lag. Copied into the note on pause.
     */
    @State private var draft: String

    init(note: Note, mode: EditorMode, allTags: [String], tagHexes: [String: Int], linkTargets: Set<String>) {
        self.note = note
        self.mode = mode
        self.allTags = allTags
        self.tagHexes = tagHexes
        self.linkTargets = linkTargets
        _draft = State(initialValue: note.body)
    }

    var body: some View {
        let palette = theme.palette(scheme)
        VStack(spacing: 0) {
            TagBar(note: note, allTags: allTags, tagHexes: tagHexes, palette: palette)
            Rectangle().fill(palette.secondary.opacity(0.25)).frame(height: 1)
            HStack(spacing: 0) {
                if mode != .preview {
                    MarkdownEditor(text: $draft, fontSize: fontSize, palette: palette)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if mode == .split {
                    Rectangle().fill(palette.secondary.opacity(0.25)).frame(width: 1)
                }

                if mode != .edit {
                    ScrollView {
                        MarkdownView(text: draft, fontSize: fontSize, palette: palette, linkTargets: linkTargets)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .tint(palette.accent)
        .themeTint()
        .toolbarBackground(.hidden, for: .windowToolbar)
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
        .onChange(of: draft) {
            pendingSave?.cancel()
            pendingSave = Task {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                commit()
            }
        }
        /* The body changed somewhere other than this editor; show it. */
        .onChange(of: note.body) {
            if pendingSave == nil, note.body != draft { draft = note.body }
        }
        .onDisappear {
            if pendingSave != nil { commit() }
        }
        /* Don't lose the last keystrokes when quitting or switching apps mid-pause. */
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            if pendingSave != nil { commit() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            if pendingSave != nil { commit() }
        }
    }

    /** Copies the draft into the note and saves it; called once typing pauses. */
    private func commit() {
        pendingSave?.cancel()
        pendingSave = nil
        guard note.body != draft else { return }
        note.body = draft
        note.updatedAt = .now
        try? context.save()
    }
}

// MARK: - Menu commands

/** Actions the menu bar can trigger in the focused window. */
struct NoteActions {
    var newNote: () -> Void
    var newFolder: () -> Void
    var toggleNoteList: () -> Void
    var noteListVisible: Bool
    var duplicate: (() -> Void)?
    var exportPDF: (() -> Void)?
    var templates: [TemplateItem]
    var newFromTemplate: (TemplateItem) -> Void
    var saveAsTemplate: (() -> Void)?
    var deleteTemplate: (String) -> Void
    var insertLink: (() -> Void)?
    var copyServerURL: (() -> Void)?
}

private struct NoteActionsKey: FocusedValueKey {
    typealias Value = NoteActions
}

extension FocusedValues {
    var noteActions: NoteActions? {
        get { self[NoteActionsKey.self] }
        set { self[NoteActionsKey.self] = newValue }
    }
}
