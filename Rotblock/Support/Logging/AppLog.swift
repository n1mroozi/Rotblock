//
//  AppLog.swift
//  rotblock

import Foundation
import OSLog

// MARK: - Log namespace

enum AppLog {
  private static let subsystem: String =
    Bundle.main.bundleIdentifier ?? "com.n1labs.rotblock"

  /// Blocking preset activation, deactivation, pause/resume.
  static let blocking = LogChannel(subsystem: subsystem, category: "blocking")
  /// Preset CRUD operations (create, update, delete).
  static let presets = LogChannel(subsystem: subsystem, category: "presets")
  /// UI lifecycle events (launch, foreground, navigation).
  static let ui = LogChannel(subsystem: subsystem, category: "ui")
}

// MARK: - LogChannel

/// A single logging channel that fans out to os.Logger and FileLogger.
struct LogChannel {
  let category: String
  private let logger: Logger

  init(subsystem: String, category: String) {
    self.category = category
    self.logger = Logger(subsystem: subsystem, category: category)
  }

  // MARK: Log levels

  func debug(_ msg: String, metadata: [String: String] = [:]) {
    logger.debug("\(msg, privacy: .public)")
    sink("DEBUG", msg, metadata)
  }

  func info(_ msg: String, metadata: [String: String] = [:]) {
    logger.info("\(msg, privacy: .public)")
    sink("INFO", msg, metadata)
  }

  func warning(_ msg: String, metadata: [String: String] = [:]) {
    logger.warning("\(msg, privacy: .public)")
    sink("WARNING", msg, metadata)
  }

  func error(_ msg: String, metadata: [String: String] = [:]) {
    logger.error("\(msg, privacy: .public)")
    sink("ERROR", msg, metadata)
  }

  func fault(_ msg: String, metadata: [String: String] = [:]) {
    logger.fault("\(msg, privacy: .public)")
    sink("FAULT", msg, metadata)
  }

  // MARK: - Private

  private func sink(_ level: String, _ msg: String, _ metadata: [String: String]) {
    let cat = category
    Task.detached(priority: .background) {
      await FileLogger.shared.write(level: level, category: cat, message: msg, metadata: metadata)
    }
  }
}
