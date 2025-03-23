//
//  WaveformGenerator.swift
//  QwantumWaveform
//
//  Created by HAWZHIN on 15/03/2025.
//

import AVFoundation
import Accelerate
import Combine
import Foundation

/// Advanced waveform generator with real-time high-precision audio synthesis
final class WaveformGenerator {
    // MARK: - Types

    // Using WaveformType directly as it's in the same module
    // No import needed as Enums.swift is part of the same module
    // typealias GeneratorWaveformType = WaveformType

    /// Audio output configuration
    struct AudioConfig {
        var sampleRate: Double = 48000.0
        var channels: Int = 2
        var bitDepth: Int = 32
        var bufferSize: Int = 512
    }

    /// Harmonic structure for complex tones
    struct HarmonicStructure {
        var amplitudes: [Double]
        var phaseOffsets: [Double]

        static var defaultSine: HarmonicStructure {
            return HarmonicStructure(amplitudes: [1.0], phaseOffsets: [0.0])
        }

        static var defaultSquare: HarmonicStructure {
            // Approximate square wave with odd harmonics: 1, 3, 5, 7, 9...
            var amplitudes = [Double]()
            var phaseOffsets = [Double]()

            for i in 0..<10 {
                let harmonicNumber = 2 * i + 1
                amplitudes.append(1.0 / Double(harmonicNumber))
                phaseOffsets.append(0.0)
            }

            return HarmonicStructure(amplitudes: amplitudes, phaseOffsets: phaseOffsets)
        }

        static var defaultTriangle: HarmonicStructure {
            // Approximate triangle wave with odd harmonics with alternating signs
            var amplitudes = [Double]()
            var phaseOffsets = [Double]()

            for i in 0..<10 {
                let harmonicNumber = 2 * i + 1
                let sign = (i % 2 == 0) ? 1.0 : -1.0
                amplitudes.append(sign * (1.0 / Double(harmonicNumber * harmonicNumber)))
                phaseOffsets.append(0.0)
            }

            return HarmonicStructure(amplitudes: amplitudes, phaseOffsets: phaseOffsets)
        }

        static var defaultSawtooth: HarmonicStructure {
            // Approximate sawtooth wave with all harmonics
            var amplitudes = [Double]()
            var phaseOffsets = [Double]()

            for i in 0..<15 {
                let harmonicNumber = i + 1
                amplitudes.append(1.0 / Double(harmonicNumber))
                phaseOffsets.append(0.0)
            }

            return HarmonicStructure(amplitudes: amplitudes, phaseOffsets: phaseOffsets)
        }
    }

    // MARK: - Properties

    // Audio engine components
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var eqNode: AVAudioUnitEQ?
    private var mixerNode: AVAudioMixerNode?

    // Signal generation
    private var phase: Double = 0.0
    private var harmonicPhases: [Double] = [0.0]

    // Parameters
    private(set) var frequency: Double = 440.0  // Hz
    private(set) var amplitude: Double = 0.5  // 0.0 to 1.0
    private(set) var waveformType: WaveformType = .sine
    private(set) var harmonicRichness: Double = 1.0  // 0.0 to 1.0
    private(set) var customWaveformTable: [Double] = []
    private(set) var harmonicStructure: HarmonicStructure
    private(set) var audioConfig: AudioConfig
    private(set) var isRunning = false

    // FFT and spectrum analysis
    private let fftSize = 4096
    private var fftSetup: FFTSetup?
    private var spectrumMagnitudes: [Float] = []
    private var spectrumPhases: [Float] = []
    private let analysisQueue = DispatchQueue(
        label: "com.qwantumwaveform.analysis", qos: .userInteractive)

    // Monitoring
    private var isMonitoring = false
    private var audioLevels = CurrentValueSubject<Float, Never>(0.0)
    private var spectralCentroid = CurrentValueSubject<Float, Never>(0.0)

    // Conversion factors
    private let planckConstant = 6.62607015e-34  // J⋅s
    private let speedOfLight = 299792458.0  // m/s

    // Spectrum analysis buffers
    private var spectrumTempSamples: [Float] = []
    private var spectrumTempWindow: [Float] = []
    private var realBuffer: [Float] = []
    private var imagBuffer: [Float] = []

    // MARK: - Initialization

    init(config: AudioConfig = AudioConfig()) {
        self.audioConfig = config
        self.harmonicStructure = HarmonicStructure.defaultSine

        // Initialize FFT setup
        let log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        self.spectrumMagnitudes = [Float](repeating: 0, count: fftSize / 2)
        self.spectrumPhases = [Float](repeating: 0, count: fftSize / 2)

        // Set up audio engine
        setupAudioEngine()
    }

    deinit {
        // Stop audio engine and cleanup nodes
        stop()

        // Stop monitoring
        isMonitoring = false

        // Clear audio data
        customWaveformTable = []

        // Free FFT resources
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
            self.fftSetup = nil
        }

        // Clear cached buffers to free memory
        spectrumMagnitudes = []
        spectrumPhases = []
        spectrumTempSamples = []
        spectrumTempWindow = []
        realBuffer = []
        imagBuffer = []

        // Detach nodes from engine
        if let sourceNode = sourceNode {
            engine.detach(sourceNode)
        }
        if let eqNode = eqNode {
            engine.detach(eqNode)
        }
        if let mixerNode = mixerNode {
            engine.detach(mixerNode)
        }

        print("WaveformGenerator resources released")
    }

    // MARK: - Private Setup

    private func setupAudioEngine() {
        // Create audio format
        let format = AVAudioFormat(
            standardFormatWithSampleRate: audioConfig.sampleRate,
            channels: UInt32(audioConfig.channels)
        )!

        // Create equalizer with 10 bands
        eqNode = AVAudioUnitEQ(numberOfBands: 10)
        configureEQBands()

        // Create mixer node
        mixerNode = AVAudioMixerNode()

        // Create source node
        let sourceNode = AVAudioSourceNode {
            [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // Generate audio samples
            for frame in 0..<Int(frameCount) {
                // Generate the current sample based on waveform type
                let sample = self.generateSample()

                // Copy to all output channels
                for buffer in ablPointer {
                    let bufferPointer = UnsafeMutableBufferPointer<Float>(
                        start: buffer.mData?.assumingMemoryBound(to: Float.self),
                        count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                    )

                    if frame < bufferPointer.count {
                        bufferPointer[frame] = Float(sample)
                    }
                }

                // Advance phase for next sample
                self.advancePhase()
            }

            return noErr
        }

        // Store the node
        self.sourceNode = sourceNode

        // Connect components
        if let eqNode = eqNode, let mixerNode = mixerNode {
            engine.attach(sourceNode)
            engine.attach(eqNode)
            engine.attach(mixerNode)

            engine.connect(sourceNode, to: eqNode, format: format)
            engine.connect(eqNode, to: mixerNode, format: format)
            engine.connect(mixerNode, to: engine.mainMixerNode, format: format)
        }

        // Prepare engine
        engine.prepare()
    }

    private func configureEQBands() {
        guard let eqNode = eqNode else { return }

        let frequencyBands: [Float] = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

        for i in 0..<min(10, eqNode.bands.count) {
            let band = eqNode.bands[i]
            band.frequency = frequencyBands[i]
            band.gain = 0.0
            band.bypass = false
            band.filterType = .parametric
            band.bandwidth = 1.0
        }
    }

    // MARK: - Public Methods

    /// Starts audio playback
    /// - Throws: Audio engine errors if playback cannot be started
    func start() throws {
        if !isRunning {
            do {
                try engine.start()
                isRunning = true
                print("Audio engine started successfully")
            } catch {
                print("Error starting audio engine: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Stops audio playback and releases resources
    func stop() {
        if isRunning {
            engine.stop()
            isRunning = false
        }
    }

    /// Sets the frequency in Hz with safety bounds
    /// - Parameter frequency: Target frequency (clamped to 20-20000 Hz)
    func setFrequency(_ frequency: Double) {
        self.frequency = max(20.0, min(20000.0, frequency))
    }

    /// Sets the amplitude with safety bounds
    /// - Parameter amplitude: Target amplitude (clamped to 0.0-1.0)
    func setAmplitude(_ amplitude: Double) {
        self.amplitude = min(1.0, max(0.0, amplitude))
    }

    /// Sets the waveform type and updates harmonic structure accordingly
    /// - Parameter type: The waveform type to use
    func setWaveformType(_ type: WaveformType) {
        self.waveformType = type

        // Update harmonic structure based on waveform type
        switch type {
        case .sine:
            harmonicStructure = HarmonicStructure.defaultSine
        case .square:
            harmonicStructure = HarmonicStructure.defaultSquare
        case .triangle:
            harmonicStructure = HarmonicStructure.defaultTriangle
        case .sawtooth:
            harmonicStructure = HarmonicStructure.defaultSawtooth
        case .noise:
            harmonicStructure = HarmonicStructure.defaultSine
        case .custom:
            if customWaveformTable.isEmpty && harmonicStructure.amplitudes.isEmpty {
                harmonicStructure = HarmonicStructure.defaultSine
            }
        }

        resetHarmonicPhases()
    }

    /// Sets a custom waveform table for advanced waveform generation
    /// - Parameter waveform: Array of normalized values between -1.0 and 1.0
    func setCustomWaveform(_ waveform: [Double]) {
        guard !waveform.isEmpty else { return }
        customWaveformTable = waveform
    }

    /// Sets custom harmonic structure for complex tones
    /// - Parameter structure: The harmonic structure defining amplitudes and phase offsets
    func setHarmonicStructure(_ structure: HarmonicStructure) {
        harmonicStructure = structure
        resetHarmonicPhases()
    }

    /// Sets the harmonic richness parameter with safety bounds
    /// - Parameter richness: Harmonic richness value (clamped to 0.0-1.0)
    func setHarmonicRichness(_ richness: Double) {
        harmonicRichness = min(1.0, max(0.0, richness))
    }

    /// Starts audio spectrum analysis
    func startMonitoring() {
        isMonitoring = true
    }

    /// Stops audio spectrum analysis
    func stopMonitoring() {
        isMonitoring = false
    }

    /// Sets EQ band gain
    func setEQBand(at index: Int, gain: Float) {
        guard let eqNode = eqNode, index < eqNode.bands.count else { return }
        eqNode.bands[index].gain = gain
    }

    /// Gets current spectrum data
    func getSpectrumData() -> [Float] {
        if isMonitoring {
            calculateSpectrum()
        }
        return spectrumMagnitudes
    }

    /// Gets current spectral centroid (brightness)
    func getSpectralCentroid() -> Float {
        return spectralCentroid.value
    }

    /// Gets current audio level (RMS)
    func getAudioLevel() -> Float {
        return audioLevels.value
    }

    /// Subscribes to audio level updates
    func subscribeToAudioLevels() -> AnyPublisher<Float, Never> {
        return audioLevels.eraseToAnyPublisher()
    }

    /// Subscribes to spectral centroid updates
    func subscribeToSpectralCentroid() -> AnyPublisher<Float, Never> {
        return spectralCentroid.eraseToAnyPublisher()
    }

    // MARK: - Derived Metrics

    /// Converts frequency to wavelength (in meters)
    func wavelengthFromFrequency(_ frequency: Double) -> Double {
        return speedOfLight / frequency
    }

    /// Converts frequency to period (in seconds)
    func periodFromFrequency(_ frequency: Double) -> Double {
        return 1.0 / frequency
    }

    // MARK: - Quantum Conversions

    /// Maps quantum wavelength to audio frequency
    func audioFrequencyFromQuantumWavelength(_ wavelength: Double, scalingFactor: Double = 1e34)
        -> Double
    {
        // Ensure the wavelength is positive
        let absWavelength = abs(wavelength)

        // Scale the quantum wavelength to audio range
        // We want longer quantum wavelengths to map to lower audio frequencies
        let normalizedValue = min(1.0, absWavelength * scalingFactor)

        // Map to logarithmic audio range (20Hz - 20kHz)
        let minFreqLog = log10(20.0)
        let maxFreqLog = log10(20000.0)
        let freqLog = minFreqLog + (1.0 - normalizedValue) * (maxFreqLog - minFreqLog)

        return pow(10.0, freqLog)
    }

    /// Maps energy to frequency using E = hf relationship
    func frequencyFromEnergy(_ energyInJoules: Double) -> Double {
        return energyInJoules / planckConstant
    }

    /// Maps audio frequency to a scaled quantum wavelength
    func quantumWavelengthFromAudioFrequency(_ frequency: Double, scalingFactor: Double = 1e34)
        -> Double
    {
        // Normalize frequency in audio range (20Hz - 20kHz)
        let normalizedFreq = (log10(frequency) - log10(20.0)) / (log10(20000.0) - log10(20.0))

        // Map to quantum wavelength (inverted - higher frequencies map to shorter wavelengths)
        return (1.0 - normalizedFreq) / scalingFactor
    }

    // MARK: - Quantum Visualization

    /// Generates quantum probability data for visualization
    /// - Parameters:
    ///   - energyLevel: Energy level (quantum number)
    ///   - pointCount: Number of points to generate
    ///   - potentialHeight: Height of potential barrier (for certain systems)
    /// - Returns: Probability amplitude data as [x, probability] pairs
    func generateQuantumProbability(
        energyLevel: Int,
        pointCount: Int = 512,
        potentialHeight: Double = 0
    ) -> [(x: Double, probability: Double)] {
        let n = max(1, energyLevel)  // Quantum number (energy level)
        var result = [(x: Double, probability: Double)]()
        result.reserveCapacity(pointCount)

        // Constants for the quantum system
        let h = 6.62607015e-34  // Planck's constant
        let m = 9.10938356e-31  // Electron mass
        let L = 1.0e-9  // System size (1 nm)

        // Calculate energy for this level (particle in a box)
        let E = (pow(Double.pi, 2) * pow(Double(n), 2) * pow(h, 2)) / (8.0 * m * pow(L, 2))

        // Normalization factor
        let normFactor = sqrt(2.0 / L)

        for i in 0..<pointCount {
            let x = (Double(i) / Double(pointCount - 1)) * L

            // Calculate wavefunction (particle in a box)
            let psi = normFactor * sin(Double(n) * Double.pi * x / L)

            // Calculate probability density
            let probability = pow(psi, 2)

            result.append((x: x, probability: probability))
        }

        return result
    }

    /// Generates quantum wavefunction data for visualization
    /// - Parameters:
    ///   - energyLevel: Energy level (quantum number) - must be a positive integer
    ///   - pointCount: Number of points to generate (default: 512)
    ///   - potentialHeight: Height of potential barrier in eV (for certain systems)
    /// - Returns: Complex wavefunction data as [x, real, imaginary] triplets
    func generateQuantumWavefunction(
        energyLevel: Int,
        pointCount: Int = 512,
        potentialHeight: Double = 0
    ) -> [(x: Double, real: Double, imaginary: Double)] {
        let n = max(1, energyLevel)  // Quantum number (energy level)
        var result = [(x: Double, real: Double, imaginary: Double)]()
        result.reserveCapacity(pointCount)

        // Constants for the quantum system
        let h = 6.62607015e-34  // Planck's constant
        let m = 9.10938356e-31  // Electron mass
        let L = 1.0e-9  // System size (1 nm)
        let hbar = h / (2.0 * .pi)

        // Calculate energy for this level (particle in a box)
        let E = (pow(Double.pi, 2) * pow(Double(n), 2) * pow(h, 2)) / (8.0 * m * pow(L, 2))

        // Pre-compute frequently used values to optimize the loop
        let normFactor = sqrt(2.0 / L)
        let angularFreq = E / hbar
        let piOverL = Double.pi / L
        let nPiOverL = Double(n) * piOverL

        // Generate wavefunction data in a single pass
        for i in 0..<pointCount {
            let x = (Double(i) / Double(pointCount - 1)) * L
            let psi = normFactor * sin(nPiOverL * x)

            // Time-dependent phase factor (exp(-iEt/ħ))
            // For t = 0, this is just 1.0 for real part and 0.0 for imaginary part
            // In a dynamic simulation, we would use:
            // real = cos(angularFreq * time)
            // imaginary = -sin(angularFreq * time)
            let real = psi * 1.0
            let imaginary = psi * 0.0

            result.append((x: x, real: real, imaginary: imaginary))
        }

        return result
    }

    /// Maps quantum data to waveform for audio synthesis
    /// - Parameters:
    ///   - energyLevel: Energy level (quantum number)
    ///   - systemType: Type of quantum system
    ///   - potentialHeight: Height of potential barrier (for certain systems)
    /// - Returns: Audio parameter settings (frequency, amplitude, waveform)
    func getAudioParametersFromQuantumState(
        energyLevel: Int,
        systemType: String = "particle",
        potentialHeight: Double = 0
    ) -> (frequency: Double, amplitude: Double, waveformType: WaveformType) {
        let n = max(1, energyLevel)  // Quantum number

        // Calculate base frequency from energy level (logarithmic mapping)
        let baseFreq = 110.0 * pow(2.0, Double(n - 1) / 12.0)

        // Adjust based on system type
        var frequency = baseFreq
        var amplitude = 0.5
        var waveType: WaveformType = .sine

        switch systemType.lowercased() {
        case "harmonic":
            // Harmonic oscillator - evenly spaced energy levels
            frequency = 110.0 + (Double(n) * 110.0)
            waveType = .sine
        case "particle":
            // Particle in a box - quadratic energy spacing
            frequency = 110.0 + (Double(n * n) * 20.0)
            waveType = .triangle
        case "barrier":
            // Potential barrier - affected by barrier height
            let barrierFactor = 1.0 + (potentialHeight / 10.0)
            frequency = (110.0 + (Double(n * n) * 20.0)) / barrierFactor
            amplitude = max(0.1, 0.7 - (potentialHeight / 15.0))
            waveType = .square
        default:
            // Default simple mapping
            frequency = 110.0 * Double(n)
            waveType = .sine
        }

        // Clamp frequency to audible range
        frequency = max(20.0, min(20000.0, frequency))

        return (frequency, amplitude, waveType)
    }

    // MARK: - Private Methods

    /// Resets the phase of all harmonics
    private func resetHarmonicPhases() {
        harmonicPhases = [Double](repeating: 0.0, count: max(1, harmonicStructure.amplitudes.count))
    }

    /// Advances the phase for the next sample with optimized calculations
    private func advancePhase() {
        // Pre-calculate the increment once
        let phaseIncrement = frequency / audioConfig.sampleRate

        // Fast path for simple waveforms that don't use harmonics
        if harmonicStructure.amplitudes.count <= 1 || harmonicRichness <= 0.001 {
            phase += phaseIncrement
            if phase >= 1.0 {
                phase -= floor(phase)  // Handle multiple wraps in one step
            }
            return
        }

        // Advance main oscillator phase
        phase += phaseIncrement
        if phase >= 1.0 {
            phase -= floor(phase)  // Efficient modulo for phase wrapping
        }

        // Advance harmonic oscillator phases - use direct indexing for performance
        // Limit harmonics processing to what's actually needed
        let maxHarmonics = min(harmonicStructure.amplitudes.count, harmonicPhases.count)

        for i in 0..<maxHarmonics {
            let harmonicPhaseIncrement = phaseIncrement * Double(i + 1)
            harmonicPhases[i] += harmonicPhaseIncrement
            if harmonicPhases[i] >= 1.0 {
                harmonicPhases[i] -= floor(harmonicPhases[i])  // Handle multiple wraps efficiently
            }
        }
    }

    /// Generates a sample at the current phase
    private func generateSample() -> Double {
        switch waveformType {
        case .sine:
            if harmonicRichness <= 0.001 || harmonicStructure.amplitudes.count <= 1 {
                // Simple sine wave when no harmonics or richness is zero
                return amplitude * sin(2.0 * .pi * phase)
            } else {
                // Generate harmonically rich sine wave
                return generateHarmonicSample()
            }

        case .square:
            if harmonicRichness <= 0.001 {
                // Simple square wave
                return amplitude * (phase < 0.5 ? 1.0 : -1.0)
            } else {
                // Square wave from harmonics
                return generateHarmonicSample()
            }

        case .triangle:
            if harmonicRichness <= 0.001 {
                // Simple triangle wave
                let normalizedPhase = phase >= 0.5 ? 1.0 - phase : phase
                return amplitude * (4.0 * normalizedPhase - 1.0)
            } else {
                // Triangle wave from harmonics
                return generateHarmonicSample()
            }

        case .sawtooth:
            if harmonicRichness <= 0.001 {
                // Simple sawtooth wave
                return amplitude * (2.0 * phase - 1.0)
            } else {
                // Sawtooth from harmonics
                return generateHarmonicSample()
            }

        case .noise:
            // White noise (random values between -1 and 1)
            return amplitude * (Double.random(in: -1.0...1.0))

        case .custom:
            if !customWaveformTable.isEmpty {
                // Sample from custom wavetable
                let position = phase * Double(customWaveformTable.count)
                let index = Int(position) % customWaveformTable.count
                let nextIndex = (index + 1) % customWaveformTable.count
                let fraction = position - Double(Int(position))

                // Linear interpolation between samples
                let currentSample = customWaveformTable[index]
                let nextSample = customWaveformTable[nextIndex]
                let interpolatedSample = currentSample + fraction * (nextSample - currentSample)

                return amplitude * interpolatedSample
            } else {
                // Use harmonic structure if no wavetable
                return generateHarmonicSample()
            }
        }
    }

    /// Generates a sample using harmonic structure - optimized for performance
    private func generateHarmonicSample() -> Double {
        guard !harmonicStructure.amplitudes.isEmpty else {
            return amplitude * sin(2.0 * .pi * phase)
        }

        // Pre-calculate common values
        let maxHarmonics = min(harmonicStructure.amplitudes.count, harmonicPhases.count)
        let twoPI = 2.0 * .pi

        // For small number of harmonics, avoid overhead of array operations
        if maxHarmonics <= 4 {
            var sample = 0.0
            var normalizationFactor = 0.0

            for i in 0..<maxHarmonics {
                let harmonicAmplitude =
                    harmonicStructure.amplitudes[i] * pow(harmonicRichness, Double(i))
                let phaseOffset =
                    i < harmonicStructure.phaseOffsets.count
                    ? harmonicStructure.phaseOffsets[i] : 0.0

                sample += harmonicAmplitude * sin(twoPI * harmonicPhases[i] + phaseOffset)
                normalizationFactor += harmonicAmplitude
            }

            // Normalize and apply amplitude
            return normalizationFactor > 0.0 ? (amplitude * sample / normalizationFactor) : 0.0
        }

        // For larger harmonic counts, use array-based approach
        var amplitudes = [Double](repeating: 0.0, count: maxHarmonics)
        var normalizationFactor = 0.0

        // Calculate all harmonic amplitudes with richness scaling
        for i in 0..<maxHarmonics {
            amplitudes[i] = harmonicStructure.amplitudes[i] * pow(harmonicRichness, Double(i))
            normalizationFactor += amplitudes[i]
        }

        // Early exit if no harmonics contribute
        guard normalizationFactor > 0.0 else { return 0.0 }

        // Calculate sample from all harmonics
        var sample = 0.0
        for i in 0..<maxHarmonics {
            let phaseOffset =
                i < harmonicStructure.phaseOffsets.count ? harmonicStructure.phaseOffsets[i] : 0.0
            sample += amplitudes[i] * sin(twoPI * harmonicPhases[i] + phaseOffset)
        }

        // Apply amplitude scaling and normalization
        return amplitude * sample / normalizationFactor
    }

    /// Calculate spectrum using FFT with optimized memory usage
    private func calculateSpectrum() {
        guard let fftSetup = fftSetup else { return }

        // Reuse existing buffers instead of creating new ones each time
        // These are now instance variables to avoid repeated allocations
        if spectrumTempSamples.isEmpty {
            spectrumTempSamples = [Float](repeating: 0, count: fftSize)
            spectrumTempWindow = [Float](repeating: 0, count: fftSize)
            vDSP_hann_window(&spectrumTempWindow, vDSP_Length(fftSize), Int32(0))
        }

        // Store current phase to restore after analysis
        let originalPhase = phase

        // Generate samples for spectrum analysis using temp buffer
        for i in 0..<fftSize {
            // Calculate normalized phase for this sample
            phase = Double(i) / Double(fftSize)

            // Generate sample at this phase
            spectrumTempSamples[i] = Float(generateSample())
        }

        // Restore original phase
        phase = originalPhase

        // Apply window to reduce spectral leakage - reuse window buffer
        vDSP_vmul(
            spectrumTempSamples, 1, spectrumTempWindow, 1, &spectrumTempSamples, 1,
            vDSP_Length(fftSize))

        // Split complex setup - reuse buffers to avoid allocations
        if realBuffer.isEmpty {
            realBuffer = [Float](repeating: 0, count: fftSize)
            imagBuffer = [Float](repeating: 0, count: fftSize)
        } else {
            // Clear the buffers for reuse
            vDSP_vclr(&realBuffer, 1, vDSP_Length(fftSize))
            vDSP_vclr(&imagBuffer, 1, vDSP_Length(fftSize))
        }

        // Copy samples to real part
        vDSP_mmov(
            spectrumTempSamples, &realBuffer, vDSP_Length(fftSize), 1, vDSP_Length(fftSize),
            vDSP_Length(1))

        // Create DSP split complex structure
        var splitComplex = DSPSplitComplex(
            realp: &realBuffer,
            imagp: &imagBuffer
        )

        // Perform forward FFT
        vDSP_fft_zip(
            fftSetup,
            &splitComplex,
            1,
            vDSP_Length(log2(Float(fftSize))),
            FFTDirection(kFFTDirection_Forward)
        )

        // Calculate magnitude spectrum
        vDSP_zvmags(&splitComplex, 1, &spectrumMagnitudes, 1, vDSP_Length(fftSize / 2))

        // Calculate phase spectrum
        for i in 0..<fftSize / 2 {
            spectrumPhases[i] = atan2(imagBuffer[i], realBuffer[i])
        }

        // Scale magnitudes
        var scaleFactor: Float = 1.0 / Float(fftSize)
        vDSP_vsmul(
            spectrumMagnitudes, 1, &scaleFactor, &spectrumMagnitudes, 1, vDSP_Length(fftSize / 2))

        // Take square root to get amplitude spectrum
        for i in 0..<fftSize / 2 {
            spectrumMagnitudes[i] = sqrt(spectrumMagnitudes[i])
        }

        // Calculate audio metrics
        calculateSpectralCentroid()
        calculateAudioLevel(spectrumTempSamples)
    }

    /// Calculate spectral centroid
    private func calculateSpectralCentroid() {
        let nyquist = Float(audioConfig.sampleRate) / 2.0
        var centroid: Float = 0.0
        var totalPower: Float = 0.0

        for i in 0..<fftSize / 2 {
            let freq = Float(i) * nyquist / Float(fftSize / 2)
            let power = spectrumMagnitudes[i]
            centroid += freq * power
            totalPower += power
        }

        if totalPower > 0 {
            centroid /= totalPower
            spectralCentroid.send(centroid)
        }
    }

    /// Calculate RMS audio level
    private func calculateAudioLevel(_ samples: [Float]) {
        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        audioLevels.send(rms)
    }

    // MARK: - Interface Compatibility Methods

    /// Sets the waveform type (alias for setWaveformType for API compatibility)
    func setType(_ type: WaveformType) {
        setWaveformType(type)
    }

    /// Sets the phase offset of the waveform
    func setPhase(_ phase: Double) {
        self.phase = phase
        resetHarmonicPhases()
    }

    /// Generates waveform data for visualization
    /// - Parameter sampleCount: Number of samples to generate
    /// - Returns: Array of waveform values normalized to -1.0 to 1.0
    func generateWaveform(sampleCount: Int = 1024) -> [Double] {
        // Create a buffer to hold the waveform data
        var waveformData = [Double](repeating: 0.0, count: sampleCount)

        // Store the original phase to restore it later
        let originalPhase = phase

        // Get the current frequency
        let freq = frequency

        // Calculate the phase increment per sample
        let phaseIncrement = 2.0 * Double.pi * freq / audioConfig.sampleRate

        // Use a local phase variable to avoid affecting the audio generation
        var localPhase = 0.0

        // Generate waveform samples in a single pass
        for i in 0..<sampleCount {
            // Calculate normalized phase (0 to 1) for this sample
            let normalizedPhase = Double(i) / Double(sampleCount)

            // Set the phase for this sample
            localPhase = normalizedPhase * 2.0 * Double.pi

            // Temporarily set the phase for sample generation
            phase = localPhase

            // Generate the sample
            waveformData[i] = generateSample()
        }

        // Restore the original phase
        phase = originalPhase

        return waveformData
    }

    /// Generates spectrum data for visualization
    /// - Parameter sampleCount: Number of samples to generate
    /// - Returns: Array of spectrum values normalized to 0.0 to 1.0
    func generateSpectrum(sampleCount: Int = 512) -> [Double] {
        // Ensure spectrum is calculated
        calculateSpectrum()

        // Create spectrum data array with appropriate size
        var spectrumData = [Double](
            repeating: 0.0, count: min(sampleCount, spectrumMagnitudes.count))

        // Scale factor to normalize values
        let maxPossibleValue: Float = 1.0

        // If we need to downsample (more spectrum data than requested samples)
        if spectrumMagnitudes.count > sampleCount {
            // Calculate the scaling factor for each bin
            let binScale = Float(spectrumMagnitudes.count) / Float(sampleCount)

            // For each output sample, average the corresponding input bins
            for i in 0..<sampleCount {
                let startBin = Int(Float(i) * binScale)
                let endBin = min(spectrumMagnitudes.count - 1, Int(Float(i + 1) * binScale))

                // Average the bins in this range
                var sum: Float = 0.0
                for bin in startBin...endBin {
                    sum += spectrumMagnitudes[bin]
                }

                // Normalize and store
                let avg = sum / Float(endBin - startBin + 1)
                spectrumData[i] = Double(min(1.0, avg / maxPossibleValue))
            }
        } else {
            // We have fewer spectrum values than requested samples - direct copy with scaling
            for i in 0..<spectrumMagnitudes.count {
                spectrumData[i] = Double(min(1.0, spectrumMagnitudes[i] / maxPossibleValue))
            }
        }

        return spectrumData
    }

    /// Starts playback with specified parameters
    /// - Parameters:
    ///   - waveformType: Type of waveform to generate
    ///   - frequency: Frequency in Hz
    ///   - amplitude: Amplitude (0.0-1.0)
    ///   - phase: Initial phase offset
    /// - Returns: Success status and optional error
    @discardableResult
    func startPlayback(
        waveformType: WaveformType,
        frequency: Double,
        amplitude: Double,
        phase: Double
    ) -> (success: Bool, error: Error?) {
        // Set parameters
        setWaveformType(waveformType)
        setFrequency(frequency)
        setAmplitude(amplitude)
        setPhase(phase)

        // Start audio
        do {
            try start()
            return (true, nil)
        } catch {
            print("Error starting playback: \(error.localizedDescription)")
            return (false, error)
        }
    }

    /// Stops playback and releases resources
    func stopPlayback() {
        stop()
    }

    /// Saves the current waveform to a file at the specified URL
    /// - Parameters:
    ///   - fileURL: The URL to save the file to
    ///   - duration: Duration of the audio in seconds
    ///   - sampleRate: Sample rate to use (defaults to current audio config)
    /// - Returns: A boolean indicating success and optional error
    func saveWaveformToFile(
        at fileURL: URL,
        duration: Double = 5.0,
        sampleRate: Double? = nil
    ) -> (success: Bool, error: Error?) {
        // Configure the audio format
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate ?? audioConfig.sampleRate,
            channels: 2)!

        guard
            let file = try? AVAudioFile(
                forWriting: fileURL,
                settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false)
        else {
            return (
                false,
                NSError(
                    domain: "com.qwantumwaveform.export",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not create audio file"])
            )
        }

        // Create a buffer
        let actualSampleRate = sampleRate ?? audioConfig.sampleRate
        let frameCount = AVAudioFrameCount(duration * actualSampleRate)
        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCount)
        else {
            return (
                false,
                NSError(
                    domain: "com.qwantumwaveform.export",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not create audio buffer"])
            )
        }

        // Fill the buffer with waveform data
        buffer.frameLength = frameCount

        // Save original phase
        let originalPhase = phase

        // Generate samples
        for frame in 0..<Int(frameCount) {
            // Calculate normalized phase for this sample
            let t = Double(frame) / actualSampleRate
            phase = t * frequency - floor(t * frequency)

            // Generate the sample
            let sample = Float(generateSample())

            // Write to all channels
            for channel in 0..<format.channelCount {
                buffer.floatChannelData?[Int(channel)][frame] = sample
            }
        }

        // Restore original phase
        phase = originalPhase

        // Write the buffer to the file
        do {
            try file.write(from: buffer)
            return (true, nil)
        } catch {
            return (false, error)
        }
    }
}
