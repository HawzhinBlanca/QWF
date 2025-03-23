import Foundation
import Metal
import MetalKit
import os.lock
import simd

/// Thread-safe property wrapper using NSLock for efficient multi-threaded access
final class ThreadSafe<T> {
    private var value: T
    private let lock = NSLock()

    init(wrappedValue: T) {
        self.value = wrappedValue
    }

    var wrappedValue: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }
}

/// Renderer for 3D visualization of waveforms and quantum functions
class WaveformRenderer3D: NSObject, MTKViewDelegate {
    // MARK: - Type Definitions

    /// Complex number structure
    struct Complex {
        var real: Float
        var imag: Float
    }

    /// 3D vertex structure
    struct Vertex {
        var position: SIMD4<Float>
        var color: SIMD4<Float>
        var texCoord: SIMD2<Float>
    }

    /// Uniform structure for 3D rendering
    struct Uniforms {
        var viewMatrix: matrix_float4x4
        var projectionMatrix: matrix_float4x4
        var time: Float
        var colorScheme: UInt32
    }

    /// Quantum simulation parameters
    struct QuantumSimParams {
        var time: Float
        var hbar: Float
        var mass: Float
        var potentialHeight: Float
        var systemType: UInt32
        var energyLevel: UInt32
        var gridSize: UInt32
        var reserved: UInt32 = 0  // For alignment
        var domain: SIMD2<Float>  // min and max domain values
    }

    // MARK: - Metal Properties

    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState
    private var depthState: MTLDepthStencilState
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer
    private var waveComputePipeline: MTLComputePipelineState
    private var waveFunctionBuffer: MTLBuffer
    private var meshVertexBuffer: MTLBuffer
    private var probabilityBuffer: MTLBuffer

    // MARK: - Camera and Transformation

    private var viewMatrix = matrix_identity_float4x4
    private var projectionMatrix = matrix_identity_float4x4
    private var rotationAngle: Float = 0.0

    // MARK: - Visualization Parameters

    private var gridSize: Int = 512
    private var colorScheme: UInt32 = 0  // 0=Classic, 1=Thermal, 2=Rainbow, 3=Monochrome (from ShaderTypes.h ColorScheme enum)
    private var quantumParams = WaveformRenderer3D.QuantumSimParams(
        time: 0.0,
        hbar: 1.054571817e-34,
        mass: 9.1093837e-31,
        potentialHeight: 0.0,
        systemType: 0,
        energyLevel: 1,
        gridSize: 512,
        domain: SIMD2<Float>(-10e-9, 10e-9)
    )
    private var showWireframe: Bool = false
    private var surfaceSmoothing: Bool = true

    // Animation state
    private var time: Float = 0.0
    private var animating: Bool = false

    // Add flag to prevent concurrent updates
    private var meshUpdateLockObj = ThreadSafe<Bool>(wrappedValue: false)
    private var isUpdatingMesh: Bool {
        get { return meshUpdateLockObj.wrappedValue }
        set { meshUpdateLockObj.wrappedValue = newValue }
    }
    private var pendingParamUpdate:
        (systemType: UInt32, energyLevel: UInt32, mass: Float, potentialHeight: Float)?

    // MARK: - Initialization

    #if DEBUG
        private let enableLogging = true
    #else
        private let enableLogging = false
    #endif

    private func log(_ message: String) {
        if enableLogging {
            print("WaveformRenderer3D: \(message)")
        }
    }

    init(device: MTLDevice) {
        print("WaveformRenderer3D: Starting initialization")

        self.device = device

        // Create command queue with nil checking
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        self.commandQueue = commandQueue

        // Set up render pipeline with safer error handling
        guard let library = device.makeDefaultLibrary() else {
            fatalError(
                "Failed to create Metal library - check that .metal shader files are included in the target"
            )
        }

        // Get shader functions in one go to fail fast
        guard let vertexFunction = library.makeFunction(name: "vertexShader3D"),
            let fragmentFunction = library.makeFunction(name: "fragmentShader3D"),
            let computeFunction = library.makeFunction(name: "compute_quantum_wavefunction")
        else {
            fatalError("Failed to find required shader functions - check shader names")
        }

        // Create pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        // Create pipeline states directly
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            waveComputePipeline = try device.makeComputePipelineState(function: computeFunction)
        } catch {
            fatalError("Failed to create pipeline: \(error)")
        }

        // Create depth state
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            fatalError("Failed to create depth stencil state")
        }
        self.depthState = depthState

        // Create buffers with minimal size first
        guard
            let uniformBuffer = device.makeBuffer(
                length: MemoryLayout<WaveformRenderer3D.Uniforms>.stride,
                options: [.storageModeShared])
        else {
            fatalError("Failed to create uniform buffer")
        }
        self.uniformBuffer = uniformBuffer

        guard
            let waveFunctionBuffer = device.makeBuffer(
                length: gridSize * MemoryLayout<WaveformRenderer3D.Complex>.stride,
                options: [.storageModeShared])
        else {
            fatalError("Failed to create wave function buffer")
        }
        self.waveFunctionBuffer = waveFunctionBuffer

        guard
            let probabilityBuffer = device.makeBuffer(
                length: gridSize * MemoryLayout<Float>.stride,
                options: [.storageModeShared])
        else {
            fatalError("Failed to create probability buffer")
        }
        self.probabilityBuffer = probabilityBuffer

        // Create a smaller buffer initially - we'll expand if needed later
        guard
            let meshVertexBuffer = device.makeBuffer(
                length: gridSize * 6,
                options: [.storageModeShared])
        else {
            fatalError("Failed to create mesh vertex buffer")
        }
        self.meshVertexBuffer = meshVertexBuffer

        super.init()

        // Setup camera with basic values
        setupCamera()

        // Initial generation of data - don't wait for it to complete
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Initialize the compute operation without blocking
            self.initializeWaveFunction()

            DispatchQueue.main.async {
                print("WaveformRenderer3D: Initialization completed asynchronously")
            }
        }

        print(
            "WaveformRenderer3D: Base initialization complete, compute operations continuing in background"
        )
    }

    // MARK: - Public Methods

    /// Renders the 3D visualization to the provided texture
    func render(to texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let renderPassDescriptor = createRenderPassDescriptor(texture) else {
            return
        }

        // Create render command encoder
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor)
        else {
            return
        }

        // Set render state
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)

        // Set vertex buffers - verify they exist
        guard meshVertexBuffer.length > 0 else {
            renderEncoder.endEncoding()
            return
        }

        renderEncoder.setVertexBuffer(meshVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)

        // Set fragment buffer
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)

        // Make sure to update uniforms before drawing
        updateUniforms()

        // Use a safe vertex count
        let vertexCount = min(
            (gridSize - 1) * 6, meshVertexBuffer.length / MemoryLayout<Vertex>.stride)

        // Set wireframe mode if needed
        if showWireframe {
            renderEncoder.setTriangleFillMode(.lines)
        } else {
            renderEncoder.setTriangleFillMode(.fill)
        }

        // Draw primitives if we have vertices
        if vertexCount > 0 {
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        }

        // End encoding
        renderEncoder.endEncoding()
    }

    /// Updates the visualization with new quantum parameters
    func updateQuantumParams(
        systemType: UInt32, energyLevel: UInt32, mass: Float, potentialHeight: Float
    ) {
        log(
            "updateQuantumParams called with systemType: \(systemType), energyLevel: \(energyLevel)"
        )

        // Use atomic property directly - no need for queue sync
        if isUpdatingMesh {
            // Store parameters for later application
            pendingParamUpdate = (
                systemType: systemType,
                energyLevel: energyLevel,
                mass: mass,
                potentialHeight: potentialHeight
            )
            return
        }

        // Update parameters directly when not updating mesh
        quantumParams.systemType = systemType
        quantumParams.energyLevel = energyLevel
        quantumParams.mass = mass
        quantumParams.potentialHeight = potentialHeight

        // Trigger mesh update
        createMesh()
    }

    /// Sets the color scheme
    func setColorScheme(_ scheme: UInt32) {
        colorScheme = scheme
    }

    /// Toggles wireframe mode
    func toggleWireframe(_ enabled: Bool) {
        showWireframe = enabled
    }

    /// Toggles animation
    func setAnimating(_ animate: Bool) {
        animating = animate
    }

    /// Rotates the visualization by the given angle
    func rotate(byAngle angle: Float) {
        rotationAngle += angle
        updateViewMatrix()
    }

    /// Resets the camera to default position
    func resetCamera() {
        rotationAngle = 0.0
        setupCamera()
    }

    // MARK: - Private Methods

    private func setupCamera() {
        // Set up view matrix with better initial position to see waveform
        let eye = SIMD3<Float>(0, 1.5, 3)  // Closer and lower position
        let center = SIMD3<Float>(0, 0.5, 0)  // Look at center of waveform
        let up = SIMD3<Float>(0, 1, 0)

        viewMatrix = matrix_look_at_right_hand(eye, center, up)

        // Initial projection matrix (perspective)
        let aspect: Float = 16.0 / 9.0
        let fov: Float = 65.0 * (.pi / 180.0)
        let near: Float = 0.1
        let far: Float = 100.0

        projectionMatrix = matrix_perspective_right_hand(fov, aspect, near, far)

        // Add a slight initial rotation for better view
        rotationAngle = 0.3
        updateViewMatrix()
    }

    private func updateViewMatrix() {
        // Apply rotation
        var rotationMatrix = matrix_identity_float4x4
        rotationMatrix.columns.0 = SIMD4<Float>(cos(rotationAngle), 0, sin(rotationAngle), 0)
        rotationMatrix.columns.2 = SIMD4<Float>(-sin(rotationAngle), 0, cos(rotationAngle), 0)

        let updatedViewMatrix = matrix_multiply(viewMatrix, rotationMatrix)

        // Update uniform buffer
        let uniformContents = uniformBuffer.contents().bindMemory(
            to: WaveformRenderer3D.Uniforms.self, capacity: 1)
        uniformContents.pointee.viewMatrix = updatedViewMatrix
        uniformContents.pointee.projectionMatrix = projectionMatrix
        uniformContents.pointee.colorScheme = colorScheme
    }

    private func updateUniforms() {
        let uniformContents = uniformBuffer.contents().bindMemory(
            to: WaveformRenderer3D.Uniforms.self, capacity: 1)
        uniformContents.pointee.time = time
    }

    private func createRenderPassDescriptor(_ texture: MTLTexture) -> MTLRenderPassDescriptor? {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        // Create depth texture if needed
        let depthTexture = createDepthTexture(matching: texture)
        descriptor.depthAttachment.texture = depthTexture
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .dontCare
        descriptor.depthAttachment.clearDepth = 1.0

        return descriptor
    }

    private func createDepthTexture(matching texture: MTLTexture) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .private

        return device.makeTexture(descriptor: descriptor)
    }

    private func updateWaveFunction(time: Float) {
        // Update time parameter
        quantumParams.time = time

        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            isUpdatingMesh = false  // Reset flag in case of error
            return
        }

        // Create a compute command encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            isUpdatingMesh = false  // Reset flag in case of error
            return
        }

        // Set the compute pipeline state
        computeEncoder.setComputePipelineState(waveComputePipeline)

        // Create a buffer for the parameters
        let paramsSize = MemoryLayout<WaveformRenderer3D.QuantumSimParams>.stride
        guard
            let paramsBuffer = device.makeBuffer(
                bytes: &quantumParams, length: paramsSize, options: .storageModeShared)
        else {
            computeEncoder.endEncoding()
            isUpdatingMesh = false  // Reset flag in case of error
            return
        }

        // Set the buffers
        computeEncoder.setBuffer(waveFunctionBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 1)

        // Calculate grid and thread group sizes
        let gridSize = MTLSize(width: self.gridSize, height: 1, depth: 1)
        let threadGroupSize = MTLSize(
            width: min(self.gridSize, waveComputePipeline.maxTotalThreadsPerThreadgroup),
            height: 1,
            depth: 1
        )

        // Dispatch the compute kernel
        computeEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()

        // Add completion handler to reset the updating flag and process results
        commandBuffer.addCompletedHandler { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }

                // Process results and update mesh
                self.calculateProbabilityData()
                self.createMesh()

                // Always reset the flag at the end
                self.isUpdatingMesh = false
            }
        }

        // Commit the command buffer without waiting
        commandBuffer.commit()

        // Set a backup timer to ensure isUpdatingMesh gets reset even if the handler doesn't execute
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isUpdatingMesh else { return }

            // If still updating after 1 second, reset the flag
            print("WaveformRenderer3D: Forcing reset of isUpdatingMesh flag due to timeout")
            self.isUpdatingMesh = false
        }
    }

    // New method to handle initial wave function generation without blocking
    private func initializeWaveFunction() {
        // Create a simple initial state without waiting
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeEncoder = commandBuffer?.makeComputeCommandEncoder()

        // If we can't get these, just fail silently - we'll retry during rendering
        guard let encoder = computeEncoder else {
            print("Failed to create initial compute encoder - will retry later")
            return
        }

        // Set up compute parameters
        encoder.setComputePipelineState(waveComputePipeline)

        // Create a buffer for the parameters
        let paramsSize = MemoryLayout<WaveformRenderer3D.QuantumSimParams>.stride
        guard
            let paramsBuffer = device.makeBuffer(
                bytes: &quantumParams, length: paramsSize, options: .storageModeShared)
        else {
            encoder.endEncoding()
            return
        }

        // Set the buffers
        encoder.setBuffer(waveFunctionBuffer, offset: 0, index: 0)
        encoder.setBuffer(paramsBuffer, offset: 0, index: 1)

        // Calculate grid and thread group sizes
        let gridSize = MTLSize(width: self.gridSize, height: 1, depth: 1)
        let threadGroupSize = MTLSize(
            width: min(self.gridSize, waveComputePipeline.maxTotalThreadsPerThreadgroup),
            height: 1,
            depth: 1
        )

        // Dispatch the compute kernel
        encoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        // Don't wait - just commit and continue
        commandBuffer?.commit()
    }

    // MARK: - Mesh Creation Optimization

    // Reusable vertex array to avoid recreating arrays on each frame
    private var vertexCache: [Vertex] = []
    private var vertexCacheCapacity = 0
    private var lastMeshTime: Float = -1  // Track when mesh was last updated

    private func createMesh() {
        // Skip recreation if already in progress
        if isUpdatingMesh && lastMeshTime >= 0 {
            return
        }

        // Skip creation if we have existing mesh and time hasn't changed much
        if !vertexCache.isEmpty && abs(lastMeshTime - time) < 0.01 {
            return
        }

        // Update time parameter
        quantumParams.time = time

        // Get probability data safely - if empty, defer mesh creation
        let probabilityData = getProbabilityData()
        if probabilityData.isEmpty {
            return
        }

        // Calculate required vertex count
        let requiredVertices = (gridSize - 1) * 6

        // Ensure our mesh buffer is large enough
        let requiredBufferSize = requiredVertices * MemoryLayout<Vertex>.stride
        if meshVertexBuffer.length < requiredBufferSize {
            // Need to create a larger buffer
            if let newBuffer = device.makeBuffer(
                length: requiredBufferSize * 2, options: .storageModeShared)
            {
                meshVertexBuffer = newBuffer
            } else {
                print("Failed to resize mesh vertex buffer")
                return
            }
        }

        // Ensure our cache has enough capacity
        if vertexCacheCapacity < requiredVertices {
            vertexCache = [Vertex](
                repeating: Vertex(
                    position: SIMD4<Float>(0, 0, 0, 1),
                    color: SIMD4<Float>(0, 0, 0, 1),
                    texCoord: SIMD2<Float>(0, 0)),
                count: requiredVertices)
            vertexCacheCapacity = requiredVertices
        }

        // Create mesh using the cache array
        generateMeshVertices(into: &vertexCache, with: probabilityData)

        // Copy vertices to buffer if we have data
        let bufferPointer = meshVertexBuffer.contents().assumingMemoryBound(to: Vertex.self)
        memcpy(bufferPointer, vertexCache, requiredVertices * MemoryLayout<Vertex>.stride)

        // Update the last mesh time
        lastMeshTime = time

        // Handle any pending param updates
        if let pending = pendingParamUpdate {
            DispatchQueue.main.async {
                self.updateQuantumParams(
                    systemType: pending.systemType,
                    energyLevel: pending.energyLevel,
                    mass: pending.mass,
                    potentialHeight: pending.potentialHeight
                )
                self.pendingParamUpdate = nil
            }
        }
    }

    // Modify generateMeshVertices to take the probability data as a parameter
    private func generateMeshVertices(into vertices: inout [Vertex], with probabilityData: [Float])
    {
        // Scale for visualization
        let xScale: Float = 2.0 / Float(gridSize - 1)
        let heightScale: Float = 2.5

        // Safe bounds check
        let count = min(gridSize - 1, probabilityData.count - 1)

        // Generate vertices for each grid segment
        var vertexIndex = 0
        for i in 0..<count {
            let x1 = -1.0 + Float(i) * xScale
            let x2 = -1.0 + Float(i + 1) * xScale

            // Apply height from probability data
            let y1 = probabilityData[i] * heightScale
            let y2 = probabilityData[i + 1] * heightScale

            // Use vibrant colors
            let color1 = colorForHeight(y1)
            let color2 = colorForHeight(y2)

            // First triangle
            vertices[vertexIndex] = Vertex(
                position: SIMD4<Float>(x1, y1, 0, 1),
                color: color1,
                texCoord: SIMD2<Float>(Float(i) / Float(gridSize - 1), 0)
            )
            vertexIndex += 1

            vertices[vertexIndex] = Vertex(
                position: SIMD4<Float>(x2, 0, 0, 1),
                color: SIMD4<Float>(0.1, 0.1, 0.7, 1),
                texCoord: SIMD2<Float>(Float(i + 1) / Float(gridSize - 1), 0.5)
            )
            vertexIndex += 1

            vertices[vertexIndex] = Vertex(
                position: SIMD4<Float>(x2, y2, 0, 1),
                color: color2,
                texCoord: SIMD2<Float>(Float(i + 1) / Float(gridSize - 1), 0)
            )
            vertexIndex += 1

            // Second triangle
            vertices[vertexIndex] = Vertex(
                position: SIMD4<Float>(x1, y1, 0, 1),
                color: color1,
                texCoord: SIMD2<Float>(Float(i) / Float(gridSize - 1), 0)
            )
            vertexIndex += 1

            vertices[vertexIndex] = Vertex(
                position: SIMD4<Float>(x1, 0, 0, 1),
                color: SIMD4<Float>(0.1, 0.1, 0.7, 1),
                texCoord: SIMD2<Float>(Float(i) / Float(gridSize - 1), 0.5)
            )
            vertexIndex += 1

            vertices[vertexIndex] = Vertex(
                position: SIMD4<Float>(x2, 0, 0, 1),
                color: SIMD4<Float>(0.1, 0.1, 0.7, 1),  // More vibrant base color
                texCoord: SIMD2<Float>(Float(i + 1) / Float(gridSize - 1), 0.5)
            )
            vertexIndex += 1
        }
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("DEBUG: mtkView:drawableSizeWillChange: - Start with size \(size)")

        // Check view configuration
        print(
            "DEBUG: mtkView:drawableSizeWillChange: - View pixel format: \(view.colorPixelFormat.rawValue)"
        )
        print(
            "DEBUG: mtkView:drawableSizeWillChange: - View depth format: \(view.depthStencilPixelFormat.rawValue)"
        )
        print("DEBUG: mtkView:drawableSizeWillChange: - View sample count: \(view.sampleCount)")

        // Update aspect ratio for projection matrix
        let aspect: Float
        if size.width > 0 && size.height > 0 {
            aspect = Float(size.width / size.height)
        } else {
            aspect = 1.0  // Default to square if dimensions are invalid
            log("Warning: Invalid drawable size detected: \(size)")
        }

        let fov: Float = 65.0 * (.pi / 180.0)
        let near: Float = 0.1
        let far: Float = 100.0

        log("Updating projection matrix with aspect \(aspect)")
        projectionMatrix = matrix_perspective_right_hand(fov, aspect, near, far)
        log("Updating view matrix")
        updateViewMatrix()
        print("DEBUG: mtkView:drawableSizeWillChange: - Complete")
    }

    func draw(in view: MTKView) {
        // Simplified logging for performance
        #if DEBUG
            print("DEBUG: draw(in:)")
        #endif

        guard let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            view.currentRenderPassDescriptor != nil
        else {
            return
        }

        // Update time if animating and not already updating
        if animating && !isUpdatingMesh {
            isUpdatingMesh = true
            time += 0.01
            updateWaveFunctionAsync(time: time)
            // Note: isUpdatingMesh will be reset in the completion handler
        }

        // Render to the current drawable
        render(to: drawable.texture, commandBuffer: commandBuffer)

        // Present drawable
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Memory Management

    // Add a method to clean up resources and prevent memory leaks
    func cleanupResources() {
        print("Cleaning up WaveformRenderer3D resources")

        isUpdatingMesh = false
    }

    deinit {
        cleanupResources()
        print("WaveformRenderer3D deallocated")
    }

    // Optimize buffer creation and reuse
    private func createOrReuseBuffer(
        existing: inout MTLBuffer?,
        length: Int,
        label: String
    ) -> MTLBuffer {
        // If buffer exists with sufficient size, reuse it
        if let buffer = existing, buffer.length >= length {
            return buffer
        }

        // Otherwise create a new buffer with some extra capacity for future growth
        let newLength = Int(Double(length) * 1.5)  // Add 50% extra capacity
        let newBuffer = device.makeBuffer(length: newLength, options: .storageModeShared)!
        newBuffer.label = label
        existing = newBuffer
        return newBuffer
    }

    // MARK: - Helper Functions for Visualization

    /// Maps height value to a color based on current color scheme
    private func colorForHeight(_ height: Float) -> SIMD4<Float> {
        switch colorScheme {
        case 0:  // Classic
            return SIMD4<Float>(0.0, height, 1.0 - height, 1.0)
        case 1:  // Thermal
            return SIMD4<Float>(
                min(height * 2.0, 1.0), min(height, 1.0), max(1.0 - height * 2.0, 0.0), 1.0)
        case 2:  // Rainbow
            let h = max(0.0, min(1.0, height))
            if h < 0.25 {
                return SIMD4<Float>(0.0, h * 4.0, 1.0, 1.0)
            } else if h < 0.5 {
                return SIMD4<Float>(0.0, 1.0, 1.0 - (h - 0.25) * 4.0, 1.0)
            } else if h < 0.75 {
                return SIMD4<Float>((h - 0.5) * 4.0, 1.0, 0.0, 1.0)
            } else {
                return SIMD4<Float>(1.0, 1.0 - (h - 0.75) * 4.0, 0.0, 1.0)
            }
        case 3:  // Monochrome
            return SIMD4<Float>(height, height, height, 1.0)
        default:
            return SIMD4<Float>(0.0, height, 1.0 - height, 1.0)
        }
    }

    /// Retrieves probability data from wave function buffer
    private func getProbabilityData() -> [Float] {
        var probData = [Float](repeating: 0.0, count: gridSize)

        // Access wave function buffer directly instead of using conditional binding
        let waveData = waveFunctionBuffer.contents().assumingMemoryBound(to: Complex.self)

        // Calculate probability density (|ψ|²)
        for i in 0..<gridSize {
            let psi = waveData[i]
            probData[i] = psi.real * psi.real + psi.imag * psi.imag
        }

        // Find maximum probability for normalization
        if let maxProb = probData.max(), maxProb > 0 {
            for i in 0..<gridSize {
                probData[i] /= maxProb
            }
        }

        return probData
    }

    private func calculateProbabilityData() {
        // Access wave function buffer directly
        let waveData = waveFunctionBuffer.contents().bindMemory(
            to: Complex.self, capacity: gridSize)
        let probDestination = probabilityBuffer.contents().bindMemory(
            to: Float.self, capacity: gridSize)

        // Calculate probability density (|ψ|²) for each point
        var maxProb: Float = 0.0

        for i in 0..<gridSize {
            let psi = waveData[i]
            let probability = psi.real * psi.real + psi.imag * psi.imag
            probDestination[i] = probability

            // Track maximum for normalization
            if probability > maxProb {
                maxProb = probability
            }
        }

        // Normalize probabilities if we found a non-zero maximum
        if maxProb > 0 {
            for i in 0..<gridSize {
                probDestination[i] /= maxProb
            }
        }

        log("Probability data calculated with max value: \(maxProb)")
    }

    // Add async version that sets isUpdatingMesh first
    private func updateWaveFunctionAsync(time: Float) {
        isUpdatingMesh = true
        updateWaveFunction(time: time)
    }
}

// MARK: - Matrix Mathematics

/// Creates a right-handed look-at matrix
func matrix_look_at_right_hand(_ eye: SIMD3<Float>, _ center: SIMD3<Float>, _ up: SIMD3<Float>)
    -> matrix_float4x4
{
    let z = normalize(eye - center)
    let x = normalize(cross(up, z))
    let y = cross(z, x)

    let t = SIMD3<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye))

    return matrix_float4x4(
        SIMD4<Float>(x.x, y.x, z.x, 0),
        SIMD4<Float>(x.y, y.y, z.y, 0),
        SIMD4<Float>(x.z, y.z, z.z, 0),
        SIMD4<Float>(t.x, t.y, t.z, 1)
    )
}

/// Creates a right-handed perspective projection matrix
func matrix_perspective_right_hand(
    _ fovRadians: Float, _ aspect: Float, _ nearZ: Float, _ farZ: Float
) -> matrix_float4x4 {
    let ys = 1 / tanf(fovRadians * 0.5)
    let xs = ys / aspect
    let zs = farZ / (nearZ - farZ)

    return matrix_float4x4(
        SIMD4<Float>(xs, 0, 0, 0),
        SIMD4<Float>(0, ys, 0, 0),
        SIMD4<Float>(0, 0, zs, -1),
        SIMD4<Float>(0, 0, nearZ * zs, 0)
    )
}
