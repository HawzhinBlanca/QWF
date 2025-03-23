//
//  QuantumVisualizationComponent.swift
//  QwantumWaveform
//
//  Created by HAWZHIN on 15/03/2025.
//

import Accelerate
import Metal
import MetalKit
import SwiftUI

/// A SwiftUI component for visualizing quantum wave functions and audio waveforms
/// with scientific precision and elegant design.
struct QuantumVisualizationComponent: View {
    @ObservedObject var viewModel: WaveformViewModel

    // Local state
    @State private var isRotating = false
    @State private var rotationAngle: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var previousLocation: CGPoint?
    @State private var showScientificValues = false
    @State private var hoverPoint: CGPoint?
    @State private var fadeInOpacity: Double = 0
    @State private var breathingAnimation: CGFloat = 1.0

    // Animation timing
    @State private var animationPhase: Double = 0

    // System info label
    private var systemInfoLabel: some View {
        Text(
            "Quantum System: \(viewModel.quantumSystemType.rawValue) | Energy Level: \(viewModel.energyLevel)"
        )
        .font(.system(size: 12))
        .foregroundColor(.white)
    }

    var body: some View {
        ZStack {
            // Main visualization view
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.black.opacity(0.2)
                        .edgesIgnoringSafeArea(.all)

                    // MetalKit view for rendering
                    if viewModel.dimensionMode == .threeDimensional {
                        // Placeholder for Metal3DVisualizationView
                        Text("3D Visualization")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.1))
                    } else {
                        // Placeholder for MetalVisualizationView
                        Text("2D Visualization")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.1))
                    }

                    // Grid and axis (lowest z-index)
                    if viewModel.dimensionMode == .twoDimensional {
                        Group {
                            // Grid (if enabled)
                            if viewModel.showGrid {
                                GridView(
                                    size: geometry.size,
                                    density: viewModel.renderQuality.rawValue + 4
                                )
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            }

                            // Axis lines (if enabled)
                            if viewModel.showAxes {
                                AxisView(size: geometry.size)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            }
                        }
                    }

                    // Scale indicators (if enabled and in 2D mode)
                    if viewModel.showScale && viewModel.dimensionMode == .twoDimensional {
                        ScaleIndicatorView(size: geometry.size, viewModel: viewModel)
                            .opacity(fadeInOpacity)
                    }

                    // Energy level indicator for quantum systems (mid z-index)
                    if (viewModel.visualizationType == .probability
                        || viewModel.visualizationType == .phase)
                        && viewModel.dimensionMode == .twoDimensional
                    {
                        EnergyLevelIndicator(
                            level: viewModel.energyLevel, maxLevel: 10, size: geometry.size
                        )
                        .scaleEffect(breathingAnimation)
                        .opacity(fadeInOpacity)
                        .onAppear {
                            withAnimation(
                                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                            ) {
                                breathingAnimation = 1.05
                            }
                        }
                    }

                    // System info label (top-left corner)
                    VStack {
                        HStack {
                            systemInfoLabel
                                .padding(10)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(8)
                                .padding()
                                .opacity(fadeInOpacity)

                            Spacer()
                        }

                        Spacer()
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if viewModel.dimensionMode == .threeDimensional {
                                if let previousLocation = self.previousLocation {
                                    let deltaX = Float(value.location.x - previousLocation.x)
                                    viewModel.rotateVisualization(byAngle: deltaX * 0.01)
                                }
                                self.previousLocation = value.location
                            } else {
                                // Store hover point for 2D visualization
                                hoverPoint = value.location
                            }
                        }
                        .onEnded { _ in
                            self.previousLocation = nil
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            self.scale = value
                        }
                        .onEnded { _ in
                            self.scale = 1.0
                        }
                )
                .onHover { hovering in
                    if !hovering {
                        hoverPoint = nil
                    }
                }
            }

            // Scientific data overlay (optional - high z-index)
            if showScientificValues {
                GeometryReader { geo in
                    ScientificDataOverlayView(viewModel: viewModel)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .frame(width: min(300, geo.size.width * 0.3), alignment: .leading)
                        .position(x: geo.size.width * 0.2, y: geo.size.height * 0.25)
                        .transition(.opacity)
                }
            }

            // Quantum-audio relationship indicator (highest z-index)
            if viewModel.visualizationType == .phase {
                QuantumAudioRelationshipIndicator(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.scale)
            }

            // Controls overlay (highest z-index)
            VStack {
                Spacer()

                HStack {
                    ControlButton(
                        icon: "info.circle",
                        action: { showScientificValues.toggle() },
                        isActive: showScientificValues
                    )

                    Spacer()

                    // Play/pause button
                    ControlButton(
                        icon: viewModel.isPlaying ? "pause.circle" : "play.circle",
                        action: { viewModel.isPlaying.toggle() },
                        isActive: viewModel.isPlaying
                    )
                    .keyboardShortcut(.space, modifiers: [])

                    // 2D/3D toggle button
                    ControlButton(
                        icon: viewModel.dimensionMode == .threeDimensional
                            ? "square.stack.3d.down.right" : "square.stack.3d.up.fill",
                        action: { viewModel.toggleVisualizationMode() },
                        isActive: viewModel.dimensionMode == .threeDimensional
                    )

                    // Export button
                    ControlButton(
                        icon: "square.and.arrow.up",
                        action: { viewModel.exportCurrentVisualization() },
                        isActive: false
                    )
                }
                .padding([.horizontal, .bottom])
            }
        }
        .onAppear {
            // Start animation timer
            startAnimationTimer()

            // Fade in overlay elements
            withAnimation(.easeIn(duration: 1.0)) {
                fadeInOpacity = 1.0
            }
        }
    }

    private func startAnimationTimer() {
        // Create timer for animations
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            animationPhase += 0.05
            if animationPhase > .pi * 2 {
                animationPhase -= .pi * 2
            }
        }
    }
}

// MARK: - Supporting Views

/// Scientific data overlay view displaying physics parameters
struct ScientificDataOverlayView: View {
    @ObservedObject var viewModel: WaveformViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantum Wave Parameters")
                .font(.headline)
                .foregroundColor(.white)

            Divider().background(Color.white.opacity(0.5))

            Group {
                if let deBroglie = viewModel.quantumObservables["de_broglie_wavelength"] {
                    valueRow(label: "De Broglie λ:", value: formatScientific(deBroglie) + " m")
                }

                if let energy = viewModel.quantumObservables["energy"] {
                    valueRow(label: "Energy:", value: formatScientific(energy) + " J")
                }

                if let energyEV = viewModel.quantumObservables["energy_ev"] {
                    valueRow(label: "Energy:", value: formatScientific(energyEV) + " eV")
                }

                switch viewModel.quantumSystemType {
                case .freeParticle:
                    if let momentum = viewModel.quantumObservables["momentum"] {
                        valueRow(label: "Momentum:", value: formatScientific(momentum) + " kg·m/s")
                    }

                case .potentialWell:
                    if let width = viewModel.quantumObservables["confinement_width"] {
                        valueRow(label: "Well width:", value: formatScientific(width) + " m")
                    }

                case .harmonicOscillator:
                    if let omega = viewModel.quantumObservables["angular_frequency"] {
                        valueRow(label: "ω:", value: formatScientific(omega) + " rad/s")
                    }

                    if let amplitude = viewModel.quantumObservables["classical_amplitude"] {
                        valueRow(label: "Classical A:", value: formatScientific(amplitude) + " m")
                    }

                case .hydrogenAtom:
                    if let orbitalRadius = viewModel.quantumObservables["orbital_radius"] {
                        valueRow(
                            label: "Orbital radius:", value: formatScientific(orbitalRadius) + " m")
                    }
                }
            }

            Divider().background(Color.white.opacity(0.5))

            // Audio-Quantum relationship
            if viewModel.wavelength > 0 && viewModel.deBroglieWavelength > 0 {
                let ratio = viewModel.wavelength / viewModel.deBroglieWavelength
                valueRow(label: "λₐᵤₐ/λₚₕᵧₛ ratio:", value: formatScientific(ratio))
            }

            valueRow(
                label: "ΔxΔp uncertainty:",
                value: formatScientific(viewModel.uncertaintyProduct) + " J·s")
        }
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.white)
    }

    private func valueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
    }

    private func formatScientific(_ value: Double) -> String {
        if abs(value) < 0.001 || abs(value) > 1000 {
            return String(format: "%.3e", value)
        }
        return String(format: "%.4f", value)
    }
}

/// Visualization overlay with grid, axis labels, and scale
struct VisualizationOverlayView: View {
    @ObservedObject var viewModel: WaveformViewModel
    let size: CGSize

    // Animation state
    @State private var breathingAnimation: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Grid (if enabled)
            if viewModel.showGrid && viewModel.dimensionMode == .twoDimensional {
                GridView(size: size, density: viewModel.renderQuality.rawValue + 4)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }

            // Axis lines (if enabled)
            if viewModel.showAxes && viewModel.dimensionMode == .twoDimensional {
                AxisView(size: size)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            }

            // System labels
            VStack {
                HStack {
                    systemInfoLabel
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                        .padding()

                    Spacer()
                }

                Spacer()
            }

            // Scale indicators (if enabled)
            if viewModel.showScale && viewModel.dimensionMode == .twoDimensional {
                ScaleIndicatorView(size: size, viewModel: viewModel)
            }

            // Energy level indicator for quantum systems
            if viewModel.visualizationType == .probability
                || viewModel.visualizationType == .phase
            {
                EnergyLevelIndicator(level: viewModel.energyLevel, maxLevel: 10, size: size)
                    .scaleEffect(breathingAnimation)
                    .onAppear {
                        withAnimation(
                            Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                        ) {
                            breathingAnimation = 1.05
                        }
                    }
            }
        }
    }

    private var systemInfoLabel: some View {
        VStack(alignment: .leading) {
            if viewModel.visualizationType == .waveform || viewModel.visualizationType == .spectrum
            {
                Text("\(self.getWaveformTypeDescription()) Wave")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(Int(viewModel.frequency)) Hz, A=\(viewModel.amplitude, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("\(self.getQuantumTypeDescription())")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("n=\(viewModel.energyLevel), t=\(viewModel.simulationTime, specifier: "%.1f")")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // Helper methods to access properties without wrapper issues
    private func getWaveformTypeDescription() -> String {
        switch viewModel.waveformType {
        case .sine: return "Sine"
        case .square: return "Square"
        case .triangle: return "Triangle"
        case .sawtooth: return "Sawtooth"
        case .noise: return "Noise"
        case .custom: return "Custom"
        }
    }

    private func getQuantumTypeDescription() -> String {
        switch viewModel.quantumSystemType {
        case .freeParticle: return "Free Particle"
        case .potentialWell: return "Potential Well"
        case .harmonicOscillator: return "Harmonic Oscillator"
        case .hydrogenAtom: return "Hydrogen Atom"
        }
    }
}

/// Grid view for visualization background
struct GridView: Shape {
    let size: CGSize
    let density: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let horizontalSpacing = size.width / CGFloat(density)
        let verticalSpacing = size.height / CGFloat(density)

        // Vertical lines
        for i in 0...density {
            let x = CGFloat(i) * horizontalSpacing
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }

        // Horizontal lines
        for i in 0...density {
            let y = CGFloat(i) * verticalSpacing
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }

        return path
    }
}

/// Axis view for visualization
struct AxisView: Shape {
    let size: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // X-axis
        let xAxisY = size.height / 2
        path.move(to: CGPoint(x: 0, y: xAxisY))
        path.addLine(to: CGPoint(x: size.width, y: xAxisY))

        // Y-axis
        let yAxisX = size.width / 2
        path.move(to: CGPoint(x: yAxisX, y: 0))
        path.addLine(to: CGPoint(x: yAxisX, y: size.height))

        return path
    }
}

/// Scale indicator for visualization
struct ScaleIndicatorView: View {
    let size: CGSize
    @ObservedObject var viewModel: WaveformViewModel

    var body: some View {
        ZStack {
            // X-axis scale
            VStack {
                Spacer()

                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 1, height: 6)

                            if viewModel.visualizationType == .waveform
                                || viewModel.visualizationType == .spectrum
                            {
                                Text(formatTime(CGFloat(i) / 4))
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.7))
                            } else {
                                Text(formatPosition(CGFloat(i) / 4))
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .frame(width: size.width / 5)

                        if i < 4 {
                            Spacer()
                        }
                    }
                }
                .frame(width: size.width, height: 25)
                .offset(y: -5)
            }

            // Y-axis scale
            HStack {
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        HStack(spacing: 4) {
                            if viewModel.visualizationType == .waveform
                                || viewModel.visualizationType == .spectrum
                            {
                                Text(formatAmplitude(1.0 - CGFloat(i) / 4))
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 25, alignment: .trailing)
                            } else {
                                Text(formatProbability(1.0 - CGFloat(i) / 4))
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 25, alignment: .trailing)
                            }

                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 6, height: 1)
                        }
                        .frame(height: size.height / 5)

                        if i < 4 {
                            Spacer()
                        }
                    }
                }
                .frame(width: 40, height: size.height)

                Spacer()
            }
        }
    }

    private func formatTime(_ fraction: CGFloat) -> String {
        let period = 1.0 / viewModel.frequency
        let time = period * Double(fraction)
        return String(format: "%.1f ms", time * 1000)
    }

    private func formatAmplitude(_ fraction: CGFloat) -> String {
        return String(format: "%.1f", Double(fraction))
    }

    private func formatPosition(_ fraction: CGFloat) -> String {
        // For quantum visualization, use appropriate scale
        return String(format: "%.1f Å", Double(fraction - 0.5) * 10)
    }

    private func formatProbability(_ fraction: CGFloat) -> String {
        return String(format: "%.1f", Double(fraction))
    }
}

/// Energy level indicator for quantum systems
struct EnergyLevelIndicator: View {
    let level: Int
    let maxLevel: Int
    let size: CGSize

    var body: some View {
        ZStack {
            // Energy level lines
            VStack(spacing: 0) {
                ForEach(1...maxLevel, id: \.self) { n in
                    let energyScale = calculateEnergy(n)
                    let isCurrentLevel = n == level

                    ZStack {
                        Rectangle()
                            .fill(isCurrentLevel ? Color.yellow : Color.white.opacity(0.3))
                            .frame(height: 1)

                        if isCurrentLevel {
                            Text("n = \(n)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                                .offset(y: -12)
                        }
                    }
                    .frame(width: min(size.width * 0.15, 60))

                    Spacer(minLength: calculateSpacing(n, energyScale))
                }
            }
            .frame(height: size.height * 0.7)
            .position(x: size.width * 0.9, y: size.height * 0.5)
        }
    }

    private func calculateEnergy(_ n: Int) -> CGFloat {
        // Different scaling based on quantum system type
        return 1.0 / CGFloat(n * n)  // For hydrogen-like systems
    }

    private func calculateSpacing(_ n: Int, _ energyScale: CGFloat) -> CGFloat {
        // Scale spacing based on energy levels, with minimum spacing
        return max(size.height * 0.07 * energyScale, 5)
    }
}

/// Quantum-audio relationship indicator
struct QuantumAudioRelationshipIndicator: View {
    @ObservedObject var viewModel: WaveformViewModel
    @State private var animationPhase: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let circleSize = min(size * 0.12, 70)
            let fontSize = max(min(size * 0.018, 14), 9)

            VStack(spacing: fontSize * 0.8) {
                Text("Quantum-Audio Bridge")
                    .font(.system(size: fontSize * 1.2, weight: .medium))
                    .foregroundColor(.white)

                HStack(spacing: max(fontSize * 2, 20)) {
                    // Quantum side
                    VStack {
                        Text("Quantum")
                            .font(.system(size: fontSize))
                            .foregroundColor(.blue)

                        ZStack {
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                                .frame(width: circleSize, height: circleSize)

                            // Electron orbit visualization
                            ForEach(0..<10, id: \.self) { i in
                                Circle()
                                    .fill(Color.blue)
                                    .frame(
                                        width: max(circleSize * 0.06, 3),
                                        height: max(circleSize * 0.06, 3)
                                    )
                                    .offset(
                                        x: circleSize / 2 * cos(Double(i) * 0.628 + animationPhase),
                                        y: circleSize / 2 * sin(Double(i) * 0.628 + animationPhase)
                                    )
                            }

                            Text("λ = \(formatScientific(viewModel.deBroglieWavelength)) m")
                                .font(.system(size: fontSize * 0.8))
                                .foregroundColor(.white)
                                .offset(y: circleSize * 0.7)
                        }
                    }

                    // Connecting arrows
                    VStack {
                        Image(systemName: "arrow.right")
                            .font(.system(size: fontSize * 1.5))
                            .foregroundColor(.purple)

                        Text("ƒ = ħ/λ × S")
                            .font(.system(size: fontSize * 0.8))
                            .foregroundColor(.yellow)

                        Image(systemName: "arrow.left")
                            .font(.system(size: fontSize * 1.5))
                            .foregroundColor(.purple)
                    }

                    // Audio side
                    VStack {
                        Text("Audio")
                            .font(.system(size: fontSize))
                            .foregroundColor(.green)

                        ZStack {
                            Circle()
                                .stroke(Color.green, lineWidth: 2)
                                .frame(width: circleSize, height: circleSize)

                            // Audio wave visualization
                            Path { path in
                                path.move(to: CGPoint(x: -circleSize / 2, y: 0))

                                for i in -Int(circleSize / 2)...Int(circleSize / 2) {
                                    let x = CGFloat(i)
                                    let y =
                                        circleSize / 4
                                        * sin(CGFloat(i) / 5 + CGFloat(animationPhase))
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: circleSize, height: circleSize)
                            .clipShape(Circle())

                            Text("ƒ = \(Int(viewModel.frequency)) Hz")
                                .font(.system(size: fontSize * 0.8))
                                .foregroundColor(.white)
                                .offset(y: circleSize * 0.7)
                        }
                    }
                }

                Text("Scaling Factor: \(formatScientific(viewModel.quantumAudioScalingFactor))")
                    .font(.system(size: fontSize * 0.8))
                    .foregroundColor(.gray)
            }
            .padding(fontSize)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .onAppear {
            // Start animation timer
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                animationPhase += 0.05
                if animationPhase > .pi * 2 {
                    animationPhase -= .pi * 2
                }
            }
        }
    }

    private func formatScientific(_ value: Double) -> String {
        if abs(value) < 0.001 || abs(value) > 1000 {
            return String(format: "%.2e", value)
        }
        return String(format: "%.4f", value)
    }
}

/// Control button for the visualization
struct ControlButton: View {
    let icon: String
    let action: () -> Void
    let isActive: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isActive ? .yellow : .white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.4))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct QuantumVisualizationComponent_Previews: PreviewProvider {
    static var previews: some View {
        QuantumVisualizationComponent(viewModel: WaveformViewModel())
            .frame(width: 800, height: 600)
            .preferredColorScheme(.dark)
    }
}
