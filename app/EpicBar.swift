import AppKit
import SwiftUI

struct Epic: Identifiable, Sendable, Equatable {
  var slug: String
  var dir: String
  var updated = ""
  var kickoff: String?
  var cwd: String?
  var step: String?

  var id: String { dir }
  var statePath: String { dir + "/state.md" }

  var kickoffBody: String? {
    guard let kickoff else { return nil }
    for prefix in ["epic \(slug): ", "\(slug): "] where kickoff.hasPrefix(prefix) {
      return String(kickoff.dropFirst(prefix.count))
    }
    return kickoff
  }

  func stamp(today: String) -> String {
    let parts = updated.split(separator: "T", maxSplits: 1).map(String.init)
    guard let day = parts.first else { return "—" }
    return day == today && parts.count == 2 ? String(parts[1].prefix(5)) : day
  }
}

enum StateFile {
  static func apply(_ text: String, to epic: inout Epic) {
    var inActiveSlice = false
    for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
      if let value = field("updated", in: line), epic.updated.isEmpty {
        epic.updated = String(value.split(separator: " ").first ?? "")
      } else if let value = field("kickoff", in: line), epic.kickoff == nil {
        epic.kickoff = value.hasPrefix("(none") || value.isEmpty ? nil : value
      } else if let value = field("cwd", in: line), epic.cwd == nil {
        epic.cwd = value.isEmpty ? nil : value
      } else if line.hasPrefix("## ") {
        inActiveSlice = line.hasPrefix("## Active slice")
      } else if inActiveSlice, epic.step == nil, !line.trimmingCharacters(in: .whitespaces).isEmpty {
        epic.step = line
      }
    }
  }

  private static func field(_ name: String, in line: String) -> String? {
    guard line.hasPrefix(name + ":") else { return nil }
    return line.dropFirst(name.count + 1).trimmingCharacters(in: .whitespaces)
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

  static func load() -> [Epic] {
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
    return Listing.parse(output).compactMap { root, slug in
      let candidates = ["\(root)/epics/\(slug)", "\(root)/.claude/epics/\(slug)"]
      guard let dir = candidates.first(where: { files.fileExists(atPath: $0) }) else { return nil }
      var epic = Epic(slug: slug, dir: dir)
      if let text = try? String(contentsOfFile: epic.statePath, encoding: .utf8) {
        StateFile.apply(text, to: &epic)
      }
      return epic
    }
    .sorted { $0.updated > $1.updated }
  }
}

@MainActor @Observable
final class Model {
  var epics: [Epic] = []
  var copiedID: String?
  var today = Model.dayString()
  var weekStart = Model.weekStart(weeksAgo: 0)
  var lastWeekStart = Model.weekStart(weeksAgo: 1)

  var waiting: Int { epics.count { $0.kickoff != nil && $0.updated.hasPrefix(today) } }

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
    today = Model.dayString()
    weekStart = Model.weekStart(weeksAgo: 0)
    lastWeekStart = Model.weekStart(weeksAgo: 1)
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

  static func dayString(_ date: Date = .now) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  static func weekStart(weeksAgo: Int) -> String {
    let calendar = Calendar(identifier: .iso8601)
    let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    return dayString(calendar.date(byAdding: .day, value: -7 * weeksAgo, to: start) ?? start)
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
        HStack {
          Text(epic.slug).font(.system(.body, design: .monospaced)).bold()
          Spacer()
          Text(model.copiedID == epic.id ? "Copied" : epic.stamp(today: model.today))
            .font(.caption)
            .foregroundStyle(model.copiedID == epic.id ? Color.accentColor : .secondary)
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
    .help(epic.step ?? "")
    .contextMenu {
      if let cwd = epic.cwd {
        Button("Copy cwd") { model.copy(cwd, id: epic.id) }
      }
      Button("Open state.md") { NSWorkspace.shared.open(URL(fileURLWithPath: epic.statePath)) }
      Button("Show in Finder") {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: epic.dir)
      }
    }
  }
}

struct PanelView: View {
  let model: Model
  @State private var showThisWeek = true
  @State private var showLastWeek = false
  @State private var showOlder = false
  @State private var showIdle = false

  var body: some View {
    let withKickoff = model.epics.filter { $0.kickoff != nil }
    let today = withKickoff.filter { $0.updated.hasPrefix(model.today) }
    let thisWeek = withKickoff.filter { $0.updated >= model.weekStart && $0.updated < model.today }
    let lastWeek = withKickoff.filter { $0.updated >= model.lastWeekStart && $0.updated < model.weekStart }
    let older = withKickoff.filter { $0.updated < model.lastWeekStart }
    let idle = model.epics.filter { $0.kickoff == nil }

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
          group("No kickoff", idle, $showIdle)
        }
        .padding(8)
      }
      Divider()
      HStack {
        Text("Click a row to copy its kickoff").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("Refresh") { Task { await model.refresh() } }
        Button("Quit") { NSApp.terminate(nil) }
      }
      .controlSize(.small)
      .padding(8)
    }
    .frame(width: 460, height: 540)
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
      Label("\(model.waiting)", systemImage: "square.stack.3d.up").labelStyle(.titleAndIcon)
    }
    .menuBarExtraStyle(.window)
  }
}

if CommandLine.arguments.contains("--dump") {
  for epic in Loader.load() {
    print([epic.slug, epic.updated, epic.cwd ?? "-", epic.kickoff ?? "-"].joined(separator: "\t"))
  }
} else {
  EpicBarApp.main()
}
