import AppKit
import SwiftUI

enum Status: String, Sendable {
  case working, waiting, blocked, ready, closed

  var label: String {
    switch self {
    case .working: "Working now"
    case .waiting: "Waiting for you"
    case .blocked: "Blocked"
    case .ready: "Ready for the next chat"
    case .closed: "Closed or no kickoff"
    }
  }

  var color: Color {
    switch self {
    case .working: .green
    case .waiting: .orange
    case .blocked: .red
    case .ready: .blue
    case .closed: .gray
    }
  }
}

struct Epic: Identifiable, Sendable, Equatable {
  var slug: String
  var dir: String
  var kickoff: String?
  var cwd: String?
  var step: String?
  var blockers: [String] = []
  var modified = Date.distantPast
  var day = ""
  var time = ""
  var status = Status.closed
  var note: String?

  var handoffPath: String?

  var id: String { handoffPath ?? dir }
  var statePath: String { handoffPath ?? dir + "/state.md" }

  var kickoffBody: String? {
    guard let kickoff else { return nil }
    for prefix in ["epic \(slug): ", "\(slug): "] where kickoff.hasPrefix(prefix) {
      return String(kickoff.dropFirst(prefix.count))
    }
    return kickoff
  }

  var tooltip: String {
    [status.label, note, step].compactMap { $0 }.joined(separator: "\n")
  }
}

enum StateFile {
  static func apply(_ text: String, to epic: inout Epic) {
    var section = ""
    for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if let value = field("kickoff", in: line), epic.kickoff == nil {
        epic.kickoff = value.hasPrefix("(none") || value.count < 2 ? nil : value
      } else if let value = field("cwd", in: line), epic.cwd == nil {
        epic.cwd = value.isEmpty ? nil : value
      } else if line.hasPrefix("## ") {
        section = line
      } else if trimmed.isEmpty || trimmed.hasPrefix("<!--") {
        continue
      } else if section.hasPrefix("## Active slice"), epic.step == nil {
        epic.step = trimmed
      } else if section.hasPrefix("## Map"), trimmed.hasPrefix("[!]") {
        epic.blockers.append(trimmed)
      } else if section.hasPrefix("## Blocked on"), !["nothing", "none", "—", "-"].contains(trimmed.lowercased()) {
        epic.blockers.append(trimmed)
      }
    }
  }

  private static func field(_ name: String, in line: String) -> String? {
    guard line.hasPrefix(name + ":") else { return nil }
    return line.dropFirst(name.count + 1).trimmingCharacters(in: .whitespaces)
  }
}

enum HandoffFile {
  /// A handoff is front matter (`title:`, `cwd:`, `plan:`) between `---` lines, then the kickoff text.
  static func parse(_ text: String, path: String) -> Epic? {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else { return nil }
    var fields: [String: String] = [:]
    for line in lines[1..<end] {
      let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
      if parts.count == 2 { fields[parts[0]] = parts[1] }
    }
    let kickoff = lines[(end + 1)...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !kickoff.isEmpty else { return nil }
    let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    var epic = Epic(slug: fields["title"] ?? name, dir: URL(fileURLWithPath: path).deletingLastPathComponent().path)
    epic.kickoff = kickoff
    epic.cwd = fields["cwd"]
    epic.note = fields["plan"]
    epic.status = .ready
    epic.handoffPath = path
    return epic
  }
}

enum Gates {
  /// Maps gate id to its heading for every `## G-NN … pending` heading in gated-actions.md.
  static func pending(_ text: String) -> [String: String] {
    var result: [String: String] = [:]
    for line in text.split(separator: "\n").map(String.init)
    where line.hasPrefix("#") && line.localizedCaseInsensitiveContains("pending") {
      if let id = line.firstMatch(of: /G-\d+/) {
        result[String(id.output)] = line.drop { $0 == "#" || $0 == " " }.description
      }
    }
    return result
  }
}

extension Epic {
  static let workingWindow: TimeInterval = 20 * 60

  mutating func resolveStatus(pendingGates: [String: String], journalModified: Date?, now: Date) {
    let named = blockers.flatMap { $0.matches(of: /G-\d+/).map { String($0.output) } }
    if let journalModified, now.timeIntervalSince(journalModified) < Epic.workingWindow {
      status = .working
    } else if let gate = named.first(where: { pendingGates[$0] != nil }) {
      status = .waiting
      note = pendingGates[gate]
    } else if let first = blockers.first {
      status = .blocked
      note = first
    } else {
      status = kickoff == nil ? .closed : .ready
    }
  }
}

enum Listing {
  /// Parses `epic-list.sh` output into (root, slug) pairs; root lines are unindented, slug lines indented by two spaces.
  static func parse(_ text: String) -> [(root: String, slug: String)] {
    var result: [(String, String)] = []
    var root = ""
    for line in text.split(separator: "\n").map(String.init) {
      if !line.hasPrefix(" ") {
        root = line.range(of: "  (", options: .backwards).map { String(line[..<$0.lowerBound]) } ?? ""
      } else if !line.hasPrefix("   "), !root.isEmpty,
        let slug = line.split(separator: " ").first
      {
        result.append((root, String(slug)))
      }
    }
    return result
  }
}

enum Loader {
  static let rootsPath = NSHomeDirectory() + "/.config/epic-tree/roots"

  static func roots() -> [String] {
    let text = (try? String(contentsOfFile: rootsPath, encoding: .utf8)) ?? ""
    return text.split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && !$0.hasPrefix("#") }
      .map { NSString(string: $0).expandingTildeInPath }
  }

  static let handoffsPath = NSHomeDirectory() + "/.claude/handoffs"

  static func load() -> [Epic] {
    (epics() + handoffs()).sorted { $0.modified > $1.modified }
  }

  static func handoffs() -> [Epic] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: handoffsPath)) ?? []
    return names.filter { $0.hasSuffix(".md") }.compactMap { name in
      let path = handoffsPath + "/" + name
      guard let text = try? String(contentsOfFile: path, encoding: .utf8),
        var epic = HandoffFile.parse(text, path: path)
      else { return nil }
      epic.modified = modified(path) ?? .distantPast
      epic.day = Clock.day(epic.modified)
      epic.time = Clock.time(epic.modified)
      return epic
    }
  }

  static func epics() -> [Epic] {
    let roots = roots()
    guard !roots.isEmpty,
      let home = Bundle.main.object(forInfoDictionaryKey: "EpicTreeHome") as? String
        ?? ProcessInfo.processInfo.environment["EPIC_TREE_HOME"]
    else { return [] }

    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [home + "/bin/epic-list.sh"] + roots
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return [] }
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()

    let files = FileManager.default
    let now = Date.now
    return Listing.parse(output).compactMap { root, slug in
      let candidates = ["\(root)/epics/\(slug)", "\(root)/.claude/epics/\(slug)"]
      guard let dir = candidates.first(where: { files.fileExists(atPath: $0) }) else { return nil }
      var epic = Epic(slug: slug, dir: dir)
      if let text = try? String(contentsOfFile: epic.statePath, encoding: .utf8) {
        StateFile.apply(text, to: &epic)
      }
      let journal = (try? files.contentsOfDirectory(atPath: dir + "/journal")) ?? []
      let journalModified = journal.compactMap { modified(dir + "/journal/" + $0) }.max()
      let stateModified = modified(epic.statePath) ?? .distantPast
      let openJournal = journalModified.flatMap { $0 > stateModified ? $0 : nil }
      epic.modified = max(stateModified, journalModified ?? .distantPast)
      epic.day = Clock.day(epic.modified)
      epic.time = Clock.time(epic.modified)
      let gates = (try? String(contentsOfFile: dir + "/gated-actions.md", encoding: .utf8)) ?? ""
      epic.resolveStatus(pendingGates: Gates.pending(gates), journalModified: openJournal, now: now)
      return epic
    }
  }

  private static func modified(_ path: String) -> Date? {
    (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
  }
}

enum Clock {
  static func day(_ date: Date = .now) -> String { format(date, "yyyy-MM-dd") }
  static func time(_ date: Date) -> String { format(date, "HH:mm") }

  static func weekStart(weeksAgo: Int) -> String {
    let calendar = Calendar(identifier: .iso8601)
    let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    return day(calendar.date(byAdding: .day, value: -7 * weeksAgo, to: start) ?? start)
  }

  private static func format(_ date: Date, _ pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = pattern
    return formatter.string(from: date)
  }
}

@MainActor @Observable
final class Model {
  var epics: [Epic] = []
  var copiedID: String?
  var today = Clock.day()
  var weekStart = Clock.weekStart(weeksAgo: 0)
  var lastWeekStart = Clock.weekStart(weeksAgo: 1)

  var needsYou: Int {
    epics.count { ($0.status == .waiting || $0.status == .ready) && $0.day >= weekStart }
  }

  init() {
    Task { [weak self] in
      while let self {
        await self.refresh()
        try? await Task.sleep(for: .seconds(30))
      }
    }
  }

  func refresh() async {
    epics = await Task.detached { Loader.load() }.value
    today = Clock.day()
    weekStart = Clock.weekStart(weeksAgo: 0)
    lastWeekStart = Clock.weekStart(weeksAgo: 1)
  }

  func copy(_ text: String, id: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    copiedID = id
    Task {
      try? await Task.sleep(for: .seconds(1.5))
      if copiedID == id { copiedID = nil }
    }
  }
}

struct StatusDot: View {
  let status: Status
  @State private var dimmed = false

  var body: some View {
    Circle()
      .fill(status.color)
      .frame(width: 8, height: 8)
      .opacity(status == .working && dimmed ? 0.25 : 1)
      .onAppear {
        guard status == .working else { return }
        withAnimation(.easeInOut(duration: 0.9).repeatForever()) { dimmed = true }
      }
  }
}

struct EpicRow: View {
  let epic: Epic
  let model: Model
  @State private var hovering = false

  var body: some View {
    Button {
      if let kickoff = epic.kickoff { model.copy(kickoff, id: epic.id) }
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          StatusDot(status: epic.status)
          Text(epic.slug).font(.system(.body, design: .monospaced)).bold().lineLimit(1)
          if epic.handoffPath != nil {
            Text("handoff").font(.caption2).foregroundStyle(.secondary)
              .padding(.horizontal, 4).background(Color.primary.opacity(0.1), in: .capsule)
          }
          Spacer()
          Text(model.copiedID == epic.id ? "Copied" : stamp)
            .font(.caption)
            .foregroundStyle(model.copiedID == epic.id ? Color.accentColor : .secondary)
        }
        if epic.status == .waiting || epic.status == .blocked, let note = epic.note {
          Text(note).font(.caption).foregroundStyle(epic.status.color).lineLimit(1)
        }
        if let body = epic.kickoffBody {
          Text(body).font(.callout).foregroundStyle(.secondary).lineLimit(2)
        }
        if let cwd = epic.cwd {
          Text(cwd).font(.caption.monospaced()).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.head)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(hovering ? Color.primary.opacity(0.08) : .clear, in: .rect(cornerRadius: 6))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(epic.kickoff == nil)
    .onHover { hovering = $0 }
    .help(epic.tooltip)
    .contextMenu {
      if let cwd = epic.cwd {
        Button("Copy cwd") { model.copy(cwd, id: epic.id) }
      }
      Button(epic.handoffPath == nil ? "Open state.md" : "Open handoff file") { NSWorkspace.shared.open(URL(fileURLWithPath: epic.statePath)) }
      Button("Show in Finder") {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: epic.dir)
      }
    }
  }

  private var stamp: String {
    let when = epic.day == model.today ? epic.time : epic.day
    return epic.status == .working ? "working · \(when)" : when
  }
}

struct PanelView: View {
  let model: Model
  @State private var showThisWeek = true
  @State private var showLastWeek = false
  @State private var showOlder = false
  @State private var showClosed = false

  var body: some View {
    let open = model.epics.filter { $0.status != .closed }
    let today = open.filter { $0.day == model.today }
    let thisWeek = open.filter { $0.day >= model.weekStart && $0.day < model.today }
    let lastWeek = open.filter { $0.day >= model.lastWeekStart && $0.day < model.weekStart }
    let older = open.filter { $0.day < model.lastWeekStart }
    let closed = model.epics.filter { $0.status == .closed }

    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 2) {
          if model.epics.isEmpty {
            Text("No epics found. List one root directory per line in \(Loader.rootsPath).")
              .font(.callout).foregroundStyle(.secondary).padding(8)
          }
          if !today.isEmpty {
            header("Today")
            rows(today)
          }
          group("This week", thisWeek, $showThisWeek)
          group("Last week", lastWeek, $showLastWeek)
          group("Older", older, $showOlder)
          group("Closed or no kickoff", closed, $showClosed)
        }
        .padding(8)
      }
      Divider()
      HStack(spacing: 10) {
        ForEach([Status.working, .waiting, .blocked, .ready], id: \.self) { status in
          HStack(spacing: 4) {
            StatusDot(status: status)
            Text(status.label).font(.caption2).foregroundStyle(.secondary)
          }
        }
      }
      .padding(.top, 6)
      HStack {
        Text("Click a row to copy its kickoff").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("Refresh") { Task { await model.refresh() } }
        Button("Quit") { NSApp.terminate(nil) }
      }
      .controlSize(.small)
      .padding(8)
    }
    .frame(width: 480, height: 560)
  }

  private func header(_ title: String) -> some View {
    Text(title.uppercased()).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8).padding(.top, 4)
  }

  @ViewBuilder
  private func group(_ title: String, _ epics: [Epic], _ expanded: Binding<Bool>) -> some View {
    if !epics.isEmpty {
      DisclosureGroup(isExpanded: expanded) { rows(epics) } label: {
        header("\(title) (\(epics.count))")
      }
    }
  }

  private func rows(_ epics: [Epic]) -> some View {
    ForEach(epics) { EpicRow(epic: $0, model: model) }
  }
}

struct EpicBarApp: App {
  @State private var model = Model()

  var body: some Scene {
    MenuBarExtra {
      PanelView(model: model)
    } label: {
      Label("\(model.needsYou)", systemImage: "square.stack.3d.up").labelStyle(.titleAndIcon)
    }
    .menuBarExtraStyle(.window)
  }
}

if CommandLine.arguments.contains("--dump") {
  for epic in Loader.load() {
    print([epic.slug, epic.day, epic.time, epic.status.rawValue, epic.note ?? "-"].joined(separator: "\t"))
  }
} else {
  EpicBarApp.main()
}
