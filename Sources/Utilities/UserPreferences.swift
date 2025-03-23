import Combine
import SwiftUI

/// UserPreferences system for saving and restoring application settings
/// with persistence and profile management.
class UserPreferences: ObservableObject {
    // MARK: - Singleton

    static let shared = UserPreferences()

    // MARK: - Published Properties

    // Audio preferences
    @Published var defaultFrequency: Double = 440.0
    @Published var defaultAmplitude: Double = 0.5
    @Published var defaultWaveformType: Int = 0
    @Published var useLogarithmicFrequency: Bool = true
    @Published var audioFrameSize: Int = 1024
    @Published var sampleRate: Double = 48000.0
    @Published var enableHarmonics: Bool = true

    // Quantum preferences
    @Published var defaultQuantumSystem: Int = 0
    @Published var defaultEnergyLevel: Int = 1
    @Published var quantumResolution: Int = 1024
    @Published var animateTimeEvolution: Bool = true
    @Published var showVirtualParticles: Bool = false
    @Published var scientificNotation: Bool = true

    // Visualization preferences
    @Published var colorScheme: Int = 0
    @Published var showGrid: Bool = true
    @Published var showAxes: Bool = true
    @Published var showScale: Bool = true
    @Published var defaultVisualizationType: Int = 0
    @Published var renderQuality: Int = 2
    @Published var backgroundColor: Color = Color.black
    @Published var targetFrameRate: Int = 60

    // UI preferences
    @Published var expandedSections: [String: Bool] = [
        "basic": true,
        "visualizations": true,
        "presets": true,
        "measurements": true,
    ]
    @Published var sidebarWidth: CGFloat = 250
    @Published var showAdvancedControls: Bool = false
    @Published var autoSaveEnabled: Bool = true

    // User presets
    @Published var userPresets: [UserPreset] = []

    // Active profile
    @Published var activeProfile: String = "Default"
    @Published var availableProfiles: [String] = [
        "Default", "Scientific", "Performance", "Educational",
    ]

    // MARK: - Private Properties

    private let userDefaultsPrefix = "com.qwantumwaveform.preferences."
    private var cancellables = Set<AnyCancellable>()
    private let saveDebounceTime: TimeInterval = 1.0  // Seconds to wait before saving
    private var needsSave = false
    private var saveWorkItem: DispatchWorkItem?

    // MARK: - Types

    struct UserPreset: Codable, Identifiable {
        var id = UUID()
        var name: String
        var description: String
        var type: String
        var date: Date
        var parameters: [String: Any]

        // For Codable conformance
        enum CodingKeys: String, CodingKey {
            case id, name, description, type, date, parameters
        }

        init(name: String, description: String, type: String, parameters: [String: Any]) {
            self.name = name
            self.description = description
            self.type = type
            self.date = Date()
            self.parameters = parameters
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            description = try container.decode(String.self, forKey: .description)
            type = try container.decode(String.self, forKey: .type)
            date = try container.decode(Date.self, forKey: .date)

            // Convert Data to Dictionary
            let parametersData = try container.decode(Data.self, forKey: .parameters)
            if let decodedParams = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(
                parametersData) as? [String: Any]
            {
                parameters = decodedParams
            } else {
                parameters = [:]
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(description, forKey: .description)
            try container.encode(type, forKey: .type)
            try container.encode(date, forKey: .date)

            // Convert Dictionary to Data
            let parametersData = try NSKeyedArchiver.archivedData(
                withRootObject: parameters, requiringSecureCoding: false)
            try container.encode(parametersData, forKey: .parameters)
        }
    }

    // MARK: - Initialization

    private init() {
        // Set up persistence
        loadPreferences()
        setupSavingMechanism()
    }

    // MARK: - Public Methods

    /// Load settings from UserDefaults
    func loadPreferences() {
        // Audio settings
        defaultFrequency =
            UserDefaults.standard.double(forKey: userDefaultsKey("defaultFrequency")) != 0
            ? UserDefaults.standard.double(forKey: userDefaultsKey("defaultFrequency")) : 440.0

        defaultAmplitude =
            UserDefaults.standard.double(forKey: userDefaultsKey("defaultAmplitude")) != 0
            ? UserDefaults.standard.double(forKey: userDefaultsKey("defaultAmplitude")) : 0.5

        defaultWaveformType = UserDefaults.standard.integer(
            forKey: userDefaultsKey("defaultWaveformType"))
        useLogarithmicFrequency = UserDefaults.standard.bool(
            forKey: userDefaultsKey("useLogarithmicFrequency"))
        audioFrameSize =
            UserDefaults.standard.integer(forKey: userDefaultsKey("audioFrameSize")) != 0
            ? UserDefaults.standard.integer(forKey: userDefaultsKey("audioFrameSize")) : 1024

        sampleRate =
            UserDefaults.standard.double(forKey: userDefaultsKey("sampleRate")) != 0
            ? UserDefaults.standard.double(forKey: userDefaultsKey("sampleRate")) : 48000.0

        enableHarmonics = UserDefaults.standard.bool(forKey: userDefaultsKey("enableHarmonics"))

        // Quantum settings
        defaultQuantumSystem = UserDefaults.standard.integer(
            forKey: userDefaultsKey("defaultQuantumSystem"))
        defaultEnergyLevel =
            UserDefaults.standard.integer(forKey: userDefaultsKey("defaultEnergyLevel")) != 0
            ? UserDefaults.standard.integer(forKey: userDefaultsKey("defaultEnergyLevel")) : 1

        quantumResolution =
            UserDefaults.standard.integer(forKey: userDefaultsKey("quantumResolution")) != 0
            ? UserDefaults.standard.integer(forKey: userDefaultsKey("quantumResolution")) : 1024

        animateTimeEvolution = UserDefaults.standard.bool(
            forKey: userDefaultsKey("animateTimeEvolution"))
        showVirtualParticles = UserDefaults.standard.bool(
            forKey: userDefaultsKey("showVirtualParticles"))
        scientificNotation = UserDefaults.standard.bool(
            forKey: userDefaultsKey("scientificNotation"))

        // Visualization settings
        colorScheme = UserDefaults.standard.integer(forKey: userDefaultsKey("colorScheme"))
        showGrid =
            UserDefaults.standard.object(forKey: userDefaultsKey("showGrid")) == nil
            ? true : UserDefaults.standard.bool(forKey: userDefaultsKey("showGrid"))

        showAxes =
            UserDefaults.standard.object(forKey: userDefaultsKey("showAxes")) == nil
            ? true : UserDefaults.standard.bool(forKey: userDefaultsKey("showAxes"))

        showScale =
            UserDefaults.standard.object(forKey: userDefaultsKey("showScale")) == nil
            ? true : UserDefaults.standard.bool(forKey: userDefaultsKey("showScale"))

        defaultVisualizationType = UserDefaults.standard.integer(
            forKey: userDefaultsKey("defaultVisualizationType"))
        renderQuality =
            UserDefaults.standard.integer(forKey: userDefaultsKey("renderQuality")) != 0
            ? UserDefaults.standard.integer(forKey: userDefaultsKey("renderQuality")) : 2

        targetFrameRate =
            UserDefaults.standard.integer(forKey: userDefaultsKey("targetFrameRate")) != 0
            ? UserDefaults.standard.integer(forKey: userDefaultsKey("targetFrameRate")) : 60

        // UI settings
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey("expandedSections")) {
            expandedSections =
                (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? expandedSections
        }

        sidebarWidth =
            UserDefaults.standard.double(forKey: userDefaultsKey("sidebarWidth")) != 0
            ? UserDefaults.standard.double(forKey: userDefaultsKey("sidebarWidth")) : 250

        showAdvancedControls = UserDefaults.standard.bool(
            forKey: userDefaultsKey("showAdvancedControls"))
        autoSaveEnabled =
            UserDefaults.standard.object(forKey: userDefaultsKey("autoSaveEnabled")) == nil
            ? true : UserDefaults.standard.bool(forKey: userDefaultsKey("autoSaveEnabled"))

        // User presets
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey("userPresets")) {
            userPresets = (try? JSONDecoder().decode([UserPreset].self, from: data)) ?? []
        }

        // Active profile
        activeProfile =
            UserDefaults.standard.string(forKey: userDefaultsKey("activeProfile")) ?? "Default"
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey("availableProfiles")) {
            availableProfiles =
                (try? JSONDecoder().decode([String].self, from: data)) ?? availableProfiles
        }
    }

    /// Save settings to UserDefaults
    func savePreferences() {
        // Audio settings
        UserDefaults.standard.set(defaultFrequency, forKey: userDefaultsKey("defaultFrequency"))
        UserDefaults.standard.set(defaultAmplitude, forKey: userDefaultsKey("defaultAmplitude"))
        UserDefaults.standard.set(
            defaultWaveformType, forKey: userDefaultsKey("defaultWaveformType"))
        UserDefaults.standard.set(
            useLogarithmicFrequency, forKey: userDefaultsKey("useLogarithmicFrequency"))
        UserDefaults.standard.set(audioFrameSize, forKey: userDefaultsKey("audioFrameSize"))
        UserDefaults.standard.set(sampleRate, forKey: userDefaultsKey("sampleRate"))
        UserDefaults.standard.set(enableHarmonics, forKey: userDefaultsKey("enableHarmonics"))

        // Quantum settings
        UserDefaults.standard.set(
            defaultQuantumSystem, forKey: userDefaultsKey("defaultQuantumSystem"))
        UserDefaults.standard.set(defaultEnergyLevel, forKey: userDefaultsKey("defaultEnergyLevel"))
        UserDefaults.standard.set(quantumResolution, forKey: userDefaultsKey("quantumResolution"))
        UserDefaults.standard.set(
            animateTimeEvolution, forKey: userDefaultsKey("animateTimeEvolution"))
        UserDefaults.standard.set(
            showVirtualParticles, forKey: userDefaultsKey("showVirtualParticles"))
        UserDefaults.standard.set(scientificNotation, forKey: userDefaultsKey("scientificNotation"))

        // Visualization settings
        UserDefaults.standard.set(colorScheme, forKey: userDefaultsKey("colorScheme"))
        UserDefaults.standard.set(showGrid, forKey: userDefaultsKey("showGrid"))
        UserDefaults.standard.set(showAxes, forKey: userDefaultsKey("showAxes"))
        UserDefaults.standard.set(showScale, forKey: userDefaultsKey("showScale"))
        UserDefaults.standard.set(
            defaultVisualizationType, forKey: userDefaultsKey("defaultVisualizationType"))
        UserDefaults.standard.set(renderQuality, forKey: userDefaultsKey("renderQuality"))
        UserDefaults.standard.set(targetFrameRate, forKey: userDefaultsKey("targetFrameRate"))

        // UI settings
        if let data = try? JSONEncoder().encode(expandedSections) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey("expandedSections"))
        }

        UserDefaults.standard.set(sidebarWidth, forKey: userDefaultsKey("sidebarWidth"))
        UserDefaults.standard.set(
            showAdvancedControls, forKey: userDefaultsKey("showAdvancedControls"))
        UserDefaults.standard.set(autoSaveEnabled, forKey: userDefaultsKey("autoSaveEnabled"))

        // User presets
        if let data = try? JSONEncoder().encode(userPresets) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey("userPresets"))
        }

        // Active profile
        UserDefaults.standard.set(activeProfile, forKey: userDefaultsKey("activeProfile"))
        if let data = try? JSONEncoder().encode(availableProfiles) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey("availableProfiles"))
        }
    }

    /// Reset all preferences to default values
    func resetToDefaults() {
        // Audio defaults
        defaultFrequency = 440.0
        defaultAmplitude = 0.5
        defaultWaveformType = 0
        useLogarithmicFrequency = true
        audioFrameSize = 1024
        sampleRate = 48000.0
        enableHarmonics = true

        // Quantum defaults
        defaultQuantumSystem = 0
        defaultEnergyLevel = 1
        quantumResolution = 1024
        animateTimeEvolution = true
        showVirtualParticles = false
        scientificNotation = true

        // Visualization defaults
        colorScheme = 0
        showGrid = true
        showAxes = true
        showScale = true
        defaultVisualizationType = 0
        renderQuality = 2
        backgroundColor = Color.black
        targetFrameRate = 60

        // UI defaults
        expandedSections = [
            "basic": true,
            "visualizations": true,
            "presets": true,
            "measurements": true,
        ]
        sidebarWidth = 250
        showAdvancedControls = false
        autoSaveEnabled = true

        // Save changes
        savePreferences()
    }

    /// Switch to a different profile
    func switchToProfile(_ profileName: String) {
        guard availableProfiles.contains(profileName) else { return }

        // Save current profile
        savePreferences()

        // Update active profile
        activeProfile = profileName

        // Load profile-specific settings
        switch profileName {
        case "Scientific":
            scientificProfile()
        case "Performance":
            performanceProfile()
        case "Educational":
            educationalProfile()
        default:
            // "Default" profile - load regular preferences
            loadPreferences()
        }

        // Save changes
        savePreferences()
    }

    /// Create a new user preset
    func createPreset(name: String, description: String, type: String, parameters: [String: Any]) {
        let preset = UserPreset(
            name: name,
            description: description,
            type: type,
            parameters: parameters
        )

        userPresets.append(preset)

        // Save changes
        if autoSaveEnabled {
            scheduleSave()
        }
    }

    /// Delete a user preset
    func deletePreset(id: UUID) {
        userPresets.removeAll { $0.id == id }

        // Save changes
        if autoSaveEnabled {
            scheduleSave()
        }
    }

    /// Apply view model state to preferences
    func saveViewModelState(from viewModel: WaveformViewModel) {
        // Audio settings
        defaultFrequency = viewModel.frequency
        defaultAmplitude = viewModel.amplitude
        defaultWaveformType = viewModel.waveformType.rawValue

        // Quantum settings
        defaultQuantumSystem = viewModel.quantumSystemType.rawValue
        defaultEnergyLevel = viewModel.energyLevel
        animateTimeEvolution = viewModel.animateTimeEvolution

        // Visualization settings
        colorScheme = viewModel.colorScheme.rawValue
        showGrid = viewModel.showGrid
        showAxes = viewModel.showAxes
        showScale = viewModel.showScale
        defaultVisualizationType = viewModel.visualizationType.rawValue
        renderQuality = viewModel.renderQuality.rawValue
        targetFrameRate = viewModel.targetFrameRate

        // Save changes
        if autoSaveEnabled {
            scheduleSave()
        }
    }

    /// Load preferences into view model
    func loadViewModelState(into viewModel: WaveformViewModel) {
        // Audio settings
        viewModel.frequency = defaultFrequency
        viewModel.amplitude = defaultAmplitude
        viewModel.waveformType = WaveformType(rawValue: defaultWaveformType) ?? .sine
        viewModel.useLogFrequency = useLogarithmicFrequency

        // Quantum settings
        viewModel.quantumSystemType =
            QuantumSystemType(rawValue: defaultQuantumSystem) ?? .freeParticle
        viewModel.energyLevel = defaultEnergyLevel
        viewModel.energyLevelFloat = Double(defaultEnergyLevel)
        viewModel.animateTimeEvolution = animateTimeEvolution

        // Visualization settings
        viewModel.colorScheme = ColorSchemeType(rawValue: colorScheme) ?? .classic
        viewModel.showGrid = showGrid
        viewModel.showAxes = showAxes
        viewModel.showScale = showScale
        viewModel.visualizationType =
            VisualizationType(rawValue: defaultVisualizationType) ?? .waveform
        viewModel.renderQuality = RenderQuality(rawValue: renderQuality) ?? .high
        viewModel.targetFrameRate = targetFrameRate
        viewModel.targetFrameRateFloat = Double(targetFrameRate)

        // Update model
        viewModel.updateWaveform()
        viewModel.updateQuantumSimulation()
        viewModel.updateVisualization()
    }

    /// Export all preferences to a file
    func exportPreferences() -> URL? {
        var preferences: [String: Any] = [:]

        // Audio settings
        preferences["audio"] = [
            "defaultFrequency": defaultFrequency,
            "defaultAmplitude": defaultAmplitude,
            "defaultWaveformType": defaultWaveformType,
            "useLogarithmicFrequency": useLogarithmicFrequency,
            "audioFrameSize": audioFrameSize,
            "sampleRate": sampleRate,
            "enableHarmonics": enableHarmonics,
        ]

        // Quantum settings
        preferences["quantum"] = [
            "defaultQuantumSystem": defaultQuantumSystem,
            "defaultEnergyLevel": defaultEnergyLevel,
            "quantumResolution": quantumResolution,
            "animateTimeEvolution": animateTimeEvolution,
            "showVirtualParticles": showVirtualParticles,
            "scientificNotation": scientificNotation,
        ]

        // Visualization settings
        preferences["visualization"] = [
            "colorScheme": colorScheme,
            "showGrid": showGrid,
            "showAxes": showAxes,
            "showScale": showScale,
            "defaultVisualizationType": defaultVisualizationType,
            "renderQuality": renderQuality,
            "targetFrameRate": targetFrameRate,
        ]

        // UI settings
        preferences["ui"] = [
            "expandedSections": expandedSections,
            "sidebarWidth": sidebarWidth,
            "showAdvancedControls": showAdvancedControls,
            "autoSaveEnabled": autoSaveEnabled,
        ]

        // User presets
        preferences["presets"] = userPresets.map { preset in
            [
                "id": preset.id.uuidString,
                "name": preset.name,
                "description": preset.description,
                "type": preset.type,
                "date": preset.date.timeIntervalSince1970,
            ]
        }

        // Generate JSON data
        guard
            let jsonData = try? JSONSerialization.data(
                withJSONObject: preferences, options: [.prettyPrinted])
        else {
            return nil
        }

        // Write to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(
            "QwantumWaveform_Preferences_\(Date().timeIntervalSince1970).json")

        do {
            try jsonData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Failed to write preferences file: \(error)")
            return nil
        }
    }

    /// Import preferences from a file
    func importPreferences(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)

            guard
                let preferences = try JSONSerialization.jsonObject(with: data, options: [])
                    as? [String: Any]
            else {
                return false
            }

            // Audio settings
            if let audio = preferences["audio"] as? [String: Any] {
                defaultFrequency = audio["defaultFrequency"] as? Double ?? defaultFrequency
                defaultAmplitude = audio["defaultAmplitude"] as? Double ?? defaultAmplitude
                defaultWaveformType = audio["defaultWaveformType"] as? Int ?? defaultWaveformType
                useLogarithmicFrequency =
                    audio["useLogarithmicFrequency"] as? Bool ?? useLogarithmicFrequency
                audioFrameSize = audio["audioFrameSize"] as? Int ?? audioFrameSize
                sampleRate = audio["sampleRate"] as? Double ?? sampleRate
                enableHarmonics = audio["enableHarmonics"] as? Bool ?? enableHarmonics
            }

            // Quantum settings
            if let quantum = preferences["quantum"] as? [String: Any] {
                defaultQuantumSystem =
                    quantum["defaultQuantumSystem"] as? Int ?? defaultQuantumSystem
                defaultEnergyLevel = quantum["defaultEnergyLevel"] as? Int ?? defaultEnergyLevel
                quantumResolution = quantum["quantumResolution"] as? Int ?? quantumResolution
                animateTimeEvolution =
                    quantum["animateTimeEvolution"] as? Bool ?? animateTimeEvolution
                showVirtualParticles =
                    quantum["showVirtualParticles"] as? Bool ?? showVirtualParticles
                scientificNotation = quantum["scientificNotation"] as? Bool ?? scientificNotation
            }

            // Visualization settings
            if let visualization = preferences["visualization"] as? [String: Any] {
                colorScheme = visualization["colorScheme"] as? Int ?? colorScheme
                showGrid = visualization["showGrid"] as? Bool ?? showGrid
                showAxes = visualization["showAxes"] as? Bool ?? showAxes
                showScale = visualization["showScale"] as? Bool ?? showScale
                defaultVisualizationType =
                    visualization["defaultVisualizationType"] as? Int ?? defaultVisualizationType
                renderQuality = visualization["renderQuality"] as? Int ?? renderQuality
                targetFrameRate = visualization["targetFrameRate"] as? Int ?? targetFrameRate
            }

            // UI settings
            if let ui = preferences["ui"] as? [String: Any] {
                if let sections = ui["expandedSections"] as? [String: Bool] {
                    expandedSections = sections
                }

                sidebarWidth = ui["sidebarWidth"] as? CGFloat ?? sidebarWidth
                showAdvancedControls = ui["showAdvancedControls"] as? Bool ?? showAdvancedControls
                autoSaveEnabled = ui["autoSaveEnabled"] as? Bool ?? autoSaveEnabled
            }

            // Save changes
            savePreferences()

            return true
        } catch {
            print("Failed to import preferences: \(error)")
            return false
        }
    }

    // MARK: - Private Methods

    /// Generate a UserDefaults key with the prefix
    private func userDefaultsKey(_ key: String) -> String {
        return userDefaultsPrefix + activeProfile + "." + key
    }

    /// Set up a mechanism to save preferences after changes
    private func setupSavingMechanism() {
        // Auto-save triggered by changes to properties
        // Subscribe to each publisher individually to avoid type conflicts
        $defaultFrequency.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(
            in: &cancellables)
        $defaultAmplitude.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(
            in: &cancellables)
        $colorScheme.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(
            in: &cancellables)
        $showGrid.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(
            in: &cancellables)
        $showAxes.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(
            in: &cancellables)
        $renderQuality.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(
            in: &cancellables)
        $defaultEnergyLevel.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(
            in: &cancellables)
        $autoSaveEnabled.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(
            in: &cancellables)
    }

    /// Schedule a save operation with debouncing
    public func scheduleSave() {
        guard autoSaveEnabled else { return }

        // Cancel any pending save
        saveWorkItem?.cancel()

        // Schedule a new save
        let workItem = DispatchWorkItem { [weak self] in
            self?.savePreferences()
        }

        saveWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceTime, execute: workItem)
    }

    // MARK: - Profile Configurations

    /// Scientific profile with high precision settings
    private func scientificProfile() {
        // High precision settings
        quantumResolution = 2048
        renderQuality = 3  // Ultra
        scientificNotation = true
        sampleRate = 96000.0
        audioFrameSize = 2048
        showVirtualParticles = true
        showAdvancedControls = true
    }

    /// Performance profile with optimized settings
    private func performanceProfile() {
        // Performance optimized settings
        quantumResolution = 512
        renderQuality = 1  // Medium
        targetFrameRate = 30
        audioFrameSize = 512
        showVirtualParticles = false
    }

    /// Educational profile with simplified settings
    private func educationalProfile() {
        // Educational settings
        defaultQuantumSystem = 1  // Potential well (simplest to understand)
        defaultEnergyLevel = 1
        defaultWaveformType = 0  // Sine wave
        colorScheme = 2  // Rainbow (visually appealing)
        showGrid = true
        showAxes = true
        showScale = true
        scientificNotation = false  // Use regular notation for readability
        animateTimeEvolution = true
        showAdvancedControls = false
    }
}

// MARK: - Preference View

/// View for editing user preferences
struct PreferencesView: View {
    @ObservedObject var preferences = UserPreferences.shared
    @State private var selectedTab = 0
    @State private var showingExportDialog = false
    @State private var showingImportDialog = false

    var body: some View {
        VStack {
            // Tabs for different preference categories
            Picker("Settings", selection: $selectedTab) {
                Text("Audio").tag(0)
                Text("Quantum").tag(1)
                Text("Visualization").tag(2)
                Text("Interface").tag(3)
                Text("Profiles").tag(4)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // Tab content
            ScrollView {
                Group {
                    switch selectedTab {
                    case 0:
                        audioPreferencesView
                    case 1:
                        quantumPreferencesView
                    case 2:
                        visualizationPreferencesView
                    case 3:
                        interfacePreferencesView
                    case 4:
                        profilesView
                    default:
                        Text("Settings")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // Bottom buttons
            HStack {
                Button(action: {
                    preferences.resetToDefaults()
                }) {
                    Text("Reset to Defaults")
                }

                Spacer()

                Button(action: {
                    let exportURL = preferences.exportPreferences()
                    showingExportDialog = exportURL != nil
                }) {
                    Text("Export")
                }

                Button(action: {
                    showingImportDialog = true
                }) {
                    Text("Import")
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showingExportDialog) {
            Text("Preferences exported successfully")
                .padding()
        }
        .sheet(isPresented: $showingImportDialog) {
            // In a real implementation, would show a file picker
            VStack {
                Text("Import Preferences")
                    .font(.headline)
                    .padding()

                Text("This would open a file picker to select a preferences file.")
                    .padding()

                Button("Close") {
                    showingImportDialog = false
                }
                .padding()
            }
            .frame(width: 400, height: 200)
        }
    }

    // MARK: - Tab Views

    private var audioPreferencesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Settings")
                .font(.headline)

            Group {
                HStack {
                    Text("Default Frequency:")
                    Spacer()
                    Text("\(preferences.defaultFrequency, specifier: "%.2f") Hz")
                }

                Slider(value: $preferences.defaultFrequency, in: 20...20000)
                    .onChange(of: preferences.defaultFrequency) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                HStack {
                    Text("Default Amplitude:")
                    Spacer()
                    Text("\(preferences.defaultAmplitude, specifier: "%.2f")")
                }

                Slider(value: $preferences.defaultAmplitude, in: 0...1)
                    .onChange(of: preferences.defaultAmplitude) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                HStack {
                    Text("Default Waveform:")

                    Picker("", selection: $preferences.defaultWaveformType) {
                        Text("Sine").tag(0)
                        Text("Square").tag(1)
                        Text("Triangle").tag(2)
                        Text("Sawtooth").tag(3)
                        Text("Noise").tag(4)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: preferences.defaultWaveformType) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
                }

                Toggle(
                    "Use Logarithmic Frequency Scale", isOn: $preferences.useLogarithmicFrequency
                )
                .onChange(of: preferences.useLogarithmicFrequency) { oldValue, newValue in
                    preferences.scheduleSave()
                }

                Toggle("Enable Harmonic Processing", isOn: $preferences.enableHarmonics)
                    .onChange(of: preferences.enableHarmonics) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                HStack {
                    Text("Sample Rate:")
                    Spacer()
                    Picker("", selection: $preferences.sampleRate) {
                        Text("44.1 kHz").tag(44100.0)
                        Text("48 kHz").tag(48000.0)
                        Text("96 kHz").tag(96000.0)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    .onChange(of: preferences.sampleRate) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
                }

                HStack {
                    Text("Buffer Size:")
                    Spacer()
                    Picker("", selection: $preferences.audioFrameSize) {
                        Text("256").tag(256)
                        Text("512").tag(512)
                        Text("1024").tag(1024)
                        Text("2048").tag(2048)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    .onChange(of: preferences.audioFrameSize) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
                }
            }
        }
    }

    private var quantumPreferencesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quantum Settings")
                .font(.headline)

            Group {
                HStack {
                    Text("Default Quantum System:")
                    Spacer()
                    Picker("", selection: $preferences.defaultQuantumSystem) {
                        Text("Free Particle").tag(0)
                        Text("Potential Well").tag(1)
                        Text("Harmonic Oscillator").tag(2)
                        Text("Hydrogen Atom").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    .onChange(of: preferences.defaultQuantumSystem) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
                }

                HStack {
                    Text("Default Energy Level:")
                    Spacer()
                    Text("\(preferences.defaultEnergyLevel)")
                }

                Slider(
                    value: Binding(
                        get: { Double(preferences.defaultEnergyLevel) },
                        set: { preferences.defaultEnergyLevel = Int($0) }
                    ), in: 1...10, step: 1
                )
                .onChange(of: preferences.defaultEnergyLevel) { oldValue, newValue in
                    preferences.scheduleSave()
                }

                HStack {
                    Text("Simulation Resolution:")
                    Spacer()
                    Picker("", selection: $preferences.quantumResolution) {
                        Text("Low (512)").tag(512)
                        Text("Standard (1024)").tag(1024)
                        Text("High (2048)").tag(2048)
                        Text("Ultra (4096)").tag(4096)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    .onChange(of: preferences.quantumResolution) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
                }

                Toggle("Animate Time Evolution", isOn: $preferences.animateTimeEvolution)
                    .onChange(of: preferences.animateTimeEvolution) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                Toggle("Show Virtual Particles", isOn: $preferences.showVirtualParticles)
                    .onChange(of: preferences.showVirtualParticles) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                Toggle("Use Scientific Notation", isOn: $preferences.scientificNotation)
                    .onChange(of: preferences.scientificNotation) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
            }
        }
    }

    private var visualizationPreferencesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visualization Settings")
                .font(.headline)

            Group {
                HStack {
                    Text("Color Scheme:")
                    Spacer()
                    Picker("", selection: $preferences.colorScheme) {
                        Text("Classic").tag(0)
                        Text("Thermal").tag(1)
                        Text("Rainbow").tag(2)
                        Text("Monochrome").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    .onChange(of: preferences.colorScheme) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
                }

                Toggle("Show Grid", isOn: $preferences.showGrid)
                    .onChange(of: preferences.showGrid) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                Toggle("Show Axes", isOn: $preferences.showAxes)
                    .onChange(of: preferences.showAxes) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                Toggle("Show Scale", isOn: $preferences.showScale)
                    .onChange(of: preferences.showScale) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                HStack {
                    Text("Default Visualization:")
                    Spacer()
                    Picker("", selection: $preferences.defaultVisualizationType) {
                        Text("Waveform").tag(0)
                        Text("Spectrum").tag(1)
                        Text("Probability").tag(2)
                        Text("Phase Space").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    .onChange(of: preferences.defaultVisualizationType) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
                }

                HStack {
                    Text("Render Quality:")
                    Spacer()
                    Picker("", selection: $preferences.renderQuality) {
                        Text("Low").tag(0)
                        Text("Medium").tag(1)
                        Text("High").tag(2)
                        Text("Ultra").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    .onChange(of: preferences.renderQuality) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
                }

                HStack {
                    Text("Background Color:")
                    Spacer()
                    ColorPicker("", selection: $preferences.backgroundColor)
                        .onChange(of: preferences.backgroundColor) { oldValue, newValue in
                            preferences.scheduleSave()
                        }
                }

                HStack {
                    Text("Target Frame Rate:")
                    Spacer()
                    Picker("", selection: $preferences.targetFrameRate) {
                        Text("30 FPS").tag(30)
                        Text("60 FPS").tag(60)
                        Text("120 FPS").tag(120)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    .onChange(of: preferences.targetFrameRate) { oldValue, newValue in
                        preferences.scheduleSave()
                    }
                }
            }
        }
    }

    private var interfacePreferencesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interface Settings")
                .font(.headline)

            Group {
                HStack {
                    Text("Sidebar Width:")
                    Spacer()
                    Text("\(Int(preferences.sidebarWidth))")
                }

                Slider(value: $preferences.sidebarWidth, in: 200...400, step: 10)
                    .onChange(of: preferences.sidebarWidth) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                Toggle("Show Advanced Controls", isOn: $preferences.showAdvancedControls)
                    .onChange(of: preferences.showAdvancedControls) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                Toggle("Auto-Save Preferences", isOn: $preferences.autoSaveEnabled)
                    .onChange(of: preferences.autoSaveEnabled) { oldValue, newValue in
                        preferences.scheduleSave()
                    }

                Text("Default Expanded Sections:")
                    .padding(.top, 8)

                VStack(alignment: .leading) {
                    ForEach(Array(preferences.expandedSections.keys.sorted()), id: \.self) { key in
                        if let isExpanded = preferences.expandedSections[key] {
                            Toggle(
                                key.capitalized,
                                isOn: Binding(
                                    get: { isExpanded },
                                    set: {
                                        preferences.expandedSections[key] = $0
                                        preferences.scheduleSave()
                                    }
                                ))
                        }
                    }
                }
                .padding(.leading)
            }
        }
    }

    private var profilesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile Settings")
                .font(.headline)

            HStack {
                Text("Active Profile:")
                Spacer()
                Picker("", selection: $preferences.activeProfile) {
                    ForEach(preferences.availableProfiles, id: \.self) { profile in
                        Text(profile).tag(profile)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .onChange(of: preferences.activeProfile) { oldValue, newValue in
                    preferences.switchToProfile(newValue)
                }
            }

            Text("Available Profiles:")
                .padding(.top, 8)

            List {
                ForEach(preferences.availableProfiles, id: \.self) { profile in
                    HStack {
                        Text(profile)
                            .foregroundColor(
                                preferences.activeProfile == profile ? .blue : .primary)
                        Spacer()
                        if profile == "Default" {
                            Text("Primary")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 120)

            Text("Profile Description:")
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                switch preferences.activeProfile {
                case "Scientific":
                    Text("Scientific Profile")
                        .font(.headline)
                    Text(
                        "Optimized for scientific precision with high resolution settings and advanced features for researchers and scientists."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                case "Performance":
                    Text("Performance Profile")
                        .font(.headline)
                    Text(
                        "Optimized for speed with lower resolution settings and streamlined features for smoother operation on all hardware."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                case "Educational":
                    Text("Educational Profile")
                        .font(.headline)
                    Text(
                        "Simplified settings with clear visualization options designed for classroom use and educational demonstrations."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                default:
                    Text("Default Profile")
                        .font(.headline)
                    Text(
                        "Balanced settings suitable for most users with a good mix of performance and features."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
}
