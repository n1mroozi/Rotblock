//
//  FileLogger.swift
//  rotblock
//
//

import Foundation

actor FileLogger {
  static let shared = FileLogger()

  // MARK: - Configuration

  private let maxBytes = 1_048_576  // 1 MB

  // MARK: - Paths

  private let logFile: URL
  private let backupFile: URL

  // MARK: - I/O

  private var handle: FileHandle?

  private let formatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    return dateFormatter
  }()

  // MARK: - Init

  private init() {
    let lib = FileManager.default
      .urls(for: .libraryDirectory, in: .userDomainMask).first!
    let dir = lib.appendingPathComponent("Logs/rotblock", isDirectory: true)
    logFile = dir.appendingPathComponent("app.log")
    backupFile = dir.appendingPathComponent("app.log.1")

    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    if !FileManager.default.fileExists(atPath: logFile.path) {
      FileManager.default.createFile(atPath: logFile.path, contents: nil)
    }
    handle = try? FileHandle(forWritingTo: logFile)
    handle?.seekToEndOfFile()
  }

  // MARK: - Writing

  /// Write a single log line. Automatically rotates if the file exceeds `maxBytes`.
  func write(level: String, category: String, message: String, metadata: [String: String] = [:]) {
    let ts = formatter.string(from: Date())
    let lvl = level.padding(toLength: 7, withPad: " ", startingAt: 0)
    var line = "\(ts) [\(lvl)] [\(category)] \(message)"
    if !metadata.isEmpty {
      let pairs = metadata.sorted(by: { $0.key < $1.key })
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: " ")
      line += " | \(pairs)"
    }
    line += "\n"

    guard let data = line.data(using: .utf8) else { return }
    rotateIfNeeded(adding: data.count)
    handle?.write(data)
  }

  // MARK: - Rotation

  private func rotateIfNeeded(adding bytes: Int) {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
      let size = attrs[.size] as? Int,
      size + bytes > maxBytes
    else { return }

    handle?.closeFile()
    handle = nil
    try? FileManager.default.removeItem(at: backupFile)
    try? FileManager.default.moveItem(at: logFile, to: backupFile)
    FileManager.default.createFile(atPath: logFile.path, contents: nil)
    handle = try? FileHandle(forWritingTo: logFile)
  }

  // MARK: - Reading

  /// URL of the current log file (use with ShareLink or UIActivityViewController).
  func logFileURL() -> URL { logFile }

  /// Last `count` non-empty lines from current + backup log files.
  /// Reading both helps when rotation has just occurred and `app.log` is still sparse.
  func tail(lines count: Int = 200) -> [String] {
    func lines(from url: URL) -> [String] {
      guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
      return text.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    let merged = lines(from: backupFile) + lines(from: logFile)
    return Array(merged.suffix(count))
  }

}
