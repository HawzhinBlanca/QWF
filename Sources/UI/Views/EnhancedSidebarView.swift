//
//  SidebarView.swift
//  QwantumWaveform
//
//  Created by HAWZHIN on 15/03/2025.
//

import Combine
import SwiftUI

/// Enhanced sidebar with quantum and audio presets, measurements,
/// and scientific reference data.
struct EnhancedSidebarView: View {
    @ObservedObject var viewModel: WaveformViewModel

    // Preset categories
    @State private var selectedCategory: PresetCategory = .quantum
    @State private var searchText: String = ""

    // User presets
    @State private var userPresets: [UserPreset] = [
        UserPreset(name: "Hydrogen 1s", description: "Ground state of hydrogen", type: .quantum),
        UserPreset(
            name: "Quantum Tunneling", description: "Barrier penetration demo", type: .quantum),
        UserPreset(name: "Concert A", description: "Standard tuning reference", type: .audio),
    ]

    // Expanded sections
    @State private var expandedSections: Set<String> = ["presets", "measurements"]

    // Recently used presets
    @State private var recentPresets: [String] = []

    // Bookmark state
    @State private var bookmarkedStates: [BookmarkedState] = []
    @State private var showingAddBookmark = false
    @State private var newBookmarkName = ""

    // Preset categories
    enum PresetCategory: String, CaseIterable {
        case quantum = "Quantum"
        case audio = "Audio"
        case experimental = "Experimental"
        case user = "User"
    }

    // User preset structure
    struct UserPreset: Identifiable {
        var id = UUID()
        var name: String
        var description: String
        var type: PresetCategory
        var date = Date()
    }

    // Bookmarked state structure
    struct BookmarkedState: Identifiable {
        var id = UUID()
        var name: String
        var date = Date()
        var quantumSystemType: QuantumSystemType
        var energyLevel: Int
        var waveformType: WaveformType
        var frequency: Double
        var amplitude: Double
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("QwantumWaveform")
                    .font(.headline)
                    .foregroundColor(.purple)

                Spacer()

                Menu {
                    Button("Import Preset", action: importPreset)
                    Button("Export Current State", action: exportCurrentState)
                    Divider()
                    Button("Settings", action: openSettings)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            .padding([.horizontal, .top])

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search presets...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(7)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Category selector
            Picker("Category", selection: $selectedCategory) {
                ForEach(PresetCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // Main content
            List {
                // Presets section
                sidebarSection("Presets", id: "presets") {
                    presetsContent
                }

                // Quick measurements section
                sidebarSection("Measurements", id: "measurements") {
                    measurementsContent
                }

                // Bookmarks section
                sidebarSection("Bookmarks", id: "bookmarks") {
                    bookmarksContent
                }

                // Reference section
                sidebarSection("Scientific Reference", id: "reference") {
                    referenceContent
                }
            }
            .listStyle(SidebarListStyle())

            Divider()

            // Bottom controls
            HStack(spacing: 16) {
                // Bookmark current state
                Button(action: {
                    showingAddBookmark = true
                }) {
                    Image(systemName: "bookmark")
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showingAddBookmark) {
                    bookmarkPopover
                }

                Spacer()

                // Quick audio controls
                audioControlsView
            }
            .padding()
        }
    }

    // MARK: - Content Views

    /// Presets content based on selected category
    private var presetsContent: some View {
        Group {
            switch selectedCategory {
            case .quantum:
                quantumPresetsView

            case .audio:
                audioPresetsView

            case .experimental:
                experimentalPresetsView

            case .user:
                userPresetsView
            }
        }
    }

    /// Quantum presets
    private var quantumPresetsView: some View {
        Group {
            // Filter presets if search is active
            let presets = filteredQuantumPresets

            if presets.isEmpty {
                Text("No matching quantum presets")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(presets, id: \.name) { preset in
                    presetButton(
                        name: preset.name,
                        description: preset.description,
                        systemType: preset.systemType,
                        energyLevel: preset.energyLevel,
                        icon: preset.icon
                    )
                }
            }
        }
    }

    /// Audio presets
    private var audioPresetsView: some View {
        Group {
            // Filter presets if search is active
            let presets = filteredAudioPresets

            if presets.isEmpty {
                Text("No matching audio presets")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(presets, id: \.name) { preset in
                    presetButton(
                        name: preset.name,
                        description: preset.description,
                        waveformType: preset.waveformType,
                        frequency: preset.frequency,
                        amplitude: preset.amplitude,
                        icon: preset.icon
                    )
                }
            }
        }
    }

    /// Experimental presets
    private var experimentalPresetsView: some View {
        Group {
            // Filter presets if search is active
            let presets = filteredExperimentalPresets

            if presets.isEmpty {
                Text("No matching experimental presets")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(presets, id: \.name) { preset in
                    presetButton(
                        name: preset.name,
                        description: preset.description,
                        systemType: preset.systemType,
                        waveformType: preset.waveformType,
                        icon: preset.icon,
                        experimental: true
                    )
                }
            }
        }
    }

    /// User presets
    private var userPresetsView: some View {
        Group {
            // Filter presets if search is active
            let filteredPresets = userPresets.filter {
                searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.description.localizedCaseInsensitiveContains(searchText)
            }

            if filteredPresets.isEmpty {
                VStack {
                    Text("No user presets")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button("Save Current State") {
                        showingAddBookmark = true
                    }
                    .padding(.top, 4)
                }
                .padding()
            } else {
                ForEach(filteredPresets) { preset in
                    userPresetButton(preset: preset)
                }
            }
        }
    }

    /// Quick measurements content
    private var measurementsContent: some View {
        Group {
            // Quantum wave parameters
            VStack(alignment: .leading, spacing: 2) {
                Text("Quantum Wave")
                    .font(.caption)
                    .foregroundColor(.blue)

                measurementRow("λᵦ:", formatScientific(viewModel.deBroglieWavelength) + " m")

                measurementRow("E:", formatScientific(viewModel.quantumEnergy) + " J")

                measurementRow(
                    "E:", formatScientific(viewModel.quantumEnergy / 1.602176634e-19) + " eV")

                if let momentum = viewModel.quantumObservables["momentum"] {
                    measurementRow("p:", formatScientific(momentum) + " kg·m/s")
                }
            }
            .padding(.vertical, 4)

            Divider()
                .padding(.vertical, 4)

            // Audio wave parameters
            VStack(alignment: .leading, spacing: 2) {
                Text("Audio Wave")
                    .font(.caption)
                    .foregroundColor(.green)

                measurementRow("f:", String(format: "%.2f", viewModel.frequency) + " Hz")

                measurementRow("λ:", formatScientific(viewModel.wavelength) + " m")

                measurementRow("T:", formatScientific(viewModel.period) + " s")

                measurementRow("A:", String(format: "%.2f", viewModel.amplitude))
            }
            .padding(.vertical, 4)

            Divider()
                .padding(.vertical, 4)

            // System-specific parameters
            systemSpecificMeasurements
        }
    }

    /// System-specific measurements based on quantum system type
    private var systemSpecificMeasurements: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(systemSpecificTitle)
                .font(.caption)
                .foregroundColor(.purple)

            switch viewModel.quantumSystemType {
            case .freeParticle:
                if viewModel.potentialHeight > 0 {
                    // Tunneling probability
                    let tunnelingProb = calculateTunnelingProbability()
                    measurementRow("Tunneling:", String(format: "%.2f%%", tunnelingProb * 100))
                }

                if let momentum = viewModel.quantumObservables["momentum"],
                    let mass = Optional(viewModel.particleMass)
                {
                    // Velocity
                    let velocity = momentum / mass
                    measurementRow("Velocity:", formatScientific(velocity) + " m/s")
                }

            case .potentialWell:
                // Well width approximation
                measurementRow("Well width:", formatScientific(20e-9) + " m")

                // Nodes
                measurementRow("Nodes:", "\(viewModel.energyLevel - 1)")

            case .harmonicOscillator:
                if let frequency = viewModel.quantumObservables["angular_frequency"] {
                    // Angular frequency
                    measurementRow("ω:", formatScientific(frequency) + " rad/s")
                }

                if let amplitude = viewModel.quantumObservables["classical_amplitude"] {
                    // Classical amplitude
                    measurementRow("Amplitude:", formatScientific(amplitude) + " m")
                }

            case .hydrogenAtom:
                if let radius = viewModel.quantumObservables["orbital_radius"] {
                    // Orbital radius
                    measurementRow("Radius:", formatScientific(radius) + " m")
                }

                // Binding energy
                let bindingEnergy = -13.6 / Double(viewModel.energyLevel * viewModel.energyLevel)
                measurementRow("Binding E:", String(format: "%.4f", bindingEnergy) + " eV")
            }
        }
        .padding(.vertical, 4)
    }

    /// Bookmarks content
    private var bookmarksContent: some View {
        Group {
            if bookmarkedStates.isEmpty {
                Text("No bookmarked states")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(bookmarkedStates) { bookmark in
                    bookmarkButton(bookmark)
                }
            }

            Button(action: {
                showingAddBookmark = true
            }) {
                Label("Add Current State", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 4)
        }
    }

    /// Scientific reference content
    private var referenceContent: some View {
        Group {
            // Physical constants
            VStack(alignment: .leading, spacing: 2) {
                Text("Physical Constants")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: {
                    copyToClipboard("6.62607015e-34")
                }) {
                    measurementRow("Planck (h):", "6.62607015e-34 J·s")
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    copyToClipboard("1.054571817e-34")
                }) {
                    measurementRow("ħ:", "1.054571817e-34 J·s")
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    copyToClipboard("9.1093837e-31")
                }) {
                    measurementRow("m₍ₑ₎:", "9.1093837e-31 kg")
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    copyToClipboard("1.602176634e-19")
                }) {
                    measurementRow("e:", "1.602176634e-19 C")
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    copyToClipboard("299792458")
                }) {
                    measurementRow("c:", "299792458 m/s")
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 4)

            Divider()
                .padding(.vertical, 4)

            // Audio reference
            VStack(alignment: .leading, spacing: 2) {
                Text("Audio Reference")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: {
                    viewModel.frequency = 440.0
                    viewModel.updateWaveform()
                }) {
                    measurementRow("A4:", "440 Hz")
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    viewModel.frequency = 261.63
                    viewModel.updateWaveform()
                }) {
                    measurementRow("Middle C:", "261.63 Hz")
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    viewModel.frequency = 432.0
                    viewModel.updateWaveform()
                }) {
                    measurementRow("A432:", "432 Hz")
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 4)
        }
    }

    /// Audio controls at bottom of sidebar
    private var audioControlsView: some View {
        HStack(spacing: 20) {
            // Frequency halve button
            Button(action: {
                adjustFrequency(factor: 0.5)
            }) {
                Image(systemName: "divide")
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())

            // Frequency reset button
            Button(action: {
                resetFrequency()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())

            // Frequency double button
            Button(action: {
                adjustFrequency(factor: 2.0)
            }) {
                Image(systemName: "multiply")
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    /// Bookmark popup for adding new bookmarks
    private var bookmarkPopover: some View {
        VStack(spacing: 16) {
            Text("Bookmark Current State")
                .font(.headline)

            TextField("Name", text: $newBookmarkName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack {
                Button("Cancel") {
                    showingAddBookmark = false
                    newBookmarkName = ""
                }

                Spacer()

                Button("Save") {
                    addBookmark()
                    showingAddBookmark = false
                    newBookmarkName = ""
                }
                .disabled(newBookmarkName.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Helper Views

    /// Collapsible sidebar section
    private func sidebarSection<Content: View>(
        _ title: String, id: String, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSections.contains(id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedSections.insert(id)
                    } else {
                        expandedSections.remove(id)
                    }
                }
            ),
            content: {
                content()
                    .padding(.top, 6)
            },
            label: {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        )
    }

    /// Measurement row for displaying values
    private func measurementRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    /// Preset button for quantum and audio presets
    private func presetButton(
        name: String,
        description: String,
        systemType: QuantumSystemType? = nil,
        energyLevel: Int? = nil,
        waveformType: WaveformType? = nil,
        frequency: Double? = nil,
        amplitude: Double? = nil,
        icon: String,
        experimental: Bool = false
    ) -> some View {
        Button(action: {
            applyPreset(
                systemType: systemType,
                energyLevel: energyLevel,
                waveformType: waveformType,
                frequency: frequency,
                amplitude: amplitude
            )

            // Add to recently used
            if !recentPresets.contains(name) {
                recentPresets.append(name)
                if recentPresets.count > 5 {
                    recentPresets.removeFirst()
                }
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(experimental ? .orange : .primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if experimental {
                    Image(systemName: "flask")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// User preset button
    private func userPresetButton(preset: UserPreset) -> some View {
        Button(action: {
            // In a real implementation, would load the preset
        }) {
            HStack(spacing: 12) {
                Image(systemName: preset.type == .quantum ? "atom" : "waveform")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Menu {
                    Button("Apply Preset", action: {})
                    Button("Rename", action: {})
                    Button("Delete", action: {})
                    Button("Export", action: {})
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Bookmark button
    private func bookmarkButton(_ bookmark: BookmarkedState) -> some View {
        Button(action: {
            applyBookmark(bookmark)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "bookmark.fill")
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .frame(width: 24)

                Text(bookmark.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    deleteBookmark(bookmark)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions and Helpers

    /// Apply a preset based on provided parameters
    private func applyPreset(
        systemType: QuantumSystemType? = nil,
        energyLevel: Int? = nil,
        waveformType: WaveformType? = nil,
        frequency: Double? = nil,
        amplitude: Double? = nil
    ) {
        // Update quantum parameters if provided
        if let systemType = systemType {
            viewModel.quantumSystemType = systemType
        }

        if let energyLevel = energyLevel {
            viewModel.energyLevel = energyLevel
            viewModel.energyLevelFloat = Double(energyLevel)
        }

        // Update audio parameters if provided
        if let waveformType = waveformType {
            viewModel.waveformType = waveformType
        }

        if let frequency = frequency {
            viewModel.frequency = frequency
        }

        if let amplitude = amplitude {
            viewModel.amplitude = amplitude
        }

        // Update simulations
        viewModel.updateQuantumSimulation()
        viewModel.updateWaveform()
    }

    /// Apply bookmark to current state
    private func applyBookmark(_ bookmark: BookmarkedState) {
        viewModel.quantumSystemType = bookmark.quantumSystemType
        viewModel.energyLevel = bookmark.energyLevel
        viewModel.energyLevelFloat = Double(bookmark.energyLevel)
        viewModel.waveformType = bookmark.waveformType
        viewModel.frequency = bookmark.frequency
        viewModel.amplitude = bookmark.amplitude

        viewModel.updateQuantumSimulation()
        viewModel.updateWaveform()
    }

    /// Add current state as a bookmark
    private func addBookmark() {
        let bookmark = BookmarkedState(
            name: newBookmarkName,
            quantumSystemType: viewModel.quantumSystemType,
            energyLevel: viewModel.energyLevel,
            waveformType: viewModel.waveformType,
            frequency: viewModel.frequency,
            amplitude: viewModel.amplitude
        )

        bookmarkedStates.append(bookmark)
    }

    /// Delete a bookmark
    private func deleteBookmark(_ bookmark: BookmarkedState) {
        if let index = bookmarkedStates.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarkedStates.remove(at: index)
        }
    }

    /// Adjust frequency by a factor
    private func adjustFrequency(factor: Double) {
        let newFrequency = viewModel.frequency * factor
        if newFrequency >= 20 && newFrequency <= 20000 {
            viewModel.frequency = newFrequency
            viewModel.updateWaveform()
        }
    }

    /// Reset frequency to A4 (440 Hz)
    private func resetFrequency() {
        viewModel.frequency = 440.0
        viewModel.updateWaveform()
    }

    /// Import a preset (would show file picker)
    private func importPreset() {
        // In a real implementation, would show file picker
    }

    /// Export current state (would show file save dialog)
    private func exportCurrentState() {
        // In a real implementation, would show file save dialog
    }

    /// Open settings (would show settings panel)
    private func openSettings() {
        // In a real implementation, would show settings panel
    }

    /// Copy value to clipboard
    private func copyToClipboard(_ value: String) {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(value, forType: .string)
        #endif
    }

    /// Calculate tunneling probability for potential barrier
    private func calculateTunnelingProbability() -> Double {
        guard viewModel.potentialHeight > 0 else { return 1.0 }

        // Convert potential height from eV to Joules
        let barrierEnergy = viewModel.potentialHeight * 1.602176634e-19

        // Parameters
        let energy = viewModel.quantumEnergy
        let barrierWidth = 2e-9  // 2 nm barrier width
        let reducedPlanckConstant = 1.054571817e-34

        if energy >= barrierEnergy {
            // Classical case - above barrier
            return 1.0
        } else {
            // Quantum tunneling case
            let kappa =
                sqrt(2.0 * viewModel.particleMass * (barrierEnergy - energy))
                / reducedPlanckConstant
            let exponent = -2.0 * kappa * barrierWidth

            // Simple model: T ≈ e^(-2κL)
            return exp(exponent)
        }
    }

    /// Format with scientific notation when appropriate
    private func formatScientific(_ value: Double) -> String {
        if abs(value) < 0.001 || abs(value) > 1000 {
            return String(format: "%.2e", value)
        }
        return String(format: "%.4f", value)
    }

    // MARK: - Computed Properties

    /// System-specific title based on quantum system type
    private var systemSpecificTitle: String {
        switch viewModel.quantumSystemType {
        case .freeParticle:
            return viewModel.potentialHeight > 0 ? "Tunneling" : "Free Particle"
        case .potentialWell:
            return "Potential Well"
        case .harmonicOscillator:
            return "Harmonic Oscillator"
        case .hydrogenAtom:
            return "Hydrogen Atom"
        }
    }

    /// Filtered quantum presets based on search text
    private var filteredQuantumPresets:
        [(
            name: String, description: String, systemType: QuantumSystemType, energyLevel: Int,
            icon: String
        )]
    {
        let presets = [
            (
                name: "Quantum Harmonic Oscillator", description: "Ground state oscillator",
                systemType: QuantumSystemType.harmonicOscillator, energyLevel: 1,
                icon: "waveform.path.ecg"
            ),
            (
                name: "Harmonic Oscillator n=2", description: "First excited state",
                systemType: QuantumSystemType.harmonicOscillator, energyLevel: 2,
                icon: "waveform.path.ecg"
            ),
            (
                name: "Harmonic Oscillator n=3", description: "Second excited state",
                systemType: QuantumSystemType.harmonicOscillator, energyLevel: 3,
                icon: "waveform.path.ecg"
            ),
            (
                name: "Hydrogen 1s", description: "Ground state of hydrogen",
                systemType: QuantumSystemType.hydrogenAtom, energyLevel: 1, icon: "atom"
            ),
            (
                name: "Hydrogen 2s", description: "First excited s-orbital",
                systemType: QuantumSystemType.hydrogenAtom, energyLevel: 2, icon: "atom"
            ),
            (
                name: "Hydrogen 3s", description: "Second excited s-orbital",
                systemType: QuantumSystemType.hydrogenAtom, energyLevel: 3, icon: "atom"
            ),
            (
                name: "Infinite Well n=1", description: "Ground state in box",
                systemType: QuantumSystemType.potentialWell, energyLevel: 1,
                icon: "square.split.bottomrightquarter"
            ),
            (
                name: "Infinite Well n=2", description: "First excited state",
                systemType: QuantumSystemType.potentialWell, energyLevel: 2,
                icon: "square.split.bottomrightquarter"
            ),
            (
                name: "Infinite Well n=3", description: "Second excited state",
                systemType: QuantumSystemType.potentialWell, energyLevel: 3,
                icon: "square.split.bottomrightquarter"
            ),
            (
                name: "Quantum Tunneling", description: "Wave packet with barrier",
                systemType: QuantumSystemType.freeParticle, energyLevel: 1, icon: "waveform"
            ),
        ]

        if searchText.isEmpty {
            return presets
        } else {
            return presets.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    /// Filtered audio presets based on search text
    private var filteredAudioPresets:
        [(
            name: String, description: String, waveformType: WaveformType, frequency: Double,
            amplitude: Double, icon: String
        )]
    {
        let presets = [
            (
                name: "Concert A (440 Hz)", description: "Standard tuning reference",
                waveformType: WaveformType.sine, frequency: 440.0, amplitude: 0.5, icon: "waveform"
            ),
            (
                name: "Middle C (261.63 Hz)", description: "Middle C on piano",
                waveformType: WaveformType.sine, frequency: 261.63, amplitude: 0.5, icon: "waveform"
            ),
            (
                name: "Subharmonic (220 Hz)", description: "A3 - one octave below A4",
                waveformType: WaveformType.sine, frequency: 220.0, amplitude: 0.5, icon: "waveform"
            ),
            (
                name: "Square Wave (100 Hz)", description: "Low frequency square wave",
                waveformType: WaveformType.square, frequency: 100.0, amplitude: 0.4,
                icon: "square.wave.form"
            ),
            (
                name: "Triangle Wave (200 Hz)", description: "Triangle oscillator",
                waveformType: WaveformType.triangle, frequency: 200.0, amplitude: 0.6,
                icon: "waveform.path.ecg"
            ),
            (
                name: "Sawtooth Wave (300 Hz)", description: "Bright sawtooth wave",
                waveformType: WaveformType.sawtooth, frequency: 300.0, amplitude: 0.3,
                icon: "chart.line.uptrend.xyaxis"
            ),
            (
                name: "A432 Reference", description: "Alternative A tuning",
                waveformType: WaveformType.sine, frequency: 432.0, amplitude: 0.5, icon: "waveform"
            ),
            (
                name: "Low Bass (80 Hz)", description: "Low frequency test",
                waveformType: WaveformType.sine, frequency: 80.0, amplitude: 0.7, icon: "waveform"
            ),
            (
                name: "High Treble (5000 Hz)", description: "High frequency test",
                waveformType: WaveformType.sine, frequency: 5000.0, amplitude: 0.3, icon: "waveform"
            ),
            (
                name: "White Noise", description: "Random signal", waveformType: WaveformType.noise,
                frequency: 1000.0, amplitude: 0.3, icon: "waveform.path.badge.minus"
            ),
        ]

        if searchText.isEmpty {
            return presets
        } else {
            return presets.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    /// Filtered experimental presets based on search text
    private var filteredExperimentalPresets:
        [(
            name: String, description: String, systemType: QuantumSystemType,
            waveformType: WaveformType, icon: String
        )]
    {
        let presets = [
            (
                name: "Quantum-Audio Bridge", description: "Direct frequency mapping",
                systemType: QuantumSystemType.harmonicOscillator, waveformType: WaveformType.sine,
                icon: "function"
            ),
            (
                name: "Wave Packet Evolution", description: "Time-evolving packet",
                systemType: QuantumSystemType.freeParticle, waveformType: WaveformType.sine,
                icon: "waveform.path.ecg"
            ),
            (
                name: "Superposition States", description: "Combined quantum states",
                systemType: QuantumSystemType.potentialWell, waveformType: WaveformType.sine,
                icon: "plusminus"
            ),
            (
                name: "Quantum Beats", description: "Interference pattern",
                systemType: QuantumSystemType.harmonicOscillator, waveformType: WaveformType.sine,
                icon: "waveform"
            ),
            (
                name: "Planck Scale Test", description: "Extreme small scale",
                systemType: QuantumSystemType.freeParticle, waveformType: WaveformType.sine,
                icon: "atom"
            ),
        ]

        if searchText.isEmpty {
            return presets
        } else {
            return presets.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Preview

struct EnhancedSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedSidebarView(viewModel: WaveformViewModel())
            .frame(width: 320, height: 600)
            .previewLayout(.fixed(width: 320, height: 600))
    }
}
