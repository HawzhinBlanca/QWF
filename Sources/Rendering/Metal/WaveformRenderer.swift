import Foundation
import Metal
import MetalKit
import QuartzCore
import SwiftUI
import simd

// MARK: - Enums

/// Types of rendering modes for the waveform
public enum RenderMode: Int {
    case waveform = 0
    case spectrum = 1
    case quantum = 2
    case quantum3D = 3
}

// MARK: - WaveformRenderer Base Class

/// Base class for all waveform rendering
public class WaveformRenderer: NSObject, MTKViewDelegate {
    // MARK: - Public Properties

    /// The Metal device used for rendering
    public let device: MTLDevice

    /// Whether to use high DPI rendering
    public var isHighDPI: Bool = true

    /// The current rendering mode
    public var renderMode: RenderMode = .waveform {
        didSet {
            // Update shader settings when mode changes
            updateShaderSettings()
        }
    }

    /// Visualization parameters
    public var is3DMode: Bool = false
    public var colorScheme: UInt32 = 0
    public var showGrid: Bool = true
    public var frequency: Double = 440.0
    public var amplitude: Double = 0.5
    public var waveType: Int = 0

    // MARK: - Private Properties

    // Metal objects
    private var commandQueue: MTLCommandQueue?
    private var pipelineStates: [RenderMode: MTLRenderPipelineState] = [:]

    // Buffers
    private var waveformVertexBuffer: MTLBuffer?
    private var spectrumVertexBuffer: MTLBuffer?
    private var quantum2DVertexBuffer: MTLBuffer?
    private var quantum3DVertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?

    // Visualization data
    private var waveformData: [Float] = []
    private var spectrumData: [Float] = []
    private var quantumData: [Float] = []

    // Rendering properties
    private var viewportSize = vector_float2(0, 0)
    private var devicePixelRatio: Float = 1.0
    private var timeValue: Float = 0.0

    // Metal view reference
    private weak var metalView: MTKView?

    // Performance monitoring
    private var frameCount: Int = 0
    private var lastPerformanceLog: CFTimeInterval = 0
    private var shouldLogPerformance = false
    private var lastRenderTime: CFTimeInterval = 0

    // MARK: - Initialization

    /// Initialize with a Metal device
    public init(device: MTLDevice, metalView: MTKView? = nil) {
        self.device = device
        self.metalView = metalView

        // Initialize command queue
        commandQueue = device.makeCommandQueue()

        super.init()

        setupMetal()
    }

    // MARK: - Public Methods

    /// Update waveform data for rendering
    public func updateWaveformData(_ data: [Float]) {
        waveformData = data
        updateWaveformBuffer()
    }

    /// Update spectrum data for rendering
    public func updateSpectrumData(_ data: [Float]) {
        spectrumData = data
        updateSpectrumBuffer()
    }

    /// Update quantum data for rendering
    public func updateQuantumData(_ data: [Float]) {
        quantumData = data
        updateQuantumBuffer()
    }

    /// Set the viewport size
    public func setViewportSize(_ size: CGSize) {
        viewportSize = vector_float2(Float(size.width), Float(size.height))
    }

    /// Set the Metal view to render into
    public func setMetalView(_ view: MTKView) {
        metalView = view
        view.device = device
        view.delegate = self
    }

    // MARK: - MTKViewDelegate Methods

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = vector_float2(Float(size.width), Float(size.height))
        devicePixelRatio = Float(view.drawableSize.width / view.bounds.width)
    }

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandQueue = commandQueue
        else {
            return
        }

        // Update animation time
        let currentTime = CACurrentMediaTime()
        if lastRenderTime > 0 {
            timeValue += Float(currentTime - lastRenderTime)
        }
        lastRenderTime = currentTime

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        // Get the appropriate pipeline state
        guard let pipelineState = pipelineStates[renderMode] else {
            return
        }

        // Create encoder
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor)
        else {
            return
        }

        // Set viewport and pipeline state
        renderEncoder.setViewport(
            MTLViewport(
                originX: 0, originY: 0,
                width: Double(viewportSize.x), height: Double(viewportSize.y),
                znear: 0.0, zfar: 1.0
            ))
        renderEncoder.setRenderPipelineState(pipelineState)

        // Update and set uniform buffer
        updateUniformBuffer()
        if let uniformBuffer = uniformBuffer {
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        }

        // Set vertex buffer based on render mode
        switch renderMode {
        case .waveform:
            if let waveformVertexBuffer = waveformVertexBuffer {
                renderEncoder.setVertexBuffer(waveformVertexBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(
                    type: .lineStrip,
                    vertexStart: 0,
                    vertexCount: waveformData.count)
            }

        case .spectrum:
            if let spectrumVertexBuffer = spectrumVertexBuffer {
                renderEncoder.setVertexBuffer(spectrumVertexBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(
                    type: .lineStrip,
                    vertexStart: 0,
                    vertexCount: spectrumData.count)
            }

        case .quantum:
            if let quantum2DVertexBuffer = quantum2DVertexBuffer {
                renderEncoder.setVertexBuffer(quantum2DVertexBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(
                    type: .lineStrip,
                    vertexStart: 0,
                    vertexCount: quantumData.count)
            }

        case .quantum3D:
            if let quantum3DVertexBuffer = quantum3DVertexBuffer {
                renderEncoder.setVertexBuffer(quantum3DVertexBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(
                    type: .triangleStrip,
                    vertexStart: 0,
                    vertexCount: quantumData.count * 2)
            }
        }

        // End encoding and present
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()

        // Performance logging
        trackPerformance()
    }

    // MARK: - Private Methods

    private func setupMetal() {
        // Create pipeline states for each render mode
        createPipelineStates()

        // Initialize buffers
        createBuffers()
    }

    private func createPipelineStates() {
        // Create pipeline state for waveform rendering
        if let waveformPipelineState = createPipelineState(
            vertexFunction: "waveformVertex",
            fragmentFunction: "waveformFragment")
        {
            pipelineStates[.waveform] = waveformPipelineState
        }

        // Create pipeline state for spectrum rendering
        if let spectrumPipelineState = createPipelineState(
            vertexFunction: "spectrumVertex",
            fragmentFunction: "spectrumFragment")
        {
            pipelineStates[.spectrum] = spectrumPipelineState
        }

        // Create pipeline state for quantum 2D rendering
        if let quantum2DPipelineState = createPipelineState(
            vertexFunction: "quantumVertex",
            fragmentFunction: "quantumFragment")
        {
            pipelineStates[.quantum] = quantum2DPipelineState
        }

        // Create pipeline state for quantum 3D rendering
        if let quantum3DPipelineState = createPipelineState(
            vertexFunction: "quantum3DVertex",
            fragmentFunction: "quantum3DFragment")
        {
            pipelineStates[.quantum3D] = quantum3DPipelineState
        }
    }

    private func createPipelineState(vertexFunction: String, fragmentFunction: String)
        -> MTLRenderPipelineState?
    {
        let library = device.makeDefaultLibrary()

        guard let vertexFunction = library?.makeFunction(name: vertexFunction),
            let fragmentFunction = library?.makeFunction(name: fragmentFunction)
        else {
            print("Could not create shader functions for \(vertexFunction)/\(fragmentFunction)")
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error.localizedDescription)")
            return nil
        }
    }

    private func createBuffers() {
        // Create uniform buffer
        let uniformBufferSize = MemoryLayout<WaveformUniforms>.size
        uniformBuffer = device.makeBuffer(length: uniformBufferSize, options: [])

        // Initialize with empty data arrays
        updateWaveformBuffer()
        updateSpectrumBuffer()
        updateQuantumBuffer()
    }

    private func updateWaveformBuffer() {
        let vertexBufferSize = MemoryLayout<Float>.size * waveformData.count
        waveformVertexBuffer = device.makeBuffer(
            bytes: waveformData,
            length: vertexBufferSize,
            options: [])
    }

    private func updateSpectrumBuffer() {
        let vertexBufferSize = MemoryLayout<Float>.size * spectrumData.count
        spectrumVertexBuffer = device.makeBuffer(
            bytes: spectrumData,
            length: vertexBufferSize,
            options: [])
    }

    private func updateQuantumBuffer() {
        let vertexBufferSize = MemoryLayout<Float>.size * quantumData.count
        quantum2DVertexBuffer = device.makeBuffer(
            bytes: quantumData,
            length: vertexBufferSize,
            options: [])

        // For 3D mode, we need a different buffer structure
        // This is simplified - a real implementation would create a proper 3D mesh
        quantum3DVertexBuffer = device.makeBuffer(
            bytes: quantumData,
            length: vertexBufferSize,
            options: [])
    }

    private func updateUniformBuffer() {
        guard let uniformBuffer = uniformBuffer else { return }

        var uniforms = WaveformUniforms()
        uniforms.viewportSize = viewportSize
        uniforms.time = timeValue
        uniforms.frequency = Float(frequency)
        uniforms.amplitude = Float(amplitude)
        uniforms.waveType = UInt32(waveType)
        uniforms.colorScheme = colorScheme
        uniforms.showGrid = showGrid ? 1 : 0
        uniforms.is3DMode = is3DMode ? 1 : 0

        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<WaveformUniforms>.size)
    }

    private func updateShaderSettings() {
        // Update renderer settings based on the current mode
        is3DMode = (renderMode == .quantum3D)

        // Update any other mode-specific settings
    }

    private func trackPerformance() {
        frameCount += 1

        let currentTime = CACurrentMediaTime()
        if currentTime - lastPerformanceLog > 1.0 && shouldLogPerformance {
            let frameRate = Double(frameCount) / (currentTime - lastPerformanceLog)
            print("Render performance: \(String(format: "%.1f", frameRate)) FPS")

            frameCount = 0
            lastPerformanceLog = currentTime
        }
    }
}

// MARK: - Uniform Structures

/// Uniform structure for waveform rendering
private struct WaveformUniforms {
    var viewportSize: vector_float2 = vector_float2(0, 0)
    var time: Float = 0.0
    var frequency: Float = 440.0
    var amplitude: Float = 0.5
    var waveType: UInt32 = 0
    var colorScheme: UInt32 = 0
    var showGrid: UInt32 = 1
    var is3DMode: UInt32 = 0
}
