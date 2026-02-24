//
//  ParakeetTranscriptionService.swift
//  SwiftSpeakMac
//
//  On-device transcription using NVIDIA Parakeet TDT v3 via parakeet-mlx CLI
//  macOS only - requires parakeet-mlx Python package installed
//

import Foundation
import SwiftSpeakCore

/// Transcription service that wraps the parakeet-mlx CLI tool
/// Runs NVIDIA Parakeet TDT v3 (600M params) locally on Apple Silicon via MLX
final class ParakeetTranscriptionService: TranscriptionProvider {

    // MARK: - TranscriptionProvider Conformance

    let providerId: AIProvider = .parakeetMLX

    var isConfigured: Bool {
        config.status == .ready && config.isEnabled
    }

    var model: String {
        config.modelId
    }

    // MARK: - Properties

    private let config: ParakeetMLXSettings

    init(config: ParakeetMLXSettings) {
        self.config = config
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.providerNotConfigured
        }

        // Find parakeet-mlx executable
        let executablePath = try await findExecutable()

        // Create temporary output directory
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("parakeet_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tmpDir)
        }

        // Build command arguments
        var arguments = [audioURL.path]
        arguments.append(contentsOf: ["--output-format", "json"])
        arguments.append(contentsOf: ["--output-dir", tmpDir.path])

        // Parakeet TDT v3 auto-detects language — no --language flag available

        macLog("Running parakeet-mlx: \(executablePath) \(arguments.joined(separator: " "))",
               category: "Parakeet")

        // Run parakeet-mlx process
        let (stdout, stderr, exitCode) = try await runProcess(
            executablePath: executablePath,
            arguments: arguments
        )

        guard exitCode == 0 else {
            let errorMsg = stderr.isEmpty ? "Exit code \(exitCode)" : stderr
            macLog("parakeet-mlx failed: \(errorMsg)", category: "Parakeet", level: .error)
            throw TranscriptionError.unexpectedResponse("Parakeet MLX failed: \(errorMsg)")
        }

        // Parse JSON output
        let text = try parseOutput(from: tmpDir, audioURL: audioURL, stdout: stdout)

        guard !text.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        macLog("Parakeet transcription complete: \(text.prefix(100))...", category: "Parakeet")
        return text
    }

    func validateAPIKey(_ key: String) async -> Bool {
        // No API key needed for local provider
        true
    }

    // MARK: - Installation Check

    /// Check if parakeet-mlx is installed and accessible
    static func checkInstallation() async -> (installed: Bool, path: String?, error: String?) {
        // Try direct command first
        if let path = try? await findInPath("parakeet-mlx") {
            return (true, path, nil)
        }

        // Try as Python module
        do {
            let (_, _, exitCode) = try await runProcessStatic(
                executablePath: "/usr/bin/env",
                arguments: ["python3", "-m", "parakeet_mlx", "--help"]
            )
            if exitCode == 0 {
                return (true, "python3 -m parakeet_mlx", nil)
            }
        } catch {
            // Ignore - will return not installed
        }

        return (false, nil, "parakeet-mlx not found. Install with: pip install parakeet-mlx")
    }

    // MARK: - Private Helpers

    private func findExecutable() async throws -> String {
        // Try direct command first
        if let path = try? await Self.findInPath("parakeet-mlx") {
            return path
        }

        // Try common Python locations on macOS
        let commonPaths = [
            "/opt/homebrew/bin/parakeet-mlx",
            "/usr/local/bin/parakeet-mlx",
            "\(NSHomeDirectory())/.local/bin/parakeet-mlx",
            "\(NSHomeDirectory())/Library/Python/3.11/bin/parakeet-mlx",
            "\(NSHomeDirectory())/Library/Python/3.12/bin/parakeet-mlx",
            "\(NSHomeDirectory())/Library/Python/3.13/bin/parakeet-mlx",
        ]

        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        throw TranscriptionError.providerNotConfigured
    }

    private static func findInPath(_ command: String) async throws -> String? {
        let (stdout, _, exitCode) = try await runProcessStatic(
            executablePath: "/usr/bin/which",
            arguments: [command]
        )

        if exitCode == 0, !stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Also try with user's shell PATH (which may include homebrew, pyenv, etc.)
        let (stdout2, _, exitCode2) = try await runProcessStatic(
            executablePath: "/bin/zsh",
            arguments: ["-l", "-c", "which \(command)"]
        )

        if exitCode2 == 0, !stdout2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stdout2.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func parseOutput(from outputDir: URL, audioURL: URL, stdout: String) throws -> String {
        // parakeet-mlx outputs JSON files named after the input file
        let baseName = audioURL.deletingPathExtension().lastPathComponent
        let jsonFile = outputDir.appendingPathComponent("\(baseName).json")

        if FileManager.default.fileExists(atPath: jsonFile.path) {
            let data = try Data(contentsOf: jsonFile)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Try txt fallback
        let txtFile = outputDir.appendingPathComponent("\(baseName).txt")
        if FileManager.default.fileExists(atPath: txtFile.path) {
            let text = try String(contentsOf: txtFile, encoding: .utf8)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fall back to stdout
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        throw TranscriptionError.unexpectedResponse("No transcription output found")
    }

    /// Map SwiftSpeak Language to ISO 639-1 codes supported by Parakeet TDT v3
    /// Parakeet TDT v3 supports 25 European languages
    private func parakeetLanguageCode(for language: Language) -> String? {
        switch language {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .polish: return "pl"
        case .russian: return "ru"
        case .chinese, .japanese, .korean, .arabic, .egyptianArabic:
            return nil  // Not supported by Parakeet TDT v3
        }
    }

    // MARK: - Process Execution

    private func runProcess(executablePath: String, arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        try await Self.runProcessStatic(executablePath: executablePath, arguments: arguments)
    }

    private static func runProcessStatic(executablePath: String, arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        // Inherit user's PATH for finding Python and dependencies
        var environment = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/Library/Python/3.11/bin",
            "\(NSHomeDirectory())/Library/Python/3.12/bin",
            "\(NSHomeDirectory())/Library/Python/3.13/bin",
        ]
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin"
        environment["PATH"] = (additionalPaths + [existingPath]).joined(separator: ":")
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw TranscriptionError.unexpectedResponse("Failed to launch parakeet-mlx: \(error.localizedDescription)")
        }

        // Read pipe data concurrently to avoid deadlock when output exceeds pipe buffer
        async let stdoutData = Task.detached {
            stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        }.value
        async let stderrData = Task.detached {
            stderrPipe.fileHandleForReading.readDataToEndOfFile()
        }.value

        let (outData, errData) = await (stdoutData, stderrData)
        process.waitUntilExit()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        return (stdout, stderr, process.terminationStatus)
    }
}
