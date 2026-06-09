import Foundation
import os

@MainActor
final class CommandLineService {

    private static let commandName = "mdr"
    private static let installPath = "/usr/local/bin/\(commandName)"

    private let logger = Logger(subsystem: "com.ft07.markmark", category: "CommandLineService")

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: Self.installPath)
    }

    func install(completion: @MainActor @escaping (Bool) -> Void = { _ in }) {
        let scriptContent = #"#!/bin/bash"#
            + "\n"
            + #"open -b com.ft07.markmark "$@""#
            + "\n"

        let tempDir = NSTemporaryDirectory()
        let tempPath = (tempDir as NSString).appendingPathComponent(Self.commandName)

        do {
            try scriptContent.write(toFile: tempPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempPath)
        } catch {
            logger.error("Failed to write temp script: \(error.localizedDescription)")
            completion(false)
            return
        }

        let appleScript = """
        do shell script "cp -f '\(tempPath)' '\(Self.installPath)' && chmod 755 '\(Self.installPath)'" with administrator privileges
        """

        runAppleScript(appleScript) { [weak self] success in
            try? FileManager.default.removeItem(atPath: tempPath)
            if success {
                self?.logger.info("mdr command installed successfully")
            } else {
                self?.logger.error("Failed to install mdr command")
            }
            completion(success)
        }
    }

    func uninstall(completion: @MainActor @escaping (Bool) -> Void = { _ in }) {
        guard isInstalled else {
            completion(true)
            return
        }

        let appleScript = """
        do shell script "rm -f '\(Self.installPath)'" with administrator privileges
        """

        runAppleScript(appleScript) { [weak self] success in
            if success {
                self?.logger.info("mdr command uninstalled successfully")
            } else {
                self?.logger.error("Failed to uninstall mdr command")
            }
            completion(success)
        }
    }

    private func runAppleScript(_ source: String, completion: @MainActor @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", source]

            let pipe = Pipe()
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()
                let success = task.terminationStatus == 0
                DispatchQueue.main.async {
                    completion(success)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}
