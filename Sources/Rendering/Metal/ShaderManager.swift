import Foundation
import Metal
import MetalKit

/// Error types for shader operations
enum ShaderError: Error {
    case libraryNotFound
    case functionNotFound(String)
    case pipelineCreationFailed
    case deviceNotSupported
}

/// ShaderManager provides centralized access to Metal shaders
/// and helps manage the shader loading process
class ShaderManager {
    /// Shared instance for singleton access
    static let shared = ShaderManager()

    /// Metal device
    private(set) var device: MTLDevice?

    /// Default Metal library
    private(set) var defaultLibrary: MTLLibrary?

    /// Cache for shader functions
    private var functionCache: [String: MTLFunction] = [:]

    /// Cache for render pipeline states
    private var pipelineCache: [String: MTLRenderPipelineState] = [:]

    /// Initialization loads the Metal device and default library
    private init() {
        self.device = MTLCreateSystemDefaultDevice()
        if let device = device {
            do {
                // First try the default library (compiled with the app)
                defaultLibrary = try device.makeDefaultLibrary(bundle: Bundle.main)
                print("📱 Loaded default Metal library")
            } catch {
                print("⚠️ Warning: Could not load default Metal library: \(error)")

                // Second, try finding the library in resources
                if let libraryURL = Bundle.main.url(
                    forResource: "default", withExtension: "metallib")
                {
                    do {
                        defaultLibrary = try device.makeLibrary(URL: libraryURL)
                        print("📱 Loaded Metal library from resources")
                    } catch {
                        print("❌ Error: Failed to load Metal library from resources: \(error)")
                    }
                }
            }
        } else {
            print("❌ Error: Metal is not supported on this device")
        }
    }

    /// Initialize with a Metal device
    func initialize(with device: MTLDevice) {
        self.device = device
        loadLibrary()
    }

    /// Load the Metal library
    private func loadLibrary() {
        guard let device = device else {
            print("❌ Cannot load library: No Metal device set")
            return
        }

        // Try to load from the compiled metallib file
        let metalLibURL = Bundle.main.url(
            forResource: "default", withExtension: "metallib", subdirectory: "Resources/Shaders")

        if let metalLibURL = metalLibURL {
            print("📚 Found Metal library at: \(metalLibURL.path)")
            do {
                defaultLibrary = try device.makeLibrary(URL: metalLibURL)
                print("✅ Successfully loaded Metal library from file")
            } catch {
                print(
                    "⚠️ Failed to load Metal library from file: \(error). Falling back to default.")
                defaultLibrary = device.makeDefaultLibrary()
            }
        } else {
            print("⚠️ Metal library file not found. Falling back to default.")
            defaultLibrary = device.makeDefaultLibrary()
        }

        if defaultLibrary == nil {
            print("❌ Failed to create Metal library.")
        }
    }

    /// Get a function from the Metal library
    /// - Parameter name: Name of the shader function
    /// - Returns: MTLFunction if found, nil otherwise
    func function(named name: String) -> MTLFunction? {
        // Check cache first
        if let cachedFunction = functionCache[name] {
            return cachedFunction
        }

        // Ensure library is available
        guard let library = defaultLibrary else {
            print("❌ Library not found")
            return nil
        }

        // Get the function
        guard let function = library.makeFunction(name: name) else {
            print("❌ Function not found: \(name)")
            return nil
        }

        // Cache the function
        functionCache[name] = function

        return function
    }

    /// Create a render pipeline state for vertex and fragment functions
    /// - Parameters:
    ///   - vertexFunction: Name of the vertex function
    ///   - fragmentFunction: Name of the fragment function
    ///   - pixelFormat: Pixel format of the render target
    ///   - vertexDescriptor: Optional vertex descriptor
    /// - Returns: MTLRenderPipelineState or nil if creation fails
    func createRenderPipelineState(
        vertexFunction: String,
        fragmentFunction: String,
        pixelFormat: MTLPixelFormat = .bgra8Unorm,
        vertexDescriptor: MTLVertexDescriptor? = nil
    ) -> MTLRenderPipelineState? {
        // Create a cache key
        let cacheKey = "\(vertexFunction)_\(fragmentFunction)_\(pixelFormat.rawValue)"

        // Check cache first
        if let cachedPipeline = pipelineCache[cacheKey] {
            return cachedPipeline
        }

        // Get functions
        guard let vertexFunc = function(named: vertexFunction),
            let fragmentFunc = function(named: fragmentFunction)
        else {
            print("❌ Error: Could not find shader functions")
            return nil
        }

        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

        // Set vertex descriptor if provided
        if let vertexDesc = vertexDescriptor {
            pipelineDescriptor.vertexDescriptor = vertexDesc
        }

        // Create pipeline state
        guard let device = self.device else {
            print("❌ Error: No Metal device available")
            return nil
        }

        do {
            let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

            // Cache the pipeline state
            pipelineCache[cacheKey] = pipelineState

            return pipelineState
        } catch {
            print("❌ Error: Failed to create render pipeline state: \(error)")
            return nil
        }
    }

    /// List all available shader functions
    /// - Returns: Array of function names
    func listAllFunctions() -> [String] {
        guard let library = defaultLibrary else { return [] }
        return library.functionNames
    }

    /// Check if a shader function exists
    /// - Parameter name: Function name to check
    /// - Returns: True if the function exists
    func hasFunction(named name: String) -> Bool {
        return function(named: name) != nil
    }

    /// Clear all caches
    func clearCaches() {
        functionCache.removeAll()
        pipelineCache.removeAll()
    }

    /// Create a compute pipeline state
    func createComputePipelineState(function: String) -> MTLComputePipelineState? {
        guard let device = device,
            let computeFunc = self.function(named: function)
        else {
            print("❌ Cannot create compute pipeline state: Missing device or function")
            return nil
        }

        do {
            let pipelineState = try device.makeComputePipelineState(function: computeFunc)
            print("✅ Successfully created compute pipeline state with function: \(function)")
            return pipelineState
        } catch {
            print("❌ Failed to create compute pipeline state: \(error)")
            return nil
        }
    }
}

/// Extension with convenience methods for common shader function names
extension ShaderManager {
    /// Get the basic vertex function
    func basicVertexFunction() -> MTLFunction? {
        return function(named: "basicVertex")
    }

    /// Get the basic fragment function
    func basicFragmentFunction() -> MTLFunction? {
        return function(named: "basicFragment")
    }

    /// Get the debug grid fragment function
    func debugGridFunction() -> MTLFunction? {
        return function(named: "debugGridFragment")
    }

    /// Get the 2D waveform fragment function
    func waveform2DFunction() -> MTLFunction? {
        return function(named: "waveform2DFragment")
    }

    /// Get the 3D waveform vertex function
    func waveform3DVertexFunction() -> MTLFunction? {
        return function(named: "waveform3DVertex")
    }

    /// Get the 3D waveform fragment function
    func waveform3DFragmentFunction() -> MTLFunction? {
        return function(named: "waveform3DFragment")
    }

    /// Get the quantum wave vertex function
    func quantumWaveVertexFunction() -> MTLFunction? {
        return function(named: "quantumWaveVertex")
    }

    /// Get the quantum wave fragment function
    func quantumWaveFragmentFunction() -> MTLFunction? {
        return function(named: "quantumWaveFragment")
    }

    /// Get the quantum compute function
    func quantumComputeFunction() -> MTLFunction? {
        return function(named: "quantumCompute")
    }
}
