import Combine
import SwiftUI

/// Advanced scientific data visualization and analysis component for quantum-audio data
struct ScientificDataView: View {
    @ObservedObject var viewModel: WaveformViewModel
    @State private var isExpandedMap: [String: Bool] = [:]

    // Display options
    @State private var selectedTab = 1  // Start with tab 1 since tab 0 is removed
    @State private var showPhaseInfo = true
    @State private var showEnergyLevels = true
    @State private var showWavelengthComparison = true
    @State private var showUncertaintyRelation = true
    @State private var showTimeEvolution = true
    @State private var scientificNotation = true
    @State private var scaleValues = true
    @State private var animationPhase = 0.0

    // Calculated data
    @State private var quantumAudioRelationship: [String: String] = [:]
    @State private var harmonicContent: [Double] = []
    @State private var energyLevelRatios: [Double] = []
    @State private var uncertaintyProduct: Double = 0.0
    @State private var energyToFrequencyRatio: Double = 0.0
    @State private var audioToQuantumScale: Double = 0.0

    // Animation state
    @State private var isAnimating = true

    // Update timer
    @State private var updateTimer: Timer? = nil
    @State private var updateCounter = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Data View", selection: $selectedTab) {
                // Tab 0 removed (previously QuantumAudioBridge)
                Text("Energy Spectra").tag(1)
                Text("Wave Function").tag(2)
                Text("Quantum State").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            TabView(selection: $selectedTab) {
                // Quantum-Audio Bridge View
                // QuantumAudioBridgeDataView(
                //     viewModel: viewModel,
                //     bridge: quantumAudioBridge,
                //     scientificNotation: $scientificNotation,
                //     animationPhase: $animationPhase
                // )
                // .tag(0)

                // Energy Spectra View
                EnergySpectraView(viewModel: viewModel, scientificNotation: $scientificNotation)
                    .tag(1)

                // Wave Function View
                Text("Wave Function View")
                    .tag(2)

                // Quantum State View
                Text("Quantum State View")
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            // Controls
            HStack {
                Toggle("Scientific Notation", isOn: $scientificNotation)
                    .toggleStyle(SwitchToggleStyle())
                    .padding(.horizontal)

                Spacer()

                Button(action: {
                    // Export data
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "quantum_data.csv"
                    panel.allowedContentTypes = [.commaSeparatedText]
                    panel.canCreateDirectories = true

                    panel.beginSheetModal(for: NSApp.keyWindow!) { response in
                        if response == .OK, let url = panel.url {
                            // Create simple CSV with time and energy
                            let csvString = "Time,Energy\n0,\(viewModel.quantumEnergy)"
                            try? csvString.write(to: url, atomically: true, encoding: .utf8)
                        }
                    }
                }) {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
        }
        .onAppear {
            // Start animation timer
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                animationPhase += 0.05
                if animationPhase > .pi * 2 {
                    animationPhase -= .pi * 2
                }
            }
        }
        .onDisappear {
            // Clean up timer
            updateTimer?.invalidate()
            updateTimer = nil
        }
    }
}

// MARK: - Energy Spectra View

struct EnergySpectraView: View {
    var viewModel: WaveformViewModel
    @Binding var scientificNotation: Bool

    var body: some View {
        VStack {
            Text("Energy Spectra View")
                .font(.headline)

            Text("Energy: \(formatValue(viewModel.quantumEnergy)) J")

            Text("Wavelength: \(formatValue(viewModel.deBroglieWavelength)) m")
        }
        .padding()
    }

    // Helper function to format values
    private func formatValue(_ value: Double) -> String {
        if scientificNotation && (abs(value) < 0.001 || abs(value) > 1000) {
            return String(format: "%.2e", value)
        }
        return String(format: "%.4f", value)
    }
}

// MARK: - Wave Function View

struct WaveFunctionDataView: View {
    var viewModel: WaveformViewModel
    @Binding var scientificNotation: Bool

    var body: some View {
        // Implementation of WaveFunctionDataView
        Text("Wave Function View")
    }
}

// MARK: - Quantum State View

struct QuantumStateDataView: View {
    var viewModel: WaveformViewModel
    @Binding var scientificNotation: Bool

    var body: some View {
        // Implementation of QuantumStateDataView
        Text("Quantum State View")
    }
}

// MARK: - Supporting Views

/// Value row for displaying parameters
struct ValueRow: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(color.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

/// Quantum state visualization
struct QuantumStateIndicator: View {
    var level: Int
    var animationPhase: Double

    var body: some View {
        ZStack {
            // Orbital visualization
            ForEach(0..<10) { i in
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    .frame(width: Double(i + 1) * 8, height: Double(i + 1) * 8)
                    .opacity(i < level ? 1.0 : 0.2)
            }

            // Electron
            ForEach(Array(0..<level), id: \.self) { i in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .offset(
                        x: 4.0 * Double(i + 1) * cos(animationPhase + Double(i) * 0.3),
                        y: 4.0 * Double(i + 1) * sin(animationPhase + Double(i) * 0.3)
                    )
            }
        }
        .frame(width: 80, height: 80)
    }
}

/// Audio waveform visualization
struct AudioWaveformIndicator: View {
    var frequency: Double
    var waveformType: Int
    var animationPhase: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                .frame(width: 70, height: 70)

            // Draw waveform
            Path { path in
                // Draw one cycle of the waveform
                let points = 40
                path.move(
                    to: CGPoint(
                        x: 40 + 30 * sin(0),
                        y: 40 + 30 * sampleWaveform(0, waveformType, animationPhase)
                    ))

                for i in 1...points {
                    let angle = Double(i) / Double(points) * 2 * .pi
                    path.addLine(
                        to: CGPoint(
                            x: 40 + 30 * sin(angle),
                            y: 40 + 30
                                * sampleWaveform(
                                    Double(i) / Double(points), waveformType, animationPhase)
                        )
                    )
                }
            }
            .stroke(Color.green, lineWidth: 2)
        }
        .frame(width: 80, height: 80)
    }

    private func sampleWaveform(_ t: Double, _ type: Int, _ phase: Double) -> Double {
        let p = t + phase / (2 * .pi)

        switch type {
        case 0:  // Sine
            return sin(2 * .pi * p)
        case 1:  // Square
            return p.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.0 : -1.0
        case 2:  // Triangle
            let pt = p.truncatingRemainder(dividingBy: 1.0)
            return pt < 0.5 ? 4 * pt - 1 : 3 - 4 * pt
        case 3:  // Sawtooth
            return 2 * p.truncatingRemainder(dividingBy: 1.0) - 1
        default:
            return sin(2 * .pi * p)
        }
    }
}

/// Relationship metric display
struct RelationshipMetric: View {
    var title: String
    var value: String
    var description: String

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.purple)

            Text(value)
                .font(.system(.title3, design: .monospaced))
                .foregroundColor(.primary)
                .fontWeight(.medium)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 100)
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Waveform metric display
struct WaveformMetric: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .foregroundColor(color)

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
        .frame(minWidth: 100)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Waveform comparison metric with gauge
struct WaveformComparisonMetric: View {
    var title: String
    var value: Double
    var maxValue: Double
    var color: Color

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .foregroundColor(color)

            // Gauge
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                    .cornerRadius(4)

                Rectangle()
                    .fill(color)
                    .frame(width: CGFloat(value / maxValue) * 100, height: 8)
                    .cornerRadius(4)
            }
            .frame(width: 100)

            Text(String(format: "%.2f", value))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
        .frame(minWidth: 100)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Uncertainty metric display
struct UncertaintyMetric: View {
    var title: String
    var value: String
    var description: String

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.purple)

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 100)
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}
