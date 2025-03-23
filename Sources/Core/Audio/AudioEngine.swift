import AVFoundation
import Foundation

// MARK: - Audio Engine
final class AudioEngine {
    private var audioEngine: AVAudioEngine
    private var sourceNode: AVAudioSourceNode!
    private let sampleRate: Double = 44100.0
    private var lastRenderTime: Double = 0.0

    // Audio parameters
    var frequency: Double = 440.0
    var amplitude: Double = 0.8
    var waveformType: WaveformType = .sine
    var phase: Double = 0.0

    init() {
        audioEngine = AVAudioEngine()
        setupSourceNode()
        setupAudioEngine()
    }

    private func setupSourceNode() {
        sourceNode = AVAudioSourceNode {
            [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first?.mData else {
                return kAudioUnitErr_InvalidParameter
            }

            let ptr = buffer.assumingMemoryBound(to: Float.self)
            let omega = 2.0 * Double.pi * self.frequency

            for frame in 0..<Int(frameCount) {
                let time = self.lastRenderTime + Double(frame) / self.sampleRate
                var value: Float = 0.0

                switch self.waveformType {
                case .sine:
                    value = Float(sin(omega * time + self.phase))
                case .square:
                    value = Float(self.generateSquareWave(at: time, frequency: omega))
                case .triangle:
                    value = Float(self.generateTriangleWave(at: time, frequency: omega))
                case .sawtooth:
                    value = Float(self.generateSawtoothWave(at: time, frequency: omega))
                case .noise:
                    value = Float.random(in: -1...1)
                case .custom:
                    // Generate custom waveform
                    value = Float(self.generateCustomWave(at: time, frequency: omega))
                }

                // Apply amplitude modulation
                ptr[frame] = value * Float(self.amplitude)
            }

            self.lastRenderTime += Double(frameCount) / self.sampleRate
            return noErr
        }
    }

    private func setupAudioEngine() {
        let mainMixer = audioEngine.mainMixerNode
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)

        guard let inputFormat = inputFormat else {
            print("Failed to create audio format")
            return
        }

        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: mainMixer, format: inputFormat)

        // Set output volume
        mainMixer.outputVolume = 1.0

        // Prepare engine
        audioEngine.prepare()
    }

    func start() {
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
    }

    func stop() {
        audioEngine.pause()
        lastRenderTime = 0.0
    }

    // MARK: - Waveform Generation Methods

    private func generateSquareWave(at time: Double, frequency: Double) -> Double {
        // Generate square wave with anti-aliasing
        var value = 0.0
        let harmonics = 20  // Number of harmonics to use

        for h in 1...harmonics {
            let harmonic = 2 * Double(h) - 1
            value += sin(frequency * harmonic * time) / harmonic
        }

        return value * (4 / Double.pi)
    }

    private func generateTriangleWave(at time: Double, frequency: Double) -> Double {
        // Generate triangle wave with anti-aliasing
        var value = 0.0
        let harmonics = 20

        for h in 0...harmonics {
            let harmonic = 2 * Double(h) + 1
            let coefficient = pow(-1.0, Double(h)) / (harmonic * harmonic)
            value += coefficient * sin(frequency * harmonic * time)
        }

        return value * (8 / (Double.pi * Double.pi))
    }

    private func generateSawtoothWave(at time: Double, frequency: Double) -> Double {
        // Generate sawtooth wave with anti-aliasing
        var value = 0.0
        let harmonics = 20

        for h in 1...harmonics {
            value += sin(frequency * Double(h) * time) / Double(h)
        }

        return value * (2 / Double.pi)
    }

    private func generateCustomWave(at time: Double, frequency: Double) -> Double {
        // A combination of sine and square for demonstration
        let sineComponent = sin(frequency * time) * 0.5
        let squareComponent = generateSquareWave(at: time, frequency: frequency) * 0.5

        return sineComponent + squareComponent
    }
}
