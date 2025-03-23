import Combine
import Foundation
import MetalKit
import SwiftUI

// MARK: - Audio Export Types

enum AudioExportFormat: String, CaseIterable, Identifiable {
    case wav
    case aiff
    case mp3

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wav: return "WAV"
        case .aiff: return "AIFF"
        case .mp3: return "MP3"
        }
    }

    var fileExtension: String { rawValue }
}

// Define export format options
enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"
    case matFile = "MATLAB (.mat)"
    case image = "Image (.png)"

    var id: String { self.rawValue }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .matFile: return "mat"
        case .image: return "png"
        }
    }
}

/// Main view component for the QwantumWaveform app that integrates all visualization
/// components with a professional, scientific-focused user interface.
struct MainView: View {
    @StateObject private var viewModel = WaveformViewModel()
    @State private var showSidebar: Bool = true
    @State private var isPresentingPreferences: Bool = false
    @State private var isPresentingExport: Bool = false
    @State private var isPlayingAudio: Bool = false
    @State private var rendererNeedsInitialization: Bool = true

    // MARK: - Performance Metrics

    /// Struct to hold visualization performance metrics
    private struct PerformanceMetrics {
        var frameTime: Double = 0
        var frameRate: Double = 0
        var memoryUsage: UInt64 = 0
        var lastUpdateTime: Date = Date()

        mutating func update(frameTime: Double) {
            self.frameTime = frameTime
            if Date().timeIntervalSince(lastUpdateTime) >= 0.5 {
                // Update less frequently to avoid UI flicker
                frameRate = 1.0 / max(0.001, frameTime)
                lastUpdateTime = Date()
            }
        }
    }

    @State private var performanceMetrics = PerformanceMetrics()
    @State private var showPerformanceMetrics: Bool = false

    /// View to display performance metrics overlay
    private var performanceMetricsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FPS: \(Int(performanceMetrics.frameRate))")
            Text("Frame: \(String(format: "%.1f", performanceMetrics.frameTime * 1000)) ms")
        }
        .font(.system(.caption, design: .monospaced))
        .padding(8)
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(6)
        .padding(10)
        .opacity(showPerformanceMetrics ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    /// Function to update the performance metrics
    private func updatePerformanceMetrics(frameTime: Double) {
        performanceMetrics.update(frameTime: frameTime)
    }

    // MARK: - Preset Manager

    @State private var showingPresetManager: Bool = false
    @State private var newPresetName: String? = nil
    @State private var presetSaveError: String? = nil
    @State private var presetLoadError: String? = nil
    @State private var availablePresets: [String] = []
    @State private var selectedPreset: String? = nil
    @State private var showPresetAlert: Bool = false
    @State private var presetAlertMessage: String = ""

    /// Preset manager view
    private var presetManagerView: some View {
        VStack(spacing: 20) {
            Text("Preset Manager")
                .font(.headline)
                .padding(.top)

            Divider()

            // Save preset section
            VStack(alignment: .leading, spacing: 10) {
                Text("Save Current Settings")
                    .font(.subheadline)

                HStack {
                    TextField(
                        "Preset name",
                        text: Binding(
                            get: { self.newPresetName ?? "" },
                            set: { self.newPresetName = $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                    Button("Save") {
                        saveCurrentPreset()
                    }
                    .disabled(newPresetName?.isEmpty ?? true)
                }

                if let error = presetSaveError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal)

            Divider()

            // Load preset section
            VStack(alignment: .leading, spacing: 10) {
                Text("Available Presets")
                    .font(.subheadline)

                if availablePresets.isEmpty {
                    Text("No saved presets found")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    List(availablePresets, id: \.self, selection: $selectedPreset) { preset in
                        Text(preset)
                    }
                    .frame(height: 150)

                    HStack {
                        Button("Load") {
                            loadSelectedPreset()
                        }
                        .disabled(selectedPreset == nil)

                        Spacer()

                        Button("Delete") {
                            deleteSelectedPreset()
                        }
                        .foregroundColor(.red)
                        .disabled(selectedPreset == nil)
                    }

                    if let error = presetLoadError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            Button("Close") {
                showingPresetManager = false
            }
            .padding(.bottom)
        }
        .frame(width: 300, height: 400)
        .padding()
        .onAppear {
            // Load available presets when the view appears
            fetchPresets()
        }
    }

    /// Loads the list of available presets
    private func fetchPresets() {
        let presets = viewModel.listPresets()
        availablePresets = presets
    }

    /// Saves the current settings as a preset
    private func saveCurrentPreset() {
        guard let presetName = newPresetName, !presetName.isEmpty else {
            showPresetAlert = true
            presetAlertMessage = "Please enter a valid preset name"
            return
        }

        let result = viewModel.savePreset(name: presetName)
        if result.success {
            newPresetName = nil
            fetchPresets()
        } else {
            showPresetAlert = true
            presetAlertMessage = result.message ?? "Failed to save preset"
        }
    }

    /// Loads the selected preset
    private func loadSelectedPreset() {
        guard let selectedPreset = selectedPreset else {
            showPresetAlert = true
            presetAlertMessage = "Please select a preset to load"
            return
        }

        let result = viewModel.loadPreset(name: selectedPreset)
        if result.success {
            // Update UI after loading preset
            showingPresetManager = false
        } else {
            showPresetAlert = true
            presetAlertMessage = result.message ?? "Failed to load preset"
        }
    }

    /// Deletes the selected preset
    private func deleteSelectedPreset() {
        guard let presetToDelete = selectedPreset else {
            showPresetAlert = true
            presetAlertMessage = "Please select a preset to delete"
            return
        }

        let result = viewModel.deletePreset(name: presetToDelete)
        if result.success {
            self.selectedPreset = nil
            fetchPresets()
        } else {
            showPresetAlert = true
            presetAlertMessage = result.message ?? "Failed to delete preset"
        }
    }

    // MARK: - Help System

    @State private var isPresentingHelp: Bool = false
    @State private var currentHelpTopic: HelpTopic = .overview

    /// Help topics available in the app
    enum HelpTopic: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case waveforms = "Waveform Types"
        case quantum = "Quantum Mode"
        case visualization = "Visualization"
        case export = "Exporting"
        case shortcuts = "Keyboard Shortcuts"

        var id: String { rawValue }
    }

    /// Help system view
    private var helpSystemView: some View {
        HStack(spacing: 0) {
            // Topic sidebar
            VStack(alignment: .leading, spacing: 2) {
                Text("Help Topics")
                    .font(.headline)
                    .padding(.vertical, 8)

                Divider()

                ForEach(HelpTopic.allCases) { topic in
                    Button(action: {
                        currentHelpTopic = topic
                    }) {
                        HStack {
                            Text(topic.rawValue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)

                            if currentHelpTopic == topic {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    .background(
                        currentHelpTopic == topic ? Color.accentColor.opacity(0.1) : Color.clear
                    )
                    .cornerRadius(4)
                }

                Spacer()
            }
            .frame(width: 150)
            .padding()
            .background(Color(.windowBackgroundColor).opacity(0.5))

            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(titleForTopic(currentHelpTopic))
                        .font(.title2)
                        .padding(.bottom, 8)

                    helpContentForTopic(currentHelpTopic)

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 700, height: 500)
    }

    /// Returns the title for a help topic
    private func titleForTopic(_ topic: HelpTopic) -> String {
        switch topic {
        case .overview: return "QwantumWaveform Overview"
        case .waveforms: return "Working with Waveform Types"
        case .quantum: return "Understanding Quantum Mode"
        case .visualization: return "Visualization Options"
        case .export: return "Exporting Your Work"
        case .shortcuts: return "Keyboard Shortcuts"
        }
    }

    /// Returns the content view for a help topic
    @ViewBuilder
    private func helpContentForTopic(_ topic: HelpTopic) -> some View {
        switch topic {
        case .overview:
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "QwantumWaveform is an audio visualization application that bridges classical waveforms with quantum mechanical concepts."
                )
                .font(.body)

                Text("Key Features:")
                    .font(.headline)
                    .padding(.top, 8)

                bulletPoint("Generate and visualize different waveform types")
                bulletPoint("View time-domain and frequency-domain representations")
                bulletPoint("Explore quantum mechanical interpretations")
                bulletPoint("Export visualizations and audio files")
                bulletPoint("Save and load custom presets")

                Image(systemName: "waveform.path")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .padding()
                    .frame(maxWidth: .infinity)
            }

        case .waveforms:
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "QwantumWaveform supports several waveform types, each with unique harmonic characteristics:"
                )
                .font(.body)

                Group {
                    waveformDescription(
                        name: "Sine Wave",
                        description:
                            "The purest waveform, containing only the fundamental frequency.",
                        icon: "sine"
                    )

                    waveformDescription(
                        name: "Square Wave",
                        description:
                            "Contains only odd harmonics with amplitudes that decrease as 1/n.",
                        icon: "square"
                    )

                    waveformDescription(
                        name: "Triangle Wave",
                        description: "Contains only odd harmonics that decrease as 1/n².",
                        icon: "triangle"
                    )

                    waveformDescription(
                        name: "Sawtooth Wave",
                        description: "Contains all harmonics with amplitudes that decrease as 1/n.",
                        icon: "sawtooth"
                    )
                }

                Text(
                    "Use the Harmonic Richness control to adjust how many harmonics are included in the waveform."
                )
                .padding(.top)
            }

        case .quantum:
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "Quantum Mode visualizes quantum mechanical systems and maps them to audio parameters:"
                )
                .font(.body)

                Group {
                    quantumSystemDescription(
                        name: "Particle in a Box",
                        description:
                            "A particle confined to a one-dimensional box, showing standing wave patterns.",
                        details:
                            "Energy levels increase as n², resulting in non-harmonic overtones in the audio."
                    )

                    quantumSystemDescription(
                        name: "Harmonic Oscillator",
                        description:
                            "A particle in a parabolic potential well, like a spring system.",
                        details:
                            "Energy levels increase linearly as n, resulting in evenly spaced harmonics."
                    )

                    quantumSystemDescription(
                        name: "Potential Barrier",
                        description:
                            "A system with a central potential barrier showing quantum tunneling effects.",
                        details:
                            "The barrier height affects how much the wavefunction penetrates the forbidden region."
                    )
                }

                Text(
                    "The visualization shows probability densities in 2D mode and complex wavefunctions in 3D mode."
                )
                .padding(.top)
            }

        case .visualization:
            VStack(alignment: .leading, spacing: 12) {
                Text("QwantumWaveform offers multiple visualization modes:")
                    .font(.body)

                Group {
                    visualizationDescription(
                        name: "Waveform View",
                        description: "Shows the time-domain representation of the audio signal.",
                        tip: "Use this view to see how the waveform evolves over time."
                    )

                    visualizationDescription(
                        name: "Spectrum View",
                        description:
                            "Shows the frequency-domain representation using FFT analysis.",
                        tip: "Use this view to see the harmonic content of the sound."
                    )

                    visualizationDescription(
                        name: "Quantum View",
                        description:
                            "Shows quantum mechanical probability or wavefunction visualization.",
                        tip:
                            "Switch between 2D and 3D modes to see different aspects of the quantum system."
                    )
                }

                Text("Use the 2D/3D toggle button to switch between visualization dimensions.")
                    .padding(.top)
                Text(
                    "The performance metrics display shows frame rate and rendering time information."
                )
                .padding(.top, 4)
            }

        case .export:
            VStack(alignment: .leading, spacing: 12) {
                Text("QwantumWaveform allows you to export your work in several formats:")
                    .font(.body)

                Group {
                    exportFormatDescription(
                        name: "Image Export (PNG)",
                        description: "Saves the current visualization as a PNG image file.",
                        tip: "Useful for including in documents or presentations."
                    )

                    exportFormatDescription(
                        name: "Document Export (PDF)",
                        description: "Saves the current visualization as a PDF document.",
                        tip: "Maintains vector quality for high-resolution printing."
                    )

                    exportFormatDescription(
                        name: "Audio Export (WAV/AIFF)",
                        description: "Saves the current waveform as an audio file.",
                        tip: "WAV is widely compatible, while AIFF preserves metadata better."
                    )

                    exportFormatDescription(
                        name: "Data Export (CSV/JSON)",
                        description: "Exports raw data from the current visualization.",
                        tip: "Useful for further analysis in other applications."
                    )
                }

                Text("Use the Export button in the toolbar to access these options.")
                    .padding(.top)
            }

        case .shortcuts:
            VStack(alignment: .leading, spacing: 12) {
                Text("QwantumWaveform provides keyboard shortcuts for common actions:")
                    .font(.body)

                keyboardShortcut(key: "Space", action: "Play/Pause audio")
                keyboardShortcut(key: "⌘D", action: "Toggle between 2D and 3D visualization")
                keyboardShortcut(key: "⌘⌥P", action: "Toggle performance metrics display")
                keyboardShortcut(key: "⌘⇧S", action: "Open preset manager")
                keyboardShortcut(key: "⌘E", action: "Open export options")
                keyboardShortcut(key: "⌘,", action: "Open preferences")
                keyboardShortcut(key: "⌘H", action: "Show this help system")
                keyboardShortcut(key: "⌘W", action: "Close current window")
                keyboardShortcut(key: "⌘Q", action: "Quit application")

                Text("Visualization Navigation:")
                    .font(.headline)
                    .padding(.top)

                keyboardShortcut(key: "←/→", action: "Adjust frequency by 1 Hz")
                keyboardShortcut(key: "⇧←/⇧→", action: "Adjust frequency by 10 Hz")
                keyboardShortcut(key: "↑/↓", action: "Adjust amplitude")
                keyboardShortcut(key: "1-5", action: "Select waveform type")
            }
        }
    }

    // MARK: - Help System Components

    /// Creates a bullet point text view
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text("•")
                .font(.body)
                .padding(.trailing, 4)
            Text(text)
                .font(.body)
        }
    }

    /// Creates a waveform description view
    private func waveformDescription(name: String, description: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.accentColor)
                Text(name)
                    .font(.headline)
            }
            Text(description)
                .font(.body)
                .padding(.leading)
        }
        .padding(.vertical, 4)
    }

    /// Creates a quantum system description view
    private func quantumSystemDescription(name: String, description: String, details: String)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "atom")
                    .foregroundColor(.accentColor)
                Text(name)
                    .font(.headline)
            }
            Text(description)
                .font(.body)
                .padding(.leading)
            Text(details)
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.leading)
        }
        .padding(.vertical, 4)
    }

    /// Creates a visualization description view
    private func visualizationDescription(name: String, description: String, tip: String)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.accentColor)
                Text(name)
                    .font(.headline)
            }
            Text(description)
                .font(.body)
                .padding(.leading)
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text(tip)
                    .font(.callout)
                    .italic()
            }
            .padding(.leading)
        }
        .padding(.vertical, 4)
    }

    /// Creates an export format description view
    private func exportFormatDescription(name: String, description: String, tip: String)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.accentColor)
                Text(name)
                    .font(.headline)
            }
            Text(description)
                .font(.body)
                .padding(.leading)
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text(tip)
                    .font(.callout)
                    .italic()
            }
            .padding(.leading)
        }
        .padding(.vertical, 4)
    }

    /// Creates a keyboard shortcut description view
    private func keyboardShortcut(key: String, action: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                )

            Text(action)
                .font(.body)
                .padding(.leading, 8)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Properties for UI State

    // Export Popover state
    @State private var exportPopover = false
    @State private var exportFormat: ExportFormat = .csv
    @State private var exportProgress: Double = 0.0
    @State private var isExporting = false

    // Panel states
    @State private var isPanelShowingAudioParameters = false

    // MARK: - Initialization methods

    private func setupFromPreferences() {
        // Load user preferences
        let defaults = UserDefaults.standard

        // Load visualization preferences
        if let savedVisualizationType = defaults.string(forKey: "visualizationType"),
            let type = VisualizationType(rawValue: savedVisualizationType)
        {
            viewModel.visualizationType = type
        }

        viewModel.showGrid = defaults.bool(forKey: "showGrid")
        viewModel.showAxes = defaults.bool(forKey: "showAxes")

        // Load audio preferences
        if let savedWaveformType = defaults.string(forKey: "waveformType"),
            let type = WaveformType(rawValue: savedWaveformType)
        {
            viewModel.waveformType = type
        }

        viewModel.frequency = defaults.double(forKey: "frequency")
        viewModel.amplitude = defaults.double(forKey: "amplitude")
    }

    private func saveToPreferences() {
        // Save current settings to user preferences
        let defaults = UserDefaults.standard

        // Save visualization preferences
        defaults.set(viewModel.visualizationType.rawValue, forKey: "visualizationType")
        defaults.set(viewModel.showGrid, forKey: "showGrid")
        defaults.set(viewModel.showAxes, forKey: "showAxes")

        // Save audio preferences
        defaults.set(viewModel.waveformType.rawValue, forKey: "waveformType")
        defaults.set(viewModel.frequency, forKey: "frequency")
        defaults.set(viewModel.amplitude, forKey: "amplitude")
    }

    // MARK: - Helper methods for UI components

    private func initializeRenderer() {
        // This method initializes the Metal renderer if needed
        if viewModel.renderer == nil {
            viewModel.setupRenderer()
        }
    }

    // View builders for control panels
    @ViewBuilder
    private func audioParametersControls() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Parameters")
                .font(.headline)

            Slider(value: $viewModel.frequency, in: 20...2000) {
                Text("Frequency: \(Int(viewModel.frequency)) Hz")
            }

            Slider(value: $viewModel.amplitude, in: 0...1) {
                Text("Amplitude: \(viewModel.amplitude, specifier: "%.2f")")
            }
        }
        .padding()
    }

    // Quantum parameters panel
    @ViewBuilder
    private func quantumParametersControls() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quantum Parameters")
                .font(.headline)

            Picker("System Type", selection: $viewModel.quantumSystemType) {
                ForEach(QuantumSystemType.allCases, id: \.self) { systemType in
                    Text(systemType.displayName).tag(systemType)
                }
            }
            .pickerStyle(.menu)

            Slider(value: $viewModel.energyLevelFloat, in: 1...10, step: 1) {
                Text("Energy Level: \(viewModel.energyLevel)")
            }
            .onChange(of: viewModel.energyLevelFloat) { _, newValue in
                viewModel.energyLevel = Int(newValue)
            }

            if viewModel.quantumSystemType == .potentialWell {
                Slider(value: $viewModel.potentialHeight, in: 0...10) {
                    Text("Potential Height: \(viewModel.potentialHeight, specifier: "%.1f") eV")
                }
            }

            Toggle("Time Evolution", isOn: $viewModel.animateTimeEvolution)
        }
        .padding()
    }

    // Scientific metrics section
    @ViewBuilder
    private func metricsSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metrics")
                .font(.headline)

            Group {
                Text("Frequency: \(viewModel.frequency, specifier: "%.2f") Hz")
                Text("Wavelength: \(viewModel.wavelength, specifier: "%.2f") m")
                Text("Period: \(viewModel.period * 1000, specifier: "%.2f") ms")
            }
            .font(.system(.body, design: .monospaced))
        }
        .padding()
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            EnhancedSidebarView(viewModel: viewModel)
                .frame(minWidth: 250, idealWidth: 280, maxWidth: 400)
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                // Visualization area
                GeometryReader { geometry in
                    ZStack {
                        // Visualization view
                        if viewModel.dimensionMode == .threeDimensional {
                            QuantumVisualization3DView(viewModel: viewModel)
                        } else {
                            visualizationView
                        }

                        // Overlay controls
                        visualizationControlsOverlay
                    }
                }

                // Information panel at bottom
                informationPanel
            }
        }
        .toolbar {
            // Play/Pause button
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    isPlayingAudio.toggle()
                    viewModel.isPlaying = isPlayingAudio
                }) {
                    Label(
                        isPlayingAudio ? "Pause" : "Play",
                        systemImage: isPlayingAudio ? "pause.circle" : "play.circle")
                }
                .keyboardShortcut(.space, modifiers: [])
                .help(isPlayingAudio ? "Pause audio" : "Play audio")
            }

            // Dimension toggle button
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    viewModel.toggleVisualizationMode()
                }) {
                    Label(
                        "Toggle 3D",
                        systemImage: viewModel.dimensionMode == .threeDimensional
                            ? "square.on.square" : "cube")
                }
                .help("Toggle between 2D and 3D visualization")
            }

            // Visualization type selector
            ToolbarItem(placement: .automatic) {
                Picker("Visualization", selection: $viewModel.visualizationType) {
                    ForEach(VisualizationType.allCases, id: \.self) { type in
                        visualizationTypeLabel(for: type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.visualizationType) { oldValue, newValue in
                    viewModel.updateVisualization()
                }
            }

            // Performance metrics toggle button
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showPerformanceMetrics.toggle()
                }) {
                    Label("Metrics", systemImage: "speedometer")
                }
                .keyboardShortcut("P", modifiers: [.command, .option])
                .help("Toggle performance metrics display")
            }

            // Presets button
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showingPresetManager = true
                }) {
                    Label("Presets", systemImage: "square.stack")
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
                .help("Save or load presets")
                .popover(isPresented: $showingPresetManager) {
                    presetManagerView
                }
            }

            // Help button
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    isPresentingHelp = true
                }) {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .keyboardShortcut("?", modifiers: [.command])
                .help("View application help")
                .sheet(isPresented: $isPresentingHelp) {
                    helpSystemView
                }
            }

            // Preferences button
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    isPresentingPreferences = true
                }) {
                    Label("Preferences", systemImage: "gear")
                }
                .help("Open Preferences")
            }

            // Export button
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    let exportURL = viewModel.exportCurrentVisualization()
                    isPresentingExport = exportURL != nil
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export visualization or data")
                .popover(isPresented: $isPresentingExport) {
                    exportPopover
                }
            }
        }
        .sheet(isPresented: $isPresentingPreferences) {
            PreferencesView()
                .frame(width: 600, height: 500)
        }
        .onAppear {
            setupFromPreferences()
            // Make sure the renderer is initialized when the view appears
            if viewModel.renderer == nil {
                rendererNeedsInitialization = true
            }
        }
        .onDisappear {
            saveToPreferences()
        }
        .alert(isPresented: $showPresetAlert) {
            Alert(
                title: Text("Preset Operation"),
                message: Text(presetAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Subviews

    /// Main visualization view (2D) with performance tracking
    private var visualizationView: some View {
        ZStack {
            // Use MetalKit for hardware-accelerated rendering
            if let renderer = viewModel.renderer {
                MetalWaveformView(
                    waveformData: viewModel.waveformDataCache ?? [],
                    spectrumData: viewModel.spectrumDataCache ?? [],
                    quantumData: viewModel.quantumData,
                    visualizationMode: VisualizationMode(from: viewModel.visualizationType)
                )
                .onAppear {
                    // Ensure we have a metal device
                    guard let device = MTLCreateSystemDefaultDevice() else {
                        print("ERROR: Metal is not supported on this device")
                        return
                    }

                    // Connect the renderer to a Metal view
                    viewModel.connectRenderer(to: MTKView())
                }
            } else {
                // Show placeholder when renderer is not available
                VStack {
                    Text("Initializing renderer...")
                        .font(.headline)
                        .padding()
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.windowBackgroundColor))
                .onAppear {
                    rendererNeedsInitialization = true
                }
            }

            // Overlay the performance metrics
            performanceMetricsView
        }
        .onAppear {
            // Initialize the renderer when the view appears if needed
            if viewModel.renderer == nil {
                rendererNeedsInitialization = true
            }
        }
        .onChange(of: rendererNeedsInitialization) { oldValue, newValue in
            if newValue {
                initializeRenderer()
                rendererNeedsInitialization = false
            }
        }
    }

    /// Enhanced visualization controls with accessibility
    private var visualizationControlsOverlay: some View {
        VStack {
            HStack {
                // Play/Pause button with accessibility
                Button(action: {
                    isPlayingAudio.toggle()
                    viewModel.isPlaying = isPlayingAudio
                }) {
                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .accessibilityLabel(isPlayingAudio ? "Pause audio" : "Play audio")
                .accessibilityHint("Toggles audio playback")
                .keyboardShortcut(.space, modifiers: [])

                Spacer()

                // Visualization mode toggle with accessibility
                Button(action: {
                    viewModel.toggleVisualizationMode()
                }) {
                    Image(
                        systemName: viewModel.dimensionMode == .threeDimensional
                            ? "square.on.square.fill" : "cube.fill"
                    )
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                }
                .accessibilityLabel(
                    viewModel.dimensionMode == .threeDimensional
                        ? "Switch to 2D mode" : "Switch to 3D mode"
                )
                .accessibilityHint("Changes between 2D and 3D visualization")
                .keyboardShortcut("D", modifiers: [.command])
            }
            .padding()

            Spacer()
        }
    }

    /// Information panel showing current parameters
    private var informationPanel: some View {
        HStack(spacing: 20) {
            // Audio control section
            VStack(alignment: .leading) {
                Text(isPanelShowingAudioParameters ? "Audio Parameters" : "Quantum Parameters")
                    .font(.headline)

                if isPanelShowingAudioParameters {
                    audioParametersControls
                } else {
                    quantumParametersControls
                }
            }
            .padding()

            Spacer()

            // Metrics section
            metricsSection
        }
        .frame(height: 120)
        .background(Color(.windowBackgroundColor))
    }

    // Helper function to create visualization type labels
    @ViewBuilder
    private func visualizationTypeLabel(for type: VisualizationType) -> some View {
        switch type {
        case .waveform:
            Label("Waveform", systemImage: "waveform")
        case .spectrum:
            Label("Spectrum", systemImage: "waveform.path.ecg")
        case .probability:
            Label("Probability", systemImage: "function")
        case .realPart:
            Label("Real", systemImage: "function")
        case .imaginaryPart:
            Label("Imaginary", systemImage: "function")
        case .phase:
            Label("Phase", systemImage: "circle.grid.cross")
        }
    }
}

// Extension to convert VisualizationType to VisualizationMode
extension VisualizationMode {
    init(from visualizationType: VisualizationType) {
        switch visualizationType {
        case .waveform:
            self = .waveform
        case .spectrum:
            self = .spectrum
        case .probability, .realPart, .imaginaryPart, .phase:
            self = .quantum
        }
    }
}
