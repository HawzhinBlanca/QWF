//
//  VisualizationSettingsView.swift
//  QwantumWaveform
//
//  Created by HAWZHIN on 15/03/2025.
//

import Metal
import MetalKit
import SwiftUI

/// Advanced visualization settings interface providing professional control
/// over rendering, color schemes, and display parameters for quantum and audio visualization.
struct VisualizationSettingsView: View {
    @ObservedObject var viewModel: WaveformViewModel

    // Color scheme preview
    @State private var colorPreviewType: PreviewType = .gradient

    // Metal preview
    @State private var metalPreviewController: MetalPreviewController?

    // Visualization options
    @State private var scaleType: ScaleType = .linear
    @State private var expandedSections: Set<String> = ["display", "quality"]

    // Performance metrics
    @State private var showPerformanceMetrics: Bool = false
    @State private var frameRate: Double = 60.0
    @State private var renderLatency: Double = 0.0
    @State private var gpuUtilization: Double = 0.0

    // Export options
    @State private var exportResolution: ExportResolution = .hd
    @State private var exportFormat: ExportFormat = .png
    @State private var showExportOptions: Bool = false

    // Axis and scale options
    @State private var xAxisLabel: String = "Time (s)"
    @State private var yAxisLabel: String = "Amplitude"
    @State private var xAxisUnits: String = "s"
    @State private var yAxisUnits: String = ""

    // Camera options for 3D view
    @State private var cameraDistance: Double = 10.0
    @State private var cameraPitch: Double = 0.3
    @State private var cameraYaw: Double = 0.0

    // Visualization types
    enum PreviewType: String, CaseIterable {
        case gradient = "Gradient"
        case spectrum = "Spectrum"
        case heatmap = "Heatmap"
    }

    // Scale types
    enum ScaleType: String, CaseIterable {
        case linear = "Linear"
        case logarithmic = "Logarithmic"
        case decibel = "Decibel"
    }

    // Export resolutions
    enum ExportResolution: String, CaseIterable {
        case hd = "1920×1080"
        case uhd = "3840×2160"
        case custom = "Custom"
    }

    // Export formats
    enum ExportFormat: String, CaseIterable {
        case png = "PNG"
        case jpg = "JPEG"
        case tiff = "TIFF"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Visualization type selector
                visualizationTypeSelector

                // Display settings
                parameterSection("Display Settings", id: "display") {
                    displaySettingsContent
                }

                // Color schemes
                parameterSection("Color Scheme", id: "color") {
                    colorSchemeContent
                }

                // Quality settings
                parameterSection("Quality & Performance", id: "quality") {
                    qualitySettingsContent
                }

                // Axis settings
                parameterSection("Axis & Labels", id: "axis") {
                    axisSettingsContent
                }

                // 3D settings (when applicable)
                if viewModel.dimensionMode == .threeDimensional {
                    parameterSection("3D View Settings", id: "3d") {
                        threeDSettingsContent
                    }
                }

                // Export settings
                parameterSection("Export Settings", id: "export") {
                    exportSettingsContent
                }
            }
            .padding()
        }
        .onAppear {
            initializePreviewController()
            startPerformanceMonitoring()
        }
        .onDisappear {
            stopPerformanceMonitoring()
        }
    }

    // MARK: - UI Components

    /// Visualization type selector
    private var visualizationTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visualization Type")
                .font(.headline)

            HStack(spacing: 16) {
                visualizationButton(.waveform, icon: "waveform", label: "Waveform")
                visualizationButton(
                    .spectrum, icon: "waveform.path.ecg.rectangle", label: "Spectrum")
                visualizationButton(.probability, icon: "function", label: "Probability")
                visualizationButton(.phase, icon: "circle.dotted", label: "Phase Space")
            }

            HStack {
                // 2D/3D toggle
                Toggle(
                    "3D Visualization",
                    isOn: Binding(
                        get: { viewModel.dimensionMode == .threeDimensional },
                        set: { newValue in
                            viewModel.dimensionMode = newValue ? .threeDimensional : .twoDimensional
                            viewModel.updateVisualization()
                        }
                    )
                )
                .toggleStyle(SwitchToggleStyle(tint: .purple))

                Spacer()

                if viewModel.dimensionMode == .threeDimensional {
                    Picker("Mode:", selection: $viewModel.dimensionMode) {
                        Text("Surface").tag(DimensionMode.threeDimensional)
                        // Remove or comment out unavailable dimension modes
                        // Text("Wireframe").tag(DimensionMode.wireframe)
                        // Text("Points").tag(DimensionMode.points)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(true)  // Simplified for this implementation
                }
            }
            .padding(.top, 8)
        }
    }

    /// Visualization type button
    private func visualizationButton(_ type: VisualizationType, icon: String, label: String)
        -> some View
    {
        Button(action: {
            viewModel.visualizationType = type
            viewModel.updateVisualization()
        }) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(viewModel.visualizationType == type ? .purple : .gray)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(
                                viewModel.visualizationType == type
                                    ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                    )

                Text(label)
                    .font(.caption)
                    .foregroundColor(viewModel.visualizationType == type ? .purple : .gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Display settings content
    private var displaySettingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Grid toggle
            Toggle("Show Grid", isOn: $viewModel.showGrid)
                .onChange(of: viewModel.showGrid) { oldValue, newValue in
                    viewModel.updateVisualization()
                }

            // Axes toggle
            Toggle("Show Axes", isOn: $viewModel.showAxes)
                .onChange(of: viewModel.showAxes) { oldValue, newValue in
                    viewModel.updateVisualization()
                }

            // Scale toggle
            Toggle("Show Scale", isOn: $viewModel.showScale)
                .onChange(of: viewModel.showScale) { oldValue, newValue in
                    viewModel.updateVisualization()
                }

            // Scale type
            VStack(alignment: .leading) {
                Text("Scale Type:")
                Picker("", selection: $scaleType) {
                    ForEach(ScaleType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: scaleType) { oldValue, newValue in
                    updateScaleType(newValue)
                }
            }
            .padding(.top, 4)

            // Background color
            ColorPicker("Background Color", selection: .constant(Color.black.opacity(0.9)))
                .disabled(true)  // Simplified for this implementation

            // Viewport controls
            HStack {
                Text("Time Window:")
                Slider(value: .constant(5.0), in: 1...30)
                    .disabled(true)  // Simplified for this implementation

                Text("5.0 s")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.top, 4)
        }
    }

    /// Color scheme content
    private var colorSchemeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Color scheme picker
            Picker("Color Scheme", selection: $viewModel.colorScheme) {
                Text("Classic").tag(ColorSchemeType.classic)
                Text("Heat Map").tag(ColorSchemeType.heatMap)
                Text("Rainbow").tag(ColorSchemeType.rainbow)
                Text("Grayscale").tag(ColorSchemeType.grayscale)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.colorScheme) { oldValue, newValue in
                viewModel.updateVisualization()
            }

            // Color scheme preview
            colorSchemePreview

            // Preview type selector
            Picker("Preview Type", selection: $colorPreviewType) {
                ForEach(PreviewType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            // Custom color controls (disabled in simplified implementation)
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Colors:")
                    .font(.subheadline)

                HStack {
                    ColorPicker("Low Value", selection: .constant(Color.blue))

                    ColorPicker("Mid Value", selection: .constant(Color.green))

                    ColorPicker("High Value", selection: .constant(Color.red))
                }
            }
            .padding(.top, 4)
            .disabled(true)  // Simplified for this implementation
        }
    }

    /// Quality settings content
    private var qualitySettingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Render quality selector
            VStack(alignment: .leading) {
                Text("Render Quality:")
                Picker("", selection: $viewModel.renderQuality) {
                    Text("Low").tag(RenderQuality.low)
                    Text("Medium").tag(RenderQuality.medium)
                    Text("High").tag(RenderQuality.high)
                    // Remove or comment out unavailable quality option
                    // Text("Ultra").tag(RenderQuality.ultra)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: viewModel.renderQuality) { oldValue, newValue in
                    viewModel.updateVisualization()
                }
            }

            // Frame rate control
            VStack(alignment: .leading) {
                HStack {
                    Text("Target Frame Rate:")
                    Spacer()
                    Text("\(viewModel.targetFrameRate) FPS")
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.bottom, 1)

                Slider(value: $viewModel.targetFrameRateFloat, in: 30...120, step: 30)
                    .onChange(of: viewModel.targetFrameRateFloat) { oldValue, newValue in
                        viewModel.targetFrameRate = Int(newValue)
                        viewModel.updateVisualization()
                    }
            }

            // Anti-aliasing toggle
            Toggle("Enable Anti-aliasing", isOn: .constant(true))
                .disabled(true)  // Simplified for this implementation

            // Performance metrics toggle
            Toggle("Show Performance Metrics", isOn: $showPerformanceMetrics)

            // Performance metrics display
            if showPerformanceMetrics {
                performanceMetricsView
            }
        }
    }

    /// Axis settings content
    private var axisSettingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // X-axis label
            TextField("X-Axis Label", text: $xAxisLabel)

            // Y-axis label
            TextField("Y-Axis Label", text: $yAxisLabel)

            // Units
            HStack {
                VStack(alignment: .leading) {
                    Text("X-Axis Units:")
                    TextField("", text: $xAxisUnits)
                }

                VStack(alignment: .leading) {
                    Text("Y-Axis Units:")
                    TextField("", text: $yAxisUnits)
                }
            }

            // Scale and tick marks
            VStack(alignment: .leading) {
                Text("Tick Marks:")
                Picker("", selection: .constant(5)) {
                    Text("Few").tag(3)
                    Text("Medium").tag(5)
                    Text("Many").tag(10)
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(true)  // Simplified for this implementation
            }

            // Font settings
            VStack(alignment: .leading) {
                Text("Label Font:")
                Picker("", selection: .constant(0)) {
                    Text("System").tag(0)
                    Text("Monospaced").tag(1)
                    Text("Serif").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(true)  // Simplified for this implementation
            }
        }
    }

    /// 3D view settings content
    private var threeDSettingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Camera distance
            VStack(alignment: .leading) {
                HStack {
                    Text("Camera Distance:")
                    Spacer()
                    Text("\(String(format: "%.1f", cameraDistance))")
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.bottom, 1)

                Slider(value: $cameraDistance, in: 5...20)
            }

            // Camera pitch (elevation)
            VStack(alignment: .leading) {
                HStack {
                    Text("Camera Pitch:")
                    Spacer()
                    Text("\(String(format: "%.1f", cameraPitch * 90))°")
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.bottom, 1)

                Slider(value: $cameraPitch, in: 0.1...0.9)
            }

            // Camera yaw (rotation)
            VStack(alignment: .leading) {
                HStack {
                    Text("Camera Yaw:")
                    Spacer()
                    Text("\(String(format: "%.1f", cameraYaw * 360))°")
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.bottom, 1)

                Slider(value: $cameraYaw, in: 0...1)
            }

            // Lighting controls
            VStack(alignment: .leading) {
                Text("Lighting:")

                HStack {
                    Toggle("Ambient", isOn: .constant(true))
                    Toggle("Diffuse", isOn: .constant(true))
                    Toggle("Specular", isOn: .constant(true))
                }
                .disabled(true)  // Simplified for this implementation
            }

            // Shadow and effects
            VStack(alignment: .leading) {
                Text("Effects:")

                HStack {
                    Toggle("Shadows", isOn: .constant(true))
                    Toggle("Reflection", isOn: .constant(false))
                    Toggle("Glow", isOn: .constant(true))
                }
                .disabled(true)  // Simplified for this implementation
            }

            // Reset view button
            Button(action: {
                resetCameraView()
            }) {
                Text("Reset Camera View")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 8)
        }
    }

    /// Export settings content
    private var exportSettingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Export format
            Picker("Export Format", selection: $exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            // Export resolution
            Picker("Resolution", selection: $exportResolution) {
                ForEach(ExportResolution.allCases, id: \.self) { resolution in
                    Text(resolution.rawValue).tag(resolution)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            // Custom resolution (if selected)
            if exportResolution == .custom {
                HStack {
                    TextField("Width", text: .constant("1920"))
                        .frame(width: 80)

                    Text("×")

                    TextField("Height", text: .constant("1080"))
                        .frame(width: 80)

                    Spacer()
                }
                .disabled(true)  // Simplified for this implementation
            }

            // Include settings toggle
            Toggle("Include Settings Metadata", isOn: .constant(true))
                .disabled(true)  // Simplified for this implementation

            // Export buttons
            HStack {
                Button(action: {
                    viewModel.exportCurrentVisualization()
                }) {
                    Text("Export Current View")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: {
                    showExportOptions.toggle()
                }) {
                    Text("More Options...")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 8)
        }
    }

    /// Performance metrics view
    private var performanceMetricsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Frame Rate:")
                Spacer()
                Text("\(String(format: "%.1f", frameRate)) FPS")
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Render Latency:")
                Spacer()
                Text("\(String(format: "%.2f", renderLatency)) ms")
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("GPU Utilization:")
                Spacer()
                Text("\(String(format: "%.1f", gpuUtilization))%")
                    .font(.system(.body, design: .monospaced))
            }

            // GPU info
            HStack {
                Text("GPU:")
                Spacer()
                if let device = MTLCreateSystemDefaultDevice() {
                    Text("\(device.name)")
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }

    /// Color scheme preview
    private var colorSchemePreview: some View {
        Group {
            switch colorPreviewType {
            case .gradient:
                colorGradientPreview

            case .spectrum:
                colorSpectrumPreview

            case .heatmap:
                colorHeatmapPreview
            }
        }
        .frame(height: 100)
        .padding(.vertical, 8)
    }

    /// Color gradient preview
    private var colorGradientPreview: some View {
        gradient(for: viewModel.colorScheme)
            .cornerRadius(8)
    }

    /// Color spectrum preview
    private var colorSpectrumPreview: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .cornerRadius(8)

            Path { path in
                let width: CGFloat = 300
                let height: CGFloat = 100
                let midHeight = height / 2

                path.move(to: CGPoint(x: 0, y: midHeight))

                for x in 0..<Int(width) {
                    let phase = Double(x) / 50.0
                    let y = midHeight - 40 * sin(phase)
                    path.addLine(to: CGPoint(x: CGFloat(x), y: y))
                }
            }
            .stroke(
                AngularGradient(
                    gradient: gradientColors(for: viewModel.colorScheme),
                    center: .center
                ),
                lineWidth: 3
            )
        }
    }

    /// Color heatmap preview
    private var colorHeatmapPreview: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .cornerRadius(8)

            GeometryReader { geometry in
                ForEach(0..<20) { x in
                    ForEach(0..<10) { y in
                        let value = sin(Double(x) / 3.0) * cos(Double(y) / 2.0)
                        let normalizedValue = (value + 1) / 2.0  // Map to 0-1

                        Rectangle()
                            .fill(colorAtValue(normalizedValue, for: viewModel.colorScheme))
                            .frame(
                                width: geometry.size.width / 20,
                                height: geometry.size.height / 10
                            )
                            .position(
                                x: CGFloat(x) * geometry.size.width / 20 + geometry.size.width / 40,
                                y: CGFloat(y) * geometry.size.height / 10 + geometry.size.height
                                    / 20
                            )
                    }
                }
            }
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

    /// Initialize Metal preview controller
    private func initializePreviewController() {
        metalPreviewController = MetalPreviewController()
    }

    /// Start performance monitoring
    private func startPerformanceMonitoring() {
        // In a real implementation, would start collecting real-time metrics
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let minFrameRate = Double(viewModel.targetFrameRate - 5)
            let maxFrameRate = Double(viewModel.targetFrameRate)
            frameRate = Double.random(in: minFrameRate..<maxFrameRate)
            renderLatency = Double.random(in: 1.5...5.0)
            gpuUtilization = Double.random(in: 25...50)
        }
    }

    /// Stop performance monitoring
    private func stopPerformanceMonitoring() {
        // In a real implementation, would stop the monitoring process
    }

    /// Update scale type
    private func updateScaleType(_ type: ScaleType) {
        // In a real implementation, would update the visualization scale
    }

    /// Reset camera view to defaults
    private func resetCameraView() {
        cameraDistance = 10.0
        cameraPitch = 0.3
        cameraYaw = 0.0
    }

    // MARK: - Color Helpers

    /// Get gradient for a color scheme
    private func gradient(for scheme: ColorSchemeType) -> LinearGradient {
        LinearGradient(
            gradient: gradientColors(for: scheme),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Get gradient colors for a color scheme
    private func gradientColors(for scheme: ColorSchemeType) -> Gradient {
        switch scheme {
        case .classic:
            return Gradient(colors: [.blue, .cyan, .green, .yellow, .orange, .red])

        case .heatMap:
            return Gradient(colors: [.black, .purple, .red, .orange, .yellow, .white])

        case .rainbow:
            return Gradient(colors: [
                .purple, .blue, .cyan, .green, .yellow, .orange, .red, .purple,
            ])

        case .grayscale:
            return Gradient(colors: [.black, .gray, .white])

        case .neon:
            return Gradient(colors: [.green, .yellow, .pink, .purple, .blue])
        }
    }

    /// Get color at a normalized value (0-1) for a color scheme
    private func colorAtValue(_ value: Double, for scheme: ColorSchemeType) -> Color {
        switch scheme {
        case .classic:
            if value < 0.2 {
                return .blue.opacity(value * 5)
            } else if value < 0.4 {
                return .cyan.opacity((value - 0.2) * 5)
            } else if value < 0.6 {
                return .green.opacity((value - 0.4) * 5)
            } else if value < 0.8 {
                return .orange.opacity((value - 0.6) * 5)
            } else {
                return .red.opacity((value - 0.8) * 5)
            }

        case .heatMap:
            if value < 0.25 {
                return .black.opacity(value * 4)
            } else if value < 0.5 {
                return .purple.opacity((value - 0.25) * 4)
            } else if value < 0.75 {
                return .red.opacity((value - 0.5) * 4)
            } else {
                return .yellow.opacity((value - 0.75) * 4)
            }

        case .rainbow:
            let hue = value
            return Color(hue: hue, saturation: 1.0, brightness: 1.0)

        case .grayscale:
            return Color(white: value)

        case .neon:
            let hue = value * 0.8  // Keep in the vibrant range
            return Color(hue: hue, saturation: 1.0, brightness: 1.0)
        }
    }
}

// MARK: - Metal Preview Controller

/// Controller for Metal visualization previews
class MetalPreviewController {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?

    init() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
    }

    // Additional Metal rendering methods would be implemented here
}

// MARK: - Preview

struct VisualizationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        VisualizationSettingsView(viewModel: WaveformViewModel())
            .frame(width: 600, height: 800)
            .previewLayout(.fixed(width: 600, height: 800))
    }
}
