import SwiftUI
import MetalKit

struct WaveformMetal3DView: NSViewRepresentable {
    // MARK: - Properties
    
    var waveformData: [Double]
    var spectrumData: [Double]
    var showSpectrum: Bool
    var isQuarternaryView: Bool
    
    @State private var device: MTLDevice? = MTLCreateSystemDefaultDevice()
    @State private var renderer: Waveform3DRenderer?
    @State private var lastUpdateTime: Date = Date()
    @State private var frameTimeHistory: [Double] = []
    @State private var previousViewSize: CGSize? = nil
    
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
        renderer.isQuarterView = isQuarternaryView
        
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
           renderer.isQuarterView != isQuarternaryView {
            return true
        }
        
        return false
    }
}

class Waveform3DRenderer: NSObject, MTKViewDelegate {
    // MARK: - Public Properties
    
    let device: MTLDevice
    var waveformData: [Float] = []
    var spectrumData: [Float] = []
    var showSpectrum: Bool = false
    var isQuarterView: Bool = false
    var isHighDPI: Bool = true  // Whether to render at high resolution
    
    // For change detection
    var waveformDataCount: Int { return waveformData.count }
    var spectrumDataCount: Int { return spectrumData.count }
    
    // MARK: - Private Properties
    
    // Metal objects
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var depthState: MTLDepthStencilState?
    
    // Buffers
    private var waveformVertexBuffer: MTLBuffer?
    private var spectrumVertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    
    // Rendering properties
    private var viewportSize = vector_float2(0, 0)
    private var rotation: Float = 0.0
    private var devicePixelRatio: Float = 1.0
    
    // Performance tracking
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: UInt = 0
    private var frameTimeAccumulator: CFTimeInterval = 0
    
    // MARK: - Initialization
    
    init(device: MTLDevice, view: MTKView) {
        self.device = device
        super.init()
        
        setupMetal(view: view)
    }
    
    // MARK: - Public Methods
    
    func updateWaveformData(_ data: [Double]) {
        // Convert double to float array
        waveformData = data.map { Float($0) }
        
        // Create vertex buffer
        createWaveformVertexBuffer()
    }
    
    func updateSpectrumData(_ data: [Double]) {
        // Convert double to float array
        spectrumData = data.map { Float($0) }
        
        // Create vertex buffer
        createSpectrumVertexBuffer()
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Store viewport size
        viewportSize.x = Float(size.width)
        viewportSize.y = Float(size.height)
        
        // Update device pixel ratio for high-DPI support
        let screen = NSScreen.main
        let backingScaleFactor = screen?.backingScaleFactor ?? 1.0
        devicePixelRatio = isHighDPI ? Float(backingScaleFactor) : 1.0
        
        // Update uniform buffer
        createUniformBuffer()
    }
    
    func draw(in view: MTKView) {
        // Track frame time for performance metrics
        let currentTime = CACurrentMediaTime()
        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            frameTimeAccumulator += frameTime
            frameCount += 1
            
            // Log performance every 60 frames
            if frameCount >= 60 {
                let avgFrameTime = frameTimeAccumulator / Double(frameCount)
                let fps = 1.0 / avgFrameTime
                
                // Log warning if performance is poor
                if fps < 30 {
                    NSLog("Warning: 3D View is performing at \(Int(fps)) FPS")
                }
                
                frameTimeAccumulator = 0
                frameCount = 0
            }
        }
        lastFrameTime = currentTime
        
        // Update rotation angle
        rotation += 0.005
        updateUniformBuffer(with: rotation)
        
        // Create command buffer
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        commandBuffer.label = "3DRenderCommandBuffer"
        
        // Get render pass descriptor
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        // Create render encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "3DRenderEncoder"
        
        // Set render pipeline state
        renderEncoder.setRenderPipelineState(pipelineState!)
        renderEncoder.setDepthStencilState(depthState)
        
        // Set vertex buffers
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        
        // Draw waveform
        if !waveformData.isEmpty {
            renderEncoder.setVertexBuffer(waveformVertexBuffer, offset: 0, index: 1)
            renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: waveformData.count)
        }
        
        // Draw spectrum if enabled
        if showSpectrum && !spectrumData.isEmpty {
            renderEncoder.setVertexBuffer(spectrumVertexBuffer, offset: 0, index: 1)
            renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: spectrumData.count * 2)
        }
        
        renderEncoder.endEncoding()
        
        // Present drawable and commit
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
    
    // MARK: - Private Methods
    
    private func setupMetal(view: MTKView) {
        // Create command queue
        commandQueue = device.makeCommandQueue()
        
        // Create render pipeline state
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertex_3d")
        let fragmentFunction = library?.makeFunction(name: "fragment_3d")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "3DRenderPipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
        
        // Create depth stencil state
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        
        // Create initial buffers
        createWaveformVertexBuffer()
        createSpectrumVertexBuffer()
        createUniformBuffer()
    }
    
    private func createWaveformVertexBuffer() {
        // Ensure we have data
        guard !waveformData.isEmpty else { return }
        
        // Create buffer
        let bufferSize = waveformData.count * MemoryLayout<Float>.size
        waveformVertexBuffer = device.makeBuffer(
            bytes: waveformData,
            length: bufferSize,
            options: .storageModeShared
        )
    }
    
    private func createSpectrumVertexBuffer() {
        // Ensure we have data
        guard !spectrumData.isEmpty else { return }
        
        // Create a buffer for the spectrum bars
        var vertexData = [Float]()
        
        // For each spectrum value, create a vertical line (2 points for each)
        for (i, magnitude) in spectrumData.enumerated() {
            let x = Float(i) / Float(spectrumData.count - 1)
            
            // Bottom point (0 magnitude)
            vertexData.append(x)
            vertexData.append(0)
            
            // Top point (actual magnitude)
            vertexData.append(x)
            vertexData.append(magnitude)
        }
        
        // Create buffer
        let bufferSize = vertexData.count * MemoryLayout<Float>.size
        spectrumVertexBuffer = device.makeBuffer(
            bytes: vertexData,
            length: bufferSize,
            options: .storageModeShared
        )
    }
    
    private func createUniformBuffer() {
        // Create uniform structure
        var uniforms = Waveform3DUniforms(
            projectionMatrix: matrix_identity_float4x4,
            viewMatrix: matrix_identity_float4x4,
            modelMatrix: matrix_identity_float4x4,
            viewportSize: viewportSize,
            devicePixelRatio: devicePixelRatio
        )
        
        // Set perspective projection
        let aspect = viewportSize.x / viewportSize.y
        let fov: Float = 65.0 * (Float.pi / 180.0)
        let near: Float = 0.1
        let far: Float = 100.0
        
        uniforms.projectionMatrix = matrix_perspective_right_hand(fov, aspect, near, far)
        
        // Set view matrix (camera position)
        let eye = vector_float3(0.0, 0.0, 2.0)
        let center = vector_float3(0.0, 0.0, 0.0)
        let up = vector_float3(0.0, 1.0, 0.0)
        
        uniforms.viewMatrix = matrix_look_at_right_hand(eye, center, up)
        
        // Initial model matrix
        uniforms.modelMatrix = matrix4x4_rotation(radians: 0, axis: vector_float3(0, 1, 0))
        
        // Create buffer
        let bufferSize = MemoryLayout<Waveform3DUniforms>.size
        uniformBuffer = device.makeBuffer(
            bytes: &uniforms,
            length: bufferSize,
            options: .storageModeShared
        )
    }
    
    private func updateUniformBuffer(with rotation: Float) {
        guard let uniformBuffer = uniformBuffer else { return }
        
        // Get pointer to the buffer
        let bufferPointer = uniformBuffer.contents().bindMemory(
            to: Waveform3DUniforms.self,
            capacity: 1
        )
        
        // Update model matrix with rotation
        var modelMatrix = matrix4x4_rotation(radians: rotation, axis: vector_float3(0, 1, 0))
        
        // If quarter view is enabled, also rotate around X axis
        if isQuarterView {
            let xRotation = matrix4x4_rotation(radians: Float.pi / 4, axis: vector_float3(1, 0, 0))
            modelMatrix = matrix_multiply(xRotation, modelMatrix)
        }
        
        bufferPointer.pointee.modelMatrix = modelMatrix
    }
}

// MARK: - Supporting Types and Functions

// Uniform structure to pass to the shader
struct Waveform3DUniforms {
    var projectionMatrix: matrix_float4x4
    var viewMatrix: matrix_float4x4
    var modelMatrix: matrix_float4x4
    var viewportSize: vector_float2
    var devicePixelRatio: Float
}

// Matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: vector_float3) -> matrix_float4x4 {
    let normalizedAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = normalizedAxis.x, y = normalizedAxis.y, z = normalizedAxis.z
    
    return matrix_float4x4(
        columns: (
            vector_float4(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
            vector_float4(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0),
            vector_float4(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0),
            vector_float4(0, 0, 0, 1)
        )
    )
}
