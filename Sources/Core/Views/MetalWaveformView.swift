import Foundation
import Metal
import MetalKit
import ObjectiveC
import SwiftUI

// MARK: - MetalWaveformView

/// A SwiftUI wrapper for Metal-based waveform rendering
struct MetalWaveformView: NSViewRepresentable {
    // MARK: - Properties

    var waveformData: [Double]
    var spectrumData: [Double]
    var quantumData: [Double]? = nil
    var visualizationMode: VisualizationMode

    @State private var device: MTLDevice? = MTLCreateSystemDefaultDevice()
    @State private var renderer: NSObject?
    @State private var previousViewSize: CGSize? = nil
    @State private var frameTimeHistory: [Double] = []
    @State private var lastUpdateTime: Date = Date()

    // MARK: - Methods to dynamically access renderer

    private func createRenderer(with device: MTLDevice) -> NSObject? {
        // First attempt: try to load the class directly
        if let rendererClass = objc_getClass("WaveformRenderer") as? NSObject.Type {
            let renderer = rendererClass.init()
            // Set the device using key-value coding
            renderer.setValue(device, forKey: "device")
            return renderer
        }

        // Second attempt: try with explicit module name
        if let rendererClass = objc_getClass("QwantumWaveform.WaveformRenderer") as? NSObject.Type {
            let renderer = rendererClass.init()
            // Set the device using key-value coding
            renderer.setValue(device, forKey: "device")
            return renderer
        }

        // Last attempt: try NSClassFromString
        if let rendererClass = NSClassFromString("WaveformRenderer") as? NSObject.Type {
            let renderer = rendererClass.init()
            // Set the device using key-value coding
            renderer.setValue(device, forKey: "device")
            return renderer
        }

        NSLog("Error: Could not load WaveformRenderer class dynamically")
        return nil
    }

    private func callUpdateMethod(on renderer: NSObject, named method: String, with data: [Float]) {
        let selector = NSSelectorFromString(method)
        if renderer.responds(to: selector) {
            renderer.perform(selector, with: data)
        }
    }

    private func setHighDPI(on renderer: NSObject, value: Bool) {
        renderer.setValue(value, forKey: "isHighDPI")
    }

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> MTKView {
        // Create Metal view
        let metalView = MTKView()
        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        metalView.framebufferOnly = false
        metalView.enableSetNeedsDisplay = true
        metalView.preferredFramesPerSecond = 60
        metalView.layer?.isOpaque = false

        // Create renderer
        if let device = device,
            let renderer = createRenderer(with: device)
        {
            self.renderer = renderer

            // Set as delegate if it conforms to MTKViewDelegate
            if renderer.conforms(to: MTKViewDelegate.self) {
                metalView.delegate = renderer as? MTKViewDelegate
            }

            // Initial update
            updateRenderer(renderer)
        }

        return metalView
    }

    func updateNSView(_ metalView: MTKView, context: Context) {
        // Check if view size has changed
        let currentSize = metalView.bounds.size
        let sizeChanged = previousViewSize != currentSize
        previousViewSize = currentSize

        // Check if data has changed or visualization mode changed
        let dataChanged = hasDataChanged()

        // Only update if necessary
        if sizeChanged || dataChanged {
            if let renderer = self.renderer {
                updateRenderer(renderer)
                metalView.setNeedsDisplay(metalView.bounds)

                // Track update time for performance measurements
                let currentTime = Date()
                let updateInterval = currentTime.timeIntervalSince(lastUpdateTime)
                lastUpdateTime = currentTime

                // Keep a history of the last 60 frame times (1 second at 60fps)
                frameTimeHistory.append(updateInterval)
                if frameTimeHistory.count > 60 {
                    frameTimeHistory.removeFirst()
                }

                // Calculate and log average frame time if needed
                if frameTimeHistory.count >= 60 {
                    let avgFrameTime =
                        frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
                    let fps = 1.0 / avgFrameTime
                    if fps < 30 {
                        NSLog("Warning: Metal rendering performance is low: \(fps) FPS")
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func updateRenderer(_ renderer: NSObject) {
        // Update renderer with current data based on visualization mode
        switch visualizationMode {
        case .waveform:
            callUpdateMethod(
                on: renderer, named: "updateWaveformData:", with: waveformData.map { Float($0) })
        case .spectrum:
            callUpdateMethod(
                on: renderer, named: "updateSpectrumData:", with: spectrumData.map { Float($0) })
        case .quantum:
            if let quantumData = quantumData {
                callUpdateMethod(
                    on: renderer, named: "updateQuantumData:", with: quantumData.map { Float($0) })
            } else {
                callUpdateMethod(
                    on: renderer, named: "updateQuantumData:", with: waveformData.map { Float($0) })
            }
        }

        // Enable high DPI rendering based on device capabilities
        if let screen = NSScreen.main {
            setHighDPI(on: renderer, value: screen.backingScaleFactor > 1.0)
        }
    }

    private func hasDataChanged() -> Bool {
        return true  // Always update data for now
    }
}

// MARK: - VisualizationMode Enum

enum VisualizationMode {
    case waveform
    case spectrum
    case quantum
}
