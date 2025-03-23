import AVFAudio
import Foundation
import MetalKit
import SwiftUI

// Import enums from the Models directory
// This should be part of a proper module system in a larger refactoring

/// Main view model for the QwantumWaveform application
class MainViewModel: ObservableObject {
    // MARK: - Published Properties

    // We'll link these properties to the underlying WaveformViewModel's properties
    @Published var isPlaying: Bool
    @Published var visualizationType: Int
    @Published var dimensionMode: Int

    // Custom harmonics
    @Published var harmonicAmplitudes: [Double] = []
    @Published var harmonicPhases: [Double] = []

    // Quantum parameters
    @Published var energyLevel: Int = 1
    @Published var energyLevelFloat: Double = 1.0
    @Published var quantumSystemType: Int = 0
    @Published var potentialHeight: Double = 0.0

    // MARK: - Private Properties

    // Use the full-featured WaveformViewModel instead of duplicating functionality
    private var waveformViewModel: WaveformViewModel

    // MARK: - Computed Properties

    // Forward these to the WaveformViewModel
    var wavelength: Double {
        return waveformViewModel.wavelength
    }

    var period: Double {
        return waveformViewModel.period
    }

    var deBroglieWavelength: Double {
        return waveformViewModel.deBroglieWavelength
    }

    var quantumEnergy: Double {
        return waveformViewModel.quantumEnergy
    }

    // MARK: - Initialization

    init(waveformViewModel: WaveformViewModel = WaveformViewModel()) {
        self.waveformViewModel = waveformViewModel

        // Initialize published properties from waveformViewModel
        self.isPlaying = waveformViewModel.isPlaying
        self.visualizationType = waveformViewModel.visualizationType.rawValue
        self.dimensionMode = waveformViewModel.dimensionMode.rawValue
    }

    // MARK: - Public Methods

    /// Updates the waveform based on current parameters
    func updateWaveform() {
        waveformViewModel.updateWaveform()
    }

    /// Toggles between 2D and 3D visualization
    func toggleVisualizationMode() {
        waveformViewModel.toggleVisualizationMode()
        // Update our own dimensionMode to match
        dimensionMode = waveformViewModel.dimensionMode.rawValue
    }

    /// Updates quantum simulation parameters
    func updateQuantumSimulation() {
        waveformViewModel.updateQuantumSimulation()
    }

    /// Updates the visualization based on current settings
    func updateVisualization() {
        waveformViewModel.updateVisualization()
    }

    /// Exports the current visualization as an image
    @discardableResult
    func exportCurrentVisualization() -> URL? {
        // Placeholder - could be implemented if needed
        return nil
    }

    /// Exports the current audio as a file
    func exportAudio(to fileURL: URL) {
        waveformViewModel.exportAudio(to: fileURL, duration: 10)
    }

    /// Exports quantum data to a file
    func exportQuantumData(completion: @escaping (Bool) -> Void) {
        waveformViewModel.exportQuantumData { url in
            completion(url != nil)
        }
    }

    // MARK: - Preset Management

    /// Saves the current settings as a preset
    func savePreset(name: String) -> (success: Bool, message: String?) {
        // Delegate to WaveformViewModel
        let result = waveformViewModel.savePreset(name: name)
        return (result.success, result.message)
    }

    /// Loads a preset with the given name
    func loadPreset(name: String) -> (success: Bool, message: String?) {
        // Delegate to WaveformViewModel
        let result = waveformViewModel.loadPreset(name: name)

        // Update our own properties with the WaveformViewModel's updated values
        if result.success {
            self.isPlaying = waveformViewModel.isPlaying
            self.visualizationType = waveformViewModel.visualizationType.rawValue
            self.dimensionMode = waveformViewModel.dimensionMode.rawValue
        }

        return (result.success, result.message)
    }

    /// Lists all available presets
    func listPresets() -> [String] {
        return waveformViewModel.listPresets()
    }

    /// Deletes a preset with the given name
    func deletePreset(name: String) -> (success: Bool, message: String?) {
        return waveformViewModel.deletePreset(name: name)
    }
}

// MARK: - User Presets

/// Waveform preset structure for serialization
struct WaveformPreset: Codable {
    var name: String
    var frequency: Double
    var amplitude: Double
    var waveformType: Int
    var harmonicRichness: Double
    var phase: Double
    var harmonicAmplitudes: [Double]?
    var harmonicPhases: [Double]?
    var comments: String?
    var dateCreated: Date
}
