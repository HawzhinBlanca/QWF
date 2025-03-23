import Accelerate
import Foundation
import Metal
import SwiftUI

/// Advanced real-time performance monitoring system for tracking and optimizing
/// CPU, GPU, and memory usage across quantum simulations and audio processing.
class PerformanceMonitor {
    // MARK: - Singleton

    static let shared = PerformanceMonitor()

    // MARK: - Types

    /// Performance metrics structure
    struct PerformanceMetrics {
        var frameRate: Double = 0
        var renderDuration: Double = 0
        var cpuUsage: Double = 0
        var gpuUsage: Double = 0
        var memoryUsage: UInt64 = 0
        var peakMemoryUsage: UInt64 = 0
        var quantumComputeTime: Double = 0
        var audioLatency: Double = 0
        var diskActivity: UInt64 = 0
        var energyImpact: EnergyImpact = .low
    }

    /// Energy impact levels
    enum EnergyImpact {
        case low
        case moderate
        case high
        case critical

        var description: String {
            switch self {
            case .low: return "Low"
            case .moderate: return "Moderate"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }

        var color: Color {
            switch self {
            case .low: return .green
            case .moderate: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }

    /// Performance log entry
    struct PerformanceLogEntry {
        let timestamp: Date
        let metrics: PerformanceMetrics
        let note: String?
    }

    // MARK: - Properties

    /// Current performance metrics
    private(set) var currentMetrics = PerformanceMetrics()

    /// Performance measurement buffer (for averages/trends)
    private(set) var metricsBuffer: [PerformanceMetrics] = []

    /// Performance log
    private var performanceLog: [PerformanceLogEntry] = []

    /// Configuration
    private var isMonitoring: Bool = false
    private var loggingEnabled: Bool = false
    private var sampleInterval: TimeInterval = 1.0
    private var bufferSize: Int = 60
    private var logCapacity: Int = 1000

    /// Metal performance measurement
    private var device: MTLDevice?
    private var gpuCounter: MTLCounterSampleBuffer?

    /// System monitoring
    private var lastCPUSample: host_cpu_load_info?
    private var lastMemorySample: UInt64 = 0
    private var lastDiskSample: UInt64 = 0

    /// Timing
    private var frameTimer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
    private var frameStartTime: CFAbsoluteTime = 0
    private var lastFrameTime: CFAbsoluteTime = 0
    private var frameCount: UInt = 0

    // MARK: - Initialization

    private init() {
        setupMetalDevice()
    }

    // MARK: - Public Methods

    /// Start performance monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        frameStartTime = CFAbsoluteTimeGetCurrent()
        lastFrameTime = frameStartTime
        frameCount = 0

        // Take initial CPU sample
        lastCPUSample = hostCPULoadInfo()

        // Take initial memory sample
        lastMemorySample = memoryUsage()

        // Take initial disk sample
        lastDiskSample = diskActivity()

        // Start timer for periodic sampling
        frameTimer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        frameTimer.schedule(deadline: .now() + sampleInterval, repeating: sampleInterval)
        frameTimer.setEventHandler { [weak self] in
            self?.samplePerformanceMetrics()
        }
        frameTimer.resume()
    }

    /// Stop performance monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }

        frameTimer.cancel()
        isMonitoring = false
    }

    /// Update frame rate calculation
    func frameRendered() {
        guard isMonitoring else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let currentTime = CFAbsoluteTimeGetCurrent()
            self.frameCount += 1

            // Calculate frame time
            let frameDuration = currentTime - self.lastFrameTime
            self.lastFrameTime = currentTime

            // Update render duration (smoothed)
            self.currentMetrics.renderDuration =
                self.currentMetrics.renderDuration * 0.9 + frameDuration * 0.1

            // Calculate frame rate over the interval
            let totalElapsed = currentTime - self.frameStartTime
            if totalElapsed >= 1.0 {
                self.currentMetrics.frameRate = Double(self.frameCount) / totalElapsed
                self.frameCount = 0
                self.frameStartTime = currentTime
            }
        }
    }

    /// Record the start of a quantum computation
    func startQuantumComputation() -> UInt64 {
        return mach_absolute_time()
    }

    /// Record the completion of a quantum computation
    func endQuantumComputation(_ startTime: UInt64) {
        let endTime = mach_absolute_time()
        let duration = machTimeToSeconds(endTime - startTime)

        // Update quantum compute time (smoothed)
        currentMetrics.quantumComputeTime = currentMetrics.quantumComputeTime * 0.9 + duration * 0.1
    }

    /// Record the audio latency
    func recordAudioLatency(_ latency: Double) {
        // Update audio latency (smoothed)
        currentMetrics.audioLatency = currentMetrics.audioLatency * 0.9 + latency * 0.1
    }

    /// Add a custom note to the performance log
    func logPerformanceNote(_ note: String) {
        guard loggingEnabled else { return }

        let entry = PerformanceLogEntry(
            timestamp: Date(),
            metrics: currentMetrics,
            note: note
        )

        performanceLog.append(entry)

        // Trim log if needed
        if performanceLog.count > logCapacity {
            performanceLog.removeFirst()
        }
    }

    /// Enable or disable performance logging
    func setLoggingEnabled(_ enabled: Bool) {
        loggingEnabled = enabled
    }

    /// Set the monitoring sample interval
    func setSampleInterval(_ interval: TimeInterval) {
        sampleInterval = max(0.1, interval)

        if isMonitoring {
            stopMonitoring()
            startMonitoring()
        }
    }

    /// Clear performance log
    func clearPerformanceLog() {
        performanceLog.removeAll()
    }

    /// Export performance log as CSV
    func exportPerformanceLog() -> URL? {
        guard !performanceLog.isEmpty else { return nil }

        // Create CSV content
        var csv =
            "Timestamp,Frame Rate,Render Duration,CPU Usage,GPU Usage,Memory Usage,Peak Memory Usage,Quantum Compute Time,Audio Latency,Disk Activity,Energy Impact,Note\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        for entry in performanceLog {
            let metrics = entry.metrics
            let timestamp = dateFormatter.string(from: entry.timestamp)
            let note = entry.note?.replacingOccurrences(of: ",", with: ";") ?? ""

            csv +=
                "\(timestamp),\(metrics.frameRate),\(metrics.renderDuration),\(metrics.cpuUsage),\(metrics.gpuUsage),\(metrics.memoryUsage),\(metrics.peakMemoryUsage),\(metrics.quantumComputeTime),\(metrics.audioLatency),\(metrics.diskActivity),\(metrics.energyImpact.description),\"\(note)\"\n"
        }

        // Write to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(
            "QwantumWaveform_Performance_\(Date().timeIntervalSince1970).csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write performance log: \(error)")
            return nil
        }
    }

    /// Get a formatted report of current performance metrics
    func getPerformanceReport() -> String {
        let metrics = currentMetrics

        var report = "FPS: \(String(format: "%.1f", metrics.frameRate))"
        report += " | CPU: \(String(format: "%.1f%%", metrics.cpuUsage))"
        report += " | GPU: \(String(format: "%.1f%%", metrics.gpuUsage))"
        report += " | Memory: \(formatMemory(metrics.memoryUsage))"

        if metrics.quantumComputeTime > 0.001 {
            report += " | QC: \(String(format: "%.1f ms", metrics.quantumComputeTime * 1000))"
        }

        if metrics.audioLatency > 0.001 {
            report += " | Audio: \(String(format: "%.1f ms", metrics.audioLatency * 1000))"
        }

        return report
    }

    /// Determine if we need to reduce quality for performance
    func shouldReduceQuality() -> Bool {
        // Check if performance is below acceptable thresholds
        if currentMetrics.frameRate < 20 || currentMetrics.cpuUsage > 85
            || currentMetrics.gpuUsage > 90 || currentMetrics.energyImpact == .critical
        {
            return true
        }
        return false
    }

    /// Determine if we can increase quality for better visuals
    func canIncreaseQuality() -> Bool {
        // Check if we have performance headroom
        if currentMetrics.frameRate > 55 && currentMetrics.cpuUsage < 50
            && currentMetrics.gpuUsage < 60 && currentMetrics.energyImpact == .low
        {
            return true
        }
        return false
    }

    /// Get metrics buffer for trending
    func getMetricsBuffer() -> [PerformanceMonitor.PerformanceMetrics] {
        // Return the metrics buffer directly for internal use
        return metricsBuffer
    }

    // MARK: - Private Methods

    /// Set up Metal device for GPU monitoring
    private func setupMetalDevice() {
        device = MTLCreateSystemDefaultDevice()

        if let device = device, #available(macOS 10.15, *) {
            let counterSampleBufferDescriptor = MTLCounterSampleBufferDescriptor()
            counterSampleBufferDescriptor.counterSet = device.counterSets?.first
            counterSampleBufferDescriptor.sampleCount = 1

            do {
                gpuCounter = try device.makeCounterSampleBuffer(
                    descriptor: counterSampleBufferDescriptor)
            } catch {
                print("Failed to create Metal counter sample buffer: \(error)")
            }
        }
    }

    /// Sample all performance metrics
    private func samplePerformanceMetrics() {
        // CPU usage
        if let currentCPUSample = hostCPULoadInfo(), let lastSample = lastCPUSample {
            let userDiff = Double(currentCPUSample.cpu_ticks.0 - lastSample.cpu_ticks.0)
            let systemDiff = Double(currentCPUSample.cpu_ticks.1 - lastSample.cpu_ticks.1)
            let idleDiff = Double(currentCPUSample.cpu_ticks.2 - lastSample.cpu_ticks.2)
            let niceDiff = Double(currentCPUSample.cpu_ticks.3 - lastSample.cpu_ticks.3)

            let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
            if totalTicks > 0 {
                let cpuUsage = ((userDiff + systemDiff + niceDiff) / totalTicks) * 100.0
                currentMetrics.cpuUsage = cpuUsage
            }

            lastCPUSample = currentCPUSample
        }

        // GPU usage (if available)
        sampleGPUUsage()

        // Memory usage
        let memUsage = memoryUsage()
        currentMetrics.memoryUsage = memUsage
        currentMetrics.peakMemoryUsage = max(currentMetrics.peakMemoryUsage, memUsage)

        // Disk activity
        let diskUsage = diskActivity()
        currentMetrics.diskActivity = diskUsage > lastDiskSample ? diskUsage - lastDiskSample : 0
        lastDiskSample = diskUsage

        // Determine energy impact
        updateEnergyImpact()

        // Add to metrics buffer
        metricsBuffer.append(currentMetrics)

        // Trim buffer if needed
        if metricsBuffer.count > bufferSize {
            metricsBuffer.removeFirst()
        }

        // Log metrics if enabled
        if loggingEnabled {
            performanceLog.append(
                PerformanceLogEntry(
                    timestamp: Date(),
                    metrics: currentMetrics,
                    note: nil
                ))

            // Trim log if needed
            if performanceLog.count > logCapacity {
                performanceLog.removeFirst()
            }
        }
    }

    /// Sample GPU usage using Metal performance counters
    private func sampleGPUUsage() {
        #if os(macOS)
            // This is a simplified approximation - real GPU usage monitoring is more complex
            if #available(macOS 10.15, *), let device = device, let counter = gpuCounter {
                do {
                    try device.sampleTimestamps()

                    // Fix accessing counter data - use proper MTLCounterSampleBuffer API
                    do {
                        if let counterData = try counter.resolveCounterRange(0..<1) {
                            // Process the counter data as needed
                            // This is a very simplified approximation
                            let bytes = counterData.withUnsafeBytes { $0.load(as: UInt64.self) }
                            let normalizedValue = Double(bytes) / 10000000.0

                            // Clamp to 0-100 range
                            currentMetrics.gpuUsage = min(100.0, max(0.0, normalizedValue))
                        }
                    } catch {
                        // Handle error for resolveCounterRange
                        print("Error resolving counter range: \(error)")
                    }
                } catch {
                    // Fallback to estimation based on frameRate
                    let maxFrameRate: Double = 60.0  // Assumed maximum frame rate
                    let gpuLoad = min(
                        1.0, (1.0 / max(0.01, currentMetrics.frameRate)) * maxFrameRate)
                    currentMetrics.gpuUsage = gpuLoad * 100.0
                }
            } else {
                // Fallback to estimation based on frameRate
                let maxFrameRate: Double = 60.0  // Assumed maximum frame rate
                let gpuLoad = min(1.0, (1.0 / max(0.01, currentMetrics.frameRate)) * maxFrameRate)
                currentMetrics.gpuUsage = gpuLoad * 100.0
            }
        #else
            // Simple estimation for iOS
            let maxFrameRate: Double = 60.0  // Assumed maximum frame rate
            let gpuLoad = min(1.0, (1.0 / max(0.01, currentMetrics.frameRate)) * maxFrameRate)
            currentMetrics.gpuUsage = gpuLoad * 100.0
        #endif
    }

    /// Determine energy impact based on various metrics
    private func updateEnergyImpact() {
        let cpuThreshold: Double = 75.0
        let gpuThreshold: Double = 80.0
        let memoryThreshold: UInt64 = 2 * 1024 * 1024 * 1024  // 2 GB

        if currentMetrics.cpuUsage > cpuThreshold && currentMetrics.gpuUsage > gpuThreshold {
            currentMetrics.energyImpact = .critical
        } else if currentMetrics.cpuUsage > cpuThreshold || currentMetrics.gpuUsage > gpuThreshold {
            currentMetrics.energyImpact = .high
        } else if currentMetrics.cpuUsage > cpuThreshold / 2
            || currentMetrics.gpuUsage > gpuThreshold / 2
        {
            currentMetrics.energyImpact = .moderate
        } else {
            currentMetrics.energyImpact = .low
        }

        // Adjust based on memory usage
        if currentMetrics.memoryUsage > memoryThreshold && currentMetrics.energyImpact != .critical
        {
            currentMetrics.energyImpact = .high
        }
    }

    /// Get host CPU load information
    private func hostCPULoadInfo() -> host_cpu_load_info? {
        var size = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        var cpuLoadInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }

        if result == KERN_SUCCESS {
            return cpuLoadInfo
        }

        return nil
    }

    /// Get current memory usage
    private func memoryUsage() -> UInt64 {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size)
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return taskInfo.phys_footprint
        }

        return 0
    }

    /// Get disk activity information
    private func diskActivity() -> UInt64 {
        // This is a simplified approach - real disk I/O monitoring is more complex
        // Just returning a placeholder value for now
        return UInt64(Date().timeIntervalSince1970 * 1000)
    }

    /// Convert Mach absolute time to seconds
    private func machTimeToSeconds(_ machTime: UInt64) -> Double {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)

        let nanos = machTime * UInt64(timebase.numer) / UInt64(timebase.denom)
        return Double(nanos) / 1_000_000_000.0
    }

    /// Format memory size for display
    private func formatMemory(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0

        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.2f KB", kb)
        }
    }
}

// MARK: - Performance View

/// View for displaying performance metrics
struct PerformanceView: View {
    @ObservedObject var viewModel: PerformanceViewModel
    @State private var showDetails = false
    @State private var selectedMetric: PerformanceMetricType = .framerate

    /// Available metric types
    enum PerformanceMetricType: String, CaseIterable, Identifiable {
        case framerate = "Frame Rate"
        case cpu = "CPU Usage"
        case gpu = "GPU Usage"
        case memory = "Memory Usage"
        case quantum = "Quantum Compute"
        case audio = "Audio Latency"

        var id: String { self.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Basic summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance")
                        .font(.headline)

                    Text(viewModel.performanceReport)
                        .font(.system(.caption, design: .monospaced))
                }

                Spacer()

                Button(action: {
                    showDetails.toggle()
                }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(8)
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)

            // Detailed metrics
            if showDetails {
                VStack(spacing: 8) {
                    // Metric selector
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(PerformanceMetricType.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Metric chart
                    metricChart
                        .frame(height: 150)
                        .padding(.horizontal)

                    // Controls
                    HStack {
                        Button(action: {
                            viewModel.exportLog()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer()

                        HStack {
                            Text("Log:")
                            Toggle("", isOn: $viewModel.loggingEnabled)
                                .labelsHidden()
                        }

                        Spacer()

                        Button(action: {
                            viewModel.clearLog()
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.05))
                .transition(.opacity)
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    /// Chart for the selected metric
    private var metricChart: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Divider()
                        Spacer()
                    }
                    Divider()
                }

                // Chart data
                Path { path in
                    let data = metricData()
                    guard !data.isEmpty else { return }

                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(data.count - 1)

                    path.move(to: CGPoint(x: 0, y: height - CGFloat(data[0]) * height))

                    for i in 1..<data.count {
                        path.addLine(
                            to: CGPoint(
                                x: CGFloat(i) * stepX,
                                y: height - CGFloat(data[i]) * height
                            ))
                    }
                }
                .stroke(metricColor(), lineWidth: 2)

                // Current value
                Text(formattedMetricValue())
                    .font(.title)
                    .foregroundColor(metricColor())
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)
                    .opacity(0.5)
            }
        }
    }

    /// Get normalized data for the selected metric
    private func metricData() -> [Double] {
        let metrics = viewModel.getMetricsBuffer()
        guard !metrics.isEmpty else { return [] }

        // Map and normalize values
        switch selectedMetric {
        case .framerate:
            let maxFPS = 60.0
            return metrics.map { min(1.0, $0.frameRate / maxFPS) }

        case .cpu:
            return metrics.map { $0.cpuUsage / 100.0 }

        case .gpu:
            return metrics.map { $0.gpuUsage / 100.0 }

        case .memory:
            let maxMem = Double(metrics.map { $0.memoryUsage }.max() ?? 1) * 1.2
            return metrics.map { Double($0.memoryUsage) / maxMem }

        case .quantum:
            let maxTime = metrics.map { $0.quantumComputeTime }.max() ?? 0.001
            return metrics.map { $0.quantumComputeTime / maxTime }

        case .audio:
            let maxLatency = metrics.map { $0.audioLatency }.max() ?? 0.001
            return metrics.map { $0.audioLatency / maxLatency }
        }
    }

    /// Get color for the selected metric
    private func metricColor() -> Color {
        switch selectedMetric {
        case .framerate: return .green
        case .cpu: return .blue
        case .gpu: return .purple
        case .memory: return .orange
        case .quantum: return .pink
        case .audio: return .yellow
        }
    }

    /// Format the current value of the selected metric
    private func formattedMetricValue() -> String {
        let metrics = viewModel.getCurrentMetrics()

        switch selectedMetric {
        case .framerate:
            return String(format: "%.1f FPS", metrics.frameRate)

        case .cpu:
            return String(format: "%.1f%%", metrics.cpuUsage)

        case .gpu:
            return String(format: "%.1f%%", metrics.gpuUsage)

        case .memory:
            let mb = Double(metrics.memoryUsage) / (1024.0 * 1024.0)
            return String(format: "%.1f MB", mb)

        case .quantum:
            return String(format: "%.2f ms", metrics.quantumComputeTime * 1000)

        case .audio:
            return String(format: "%.2f ms", metrics.audioLatency * 1000)
        }
    }
}

// MARK: - Performance View Model

/// View model for performance monitoring
class PerformanceViewModel: ObservableObject {
    @Published var performanceReport: String = "Monitoring inactive"
    @Published var loggingEnabled: Bool = false {
        didSet {
            PerformanceMonitor.shared.setLoggingEnabled(loggingEnabled)
        }
    }

    private var updateTimer: Timer?

    init() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceReport()
        }
    }

    deinit {
        updateTimer?.invalidate()
    }

    /// Start performance monitoring
    func startMonitoring() {
        PerformanceMonitor.shared.startMonitoring()
        updatePerformanceReport()
    }

    /// Stop performance monitoring
    func stopMonitoring() {
        PerformanceMonitor.shared.stopMonitoring()
    }

    /// Clear performance log
    func clearLog() {
        PerformanceMonitor.shared.clearPerformanceLog()
    }

    /// Export performance log
    func exportLog() {
        let fileURL = PerformanceMonitor.shared.exportPerformanceLog()

        // In a full implementation, would show a file save dialog
        print("Performance log exported to: \(fileURL?.path ?? "failed")")
    }

    /// Get current metrics
    func getCurrentMetrics() -> PerformanceMonitor.PerformanceMetrics {
        return PerformanceMonitor.shared.currentMetrics
    }

    /// Get metrics buffer for trending
    func getMetricsBuffer() -> [PerformanceMonitor.PerformanceMetrics] {
        // Access through the shared instance to use the private(set) property
        return PerformanceMonitor.shared.metricsBuffer
    }

    /// Update the performance report string
    private func updatePerformanceReport() {
        performanceReport = PerformanceMonitor.shared.getPerformanceReport()
    }
}
