
import Combine
import SwiftUI

/**
 Comprehensive error handling system for capturing,
 displaying, and logging errors throughout the application.
 */

// MARK: - AppError

/// Application-specific error types
enum AppError: Error, Identifiable {
    case audioEngineFailure(String)
    case quantumSimulationFailure(String)
    case renderingFailure(String)
    case fileAccessFailure(String)
    case invalidParameters(String)
    case unknownError(String)

    var id: String {
        switch self {
        case .audioEngineFailure(let message): return "audio_\(message.hashValue)"
        case .quantumSimulationFailure(let message): return "quantum_\(message.hashValue)"
        case .renderingFailure(let message): return "render_\(message.hashValue)"
        case .fileAccessFailure(let message): return "file_\(message.hashValue)"
        case .invalidParameters(let message): return "params_\(message.hashValue)"
        case .unknownError(let message): return "unknown_\(message.hashValue)"
        }
    }

    var title: String {
        switch self {
        case .audioEngineFailure: return "Audio Engine Error"
        case .quantumSimulationFailure: return "Quantum Simulation Error"
        case .renderingFailure: return "Rendering Error"
        case .fileAccessFailure: return "File Access Error"
        case .invalidParameters: return "Invalid Parameters"
        case .unknownError: return "Unknown Error"
        }
    }

    var message: String {
        switch self {
        case .audioEngineFailure(let msg),
            .quantumSimulationFailure(let msg),
            .renderingFailure(let msg),
            .fileAccessFailure(let msg),
            .invalidParameters(let msg),
            .unknownError(let msg):
            return msg
        }
    }

    var systemIcon: String {
        switch self {
        case .audioEngineFailure: return "speaker.wave.3.fill"
        case .quantumSimulationFailure: return "atom"
        case .renderingFailure: return "display"
        case .fileAccessFailure: return "doc.fill"
        case .invalidParameters: return "exclamationmark.triangle.fill"
        case .unknownError: return "questionmark.circle.fill"
        }
    }

    var severity: ErrorSeverity {
        switch self {
        case .audioEngineFailure, .renderingFailure, .fileAccessFailure:
            return .warning
        case .quantumSimulationFailure, .invalidParameters:
            return .error
        case .unknownError:
            return .critical
        }
    }
}

/// Error severity levels
enum ErrorSeverity {
    case info
    case warning
    case error
    case critical

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - ErrorManager

/// Centralized error management system
class ErrorManager: ObservableObject {
    // Published properties
    @Published var currentError: AppError?
    @Published var showingError: Bool = false
    @Published var errorLog: [ErrorLogEntry] = []

    // Logging options
    var loggingEnabled: Bool = true
    var verboseLogging: Bool = false
    var maxLogEntries: Int = 100

    // Singleton instance
    static let shared = ErrorManager()

    private init() {}

    /// Report an error
    func reportError(_ error: AppError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.showingError = true

            if self.loggingEnabled {
                self.logError(error)
            }

            // Print to console in development
            #if DEBUG
                print("ERROR: \(error.title) - \(error.message)")
            #endif
        }
    }

    /// Log error to internal log
    private func logError(_ error: AppError) {
        let entry = ErrorLogEntry(
            timestamp: Date(),
            error: error,
            additionalInfo: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        )

        errorLog.append(entry)

        // Trim log if too long
        if errorLog.count > maxLogEntries {
            errorLog.removeFirst(errorLog.count - maxLogEntries)
        }
    }

    /// Clear the error log
    func clearErrorLog() {
        errorLog.removeAll()
    }

    /// Export error log to file
    func exportErrorLog() -> URL? {
        guard !errorLog.isEmpty else { return nil }

        // Create log content
        var logContent = "QwantumWaveform Error Log\n"
        logContent += "Generated: \(Date())\n\n"

        for (index, entry) in errorLog.enumerated() {
            logContent += "[\(index + 1)] \(entry.timestamp)\n"
            logContent += "Type: \(entry.error.title)\n"
            logContent += "Message: \(entry.error.message)\n"
            logContent += "Severity: \(entry.error.severity)\n"
            logContent += "Version: \(entry.additionalInfo)\n\n"
        }

        // Write to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(
            "QwantumWaveform_ErrorLog_\(Date().timeIntervalSince1970).txt")

        do {
            try logContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write error log: \(error)")
            return nil
        }
    }
}

/// Structure for storing error log entries
struct ErrorLogEntry: Identifiable {
    var id = UUID()
    let timestamp: Date
    let error: AppError
    let additionalInfo: String
}

// MARK: - Error Handling View Modifier

/// SwiftUI modifier for adding error handling to views
struct ErrorHandlingModifier: ViewModifier {
    @ObservedObject var errorManager = ErrorManager.shared

    func body(content: Content) -> some View {
        content
            .alert(
                isPresented: $errorManager.showingError,
                content: {
                    Alert(
                        title: Text(errorManager.currentError?.title ?? "Error"),
                        message: Text(
                            errorManager.currentError?.message ?? "An unknown error occurred."),
                        dismissButton: .default(Text("OK"))
                    )
                })
    }
}

// MARK: - Error Banner View

/// Floating error banner that shows and automatically dismisses
struct ErrorBannerView: View {
    @ObservedObject var errorManager = ErrorManager.shared
    @State private var showBanner = false

    var body: some View {
        VStack {
            if showBanner, let error = errorManager.currentError {
                HStack(spacing: 16) {
                    Image(systemName: error.systemIcon)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(error.title)
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(error.message)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Button(action: {
                        withAnimation(.easeOut) {
                            showBanner = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(error.severity.color)
                .cornerRadius(8)
                .shadow(radius: 4)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .onChange(of: errorManager.showingError) { oldValue, newValue in
            if newValue {
                showBannerWithTimeout()
            }
        }
    }

    private func showBannerWithTimeout() {
        withAnimation(.easeIn) {
            showBanner = true
        }

        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut) {
                showBanner = false
            }
        }
    }
}

// MARK: - Error Log View

/// View for displaying and exporting the error log
struct ErrorLogView: View {
    @ObservedObject var errorManager = ErrorManager.shared
    @State private var showingExportDialog = false
    @State private var exportURL: URL?

    var body: some View {
        VStack {
            HStack {
                Text("Error Log")
                    .font(.headline)

                Spacer()

                Button(action: {
                    exportURL = errorManager.exportErrorLog()
                    showingExportDialog = exportURL != nil
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(errorManager.errorLog.isEmpty)

                Button(action: {
                    errorManager.clearErrorLog()
                }) {
                    Image(systemName: "trash")
                }
                .disabled(errorManager.errorLog.isEmpty)
            }
            .padding()

            if errorManager.errorLog.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                        .padding()

                    Text("No errors have been logged")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(errorManager.errorLog) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: entry.error.systemIcon)
                                    .foregroundColor(entry.error.severity.color)

                                Text(entry.error.title)
                                    .font(.headline)

                                Spacer()

                                Text(formatDate(entry.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(entry.error.message)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.leading, 26)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportDialog) {
            ExportView(url: exportURL)
        }
    }

    // View for handling exports
    private struct ExportView: View {
        let url: URL?

        var body: some View {
            VStack {
                if let url = url {
                    #if os(macOS)
                        Text("Exporting error log...")
                            .onAppear {
                                let panel = NSSavePanel()
                                panel.nameFieldStringValue = url.lastPathComponent
                                panel.directoryURL =
                                    FileManager.default.urls(
                                        for: .documentDirectory, in: .userDomainMask
                                    ).first
                                panel.allowedContentTypes = [.text]

                                if panel.runModal() == .OK, let saveURL = panel.url {
                                    do {
                                        try FileManager.default.copyItem(at: url, to: saveURL)
                                    } catch {
                                        print("Export failed: \(error)")
                                    }
                                }
                            }
                    #else
                        Text("Export not available on this platform")
                    #endif
                } else {
                    Text("No file to export")
                }
            }
            .frame(width: 0, height: 0)  // Make the view invisible
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Extensions

extension View {
    /// Apply error handling to a view
    func withErrorHandling() -> some View {
        self.modifier(ErrorHandlingModifier())
    }
}

// MARK: - Error Reporting Convenience Functions

/// Convenience function for reporting errors
func reportError(_ error: AppError) {
    ErrorManager.shared.reportError(error)
}

/// Create and report an audio engine error
func reportAudioError(_ message: String) {
    reportError(.audioEngineFailure(message))
}

/// Create and report a quantum simulation error
func reportQuantumError(_ message: String) {
    reportError(.quantumSimulationFailure(message))
}

/// Create and report a rendering error
func reportRenderingError(_ message: String) {
    reportError(.renderingFailure(message))
}

/// Create and report a file access error
func reportFileError(_ message: String) {
    reportError(.fileAccessFailure(message))
}

/// Create and report an invalid parameters error
func reportParameterError(_ message: String) {
    reportError(.invalidParameters(message))
}

/// Create and report an unknown error
func reportUnknownError(_ message: String) {
    reportError(.unknownError(message))
}
