//
//  AudioParametersView.swift
//  QwantumWaveform
//
//  Created by HAWZHIN on 15/03/2025.
//

import AVFoundation
import Combine
import SwiftUI

/// Advanced audio control interface with precise waveform manipulation,
/// real-time analysis, and scientific accuracy for professional audio visualization.
struct AudioParametersView: View {
    @ObservedObject var viewModel: WaveformViewModel

    // Local state for sliders
    @State private var frequencySlider: Double = 440.0
    @State private var amplitudeSlider: Double = 0.5
    @State private var harmonicRichnessSlider: Double = 0.5
    @State private var phaseSlider: Double = 0.0

    // Advanced parameters
    @State private var showHarmonicControls: Bool = false
    @State private var showAdvancedControls: Bool = false
    @State private var showEQControls: Bool = false
    @State private var showSpectrum: Bool = false
    @State private var useLogFrequency: Bool = true

    // Harmonic structure
    @State private var harmonics: [Double] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    @State private var phaseOffsets: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

    // EQ settings
    @State private var eqBands: [Float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    @State private var eqFrequencies: [Float] = [
        31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
    ]

    // Audio analysis
    @State private var spectrumData: [Float] = []
    @State private var rmsLevel: Float = 0.0
    @State private var spectralCentroid: Float = 0.0

    // Notes and musical values
    @State private var showMusicalValues: Bool = false
    @State private var selectedMusicalNote: Int = 57  // A4 (440 Hz)

    // Expanded sections
    @State private var expandedSections: Set<String> = ["basic"]

    // Timer for updates
    @State private var analyzeTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Waveform type selector
                waveformTypeSelector

                // Basic parameters section
                parameterSection("Basic Parameters", id: "basic") {
                    basicParametersContent
                }

                // Harmonic content section
                parameterSection("Harmonic Content", id: "harmonics") {
                    harmonicContent
                }

                // EQ section
                parameterSection("Equalization", id: "eq") {
                    eqContent
                }

                // Analysis section
                parameterSection("Audio Analysis", id: "analysis") {
                    analysisContent
                }

                // Musical reference section
                parameterSection("Musical Reference", id: "musical") {
                    musicalReferenceContent
                }

                // Action buttons
                actionButtonsRow
            }
            .padding()
        }
        .onAppear {
            synchronizeSliders()
            startAudioAnalysis()
            updateHarmonicStructure()
        }
        .onDisappear {
            stopAudioAnalysis()
        }
    }

    // MARK: - UI Components

    /// Waveform type selector with visual display
    private var waveformTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Waveform Type")
                .font(.headline)

            HStack(spacing: 16) {
                waveformTypeButton(.sine, icon: "waveform.path", label: "Sine")
                waveformTypeButton(.square, icon: "square.wave.form", label: "Square")
                waveformTypeButton(.triangle, icon: "waveform.path.ecg", label: "Triangle")
                waveformTypeButton(.sawtooth, icon: "chart.line.uptrend.xyaxis", label: "Sawtooth")
                waveformTypeButton(.noise, icon: "waveform.path.badge.minus", label: "Noise")

                // Custom waveform button (enabled only when harmonics are set)
                Button(action: {
                    viewModel.waveformType = .custom
                    viewModel.updateWaveform()
                }) {
                    VStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 24))
                            .foregroundColor(viewModel.waveformType == .custom ? .green : .gray)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(
                                        viewModel.waveformType == .custom
                                            ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                            )

                        Text("Custom")
                            .font(.caption)
                            .foregroundColor(viewModel.waveformType == .custom ? .green : .gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    /// Waveform type button
    private func waveformTypeButton(_ type: WaveformType, icon: String, label: String) -> some View
    {
        Button(action: {
            viewModel.waveformType = type
            viewModel.updateWaveform()
            updateHarmonicStructure()
        }) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(viewModel.waveformType == type ? .green : .gray)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(
                                viewModel.waveformType == type
                                    ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    )

                Text(label)
                    .font(.caption)
                    .foregroundColor(viewModel.waveformType == type ? .green : .gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Basic parameters content
    private var basicParametersContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Frequency control
            VStack(alignment: .leading) {
                HStack {
                    Text("Frequency:")
                    Spacer()
                    Text("\(String(format: "%.2f", viewModel.frequency)) Hz")
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.bottom, 1)

                HStack {
                    // Frequency slider
                    Slider(
                        value: $frequencySlider,
                        in: useLogFrequency ? 1...4 : 20...20000,
                        onEditingChanged: { editing in
                            if !editing {
                                if useLogFrequency {
                                    viewModel.frequency = pow(10, frequencySlider)
                                } else {
                                    viewModel.frequency = frequencySlider
                                }
                                viewModel.updateWaveform()
                            }
                        }
                    )
                    .onChange(of: frequencySlider) { oldValue, newValue in
                        if useLogFrequency {
                            viewModel.frequency = pow(10, newValue)
                        } else {
                            viewModel.frequency = newValue
                        }
                        viewModel.updateWaveform()
                    }

                    // Octave controls
                    HStack(spacing: 6) {
                        Button(action: {
                            adjustFrequency(factor: 0.5)  // Down octave
                        }) {
                            Image(systemName: "minus.square")
                                .font(.title3)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            adjustFrequency(factor: 2.0)  // Up octave
                        }) {
                            Image(systemName: "plus.square")
                                .font(.title3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // Frequency scale toggle
                Toggle("Logarithmic Frequency Scale", isOn: $useLogFrequency)
                    .onChange(of: useLogFrequency) { oldValue, newValue in
                        if newValue {
                            frequencySlider = log10(viewModel.frequency)
                        } else {
                            frequencySlider = viewModel.frequency
                        }
                    }
                    .font(.caption)
            }

            // Amplitude control
            VStack(alignment: .leading) {
                HStack {
                    Text("Amplitude:")
                    Spacer()
                    Text("\(String(format: "%.2f", viewModel.amplitude))")
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.bottom, 1)

                Slider(value: $amplitudeSlider, in: 0...1)
                    .onChange(of: amplitudeSlider) { oldValue, newValue in
                        viewModel.amplitude = newValue
                        viewModel.updateWaveform()
                    }
            }

            // Phase control
            VStack(alignment: .leading) {
                HStack {
                    Text("Phase:")
                    Spacer()
                    Text("\(String(format: "%.1f", phaseSlider))°")
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.bottom, 1)

                Slider(value: $phaseSlider, in: 0...360)
                    .onChange(of: phaseSlider) { oldValue, newValue in
                        viewModel.phase = newValue
                        viewModel.updateWaveform()
                    }
            }

            // Harmonic richness control (when applicable)
            if viewModel.waveformType != .noise && viewModel.waveformType != .custom {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Harmonic Richness:")
                        Spacer()
                        Text("\(String(format: "%.2f", harmonicRichnessSlider))")
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.bottom, 1)

                    Slider(value: $harmonicRichnessSlider, in: 0...1)
                        .onChange(of: harmonicRichnessSlider) { oldValue, newValue in
                            viewModel.harmonicRichness = newValue
                            // Update the generator
                            viewModel.waveformGenerator.setHarmonicRichness(newValue)
                            viewModel.updateWaveform()
                        }
                }
            }

            Divider()

            // Display calculated values
            HStack {
                VStack(alignment: .leading) {
                    Text("Wave Properties:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("λ = \(formatScientific(viewModel.wavelength)) m")
                        .font(.system(.caption, design: .monospaced))

                    Text("T = \(formatScientific(viewModel.period)) s")
                        .font(.system(.caption, design: .monospaced))
                }

                Spacer()

                // Play/Stop button
                Button(action: {
                    viewModel.isPlaying.toggle()
                }) {
                    Image(systemName: viewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.isPlaying ? .red : .green)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }

    /// Harmonic content controls
    private var harmonicContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.waveformType == .custom {
                Text("Define custom waveform by adjusting the harmonics below:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Harmonic structure of the current waveform:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Harmonic sliders
            ForEach(0..<min(8, harmonics.count), id: \.self) { index in
                VStack(alignment: .leading) {
                    HStack {
                        Text("Harmonic \(index + 1):")
                        Spacer()
                        Text("\(String(format: "%.2f", harmonics[index]))")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .padding(.bottom, 1)

                    HStack {
                        Slider(
                            value: Binding(
                                get: { harmonics[index] },
                                set: {
                                    harmonics[index] = $0
                                    updateCustomWaveform()
                                }
                            ), in: 0...1)

                        // Phase control for this harmonic
                        if showAdvancedControls {
                            Image(systemName: "waveform.path")
                                .foregroundColor(.green)
                                .font(.caption)

                            Slider(
                                value: Binding(
                                    get: { phaseOffsets[index] / (2 * .pi) },
                                    set: {
                                        phaseOffsets[index] = $0 * 2 * .pi
                                        updateCustomWaveform()
                                    }
                                ), in: 0...1
                            )
                            .frame(width: 80)
                        }
                    }
                }
            }

            // Show advanced controls toggle
            Toggle("Show Phase Controls", isOn: $showAdvancedControls)
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .font(.caption)

            // Preset buttons for quick harmonic combinations
            HStack {
                Button(action: {
                    setHarmonicPreset(.sine)
                }) {
                    Text("Sine")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    setHarmonicPreset(.square)
                }) {
                    Text("Square")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    setHarmonicPreset(.triangle)
                }) {
                    Text("Triangle")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    setHarmonicPreset(.sawtooth)
                }) {
                    Text("Sawtooth")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 8)

            // Harmonics visualization
            harmonicsVisualization
        }
    }

    /// Visualization of the harmonic structure
    private var harmonicsVisualization: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Harmonic Spectrum:")
                .font(.caption)
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    // Background grid
                    ForEach(0..<9) { i in
                        Path { path in
                            let x = CGFloat(i) * geometry.size.width / 8
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    }

                    // Harmonic bars
                    ForEach(0..<min(8, harmonics.count), id: \.self) { index in
                        Rectangle()
                            .fill(Color.green)
                            .frame(
                                width: max(1, geometry.size.width / 10),
                                height: CGFloat(harmonics[index]) * geometry.size.height
                            )
                            .position(
                                x: CGFloat(index) * geometry.size.width / 8 + geometry.size.width
                                    / 16,
                                y: geometry.size.height - CGFloat(harmonics[index])
                                    * geometry.size.height / 2
                            )
                    }

                    // Harmonic labels
                    ForEach(0..<min(8, harmonics.count), id: \.self) { index in
                        Text("\(index + 1)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .position(
                                x: CGFloat(index) * geometry.size.width / 8 + geometry.size.width
                                    / 16,
                                y: geometry.size.height - 8
                            )
                    }
                }
            }
            .frame(height: 100)
            .padding(.vertical, 8)
        }
    }

    /// Equalizer controls
    private var eqContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("10-Band Equalizer")
                .font(.headline)
                .foregroundColor(.green)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { index in
                        VStack(spacing: 4) {
                            Slider(
                                value: Binding(
                                    get: { eqBands[index] },
                                    set: {
                                        eqBands[index] = $0
                                        updateEQ(band: index, gain: $0)
                                    }
                                ), in: -12...12
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: geometry.size.height, height: geometry.size.width / 12)

                            Text("\(formatFrequency(eqFrequencies[index]))")
                                .font(.system(size: 8))
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
            }
            .frame(height: 150)

            HStack {
                // EQ preset buttons
                Button(action: {
                    resetEQ()
                }) {
                    Text("Flat")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    setEQPreset("bass")
                }) {
                    Text("Bass Boost")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    setEQPreset("treble")
                }) {
                    Text("Treble Boost")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    setEQPreset("mid")
                }) {
                    Text("Mid Scoop")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 8)
        }
    }

    /// Audio analysis controls and display
    private var analysisContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Spectrum analyzer
            VStack(alignment: .leading) {
                HStack {
                    Text("Frequency Spectrum")
                        .font(.headline)
                        .foregroundColor(.green)

                    Spacer()

                    Toggle("", isOn: $showSpectrum)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }

                if showSpectrum {
                    spectrumAnalyzer
                }
            }

            // Audio metrics
            HStack {
                VStack(alignment: .leading) {
                    Text("RMS Level:")
                    Text("Spectral Centroid:")
                }
                .font(.caption)

                VStack(alignment: .trailing) {
                    Text("\(String(format: "%.2f", rmsLevel))")
                    Text("\(String(format: "%.1f Hz", spectralCentroid))")
                }
                .font(.system(.caption, design: .monospaced))

                Spacer()

                // Level meter
                VStack(alignment: .leading) {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 16)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 100 * CGFloat(min(1.0, rmsLevel)), height: 16)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    /// Musical reference content
    private var musicalReferenceContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Note selection
            VStack(alignment: .leading) {
                HStack {
                    Text("Musical Note:")

                    Picker("", selection: $selectedMusicalNote) {
                        ForEach(36..<97, id: \.self) { midiNote in
                            Text(formatMIDINote(midiNote)).tag(midiNote)
                        }
                    }
                    .onChange(of: selectedMusicalNote) { oldValue, newValue in
                        // Set frequency to the selected note
                        let noteFrequency = midiNoteToFrequency(newValue)
                        viewModel.frequency = noteFrequency

                        if useLogFrequency {
                            frequencySlider = log10(noteFrequency)
                        } else {
                            frequencySlider = noteFrequency
                        }

                        viewModel.updateWaveform()
                    }

                    Spacer()

                    // Frequency to note
                    Button(action: {
                        // Find closest MIDI note to current frequency
                        selectedMusicalNote = frequencyToMIDINote(viewModel.frequency)
                    }) {
                        Text("Find Nearest Note")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Pitch reference table
            HStack(spacing: 20) {
                // Common reference pitches
                VStack(alignment: .leading, spacing: 4) {
                    Text("Common References:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: { setFrequency(440.0) }) {
                        HStack {
                            Text("A4 = 440 Hz")
                                .font(.caption)

                            if abs(viewModel.frequency - 440.0) < 0.1 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundColor(abs(viewModel.frequency - 440.0) < 0.1 ? .green : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { setFrequency(442.0) }) {
                        HStack {
                            Text("A4 = 442 Hz")
                                .font(.caption)

                            if abs(viewModel.frequency - 442.0) < 0.1 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundColor(abs(viewModel.frequency - 442.0) < 0.1 ? .green : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { setFrequency(432.0) }) {
                        HStack {
                            Text("A4 = 432 Hz")
                                .font(.caption)

                            if abs(viewModel.frequency - 432.0) < 0.1 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundColor(abs(viewModel.frequency - 432.0) < 0.1 ? .green : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Divider()

                // Harmonic series
                VStack(alignment: .leading, spacing: 4) {
                    Text("Harmonic Series of Current Note:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("1st: \(String(format: "%.2f", viewModel.frequency)) Hz")
                        .font(.system(.caption, design: .monospaced))

                    Text("2nd: \(String(format: "%.2f", viewModel.frequency * 2)) Hz")
                        .font(.system(.caption, design: .monospaced))

                    Text("3rd: \(String(format: "%.2f", viewModel.frequency * 3)) Hz")
                        .font(.system(.caption, design: .monospaced))
                }

                Divider()

                // Intervals
                VStack(alignment: .leading, spacing: 4) {
                    Text("Musical Intervals:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: { setFrequency(viewModel.frequency * pow(2, 1.0 / 12.0)) }) {
                        Text(
                            "Semitone: \(String(format: "%.2f", viewModel.frequency * pow(2, 1.0/12.0))) Hz"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { setFrequency(viewModel.frequency * pow(2, 7.0 / 12.0)) }) {
                        Text(
                            "Perfect Fifth: \(String(format: "%.2f", viewModel.frequency * pow(2, 7.0/12.0))) Hz"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { setFrequency(viewModel.frequency * 2) }) {
                        Text("Octave: \(String(format: "%.2f", viewModel.frequency * 2)) Hz")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 8)
        }
    }

    /// Spectrum analyzer visualization
    private var spectrumAnalyzer: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Background
                Rectangle()
                    .fill(Color.black.opacity(0.1))

                // Frequency grid lines
                ForEach(0..<7) { i in
                    let logPos = logFrequencyPosition(Double(i) * 1000, width: geometry.size.width)
                    Path { path in
                        path.move(to: CGPoint(x: logPos, y: 0))
                        path.addLine(to: CGPoint(x: logPos, y: geometry.size.height))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)

                    if i > 0 {
                        Text("\(i)k")
                            .font(.system(size: 8))
                            .position(x: logPos, y: geometry.size.height - 8)
                    }
                }

                // Spectrum bars
                if !spectrumData.isEmpty {
                    ForEach(0..<min(100, spectrumData.count), id: \.self) { i in
                        // Calculate logarithmic position
                        let nyquist: Float = 22050.0  // Half of 44.1kHz
                        let freq = nyquist * Float(i) / Float(spectrumData.count)
                        let logPos = logFrequencyPosition(Double(freq), width: geometry.size.width)

                        // Normalize magnitude and apply scaling for better visualization
                        let magnitude = min(1.0, spectrumData[i] * 5.0)
                        let barHeight = CGFloat(magnitude) * geometry.size.height

                        Rectangle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 3, height: barHeight)
                            .position(x: logPos, y: geometry.size.height - barHeight / 2)
                    }
                }

                // Spectral centroid indicator
                Path { path in
                    let logPos = logFrequencyPosition(
                        Double(spectralCentroid), width: geometry.size.width)
                    path.move(to: CGPoint(x: logPos, y: 0))
                    path.addLine(to: CGPoint(x: logPos, y: geometry.size.height))
                }
                .stroke(Color.yellow, lineWidth: 2)

                // Current frequency indicator
                Path { path in
                    let logPos = logFrequencyPosition(
                        viewModel.frequency, width: geometry.size.width)
                    path.move(to: CGPoint(x: logPos, y: 0))
                    path.addLine(to: CGPoint(x: logPos, y: geometry.size.height))
                }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
        }
        .frame(height: 100)
        .padding(.vertical, 8)
    }

    /// Row of action buttons
    private var actionButtonsRow: some View {
        HStack {
            Button(action: {
                exportAudioFile()
            }) {
                Label("Export Audio", systemImage: "square.and.arrow.up")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Button(action: {
                resetToDefaults()
            }) {
                Label("Reset", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    /// Collapsible parameter section
    private func parameterSection<Content: View>(
        _ title: String, id: String, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                if expandedSections.contains(id) {
                    expandedSections.remove(id)
                } else {
                    expandedSections.insert(id)
                }
            }) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Spacer()

                    Image(systemName: expandedSections.contains(id) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if expandedSections.contains(id) {
                content()
                    .transition(.opacity)
                    .animation(.easeInOut, value: expandedSections)
            }

            Divider()
        }
    }

    // MARK: - Actions and Helper Methods

    /// Adjust frequency by a factor (e.g., octave)
    private func adjustFrequency(factor: Double) {
        let newFrequency = viewModel.frequency * factor
        // Ensure within valid range
        if newFrequency >= 20 && newFrequency <= 20000 {
            viewModel.frequency = newFrequency

            if useLogFrequency {
                frequencySlider = log10(newFrequency)
            } else {
                frequencySlider = newFrequency
            }

            viewModel.updateWaveform()
        }
    }

    /// Set frequency directly (for presets)
    private func setFrequency(_ frequency: Double) {
        viewModel.frequency = frequency

        if useLogFrequency {
            frequencySlider = log10(frequency)
        } else {
            frequencySlider = frequency
        }

        viewModel.updateWaveform()
    }

    /// Synchronize sliders with view model values
    private func synchronizeSliders() {
        // Update slider values from view model
        if useLogFrequency {
            frequencySlider = log10(viewModel.frequency)
        } else {
            frequencySlider = viewModel.frequency
        }

        amplitudeSlider = viewModel.amplitude
        harmonicRichnessSlider = viewModel.harmonicRichness
        phaseSlider = viewModel.phase

        // Update MIDI note selector
        selectedMusicalNote = frequencyToMIDINote(viewModel.frequency)
    }

    /// Start audio analysis
    private func startAudioAnalysis() {
        viewModel.waveformGenerator.startMonitoring()

        // Start timer to update analysis data
        analyzeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if showSpectrum {
                spectrumData = viewModel.waveformGenerator.getSpectrumData()
            }

            rmsLevel = viewModel.waveformGenerator.getAudioLevel()
            spectralCentroid = viewModel.waveformGenerator.getSpectralCentroid()
        }
    }

    /// Stop audio analysis
    private func stopAudioAnalysis() {
        analyzeTimer?.invalidate()
        analyzeTimer = nil

        viewModel.waveformGenerator.stopMonitoring()
    }

    /// Update the harmonic structure based on waveform type
    private func updateHarmonicStructure() {
        switch viewModel.waveformType {
        case .sine:
            harmonics = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
            phaseOffsets = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
            viewModel.waveformGenerator.setHarmonicStructure(
                WaveformGenerator.HarmonicStructure.defaultSine)

        case .square:
            // Square wave has odd harmonics with 1/n amplitudes
            harmonics = [1.0, 0.0, 0.33, 0.0, 0.2, 0.0, 0.14, 0.0]
            phaseOffsets = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
            viewModel.waveformGenerator.setHarmonicStructure(
                WaveformGenerator.HarmonicStructure.defaultSquare)

        case .triangle:
            // Triangle wave has odd harmonics with 1/n² amplitudes
            harmonics = [1.0, 0.0, 0.11, 0.0, 0.04, 0.0, 0.02, 0.0]
            phaseOffsets = [0.0, 0.0, .pi, 0.0, 0.0, 0.0, .pi, 0.0]
            viewModel.waveformGenerator.setHarmonicStructure(
                WaveformGenerator.HarmonicStructure.defaultTriangle)

        case .sawtooth:
            // Sawtooth has all harmonics with 1/n amplitudes
            harmonics = [1.0, 0.5, 0.33, 0.25, 0.2, 0.17, 0.14, 0.13]
            phaseOffsets = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
            viewModel.waveformGenerator.setHarmonicStructure(
                WaveformGenerator.HarmonicStructure.defaultSawtooth)

        case .noise:
            // White noise doesn't have a harmonic structure
            harmonics = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
            phaseOffsets = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

        case .custom:
            // Keep current custom values
            break
        }
    }

    /// Update custom waveform when harmonics change
    private func updateCustomWaveform() {
        if viewModel.waveformType == .custom {
            // Create custom harmonic structure
            let structure = WaveformGenerator.HarmonicStructure(
                amplitudes: harmonics,
                phaseOffsets: phaseOffsets
            )

            viewModel.waveformGenerator.setHarmonicStructure(structure)
            viewModel.waveformGenerator.setWaveformType(WaveformType.custom)
            viewModel.updateWaveform()
        }
    }

    /// Set harmonic preset based on waveform type
    private func setHarmonicPreset(_ type: WaveformType) {
        switch type {
        case .sine:
            harmonics = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
            phaseOffsets = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

        case .square:
            harmonics = [1.0, 0.0, 0.33, 0.0, 0.2, 0.0, 0.14, 0.0]
            phaseOffsets = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

        case .triangle:
            harmonics = [1.0, 0.0, 0.11, 0.0, 0.04, 0.0, 0.02, 0.0]
            phaseOffsets = [0.0, 0.0, .pi, 0.0, 0.0, 0.0, .pi, 0.0]

        case .sawtooth:
            harmonics = [1.0, 0.5, 0.33, 0.25, 0.2, 0.17, 0.14, 0.13]
            phaseOffsets = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

        default:
            break
        }

        updateCustomWaveform()
    }

    /// Update EQ band
    private func updateEQ(band: Int, gain: Float) {
        viewModel.waveformGenerator.setEQBand(at: band, gain: gain)
    }

    /// Reset EQ to flat
    private func resetEQ() {
        for i in 0..<eqBands.count {
            eqBands[i] = 0.0
            updateEQ(band: i, gain: 0.0)
        }
    }

    /// Set EQ preset
    private func setEQPreset(_ preset: String) {
        switch preset {
        case "bass":
            eqBands = [8.0, 6.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

        case "treble":
            eqBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 4.0, 6.0, 8.0]

        case "mid":
            eqBands = [0.0, 0.0, 2.0, 0.0, -4.0, -4.0, 0.0, 2.0, 0.0, 0.0]

        default:
            eqBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        }

        // Apply to all bands
        for i in 0..<eqBands.count {
            updateEQ(band: i, gain: eqBands[i])
        }
    }

    /// Export audio file
    private func exportAudioFile() {
        // Use the new exportAudio method with a temporary file URL
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
            "export.wav")
        viewModel.exportAudio(to: tempURL)
    }

    /// Reset to defaults
    private func resetToDefaults() {
        // Reset sliders to defaults
        if useLogFrequency {
            frequencySlider = log10(440.0)
        } else {
            frequencySlider = 440.0
        }

        amplitudeSlider = 0.5
        harmonicRichnessSlider = 0.5
        phaseSlider = 0.0

        // Reset view model
        viewModel.frequency = 440.0
        viewModel.amplitude = 0.5
        viewModel.harmonicRichness = 0.5
        viewModel.phase = 0.0
        viewModel.waveformType = .sine

        // Update waveform
        viewModel.updateWaveform()

        // Reset harmonics
        updateHarmonicStructure()

        // Reset EQ
        resetEQ()
    }

    // MARK: - Utility Functions

    /// Format scientific notation
    private func formatScientific(_ value: Double) -> String {
        if abs(value) < 0.001 || abs(value) > 1000 {
            return String(format: "%.2e", value)
        }
        return String(format: "%.4f", value)
    }

    /// Format frequency with appropriate units
    private func formatFrequency(_ freq: Float) -> String {
        if freq < 1000 {
            return String(format: "%.0f Hz", freq)
        } else {
            return String(format: "%.1f kHz", freq / 1000)
        }
    }

    /// Calculate logarithmic position for frequency visualization
    private func logFrequencyPosition(_ frequency: Double, width: CGFloat) -> CGFloat {
        // Map frequency (20Hz-20kHz) to position using logarithmic scale
        let minFreq = log10(20.0)
        let maxFreq = log10(20000.0)
        let logFreq = log10(max(20.0, min(20000.0, frequency)))

        let normalizedPos = (logFreq - minFreq) / (maxFreq - minFreq)
        return CGFloat(normalizedPos) * width
    }

    /// Convert MIDI note number to frequency
    private func midiNoteToFrequency(_ note: Int) -> Double {
        // A4 (MIDI note 69) = 440 Hz
        return 440.0 * pow(2.0, Double(note - 69) / 12.0)
    }

    /// Convert frequency to nearest MIDI note
    private func frequencyToMIDINote(_ frequency: Double) -> Int {
        // A4 (MIDI note 69) = 440 Hz
        let note = 12.0 * log2(frequency / 440.0) + 69.0
        return Int(round(note))
    }

    /// Format MIDI note as note name with octave
    private func formatMIDINote(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteName = noteNames[midiNote % 12]
        let octave = (midiNote / 12) - 1
        return "\(noteName)\(octave)"
    }
}

// MARK: - Preview

struct AudioParametersView_Previews: PreviewProvider {
    static var previews: some View {
        AudioParametersView(viewModel: WaveformViewModel())
            .frame(width: 600, height: 800)
            .previewLayout(.fixed(width: 600, height: 800))
    }
}
