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
import AppKit

@main
struct TextStudioApp: App {
    let container: ModelContainer
    /** Most recently edited note, looked up at launch so the first window opens with it. */
    private let initialNote: Note?
    @AppStorage("theme") private var theme: AppTheme = .dark

    init() {
        /* Store lives at ~/Library/Application Support/TextStudio/Notes.store (SQLite) */
        let dir = URL.applicationSupportDirectory.appending(path: "TextStudio", directoryHint: .isDirectory)
        Self.migrateFromMarkdownNotes(to: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let config = ModelConfiguration(url: dir.appending(path: "Notes.store"))

        do {
            container = try ModelContainer(for: Note.self, Folder.self, TagColor.self, NoteTemplate.self, configurations: config)
        } catch {
            fatalError("Could not open notes database: \(error)")
        }

        var recent = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        recent.fetchLimit = 1
        initialNote = try? container.mainContext.fetch(recent).first
        NSApplication.shared.setActivationPolicy(.regular)
        /*
         * Apply the theme before any window exists. Doing it on appear switched the
         * appearance after the first draw and made every view render twice.
         */
        let saved = UserDefaults.standard.string(forKey: "theme") ?? ""
        (AppTheme(rawValue: saved) ?? .dark).apply()
        ZoomKeyMonitor.install()
    }

    /** One-time move of data and settings from the app's old name ("MarkdownNotes"). */
    private static func migrateFromMarkdownNotes(to newDir: URL) {
        let fm = FileManager.default
        let oldDir = URL.applicationSupportDirectory.appending(path: "MarkdownNotes", directoryHint: .isDirectory)

        if fm.fileExists(atPath: oldDir.path), !fm.fileExists(atPath: newDir.path) {
            try? fm.moveItem(at: oldDir, to: newDir)
        }

        let defaults = UserDefaults.standard

        if !defaults.bool(forKey: "migratedFromMarkdownNotes"),
           let old = UserDefaults(suiteName: "local.markdownnotes")?.persistentDomain(forName: "local.markdownnotes") {
            for key in ["theme", "fontSize", "tintOpacity", "editorMode"] {
                if let value = old[key] { defaults.set(value, forKey: key) }
            }
        }

        defaults.set(true, forKey: "migratedFromMarkdownNotes")
    }

    var body: some Scene {
        WindowGroup("TextStudio") {
            ContentView(initialSelection: initialNote)
                .frame(minWidth: 900, minHeight: 500)
                .onChange(of: theme) { theme.apply() }
        }
        .defaultSize(width: 1200, height: 750)
        .modelContainer(container)
        .commands { AppCommands() }

        Settings {
            SettingsView()
        }
    }
}

struct AppCommands: Commands {
    @AppStorage("fontSize") private var fontSize = Prefs.defaultFontSize
    @AppStorage("theme") private var theme: AppTheme = .dark

    @FocusedValue(\.noteActions) private var actions

    @ViewBuilder
    private func templateButtons(builtIn: Bool) -> some View {
        ForEach(actions?.templates.filter { $0.builtIn == builtIn } ?? []) { t in
            Button(t.name) { actions?.newFromTemplate(t) }
        }
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") { actions?.newNote() }
                .keyboardShortcut("n")
                .disabled(actions == nil)
            Menu("New Note from Template") {
                templateButtons(builtIn: true)
                if actions?.templates.contains(where: { !$0.builtIn }) == true {
                    Divider()
                    templateButtons(builtIn: false)
                }
            }
            .disabled(actions == nil)
            Button("New Folder") { actions?.newFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Divider()
            Button("Save Note as Template…") { actions?.saveAsTemplate?() }
                .disabled(actions?.saveAsTemplate == nil)
            Menu("Delete Template") {
                ForEach(actions?.templates.filter { !$0.builtIn } ?? []) { t in
                    Button(t.name) { actions?.deleteTemplate(t.id) }
                }
            }
            .disabled(actions?.templates.contains(where: { !$0.builtIn }) != true)
            Divider()
            Button("Duplicate Note") { actions?.duplicate?() }
                .keyboardShortcut("d")
                .disabled(actions?.duplicate == nil)
            Divider()
            Button("Export as PDF…") { actions?.exportPDF?() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(actions?.exportPDF == nil)
        }

        CommandGroup(after: .sidebar) {
            Button(actions?.noteListVisible == false ? "Show Note List" : "Hide Note List") {
                actions?.toggleNoteList()
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
            .disabled(actions == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Zoom In") { fontSize = Prefs.clamp(fontSize + 1) }
                .keyboardShortcut("+")
            Button("Zoom Out") { fontSize = Prefs.clamp(fontSize - 1) }
                .keyboardShortcut("-")
            Button("Actual Size") { fontSize = Prefs.defaultFontSize }
                .keyboardShortcut("0")
            Divider()
            Picker("Appearance", selection: $theme) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
            }

            Divider()
        }
    }
}

/** Lets ⌘= (unshifted, as in browsers) zoom in too, alongside the ⌘+ menu item. */
enum ZoomKeyMonitor {
    static func install() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if mods == .command, event.charactersIgnoringModifiers == "=" {
                let d = UserDefaults.standard
                let current = d.object(forKey: "fontSize") as? Double ?? Prefs.defaultFontSize
                d.set(Prefs.clamp(current + 1), forKey: "fontSize")
                return nil
            }

            return event
        }
    }
}

struct SettingsView: View {
    @AppStorage("theme") private var theme: AppTheme = .dark
    @AppStorage("fontSize") private var fontSize = Prefs.defaultFontSize
    @AppStorage("tintOpacity") private var tintOpacity = 0.55

    var body: some View {
        Form {
            Picker("Appearance", selection: $theme) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
            }
            LabeledContent("Text size") {
                HStack {
                    Slider(value: $fontSize, in: Prefs.minFontSize...Prefs.maxFontSize, step: 1)
                    Text("\(Int(fontSize)) pt").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }

            LabeledContent("Transparency") {
                HStack {
                    Text("Clear").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $tintOpacity, in: 0...1)
                    Text("Solid").font(.caption).foregroundStyle(.secondary)
                }
            }

        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
    }
}
