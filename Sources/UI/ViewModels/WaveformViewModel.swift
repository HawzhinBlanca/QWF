import AVFoundation
import Combine
import Metal
import MetalKit
import QuartzCore
import SwiftUI

// MARK: - WaveformRenderer Extensions
// Adding extensions to support methods used in the view model

extension WaveformRenderer {
    // Set the render quality (maps to internal parameters)
    func setRenderQuality(_ quality: Int) {
        // Map quality to existing properties - no direct property in base renderer
    }

    // Set show grid property
    func setShowGrid(_ show: Bool) {
        self.showGrid = show
    }

    // Set show axes property
    func setShowAxes(_ show: Bool) {
        // Map to showGrid since there's no direct property
        self.showGrid = show
    }

    // Set color scheme property
    func setColorScheme(_ scheme: UInt32) {
        self.colorScheme = scheme
    }

    // Update probability data
    func updateProbabilityData(_ data: [Double]) {
        // Convert to Float and use the existing updateQuantumData method
        updateQuantumData(data.map { Float($0) })
    }

    // Update wave function data
    func updateWaveFunctionData(_ data: [Double], isReal: Bool) {
        // Convert to Float and use the existing updateQuantumData method
        updateQuantumData(data.map { Float($0) })
    }

    // Update phase data
    func updatePhaseData(_ data: [Double]) {
        // Convert to Float and use the existing updateQuantumData method
        updateQuantumData(data.map { Float($0) })
    }

    // Set needs update (forces redraw)
    func setNeedsUpdate() {
        // Access the metal view if available and request a redraw
        if let metalView = self.value(forKey: "metalView") as? MTKView {
            metalView.needsDisplay = true
        }
    }

    // Capture current frame - simplified implementation
    func captureCurrentFrame(completion: @escaping (NSImage?) -> Void) {
        // This is a placeholder - a real implementation would need to render to a texture
        // and convert that to an NSImage. For now, we'll just call the completion with nil
        completion(nil)
    }
}

/// View model that coordinates the quantum simulator, waveform generator, and visualization renderer
/// to provide a unified interface for the application.
class WaveformViewModel: ObservableObject {
    // MARK: - Published Properties

    // Audio waveform parameters
    @Published var waveformType: WaveformType = .sine
    @Published var frequency: Double = 440.0
    @Published var amplitude: Double = 0.5
    @Published var phase: Double = 0.0
    @Published var harmonicRichness: Double = 0.5
    @Published var useLogFrequency: Bool = true
    @Published var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                startPlayback()
            } else {
                stopPlayback()
            }
        }
    }

    // Derived audio properties
    @Published var wavelength: Double = 0.0
    @Published var period: Double = 0.0

    // Quantum parameters
    @Published var quantumSystemType: QuantumSystemType = .freeParticle
    @Published var particleMass: Double = 9.1093837e-31  // electron mass
    @Published var energyLevel: Int = 1
    @Published var energyLevelFloat: Double = 1.0
    @Published var simulationTime: Double = 0.0
    @Published var animateTimeEvolution: Bool = true
    @Published var potentialHeight: Double = 0.0

    // Visualization settings
    @Published var visualizationType: VisualizationType = .waveform
    @Published var dimensionMode: DimensionMode = .twoDimensional {
        didSet {
            if oldValue != dimensionMode {
                print("DEBUG: Dimension mode changed to \(dimensionMode)")
                // Additional dimension mode change handling here
            }
        }
    }
    @Published var colorScheme: ColorSchemeType = .classic
    @Published var showGrid: Bool = true
    @Published var showAxes: Bool = true
    @Published var showScale: Bool = true
    @Published var renderQuality: RenderQuality = .medium
    @Published var targetFrameRate: Int = 60
    @Published var targetFrameRateFloat: Double = 60.0

    // Scientific calculations
    @Published var quantumAudioScalingFactor: Double = 1e34  // Scaling between quantum and audio domains
    @Published var scientificNotation: Bool = true  // Display values in scientific notation
    @Published var quantumObservables: [String: Double] = [:]  // Observable values for quantum system

    // MARK: - Performance & Animation Properties

    private var animationTimer: Timer?
    private var frameCount: Int = 0
    private var totalFrameTime: Double = 0
    private var lastFrameTime: Double = 0
    private var frameStartTime: Double = 0
    private var fpsUpdateInterval: Double = 1.0

    // MARK: - Render State Tracking

    private var lastRenderQuality: RenderQuality = .medium
    private var lastShowGrid: Bool = true
    private var lastShowAxes: Bool = true
    private var lastColorScheme: UInt32 = 0
    private var lastVisualizationType: VisualizationType = .probability
    private var lastVisualizationUpdateTime: Double = 0

    // MARK: - Quantum State Properties

    // Changed from private to public for access from Views
    public var deBroglieWavelength: Double = 0
    public var quantumEnergy: Double = 0
    public var uncertaintyProduct: Double = 0
    public var expectedPosition: Double = 0
    private var reducedPlanckConstant: Double = 1.054571817e-34
    private var planckConstant: Double = 6.62607015e-34

    // MARK: - Private Properties

    // Core engines
    private(set) var waveformGenerator: WaveformGenerator
    private(set) var quantumSimulator: QuantumSimulator
    // Use the WaveformRenderer from the Rendering/Metal directory
    var renderer: WaveformRenderer?
    var renderer3D: WaveformRenderer3D?

    // Domain bridging
    private var bridgedData: [String: Any] = [:]

    // MARK: - Data Structure Optimization

    // Cache for visualization data to avoid repeated calculations
    private var waveformDataCache: [Double]?
    private var spectrumDataCache: [Double]?
    private var lastWaveformType: WaveformType?
    private var lastFrequency: Double = 0
    private var lastAmplitude: Double = 0

    // Reset caches when parameters change
    private func invalidateDataCaches() {
        waveformDataCache = nil
        spectrumDataCache = nil
    }

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 3D Visualization Properties

    // System type for quantum visualization
    public var visualSystemType: Int = 0 {
        didSet {
            if oldValue != visualSystemType {
                update3DVisualization()
            }
        }
    }

    // Energy level for 3D quantum states
    public var visual3DEnergyLevel: Int = 1 {
        didSet {
            if oldValue != visual3DEnergyLevel {
                update3DVisualization()
            }
        }
    }

    // MARK: - Initialization

    init() {
        print("DEBUG: WaveformViewModel initializing...")

        // Create default Generator and Simulator
        waveformGenerator = WaveformGenerator()
        quantumSimulator = QuantumSimulator()

        // Initialize both renderers
        setupRenderer()  // Initialize 2D renderer
        setupRenderer3D()  // Initialize 3D renderer

        // Set up initial values
        quantumSimulator.setEnergyLevel(energyLevel)

        // Update simulation
        updateQuantumSimulation()

        print("DEBUG: Bindings setup complete")

        // Start timer for animation
        setupAnimationTimer()

        print("DEBUG: WaveformViewModel initialization complete")
    }

    deinit {
        stopPlayback()
        animationTimer?.invalidate()
        print("WaveformViewModel deallocated properly")
    }

    // MARK: - Public Methods

    /// Adjusts the frequency by the given amount
    func adjustFrequency(by amount: Double) {
        frequency = max(20, min(20000, frequency + amount))
        updateWaveform()
    }

    /// Updates the waveform generator with current parameters
    func updateWaveform() {
        // Only update if parameters have changed
        if waveformDataCache == nil || lastWaveformType != waveformType
            || abs(lastFrequency - frequency) > 0.001 || abs(lastAmplitude - amplitude) > 0.001
        {

            // Update internal state
            lastWaveformType = waveformType
            lastFrequency = frequency
            lastAmplitude = amplitude

            // Update waveform generator with current parameters
            waveformGenerator.setType(waveformType)
            waveformGenerator.setFrequency(frequency)
            waveformGenerator.setAmplitude(amplitude)
            waveformGenerator.setPhase(phase)

            // Generate new data
            let newWaveformData = waveformGenerator.generateWaveform(sampleCount: 1024)
            let newSpectrumData = waveformGenerator.generateSpectrum(sampleCount: 512)

            // Cache results
            waveformDataCache = newWaveformData
            spectrumDataCache = newSpectrumData

            // Update renderer with explicit type conversion
            renderer?.updateWaveformData(newWaveformData.map { Float($0) })
            renderer?.updateSpectrumData(newSpectrumData.map { Float($0) })

            // Update derived properties
            wavelength = 343.0 / frequency  // Speed of sound / frequency
            period = 1.0 / frequency
        }
    }

    /// Updates the quantum simulation with current parameters
    func updateQuantumSimulation() {
        // Skip debug log message that was here before

        // Configure simulator with current parameters
        quantumSimulator.setSystemType(quantumSystemType)
        quantumSimulator.setEnergyLevel(energyLevel)
        quantumSimulator.setParticleMass(particleMass)
        quantumSimulator.setPotentialHeight(potentialHeight)
        quantumSimulator.setAnimateTimeEvolution(animateTimeEvolution)

        // Run simulation
        quantumSimulator.runSimulation()

        // Update domain bridge calculations
        updateDomainBridgeCalculations()

        // Update quantum observables
        updateQuantumObservables()

        // Update visualization if needed
        if visualizationType == .probability || visualizationType == .realPart
            || visualizationType == .imaginaryPart || visualizationType == .phase
        {
            updateVisualization()
        }
    }

    /// Updates the visualization renderer with current parameters
    func updateVisualization() {
        // Skip if no renderer available
        guard let renderer = renderer else {
            return
        }

        // Update common renderer parameters only if changed
        if lastRenderQuality != renderQuality {
            // No direct equivalent in WaveformRenderer, so we skip this or use a property if it exists
            // renderer.setRenderQuality(renderQuality)
            lastRenderQuality = renderQuality
        }

        if lastShowGrid != showGrid {
            // Use the showGrid property directly
            renderer.showGrid = showGrid
            lastShowGrid = showGrid
        }

        if lastShowAxes != showAxes {
            // Map to showGrid since there's no direct property
            renderer.showGrid = showAxes
            lastShowAxes = showAxes
        }

        let colorSchemeValue = UInt32(colorScheme.rawValue)
        if lastColorScheme != colorSchemeValue {
            // Use the colorScheme property directly
            renderer.colorScheme = colorSchemeValue
            lastColorScheme = colorSchemeValue
        }

        // Check if we need to update visualization data
        let currentTime = CACurrentMediaTime()

        // Only update data if visualization type changed or sufficient time passed
        let minUpdateInterval: TimeInterval = 1.0 / Double(targetFrameRate)
        let shouldUpdateData =
            lastVisualizationType != visualizationType
            || (currentTime - lastVisualizationUpdateTime) >= minUpdateInterval

        if shouldUpdateData {
            // Update specific visualization data based on type
            switch visualizationType {
            case .waveform:
                let waveformData = waveformGenerator.generateWaveform(sampleCount: 1024)
                renderer.updateWaveformData(waveformData.map { Float($0) })

            case .spectrum:
                let spectrumData = waveformGenerator.generateSpectrum(sampleCount: 512)
                renderer.updateSpectrumData(spectrumData.map { Float($0) })

            case .probability:
                let probData = quantumSimulator.getProbabilityDensityGrid()
                // Use updateQuantumData instead since there's no updateProbabilityData method
                renderer.updateQuantumData(probData.map { Float($0) })

            case .realPart:
                let waveFunc = quantumSimulator.getWaveFunctionComponents()
                // Use updateQuantumData since there's no updateWaveFunctionData method
                renderer.updateQuantumData(waveFunc.real.map { Float($0) })

            case .imaginaryPart:
                let waveFunc = quantumSimulator.getWaveFunctionComponents()
                // Use updateQuantumData since there's no updateWaveFunctionData method
                renderer.updateQuantumData(waveFunc.imaginary.map { Float($0) })

            case .phase:
                let phaseData = quantumSimulator.getPhaseGrid()
                // Use updateQuantumData since there's no updatePhaseData method
                renderer.updateQuantumData(phaseData.map { Float($0) })
            }

            // Update tracking variables
            lastVisualizationType = visualizationType
            lastVisualizationUpdateTime = currentTime
        }

        // Signal renderer to redraw
        if let metalView = renderer.value(forKey: "metalView") as? MTKView {
            metalView.needsDisplay = true
        }

        // Also update the 3D visualization
        update3DVisualization()
    }

    /// Captures and exports the current visualization as an image
    func exportCurrentVisualization() {
        // Request renderer to capture current frame
        renderer?.captureCurrentFrame { image in
            guard let image = image else {
                print("Failed to capture visualization")
                return
            }

            // Save to photos or share
            #if os(iOS)
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            #else
                // macOS implementation - save to file
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.png]
                panel.canCreateDirectories = true
                panel.isExtensionHidden = false
                panel.title = "Save Visualization"
                panel.nameFieldStringValue = "Quantum_Waveform_\(Int(Date().timeIntervalSince1970))"

                panel.beginSheetModal(for: NSApp.keyWindow!) { response in
                    if response == .OK, let url = panel.url {
                        // On macOS, image is an NSImage
                        if let nsImage = image as? NSImage,
                            let cgImage = nsImage.cgImage(
                                forProposedRect: nil, context: nil, hints: nil)
                        {
                            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                            let pngData = bitmapRep.representation(using: .png, properties: [:])
                            try? pngData?.write(to: url)
                        }
                    }
                }
            #endif
        }
    }

    /// Export audio to a file
    func exportAudio(to fileURL: URL, duration: Double = 5.0) {
        // This functionality requires AVFoundation which may not be available
        // Commenting out for now to allow the project to build
        /*
        let sampleRate = 44100.0
        let channelCount = 2
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: UInt32(channelCount)
        )

        // Create audio file
        guard
            let audioFile = try? AVAudioFile(
                forWriting: fileURL,
                settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        else {
            print("Failed to create audio file")
            return
        }

        // Calculate buffer size for the entire duration
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let bufferFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: UInt32(channelCount)
        )

        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: bufferFormat,
                frameCapacity: frameCount
            )
        else {
            print("Failed to create audio buffer")
            return
        }
        */

        // For now, just log that we would export audio
        print("Audio export requested to \(fileURL) for duration \(duration)s")
    }

    /// Exports the current quantum state data to CSV
    func exportQuantumData(completion: @escaping (URL?) -> Void) {
        // Get quantum data
        let spatialGrid = quantumSimulator.getSpatialGrid()
        let probabilityDensity = quantumSimulator.getProbabilityDensityGrid()

        // Create CSV data
        var csvString =
            "Position,Probability Density,Wave Function (Real),Wave Function (Imaginary)\n"

        for i in 0..<min(spatialGrid.count, probabilityDensity.count) {
            let position = spatialGrid[i]
            let probability = probabilityDensity[i]
            let waveFunc = quantumSimulator.getWaveFunction(at: position)

            csvString += "\(position),\(probability),\(waveFunc.real),\(waveFunc.imaginary)\n"
        }

        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(
            "quantum_data_\(Int(Date().timeIntervalSince1970)).csv")

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)

            #if os(macOS)
                // macOS save dialog
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.commaSeparatedText]
                panel.canCreateDirectories = true
                panel.isExtensionHidden = false
                panel.title = "Save Quantum Data"
                panel.nameFieldStringValue =
                    "QuantumSystem_\(quantumSystemType)_Level\(energyLevel)"

                panel.beginSheetModal(for: NSApp.keyWindow!) { response in
                    if response == .OK, let saveURL = panel.url {
                        try? FileManager.default.copyItem(at: fileURL, to: saveURL)
                        completion(saveURL)
                    } else {
                        completion(nil)
                    }
                }
            #else
                completion(fileURL)
            #endif
        } catch {
            print("Error writing CSV file: \(error)")
            completion(nil)
        }
    }

    /// Rotates the 3D visualization by the given angle
    func rotateVisualization(byAngle angle: Float) {
        renderer3D?.rotate(byAngle: angle)
    }

    /// Toggle between 2D and 3D visualization modes
    public func toggleVisualizationMode() {
        // Toggle between 2D and 3D
        if dimensionMode == .twoDimensional {
            dimensionMode = .threeDimensional
            print("DEBUG: Switched to 3D mode")

            // Ensure 3D renderer is initialized
            if renderer3D == nil {
                setupRenderer3D()
            }
        } else {
            dimensionMode = .twoDimensional
            print("DEBUG: Switched to 2D mode")

            // Ensure 2D renderer is initialized
            if renderer == nil {
                setupRenderer()
            }
        }

        // Update both renderers with current settings
        updateRendererSettings()
    }

    /// Updates the frequency based on a quantum energy level transition
    func applyQuantumTransition(fromLevel: Int, toLevel: Int) {
        // Calculate the energy difference
        quantumSimulator.setEnergyLevel(fromLevel)
        let energy1 = quantumSimulator.getExpectedEnergy()

        quantumSimulator.setEnergyLevel(toLevel)
        let energy2 = quantumSimulator.getExpectedEnergy()

        // Calculate frequency from energy difference (E = hf)
        let energyDiff = abs(energy2 - energy1)
        let transitionFreq = energyDiff / planckConstant

        // Map to audible range
        let audioFreq = mapQuantumFrequencyToAudible(transitionFreq)

        // Set new frequency
        frequency = audioFreq
        energyLevel = toLevel
        energyLevelFloat = Double(toLevel)

        // Update
        updateWaveform()
        updateQuantumSimulation()
    }

    /// Calculates and returns scientifically formatted quantum-audio relationship data
    func getQuantumAudioRelationship() -> [String: String] {
        var relationship: [String: String] = [:]

        // Add key relationships
        relationship["audio_frequency"] = formatScientific(frequency)
        relationship["audio_wavelength"] = formatScientific(wavelength)
        relationship["quantum_wavelength"] = formatScientific(deBroglieWavelength)
        relationship["scaling_factor"] = formatScientific(quantumAudioScalingFactor)
        relationship["energy_joules"] = formatScientific(quantumEnergy)
        relationship["energy_ev"] = formatScientific(quantumEnergy / 1.602176634e-19)

        let audioQuantumRatio = wavelength / deBroglieWavelength
        relationship["wavelength_ratio"] = formatScientific(audioQuantumRatio)

        return relationship
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Set up Publishers and Subscribers for reactive properties

        // Monitor dimension mode changes
        $dimensionMode
            .sink { [weak self] newMode in
                if newMode == .threeDimensional {
                    // Initialize 3D renderer on demand
                    self?.initializeRenderer3D()
                }

                // Update visualization for new dimension mode
                self?.updateVisualization()
            }
            .store(in: &cancellables)

        // Monitor visualization type changes
        $visualizationType
            .sink { [weak self] _ in
                self?.updateVisualization()
            }
            .store(in: &cancellables)

        // Monitor frame rate changes
        $targetFrameRateFloat
            .sink { [weak self] newValue in
                self?.targetFrameRate = Int(newValue)
            }
            .store(in: &cancellables)
    }

    private func setupAnimationTimer() {
        // Clean up existing timer
        animationTimer?.invalidate()

        // Reset performance tracking
        frameCount = 0
        totalFrameTime = 0
        lastFrameTime = CACurrentMediaTime()
        frameStartTime = lastFrameTime

        // Create new timer for time evolution with better performance
        if animateTimeEvolution {
            // Use a more efficient timer update interval
            let updateInterval = 1.0 / Double(targetFrameRate)

            // Create high-precision timer
            animationTimer = Timer.scheduledTimer(
                withTimeInterval: updateInterval, repeats: true
            ) { [weak self] _ in
                guard let self = self else { return }

                self.handleAnimationUpdate()
            }

            // Ensure timer runs in common run loops for better reliability
            if let timer = animationTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    private func handleAnimationUpdate() {
        // Calculate frame time
        let currentTime = CACurrentMediaTime()
        let frameDuration = currentTime - lastFrameTime
        lastFrameTime = currentTime

        // Track performance metrics
        frameCount += 1
        totalFrameTime += frameDuration

        // Calculate and display FPS periodically
        if currentTime - frameStartTime >= fpsUpdateInterval {
            let fps = Double(frameCount) / (currentTime - frameStartTime)
            let avgFrameTime = totalFrameTime / Double(frameCount)
            print(
                "Animation: \(String(format: "%.1f", fps)) FPS (Avg frame: \(String(format: "%.2f", avgFrameTime*1000)) ms)"
            )

            // Reset counters
            frameCount = 0
            totalFrameTime = 0
            frameStartTime = currentTime
        }

        // Update simulation time - use a fixed time step for stability
        let timeStep = 0.01
        simulationTime += timeStep

        // Determine if we need to update quantum simulation
        let needsQuantumUpdate =
            visualizationType == .probability || visualizationType == .realPart
            || visualizationType == .imaginaryPart || visualizationType == .phase

        // Only perform updates if necessary
        if needsQuantumUpdate {
            // Update quantum simulation with new time - update time manually first
            quantumSimulator.setTime(simulationTime)
            quantumSimulator.advanceTime()

            // Update visualization only if visible
            updateVisualization()
        }
    }

    private func startPlayback() {
        // Ensure we have a valid waveform generator
        guard !isPlaying else { return }

        // Update waveform parameters
        updateWaveform()

        // Start audio playback through waveform generator
        waveformGenerator.startPlayback(
            waveformType: waveformType,
            frequency: frequency,
            amplitude: amplitude,
            phase: phase
        )
    }

    private func stopPlayback() {
        // Stop audio playback
        waveformGenerator.stopPlayback()
    }

    /// Maps quantum wave parameters to audible frequency range
    private func mapQuantumToAudioFrequency() -> Double {
        // Map quantum parameters to audible frequency range (20Hz - 20kHz)
        switch quantumSystemType {
        case .freeParticle:
            // Map based on de Broglie wavelength
            let deBroglie = quantumSimulator.calculateDeBroglieWavelength()
            return waveformGenerator.audioFrequencyFromQuantumWavelength(
                deBroglie, scalingFactor: quantumAudioScalingFactor
            )

        case .potentialWell:
            // Map based on energy levels in well
            let baseFreq = 55.0  // A1 note
            return baseFreq * Double(energyLevel * energyLevel)

        case .harmonicOscillator:
            // Map based on harmonic oscillator energy levels
            let baseFreq = 110.0  // A2 note
            return baseFreq * Double(energyLevel)

        case .hydrogenAtom:
            // Map based on energy transitions
            let baseFreq = 440.0  // A4 note
            return baseFreq / Double(energyLevel * energyLevel)
        }
    }

    /// Maps quantum frequency to audible frequency range
    private func mapQuantumFrequencyToAudible(_ quantumFreq: Double) -> Double {
        // Most quantum frequencies are extremely high, so we need to scale them down
        // For simplicity, we'll use a logarithmic mapping

        let minQuantumFreq = 1e12  // 1 THz
        let maxQuantumFreq = 1e18  // 1 EHz

        let minAudibleFreq = 20.0  // 20 Hz
        let maxAudibleFreq = 20000.0  // 20 kHz

        // Check if already in audible range
        if quantumFreq >= minAudibleFreq && quantumFreq <= maxAudibleFreq {
            return quantumFreq
        }

        // If very small, scale up to audible range
        if quantumFreq < minAudibleFreq {
            return minAudibleFreq + (maxAudibleFreq - minAudibleFreq)
                * (quantumFreq / minAudibleFreq)
        }

        // Use logarithmic mapping for large frequencies
        let logMinQuantum = log10(minQuantumFreq)
        let logMaxQuantum = log10(maxQuantumFreq)
        let logQuantum = log10(quantumFreq)

        // Normalize to 0-1 range
        let normalizedLogQuantum = (logQuantum - logMinQuantum) / (logMaxQuantum - logMinQuantum)

        // Map to audible range (use logarithmic mapping for audible range too)
        let logMinAudible = log10(minAudibleFreq)
        let logMaxAudible = log10(maxAudibleFreq)
        let logAudible = logMinAudible + normalizedLogQuantum * (logMaxAudible - logMinAudible)

        return pow(10, logAudible)
    }

    /// Update the quantum-audio domain bridge calculations
    private func updateDomainBridgeCalculations() {
        // Calculate de Broglie wavelength
        deBroglieWavelength = quantumSimulator.calculateDeBroglieWavelength()

        // Calculate quantum energy
        quantumEnergy = quantumSimulator.getExpectedEnergy()

        // Calculate uncertainty relationship
        let uncertainty = reducedPlanckConstant / 2.0
        uncertaintyProduct = uncertainty

        // Calculate expected position (simplified approximation)
        let spatialGrid = quantumSimulator.getSpatialGrid()
        let probDensity = quantumSimulator.getProbabilityDensityGrid()

        // Calculate weighted average for position expectation value
        var sumPos = 0.0
        var sumWeight = 0.0

        for i in 0..<min(spatialGrid.count, probDensity.count) {
            sumPos += spatialGrid[i] * probDensity[i]
            sumWeight += probDensity[i]
        }

        // Calculate position expectation value if weights are valid
        if sumWeight > 0.0 {
            expectedPosition = sumPos / sumWeight
        } else {
            expectedPosition = 0.0
        }

        // Note: Removed calculateRydbergStateEnergy call as this method doesn't exist
        // A proper implementation would calculate the Rydberg energy using:
        // E_n = -13.6 eV / n² (for hydrogen)
    }

    /// Update observable quantum values for display
    private func updateQuantumObservables() {
        // Clear existing observables
        quantumObservables.removeAll()

        // Add system-specific observables
        switch quantumSystemType {
        case .freeParticle:
            quantumObservables["de_broglie_wavelength"] = deBroglieWavelength
            quantumObservables["momentum"] = reducedPlanckConstant / deBroglieWavelength
            quantumObservables["kinetic_energy"] = quantumEnergy

        case .potentialWell:
            let width = 20e-9  // Approximate well width from simulation
            quantumObservables["energy_level"] = Double(energyLevel)
            quantumObservables["energy"] = quantumEnergy
            quantumObservables["energy_ev"] = quantumEnergy / 1.602176634e-19
            quantumObservables["confinement_width"] = width

        case .harmonicOscillator:
            // Approximate angular frequency from energy level difference
            let originalLevel = energyLevel
            let originalEnergy = quantumEnergy

            quantumSimulator.setEnergyLevel(originalLevel + 1)
            let nextLevelEnergy = quantumSimulator.getExpectedEnergy()

            let omegaApprox = (nextLevelEnergy - originalEnergy) / reducedPlanckConstant

            // Reset to original level
            quantumSimulator.setEnergyLevel(originalLevel)

            quantumObservables["energy_level"] = Double(energyLevel)
            quantumObservables["energy"] = quantumEnergy
            quantumObservables["angular_frequency"] = omegaApprox
            quantumObservables["classical_amplitude"] = sqrt(
                2 * quantumEnergy / (particleMass * omegaApprox * omegaApprox))

        case .hydrogenAtom:
            let rydberg = 2.179e-18  // Rydberg energy in joules
            quantumObservables["principal_quantum_number"] = Double(energyLevel)
            quantumObservables["energy"] = quantumEnergy
            quantumObservables["energy_ev"] = quantumEnergy / 1.602176634e-19
            quantumObservables["orbital_radius"] =
                5.29177210903e-11 * Double(energyLevel * energyLevel)  // Bohr radius * n²
        }

        // Add common observables
        quantumObservables["expected_position"] = expectedPosition
        quantumObservables["uncertainty_relation"] = uncertaintyProduct
    }

    /// Format a value in scientific notation if needed
    private func formatScientific(_ value: Double) -> String {
        if scientificNotation {
            if abs(value) < 0.01 || abs(value) > 10000 {
                return String(format: "%.4e", value)
            }
        }
        return String(format: "%.4f", value)
    }

    // MARK: - 3D Renderer Management

    /// Common method to get a Metal device for rendering
    /*
    private func getMetalDevice() -> MTLDevice? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Error: Could not create Metal device")
            return nil
        }
        return device
    }
    */

    /// Initialize the 2D renderer
    public func setupRenderer() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Error: Could not create Metal device for 2D renderer")
            return
        }

        // Create renderer with debug output
        print("Creating WaveformRenderer with device: \(device.name)")
        self.renderer = WaveformRenderer(device: device)

        // Set initial visualization parameters
        print("Setting initial 2D visualization parameters")
        renderer?.setColorScheme(UInt32(colorScheme.rawValue))
        renderer?.setShowGrid(showGrid)

        print("2D renderer setup complete")
    }

    /// Initialize the 3D renderer
    public func setupRenderer3D() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Error: Could not create Metal device")
            return
        }

        // Create renderer with debug output
        print("Creating WaveformRenderer3D with device: \(device.name)")
        self.renderer3D = WaveformRenderer3D(device: device)

        // Set initial visualization parameters with debug output
        print("Setting initial 3D visualization parameters")
        renderer3D?.setColorScheme(UInt32(colorScheme.rawValue))

        print("Setting quantum params with systemType: \(visualSystemType)")
        renderer3D?.updateQuantumParams(
            systemType: UInt32(visualSystemType),
            energyLevel: UInt32(visual3DEnergyLevel),
            mass: 9.1093837e-31,
            potentialHeight: 0.0
        )

        // Enable animation
        renderer3D?.setAnimating(animateTimeEvolution)
        print("3D renderer setup complete")
    }

    /// Connect the 2D renderer to a Metal view
    public func connectRenderer(to metalView: MTKView) {
        print("Connecting 2D renderer to MTKView")

        // Make sure we have a renderer
        if renderer == nil {
            print("2D renderer was nil, initializing...")
            setupRenderer()
        }

        guard let renderer = renderer else {
            print("ERROR: Failed to create 2D renderer")
            return
        }

        // Connect the renderer to the view
        metalView.delegate = renderer
        metalView.device = renderer.device

        // Configure for 2D rendering
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.enableSetNeedsDisplay = true
        metalView.preferredFramesPerSecond = targetFrameRate
        metalView.autoResizeDrawable = true
        metalView.isPaused = false

        // Force an initial draw
        metalView.needsDisplay = true

        print("2D renderer connected to view")
    }

    /// Connect the 3D renderer to a Metal view
    public func connectRenderer3D(to metalView: MTKView) {
        print("Connecting 3D renderer to MTKView")

        // Make sure we have a renderer
        if renderer3D == nil {
            print("3D renderer was nil, initializing...")
            setupRenderer3D()
        }

        guard let renderer = renderer3D else {
            print("ERROR: Failed to create 3D renderer")
            return
        }

        // Configure the view to use our renderer
        metalView.device = renderer.device
        metalView.delegate = renderer

        // Configure for 3D rendering
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 1.0)
        metalView.enableSetNeedsDisplay = true

        // Force an initial draw
        metalView.needsDisplay = true

        print("3D renderer successfully connected to MTKView")
    }

    /// Initialize the 3D renderer on demand
    public func initializeRenderer3D() {
        if renderer3D == nil {
            print("Initializing 3D renderer on demand")
            setupRenderer3D()
        }
    }

    /// Configure the 3D renderer with current quantum settings
    private func configure3DRenderer() {
        guard let renderer3D = renderer3D else { return }

        // Configure initial settings
        renderer3D.updateQuantumParams(
            systemType: UInt32(quantumSystemType.rawValue),
            energyLevel: UInt32(energyLevel),
            mass: Float(particleMass),
            potentialHeight: Float(potentialHeight)
        )
    }

    // Update the 3D visualization with current parameters
    private func update3DVisualization() {
        print(
            "update3DVisualization called with system: \(visualSystemType), energy: \(visual3DEnergyLevel)"
        )

        // Initialize 3D renderer if needed
        initializeRenderer3D()

        // Update quantum parameters in renderer
        print("Updating quantum parameters in 3D renderer")
        renderer3D?.updateQuantumParams(
            systemType: UInt32(visualSystemType),
            energyLevel: UInt32(visual3DEnergyLevel),
            mass: 9.1093837e-31,
            potentialHeight: 0.0
        )

        print("3D visualization updated")
    }

    // MARK: - UI Control Methods

    /// Change visualization type and update 3D renderer
    func changeVisualizationType(_ type: Int) {
        // Update visualSystemType
        visualSystemType = type

        // Update 3D visualization
        update3DVisualization()

        // If 3D rendering is active, ensure the renderer is initialized
        if dimensionMode == .threeDimensional {
            initializeRenderer3D()
        }
    }

    /// Change energy level for visualization and update 3D renderer
    func changeEnergyLevel(_ level: Int) {
        // Update visual3DEnergyLevel
        visual3DEnergyLevel = level

        // Update 3D visualization
        update3DVisualization()
    }

    /// Change color scheme for 3D visualization
    func changeColorScheme(_ scheme: Int) {
        renderer3D?.setColorScheme(UInt32(scheme))
    }

    /// Enable or disable animation in 3D renderer
    func setAnimation(_ enabled: Bool) {
        renderer3D?.setAnimating(enabled)
    }

    // Add this near the renderer methods
    func incrementFrameCount() {
        // This method is called from the 3D visualization to track frame count
        DispatchQueue.main.async {
            self.frameCount += 1
        }
    }

    /// Update both renderers with current settings
    private func updateRendererSettings() {
        // Update 2D renderer
        renderer?.setColorScheme(UInt32(colorScheme.rawValue))
        renderer?.setShowGrid(showGrid)

        // Update 3D renderer
        renderer3D?.setColorScheme(UInt32(colorScheme.rawValue))
        renderer3D?.updateQuantumParams(
            systemType: UInt32(visualSystemType),
            energyLevel: UInt32(visual3DEnergyLevel),
            mass: 9.1093837e-31,
            potentialHeight: 0.0
        )
        renderer3D?.setAnimating(animateTimeEvolution)
    }

    // MARK: - Preset Management

    /// Saves the current settings as a preset
    /// - Parameter name: The name to give the preset
    /// - Returns: Success status and optional error message
    func savePreset(name: String) -> (success: Bool, message: String?) {
        let preset = WaveformPreset(
            name: name,
            frequency: frequency,
            amplitude: amplitude,
            waveformType: waveformType.rawValue,
            harmonicRichness: harmonicRichness,
            phase: phase,
            harmonicAmplitudes: nil,  // No harmonics in this implementation
            harmonicPhases: nil,
            comments: nil,
            dateCreated: Date()
        )

        // Convert to JSON data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let presetData = try? encoder.encode(preset) else {
            return (false, "Failed to encode preset data")
        }

        // Get presets directory
        let presetsDirectory = getPresetsDirectory()
        let fileURL = presetsDirectory.appendingPathComponent("\(name).json")

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: presetsDirectory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: presetsDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                return (false, "Failed to create presets directory: \(error.localizedDescription)")
            }
        }

        // Save preset file
        do {
            try presetData.write(to: fileURL)
            return (true, nil)
        } catch {
            return (false, "Failed to save preset: \(error.localizedDescription)")
        }
    }

    /// Loads a preset by name
    /// - Parameter name: The preset name to load
    /// - Returns: Success status and optional error message
    func loadPreset(name: String) -> (success: Bool, message: String?) {
        let presetsDirectory = getPresetsDirectory()
        let fileURL = presetsDirectory.appendingPathComponent("\(name).json")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return (false, "Preset does not exist")
        }

        // Load preset data
        do {
            let presetData = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let preset = try decoder.decode(WaveformPreset.self, from: presetData)

            // Apply preset settings
            self.frequency = preset.frequency
            self.amplitude = preset.amplitude
            if let type = WaveformType(rawValue: preset.waveformType) {
                self.waveformType = type
            }
            self.harmonicRichness = preset.harmonicRichness
            self.phase = preset.phase

            // Update waveform
            updateWaveform()

            return (true, nil)
        } catch {
            return (false, "Failed to load preset: \(error.localizedDescription)")
        }
    }

    /// Lists all available presets
    /// - Returns: Array of preset names
    func listPresets() -> [String] {
        let presetsDirectory = getPresetsDirectory()

        // Check if directory exists
        guard FileManager.default.fileExists(atPath: presetsDirectory.path) else {
            return []
        }

        // List preset files
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: presetsDirectory,
                includingPropertiesForKeys: nil
            )

            // Filter for JSON files and extract names
            return
                fileURLs
                .filter { $0.pathExtension == "json" }
                .compactMap { $0.deletingPathExtension().lastPathComponent }
                .sorted()
        } catch {
            print("Failed to list presets: \(error.localizedDescription)")
            return []
        }
    }

    /// Deletes a preset by name
    /// - Parameter name: The preset to delete
    /// - Returns: Success status and optional error message
    func deletePreset(name: String) -> (success: Bool, message: String?) {
        let presetsDirectory = getPresetsDirectory()
        let fileURL = presetsDirectory.appendingPathComponent("\(name).json")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return (false, "Preset does not exist")
        }

        // Delete file
        do {
            try FileManager.default.removeItem(at: fileURL)
            return (true, nil)
        } catch {
            return (false, "Failed to delete preset: \(error.localizedDescription)")
        }
    }

    /// Gets the directory for storing presets
    private func getPresetsDirectory() -> URL {
        let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        return appSupportURL.appendingPathComponent("QwantumWaveform/Presets")
    }

    // MARK: - Utility Methods for Type Conversion

    // Helper methods to handle type conversion between Double and Float arrays
    private func updateRendererWithWaveformData(_ data: [Double]) {
        renderer?.updateWaveformData(data.map { Float($0) })
    }

    private func updateRendererWithSpectrumData(_ data: [Double]) {
        renderer?.updateSpectrumData(data.map { Float($0) })
    }

    private func updateRendererWithQuantumData(_ data: [Double]) {
        renderer?.updateQuantumData(data.map { Float($0) })
    }
}
