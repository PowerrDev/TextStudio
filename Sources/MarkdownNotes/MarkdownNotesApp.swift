import SwiftUI
import SwiftData
import AppKit

@main
struct MarkdownNotesApp: App {
    let container: ModelContainer
    @AppStorage("theme") private var theme: AppTheme = .dark

    init() {
        // Store lives at ~/Library/Application Support/MarkdownNotes/Notes.store (SQLite)
        let dir = URL.applicationSupportDirectory.appending(path: "MarkdownNotes", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let config = ModelConfiguration(url: dir.appending(path: "Notes.store"))
        do {
            container = try ModelContainer(for: Note.self, configurations: config)
        } catch {
            fatalError("Could not open notes database: \(error)")
        }
        NSApplication.shared.setActivationPolicy(.regular)
        ZoomKeyMonitor.install()
    }

    var body: some Scene {
        WindowGroup("Markdown Notes") {
            ContentView()
                .frame(minWidth: 900, minHeight: 500)
                .onAppear { theme.apply() }
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

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                NotificationCenter.default.post(name: .newNote, object: nil)
            }
            .keyboardShortcut("n")
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

/// Lets ⌘= (unshifted, as in browsers) zoom in too, alongside the ⌘+ menu item.
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
            .pickerStyle(.segmented)
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

extension Notification.Name {
    static let newNote = Notification.Name("MarkdownNotes.newNote")
}
