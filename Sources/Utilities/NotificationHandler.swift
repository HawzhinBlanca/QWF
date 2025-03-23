import Combine
import Foundation

/// Handles observation and processing of app-wide notifications
class NotificationHandler {
    private var viewModel: WaveformViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: WaveformViewModel) {
        self.viewModel = viewModel
        setupNotificationObservers()
    }

    deinit {
        // Cancel all subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        // Export notifications
        NotificationCenter.default.publisher(for: NSNotification.Name("ExportVisualization"))
            .sink { [weak self] _ in
                self?.viewModel.exportCurrentVisualization()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("ExportAudio"))
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Use the new exportAudio method with a temporary file URL
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
                    "export.wav")
                self.viewModel.exportAudio(to: tempURL)
            }
            .store(in: &cancellables)

        // Quality settings
        NotificationCenter.default.publisher(for: NSNotification.Name("SetQuality"))
            .sink { [weak self] notification in
                if let quality = notification.object as? RenderQuality {
                    self?.viewModel.renderQuality = quality
                }
            }
            .store(in: &cancellables)

        // Quantum system type
        NotificationCenter.default.publisher(for: NSNotification.Name("SetQuantumSystem"))
            .sink { [weak self] notification in
                if let systemType = notification.object as? QuantumSystemType {
                    self?.viewModel.quantumSystemType = systemType
                }
            }
            .store(in: &cancellables)

        // Energy level
        NotificationCenter.default.publisher(for: NSNotification.Name("SetEnergyLevel"))
            .sink { [weak self] notification in
                if let level = notification.object as? Int {
                    self?.viewModel.energyLevel = level
                    self?.viewModel.energyLevelFloat = Double(level)
                    self?.viewModel.updateQuantumSimulation()
                }
            }
            .store(in: &cancellables)

        // Waveform type
        NotificationCenter.default.publisher(for: NSNotification.Name("SetWaveformType"))
            .sink { [weak self] notification in
                if let waveformType = notification.object as? WaveformType {
                    self?.viewModel.waveformType = waveformType
                }
            }
            .store(in: &cancellables)

        // Frequency presets
        NotificationCenter.default.publisher(for: NSNotification.Name("SetFrequency"))
            .sink { [weak self] notification in
                if let frequency = notification.object as? Double {
                    self?.viewModel.frequency = frequency
                    self?.viewModel.updateWaveform()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("DoubleFrequency"))
            .sink { [weak self] _ in
                if let self = self {
                    self.viewModel.frequency = min(20000, self.viewModel.frequency * 2)
                    self.viewModel.updateWaveform()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("HalveFrequency"))
            .sink { [weak self] _ in
                if let self = self {
                    self.viewModel.frequency = max(20, self.viewModel.frequency / 2)
                    self.viewModel.updateWaveform()
                }
            }
            .store(in: &cancellables)

        // Visualization settings
        NotificationCenter.default.publisher(for: NSNotification.Name("SetVisualizationType"))
            .sink { [weak self] notification in
                if let type = notification.object as? VisualizationType {
                    self?.viewModel.visualizationType = type
                }
            }
            .store(in: &cancellables)

        // Toggle display options
        NotificationCenter.default.publisher(for: NSNotification.Name("ToggleGrid"))
            .sink { [weak self] _ in
                if let self = self {
                    self.viewModel.showGrid.toggle()
                    self.viewModel.updateVisualization()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("ToggleAxes"))
            .sink { [weak self] _ in
                if let self = self {
                    self.viewModel.showAxes.toggle()
                    self.viewModel.updateVisualization()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("ToggleScale"))
            .sink { [weak self] _ in
                if let self = self {
                    self.viewModel.showScale.toggle()
                    self.viewModel.updateVisualization()
                }
            }
            .store(in: &cancellables)

        // Dimension mode
        NotificationCenter.default.publisher(for: NSNotification.Name("SetDimensionMode"))
            .sink { [weak self] notification in
                if let mode = notification.object as? DimensionMode {
                    self?.viewModel.dimensionMode = mode
                }
            }
            .store(in: &cancellables)

        // Color scheme
        NotificationCenter.default.publisher(for: NSNotification.Name("SetColorScheme"))
            .sink { [weak self] notification in
                if let scheme = notification.object as? ColorSchemeType {
                    self?.viewModel.colorScheme = scheme
                }
            }
            .store(in: &cancellables)
    }
}
