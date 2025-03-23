import SwiftUI
import MetalKit

struct Metal3DView: NSViewRepresentable {
    // MARK: - Properties
    
    var waveformData: [Double]
    var spectrumData: [Double]
    var showSpectrum: Bool = false
    var isQuarterView: Bool = false
    
    @State private var device: MTLDevice? = MTLCreateSystemDefaultDevice()
    @State private var renderer: Waveform3DRenderer?
    @State private var previousViewSize: CGSize? = nil
    @State private var frameTimeHistory: [Double] = []
    @State private var lastUpdateTime: Date = Date()
    
    // MARK: - NSViewRepresentable
    
    func makeNSView(context: Context) -> MTKView {
        // Create Metal view
        let metalView = MTKView()
        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.framebufferOnly = false
        metalView.enableSetNeedsDisplay = true
        metalView.preferredFramesPerSecond = 60
        metalView.layer?.isOpaque = false
        
        // Create renderer
        if let device = device {
            let renderer = Waveform3DRenderer(device: device, view: metalView)
            self.renderer = renderer
            metalView.delegate = renderer
            
            // Initial update
            updateRenderer(renderer, metalView: metalView)
        }
        
        return metalView
    }
    
    func updateNSView(_ metalView: MTKView, context: Context) {
        // Check if view size has changed
        let currentSize = metalView.bounds.size
        let sizeChanged = previousViewSize != currentSize
        previousViewSize = currentSize
        
        // Check if data has changed
        let dataChanged = hasDataChanged(renderer: renderer)
        
        // Only update if necessary
        if sizeChanged || dataChanged {
            if let renderer = renderer {
                updateRenderer(renderer, metalView: metalView)
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
                    let avgFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
                    let fps = 1.0 / avgFrameTime
                    if fps < 30 {
                        NSLog("Warning: 3D rendering performance is low: \(fps) FPS")
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateRenderer(_ renderer: Waveform3DRenderer, metalView: MTKView) {
        // Update renderer data
        renderer.updateWaveformData(waveformData)
        renderer.updateSpectrumData(spectrumData)
        renderer.showSpectrum = showSpectrum
        renderer.isQuarterView = isQuarterView
        
        // Set high DPI rendering based on device capabilities
        if let screen = NSScreen.main {
            renderer.isHighDPI = screen.backingScaleFactor > 1.0
        }
    }
    
    private func hasDataChanged(renderer: Waveform3DRenderer?) -> Bool {
        guard let renderer = renderer else { return true }
        
        // Check if waveform data has changed
        if renderer.waveformDataCount != waveformData.count {
            return true
        }
        
        // Check if spectrum data has changed
        if renderer.spectrumDataCount != spectrumData.count {
            return true
        }
        
        // Check if display settings have changed
        if renderer.showSpectrum != showSpectrum || 
           renderer.isQuarterView != isQuarterView {
            return true
        }
        
        return false
    }
}

