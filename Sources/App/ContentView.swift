// Source/UI/Views/ContentView.swift

import MetalKit
import SwiftData
import SwiftUI

// Add extension to implement the missing render method
extension WaveformRenderer {
    func render(in view: MTKView) {
        // This is a convenience method that asks the view to redraw
        view.needsDisplay = true

        // Safely call draw(in:) if the method exists
        // We know WaveformRenderer conforms to MTKViewDelegate, so it should have this method
        if self.responds(to: #selector(MTKViewDelegate.draw(in:))) {
            self.draw(in: view)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: WaveformViewModel

    @State private var selectedTab = 0
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Waveform Visualization Tab
            VisualizationView()
                .tabItem {
                    Label("Visualization", systemImage: "waveform")
                }
                .tag(0)

            // Quantum Controls Tab
            QuantumControlsView()
                .tabItem {
                    Label("Quantum", systemImage: "atom")
                }
                .tag(1)

            // Audio Controls Tab
            AudioControlsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.3")
                }
                .tag(2)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .environmentObject(viewModel)
    }
}

struct VisualizationView: View {
    @EnvironmentObject var viewModel: WaveformViewModel
    @State private var showControls = true

    var body: some View {
        ZStack {
            // Title bar
            VStack {
                // Top control bar
                HStack {
                    Text(visualizationTitle)
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        showControls.toggle()
                    }) {
                        Image(systemName: showControls ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        exportData()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()

                // Metal visualization
                MetalKitView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom control bar
                HStack {
                    // 2D/3D toggle
                    Button(action: {
                        viewModel.toggleVisualizationMode()
                    }) {
                        Image(
                            systemName: viewModel.dimensionMode == .threeDimensional
                                ? "square.stack.3d.down.right" : "square.stack.3d.up.fill"
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // Play/pause button
                    Button(action: {
                        viewModel.isPlaying.toggle()
                    }) {
                        Image(
                            systemName: viewModel.isPlaying
                                ? "pause.circle.fill" : "play.circle.fill"
                        )
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // Visualization type menu
                    Menu {
                        ForEach(VisualizationType.allCases) { type in
                            Button(type.displayName) {
                                viewModel.visualizationType = type
                            }
                        }
                    } label: {
                        Image(systemName: "waveform.circle")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
            }

            // Side controls panel (conditional)
            if showControls {
                HStack {
                    VStack {
                        // System controls
                        systemControlsView
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)

                        if viewModel.dimensionMode == .threeDimensional {
                            // 3D Controls
                            visualizationControlsView
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                        }

                        Spacer()

                        // Scientific readouts
                        scientificDataView
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    }
                    .frame(width: 250)
                    .padding()

                    Spacer()
                }
            }
        }
        .background(Color.black)
    }

    private var visualizationTitle: String {
        switch viewModel.visualizationType {
        case .waveform, .spectrum:
            let waveformTypeName = getWaveformTypeName()
            return "\(waveformTypeName) Wave at \(String(format: "%.1f", viewModel.frequency)) Hz"
        case .probability, .realPart, .imaginaryPart, .phase:
            let systemTypeName = getQuantumSystemTypeName()
            return "\(systemTypeName) - Energy Level \(viewModel.energyLevel)"
        }
    }

    // Helper methods to safely get property names
    private func getWaveformTypeName() -> String {
        let waveformType = viewModel.waveformType
        switch waveformType {
        case .sine: return "Sine"
        case .square: return "Square"
        case .triangle: return "Triangle"
        case .sawtooth: return "Sawtooth"
        case .noise: return "Noise"
        case .custom: return "Custom"
        }
    }

    private func getQuantumSystemTypeName() -> String {
        let systemType = viewModel.quantumSystemType
        switch systemType {
        case .freeParticle: return "Free Particle"
        case .potentialWell: return "Potential Well"
        case .harmonicOscillator: return "Harmonic Oscillator"
        case .hydrogenAtom: return "Hydrogen Atom"
        }
    }

    private func exportData() {
        viewModel.exportQuantumData { url in
            if let url = url {
                // Show success message
                print("Data exported to: \(url.path)")

                #if os(iOS)
                    // Share the file on iOS
                    let activityVC = UIActivityViewController(
                        activityItems: [url],
                        applicationActivities: nil
                    )

                    // Present the share sheet
                    if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                #else
                    // On macOS, we've already saved the file, so no need for additional action
                    // You could add a confirmation dialog here if needed
                #endif
            }
        }
    }

    private var systemControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Controls")
                .font(.headline)
                .foregroundColor(.white)

            if viewModel.visualizationType == .probability
                || viewModel.visualizationType == .realPart
                || viewModel.visualizationType == .imaginaryPart
                || viewModel.visualizationType == .phase
            {

                // Quantum system controls
                Picker("System", selection: $viewModel.quantumSystemType) {
                    ForEach(QuantumSystemType.allCases) { system in
                        Text(system.displayName).tag(system)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                // Energy level slider
                VStack(alignment: .leading) {
                    Text("Energy Level: \(viewModel.energyLevel)")
                        .foregroundColor(.white)

                    HStack {
                        Text("1")
                            .foregroundColor(.gray)
                            .font(.caption)

                        Slider(value: $viewModel.energyLevelFloat, in: 1...10, step: 1)
                            .onChange(of: viewModel.energyLevelFloat) { oldValue, newValue in
                                viewModel.energyLevel = Int(newValue)
                            }

                        Text("10")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }

                // Time evolution toggle
                Toggle("Animate Time Evolution", isOn: $viewModel.animateTimeEvolution)
                    .toggleStyle(SwitchToggleStyle())

            } else {
                // Audio waveform controls
                Picker("Waveform", selection: $viewModel.waveformType) {
                    ForEach(WaveformType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                // Frequency slider
                VStack(alignment: .leading) {
                    Text("Frequency: \(Int(viewModel.frequency)) Hz")
                        .foregroundColor(.white)

                    HStack {
                        Text("20")
                            .foregroundColor(.gray)
                            .font(.caption)

                        Slider(value: $viewModel.frequency, in: 20...2000)

                        Text("2000")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }

                // Amplitude slider
                VStack(alignment: .leading) {
                    Text("Amplitude: \(viewModel.amplitude, specifier: "%.2f")")
                        .foregroundColor(.white)

                    HStack {
                        Text("0.0")
                            .foregroundColor(.gray)
                            .font(.caption)

                        Slider(value: $viewModel.amplitude, in: 0...1)

                        Text("1.0")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
            }

            // Common controls
            Picker("Visualization", selection: $viewModel.visualizationType) {
                if viewModel.quantumSystemType == .freeParticle
                    || viewModel.quantumSystemType == .potentialWell
                    || viewModel.quantumSystemType == .harmonicOscillator
                    || viewModel.quantumSystemType == .hydrogenAtom
                {
                    Text("Probability").tag(VisualizationType.probability)
                    Text("Real Part").tag(VisualizationType.realPart)
                    Text("Imaginary").tag(VisualizationType.imaginaryPart)
                    Text("Phase").tag(VisualizationType.phase)
                } else {
                    Text("Waveform").tag(VisualizationType.waveform)
                    Text("Spectrum").tag(VisualizationType.spectrum)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Divider()
                .background(Color.gray)

            Button(action: {
                viewModel.applyQuantumTransition(
                    fromLevel: viewModel.energyLevel, toLevel: viewModel.energyLevel + 1)
            }) {
                Text("Quantum Jump")
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .disabled(
                viewModel.energyLevel >= 10
                    || (viewModel.visualizationType != .probability
                        && viewModel.visualizationType != .realPart
                        && viewModel.visualizationType != .imaginaryPart
                        && viewModel.visualizationType != .phase)
            )
        }
        .foregroundColor(.white)
    }

    private var scientificDataView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scientific Data")
                .font(.headline)
                .foregroundColor(.white)

            if viewModel.visualizationType == .probability
                || viewModel.visualizationType == .realPart
                || viewModel.visualizationType == .imaginaryPart
                || viewModel.visualizationType == .phase
            {

                // Quantum data
                VStack(alignment: .leading, spacing: 12) {
                    quantumDataRow(
                        label: "Energy", value: formatScientific(viewModel.quantumEnergy) + " J")
                    quantumDataRow(
                        label: "Energy (eV)",
                        value: formatScientific(viewModel.quantumEnergy / 1.602176634e-19) + " eV")
                    quantumDataRow(
                        label: "de Broglie λ",
                        value: formatScientific(viewModel.deBroglieWavelength) + " m")

                    switch viewModel.quantumSystemType {
                    case .potentialWell:
                        quantumDataRow(label: "Well width", value: "20 nm")
                    case .harmonicOscillator:
                        quantumDataRow(
                            label: "Angular freq",
                            value: formatScientific(Double(viewModel.energyLevel) * 1e14) + " rad/s"
                        )
                    case .hydrogenAtom:
                        let bohrRadius = 5.29177210903e-11
                        quantumDataRow(
                            label: "Orbital radius",
                            value: formatScientific(
                                bohrRadius * Double(viewModel.energyLevel * viewModel.energyLevel))
                                + " m")
                    default:
                        EmptyView()
                    }
                }

                Divider()
                    .background(Color.gray)

                quantumDataRow(
                    label: "Uncertainty",
                    value: formatScientific(viewModel.uncertaintyProduct) + " J·s")

            } else {
                // Audio data
                Group {
                    quantumDataRow(
                        label: "Frequency", value: String(format: "%.2f Hz", viewModel.frequency))
                    quantumDataRow(
                        label: "Period",
                        value: String(format: "%.2f ms", 1000 / viewModel.frequency))
                    quantumDataRow(
                        label: "Wavelength",
                        value: String(format: "%.2f m", 343 / viewModel.frequency))
                    quantumDataRow(
                        label: "Amplitude", value: String(format: "%.2f", viewModel.amplitude))
                }

                Divider()
                    .background(Color.gray)

                let bridge = viewModel.getQuantumAudioRelationship()
                quantumDataRow(label: "Quantum λ", value: bridge["quantum_wavelength"] ?? "N/A")
                quantumDataRow(
                    label: "Scaling factor", value: bridge["scaling_factor"] ?? "N/A")
            }

            // Render settings
            Divider()
                .background(Color.gray)

            Group {
                Picker("Quality", selection: $viewModel.renderQuality) {
                    ForEach(RenderQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                Toggle("Show Grid", isOn: $viewModel.showGrid)
                    .toggleStyle(SwitchToggleStyle())

                Toggle("Show Axes", isOn: $viewModel.showAxes)
                    .toggleStyle(SwitchToggleStyle())
            }
        }
        .foregroundColor(.white)
    }

    private func quantumDataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Color.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func formatScientific(_ value: Double) -> String {
        if abs(value) < 0.001 || abs(value) > 1000 {
            return String(format: "%.2e", value)
        }
        return String(format: "%.4f", value)
    }

    // Additional View for 3D visualization controls
    private var visualizationControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3D Visualization Controls")
                .font(.headline)
                .foregroundColor(.white)

            // System type selector
            Picker(
                "Visualization Type",
                selection: Binding(
                    get: { viewModel.visualSystemType },
                    set: { viewModel.changeVisualizationType($0) }
                )
            ) {
                Text("Harmonic Oscillator").tag(0)
                Text("Square Well").tag(1)
                Text("Superposition").tag(2)
            }
            .pickerStyle(MenuPickerStyle())

            // Energy level slider
            VStack(alignment: .leading) {
                Text("Energy Level: \(viewModel.visual3DEnergyLevel)")
                    .foregroundColor(.white)

                Slider(
                    value: Binding(
                        get: { Double(viewModel.visual3DEnergyLevel) },
                        set: { viewModel.changeEnergyLevel(Int($0)) }
                    ), in: 1...10, step: 1)
            }

            // Color scheme picker
            Picker(
                "Color Scheme",
                selection: Binding(
                    get: { viewModel.colorScheme.rawValue },
                    set: { viewModel.changeColorScheme($0) }
                )
            ) {
                Text("Classic").tag(0)
                Text("Thermal").tag(1)
                Text("Rainbow").tag(2)
                Text("Monochrome").tag(3)
            }
            .pickerStyle(MenuPickerStyle())

            // Animation toggle
            Toggle(
                "Animate",
                isOn: Binding(
                    get: { viewModel.animateTimeEvolution },
                    set: { viewModel.setAnimation($0) }
                ))
        }
        .foregroundColor(.white)
    }
}

// MARK: - Supporting Views

struct QuantumControlsView: View {
    @EnvironmentObject var viewModel: WaveformViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Quantum Parameter Controls")
                    .font(.title)
                    .foregroundColor(.white)

                // Quantum System Type
                VStack(alignment: .leading) {
                    Text("Quantum System")
                        .font(.headline)
                        .foregroundColor(.white)

                    Picker("", selection: $viewModel.quantumSystemType) {
                        ForEach(QuantumSystemType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Text(viewModel.quantumSystemType.description)
                        .font(.caption)
                        .foregroundColor(Color.gray)
                        .padding(.top, 4)
                }

                // Particle settings
                VStack(alignment: .leading) {
                    Text("Particle Properties")
                        .font(.headline)
                        .foregroundColor(.white)

                    // Particle mass
                    VStack(alignment: .leading) {
                        Text("Mass: \(formatScientific(viewModel.particleMass)) kg")
                            .foregroundColor(.white)

                        HStack {
                            Text("e⁻")
                                .foregroundColor(Color.gray)
                                .font(.caption)

                            Slider(
                                value: $viewModel.particleMass, in: 9.1093837e-31...1.6726219e-27
                            )

                            Text("p⁺")
                                .foregroundColor(Color.gray)
                                .font(.caption)
                        }
                    }
                }

                // Energy level settings
                VStack(alignment: .leading) {
                    Text("Energy Configuration")
                        .font(.headline)
                        .foregroundColor(.white)

                    // Energy level
                    VStack(alignment: .leading) {
                        Text("Energy Level: \(viewModel.energyLevel)")
                            .foregroundColor(.white)

                        HStack {
                            Text("1")
                                .foregroundColor(Color.gray)
                                .font(.caption)

                            Slider(value: $viewModel.energyLevelFloat, in: 1...10, step: 1)
                                .onChange(of: viewModel.energyLevelFloat) { newValue, _ in
                                    viewModel.energyLevel = Int(newValue)
                                }

                            Text("10")
                                .foregroundColor(Color.gray)
                                .font(.caption)
                        }
                    }

                    // Potential height (for potential well)
                    if viewModel.quantumSystemType == .potentialWell {
                        VStack(alignment: .leading) {
                            Text(
                                "Potential Height: \(formatScientific(viewModel.potentialHeight)) eV"
                            )
                            .foregroundColor(.white)

                            HStack {
                                Text("0")
                                    .foregroundColor(Color.gray)
                                    .font(.caption)

                                Slider(value: $viewModel.potentialHeight, in: 0...10)

                                Text("10")
                                    .foregroundColor(Color.gray)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // Controls for simulation
                VStack(alignment: .leading) {
                    Text("Simulation Controls")
                        .font(.headline)
                        .foregroundColor(.white)

                    Toggle("Animate Time Evolution", isOn: $viewModel.animateTimeEvolution)
                        .toggleStyle(SwitchToggleStyle())

                    Toggle("Scientific Notation", isOn: $viewModel.scientificNotation)
                        .toggleStyle(SwitchToggleStyle())
                }

                // Quantum jump buttons
                HStack {
                    Button(action: {
                        viewModel.applyQuantumTransition(
                            fromLevel: viewModel.energyLevel, toLevel: viewModel.energyLevel - 1)
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Transition Down")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.energyLevel <= 1)

                    Spacer()

                    Button(action: {
                        viewModel.applyQuantumTransition(
                            fromLevel: viewModel.energyLevel, toLevel: viewModel.energyLevel + 1)
                    }) {
                        HStack {
                            Text("Transition Up")
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.energyLevel >= 10)
                }
            }
            .padding()
        }
        .background(Color.black)
    }

    private func formatScientific(_ value: Double) -> String {
        if viewModel.scientificNotation {
            return String(format: "%.2e", value)
        }
        return String(format: "%.4f", value)
    }
}

struct AudioControlsView: View {
    @EnvironmentObject var viewModel: WaveformViewModel

    var body: some View {
        // Content for audio tab
        Text("Audio Controls")
    }
}

struct SettingsView: View {
    @EnvironmentObject var viewModel: WaveformViewModel

    var body: some View {
        // Content for settings tab
        Text("Settings")
    }
}

// MARK: - Metal View

struct MetalKitView: NSViewRepresentable {
    var viewModel: WaveformViewModel

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()

        // Configure Metal view with default device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Error: Metal is not supported on this device")
            return mtkView
        }

        mtkView.device = device
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = viewModel.targetFrameRate
        mtkView.enableSetNeedsDisplay = true
        mtkView.framebufferOnly = false

        // Set depth buffer format for 3D rendering
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.sampleCount = 1

        print("MetalKitView: Created MTKView with device \(device)")

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.preferredFramesPerSecond = viewModel.targetFrameRate

        // Check if we need to update the delegate based on dimension mode
        if viewModel.dimensionMode == .threeDimensional {
            if viewModel.renderer3D == nil {
                viewModel.setupRenderer3D()
            }

            if context.coordinator.activeRenderer != .threeDimensional {
                print("Switching to 3D renderer")
                context.coordinator.activeRenderer = .threeDimensional
                nsView.delegate = viewModel.renderer3D
            }
        } else {
            if context.coordinator.activeRenderer != .twoDimensional {
                print("Switching to 2D renderer")
                context.coordinator.activeRenderer = .twoDimensional
                nsView.delegate = context.coordinator
            }
        }

        nsView.setNeedsDisplay(nsView.bounds)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalKitView
        var activeRenderer: DimensionMode = .twoDimensional

        init(_ parent: MetalKitView) {
            self.parent = parent
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            print("MTKViewDelegate: drawableSizeWillChange to \(size)")
            // Forward resize event to appropriate renderer
            if activeRenderer == .threeDimensional {
                parent.viewModel.renderer3D?.mtkView(view, drawableSizeWillChange: size)
            }
        }

        func draw(in view: MTKView) {
            // Only handle 2D rendering here - 3D handled by its own delegate
            if activeRenderer == .twoDimensional, let renderer = parent.viewModel.renderer {
                renderer.render(in: view)
            }
        }
    }
}
