// Source/Models/Enums.swift

import Foundation

/// Types of quantum systems that can be simulated
enum QuantumSystemType: Int, CaseIterable, Identifiable {
    case freeParticle = 0
    case potentialWell = 1
    case harmonicOscillator = 2
    case hydrogenAtom = 3

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .freeParticle: return "Free Particle"
        case .potentialWell: return "Infinite Potential Well"
        case .harmonicOscillator: return "Harmonic Oscillator"
        case .hydrogenAtom: return "Hydrogen Atom"
        }
    }

    var description: String {
        switch self {
        case .freeParticle:
            return "A quantum particle that moves freely in space, represented by a wave packet."
        case .potentialWell:
            return
                "A particle confined to a region with infinite potential barriers, resulting in standing waves."
        case .harmonicOscillator:
            return
                "A particle in a parabolic potential, similar to a mass on a spring in quantum mechanics."
        case .hydrogenAtom:
            return
                "An electron orbiting a proton, the simplest atomic system with characteristic energy levels."
        }
    }
}

/// Types of waveforms for audio generation
enum WaveformType: Int, CaseIterable, Identifiable {
    case sine = 0
    case square = 1
    case triangle = 2
    case sawtooth = 3
    case noise = 4
    case custom = 5

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .sine: return "Sine"
        case .square: return "Square"
        case .triangle: return "Triangle"
        case .sawtooth: return "Sawtooth"
        case .noise: return "Noise"
        case .custom: return "Custom"
        }
    }
}

/// Types of visualizations that can be displayed
enum VisualizationType: Int, CaseIterable, Identifiable {
    case waveform = 0  // Time-domain audio waveform
    case spectrum = 1  // Frequency-domain audio spectrum
    case probability = 2  // Quantum probability density
    case realPart = 3  // Real part of quantum wave function
    case imaginaryPart = 4  // Imaginary part of quantum wave function
    case phase = 5  // Phase of quantum wave function

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .waveform: return "Audio Waveform"
        case .spectrum: return "Audio Spectrum"
        case .probability: return "Probability Density"
        case .realPart: return "Wave Function (Real)"
        case .imaginaryPart: return "Wave Function (Imaginary)"
        case .phase: return "Wave Function Phase"
        }
    }
}

/// 2D or 3D visualization mode
enum DimensionMode: Int, CaseIterable, Identifiable {
    case twoDimensional = 0
    case threeDimensional = 1

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .twoDimensional: return "2D"
        case .threeDimensional: return "3D"
        }
    }
}

/// Visualization color schemes
enum ColorSchemeType: Int, CaseIterable, Identifiable {
    case classic = 0
    case heatMap = 1
    case rainbow = 2
    case grayscale = 3
    case neon = 4

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .heatMap: return "Heat Map"
        case .rainbow: return "Rainbow"
        case .grayscale: return "Grayscale"
        case .neon: return "Neon"
        }
    }
}

/// Rendering quality settings
enum RenderQuality: Int, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var sampleCount: Int {
        switch self {
        case .low: return 128
        case .medium: return 256
        case .high: return 512
        }
    }
}
