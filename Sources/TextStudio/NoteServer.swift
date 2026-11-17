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
import Network
import SwiftData

/**
 * Read-only HTTP server on 127.0.0.1 so tools like Claude Code can read notes
 * by URL (e.g. `curl http://127.0.0.1:7337/notes`). It only listens on the
 * loopback interface and rejects requests whose Host header isn't the loopback
 * address, which blocks DNS-rebinding attempts from web pages.
 */
@MainActor
final class NoteServer: ObservableObject {
    static let shared = NoteServer()
    static let defaultPort = 7337
    static let enabledKey = "localServerEnabled"
    static let portKey = "localServerPort"

    enum Status: Equatable {
        case stopped
        case running(Int)
        case failed(String)
    }

    @Published private(set) var status: Status = .stopped

    private var container: ModelContainer?
    private var listener: NWListener?
    private var applied: (enabled: Bool, port: Int)?
    private let queue = DispatchQueue(label: "local.textstudio.noteserver")

    static var enabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    static var port: Int {
        let p = UserDefaults.standard.integer(forKey: portKey)
        return (1024...65535).contains(p) ? p : defaultPort
    }

    static var baseURL: String { "http://127.0.0.1:\(port)" }

    static func url(for note: Note) -> String? {
        note.uid.map { "\(baseURL)/notes/\($0.uuidString)" }
    }

    func start(container: ModelContainer) {
        self.container = container
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { NoteServer.shared.applySettings() }
        }
        applySettings()
    }

    /** (Re)starts or stops the listener when the setting or port changed. */
    private func applySettings() {
        let wanted = (enabled: Self.enabled, port: Self.port)
        if let applied, applied == wanted { return }
        applied = wanted

        listener?.cancel()
        listener = nil
        status = .stopped

        guard wanted.enabled, let port = NWEndpoint.Port(rawValue: UInt16(wanted.port)) else { return }

        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
        params.allowLocalEndpointReuse = true

        let l: NWListener
        do {
            l = try NWListener(using: params)
        } catch {
            status = .failed(error.localizedDescription)
            return
        }

        l.stateUpdateHandler = { [weak self, weak l] state in
            Task { @MainActor in
                guard let self, let l, self.listener === l else { return }
                switch state {
                case .ready: self.status = .running(wanted.port)
                case .failed(let e): self.status = .failed(e.localizedDescription); l.cancel()
                default: break
                }
            }
        }
        l.newConnectionHandler = { [queue] conn in
            conn.start(queue: queue)
            Self.receive(conn, buffer: Data())
        }
        listener = l
        l.start(queue: queue)
    }

    // MARK: - HTTP

    private struct Response {
        var status: Int
        var type = "text/markdown; charset=utf-8"
        var body: String
    }

    /** Reads until the end of the request headers, then answers and closes. */
    nonisolated private static func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, done, error in
            var buffer = buffer
            if let data { buffer.append(data) }

            if buffer.range(of: Data("\r\n\r\n".utf8)) == nil {
                if done || error != nil || buffer.count > 65_536 { conn.cancel(); return }
                receive(conn, buffer: buffer)
                return
            }

            let head = String(decoding: buffer, as: UTF8.self)
            Task { @MainActor in
                let r = NoteServer.shared.respond(to: head)
                send(r, on: conn, headOnly: head.hasPrefix("HEAD "))
            }
        }
    }

    nonisolated private static func send(_ r: Response, on conn: NWConnection, headOnly: Bool) {
        let body = Data(r.body.utf8)
        let reason = [200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed"][r.status] ?? "Error"
        let head = "HTTP/1.1 \(r.status) \(reason)\r\n"
            + "Content-Type: \(r.type)\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Cache-Control: no-store\r\n"
            + "Connection: close\r\n\r\n"
        conn.send(content: Data(head.utf8) + (headOnly ? Data() : body), completion: .contentProcessed { _ in conn.cancel() })
    }

    private func respond(to head: String) -> Response {
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        guard parts.count >= 2 else { return Response(status: 400, body: "Bad request\n") }

        let host = lines.dropFirst()
            .first { $0.lowercased().hasPrefix("host:") }
            .map { $0.dropFirst(5).trimmingCharacters(in: .whitespaces).lowercased() }
        let port = Self.port
        guard let host, ["127.0.0.1:\(port)", "localhost:\(port)", "127.0.0.1", "localhost"].contains(host) else {
            return Response(status: 403, body: "Forbidden: requests must use 127.0.0.1 or localhost\n")
        }

        guard parts[0] == "GET" || parts[0] == "HEAD" else {
            return Response(status: 405, body: "Only GET is supported; this server is read-only\n")
        }

        guard let comps = URLComponents(string: "http://localhost" + parts[1]), let container else {
            return Response(status: 400, body: "Bad request\n")
        }

        let query = Dictionary((comps.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        let notes = (try? container.mainContext.fetch(
            FetchDescriptor<Note>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )) ?? []
        let path = comps.path.hasSuffix("/") && comps.path.count > 1 ? String(comps.path.dropLast()) : comps.path

        switch path {
        case "", "/":
            return Response(status: 200, body: help())

        case "/notes", "/notes.json":
            var list = notes
            if let tag = query["tag"].flatMap(Note.normalizeTag) { list = list.filter { $0.tags.contains(tag) } }
            if let folder = query["folder"] {
                list = list.filter { $0.folder?.name.localizedCaseInsensitiveCompare(folder) == .orderedSame }
            }
            return path.hasSuffix(".json") ? json(list) : Response(status: 200, body: index(list, heading: "Notes"))

        case "/search":
            let q = query["q"] ?? ""
            guard !q.isEmpty else { return Response(status: 400, body: "Missing ?q=\n") }
            let hits = notes.filter {
                $0.body.localizedCaseInsensitiveContains(q) || $0.tags.contains { $0.localizedCaseInsensitiveContains(q) }
            }
            return Response(status: 200, body: index(hits, heading: "Search results for \"\(q)\""))

        case "/note":
            guard let title = query["title"], !title.isEmpty else { return Response(status: 400, body: "Missing ?title=\n") }
            guard let note = NoteLink.resolve(title, in: notes) else {
                return Response(status: 404, body: "No note titled \"\(title)\"\n")
            }
            return Response(status: 200, body: note.body)

        case "/templates":
            return Response(status: 200, body: templates())

        default:
            if path.hasPrefix("/notes/") {
                var id = String(path.dropFirst("/notes/".count))
                if id.hasSuffix(".md") { id.removeLast(3) }
                if let uuid = UUID(uuidString: id), let note = NoteLink.resolve(uuid, in: notes) {
                    return Response(status: 200, body: note.body)
                }
            }
            return Response(status: 404, body: "Not found. See \(Self.baseURL)/ for the available URLs.\n")
        }
    }

    // MARK: - Bodies

    private func help() -> String {
        let b = Self.baseURL
        return """
        # TextStudio notes

        Read-only access to the notes in TextStudio, as Markdown.

        - `\(b)/notes` — every note (title, id, folder, tags, last edit, URL), most recent first
        - `\(b)/notes?tag=bug` or `?folder=Work` — notes with that tag / in that folder
        - `\(b)/notes.json` — the same list as JSON (accepts the same filters)
        - `\(b)/notes/<id>` — one note's Markdown
        - `\(b)/note?title=<title>` — the note with that title (follows a `[[Title]]` link)
        - `\(b)/search?q=<text>` — notes whose text or tags contain `text`
        - `\(b)/templates` — the note templates

        Inside a note, `[[Title]]` or `[[Title|text]]` links to another note by title, and
        `textstudio://note/<id>` links to a note by id.

        """
    }

    private func index(_ notes: [Note], heading: String) -> String {
        guard !notes.isEmpty else { return "# \(heading)\n\nNo notes.\n" }
        var out = "# \(heading)\n\n"

        for n in notes {
            var meta = [n.updatedAt.formatted(.iso8601)]
            if let f = n.folder { meta.append("folder: \(f.name)") }
            if !n.tags.isEmpty { meta.append("tags: " + n.tags.map { "#" + $0 }.joined(separator: " ")) }
            out += "- **\(n.title)** — \(Self.url(for: n) ?? "")\n  \(meta.joined(separator: " · "))\n"
        }

        return out
    }

    private func json(_ notes: [Note]) -> Response {
        struct Item: Encodable {
            let id: String, title: String, folder: String?, tags: [String]
            let created: Date, updated: Date, url: String
        }

        let items = notes.map {
            Item(id: $0.uid?.uuidString ?? "", title: $0.title, folder: $0.folder?.name, tags: $0.tags,
                 created: $0.createdAt, updated: $0.updatedAt, url: Self.url(for: $0) ?? "")
        }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = (try? enc.encode(items)) ?? Data("[]".utf8)
        return Response(status: 200, type: "application/json; charset=utf-8", body: String(decoding: data, as: UTF8.self) + "\n")
    }

    private func templates() -> String {
        let user = (try? container?.mainContext.fetch(FetchDescriptor<NoteTemplate>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let all = TemplateItem.builtIns + user.map(TemplateItem.init)
        return all.map { "<!-- template: \($0.name) -->\n\($0.body)" }.joined(separator: "\n")
    }
}
