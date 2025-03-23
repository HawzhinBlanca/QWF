//
//  AllShaders.metal
//  QwantumWaveform

#include <metal_stdlib>
using namespace metal;

// This is the main shader file that includes all other shader files
// to ensure they're compiled together and available as a single library

// Import common types and utils in the correct order to ensure dependencies are resolved
#include "ShaderTypes.h"
#include "ShaderUtils.h"
#include "ComplexUtils.h"
#include "QuantumWaveFunctions.h"

// Ensure ShaderUtils.h is properly included with conditional compilation
#if __METAL_VERSION__
// ShaderUtils.h is directly included in Metal context
#include "ShaderUtils.h"
#endif


// Basic vertex shader implementation
vertex float4 basicVertex(uint vertexID [[vertex_id]],
                         constant float3* positions [[buffer(0)]]) {
    return float4(positions[vertexID], 1.0);
}

// Basic fragment shader implementation for testing
fragment float4 basicFragment(float4 position [[position]],
                            constant float& time [[buffer(1)]]) {
    float2 uv = position.xy / float2(800.0, 600.0); // Normalized coordinates
    
    // Create a colorful pattern
    float3 color = float3(
        sin(uv.x * 10.0 + time) * 0.5 + 0.5,
        cos(uv.y * 8.0 + time * 0.7) * 0.5 + 0.5,
        sin((uv.x + uv.y) * 6.0 + time * 1.3) * 0.5 + 0.5
    );
    
    return float4(color, 1.0);
}

// Debug grid fragment shader
fragment float4 debugGridFragment(float4 position [[position]],
                                constant float& time [[buffer(1)]]) {
    float2 uv = position.xy / float2(800.0, 600.0) * 2.0 - 1.0;
    
    // Create a grid pattern
    float2 grid = abs(fract(uv * 10.0) - 0.5);
    float lines = min(grid.x, grid.y);
    lines = smoothstep(0.05, 0.0, lines);
    
    // Animate a circle
    float circle = length(uv - float2(sin(time) * 0.5, cos(time * 0.7) * 0.5)) - 0.2;
    circle = smoothstep(0.01, 0.0, circle);
    
    // Combine patterns
    float3 color = mix(
        float3(0.1, 0.1, 0.2),
        float3(0.9, 0.6, 0.3),
        lines + circle
    );
    
    return float4(color, 1.0);
}

// ================ IMPORT OTHER SHADERS ================
// This section would typically include the rest of your shader code or appropriate #include directives
// For a full implementation, you would include or implement all shaders here

// Note: For a complete implementation, you would need to:
// 1. Include other shader functions from your existing files
// 2. Or use a build system that concatenates all .metal files together

// Forward declarations of external functions - these should match your existing shader files
//vertex float4 waveform3DVertex(uint vertexID [[vertex_id]], 
//                             constant Vertex* vertices [[buffer(VertexBuffer)]],
//                             constant Uniforms& uniforms [[buffer(UniformBuffer)]]);
//
//fragment float4 waveform3DFragment(float4 position [[position]],
//                                 float2 texCoord [[stage_in]],
//                                 constant Uniforms& uniforms [[buffer(UniformBuffer)]]);
//
//vertex float4 quantumWaveVertex(uint vertexID [[vertex_id]], 
//                              constant Vertex* vertices [[buffer(VertexBuffer)]],
//                              constant Quantum3DUniforms& uniforms [[buffer(UniformBuffer)]]);
//
//fragment float4 quantumWaveFragment(float4 position [[position]],
//                                  float2 texCoord [[stage_in]],
//                                  constant Quantum3DUniforms& uniforms [[buffer(UniformBuffer)]]);

// Other shader function declarations would go here 

// MARK: - Vertex Shader

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(const VertexIn vertexIn [[stage_in]]) {
    VertexOut out;
    out.position = float4(vertexIn.position, 1.0);
    out.texCoord = vertexIn.texCoord;
    return out;
}

// MARK: - Fragment Shader

struct FragmentUniforms {
    float time;
    float amplitude;
    float frequency;
    int colorScheme;
    int waveFunction;
    int is3D;
};

// Basic color fragment shader
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant FragmentUniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    
    float t = uniforms.time;
//    float amp = uniforms.amplitude;
//    float freq = uniforms.frequency;
    
    // Simple visualization: rainbow pattern
    float3 color = float3(0.5 + 0.5 * sin(t + uv.x * 3.0),
                         0.5 + 0.5 * sin(t * 0.7 + uv.y * 4.0),
                         0.5 + 0.5 * sin(t * 1.3 + length(uv) * 5.0));
    
    return float4(color, 1.0);
}

// 2D quantum waveform visualization
fragment float4 quantumWaveform2D(VertexOut in [[stage_in]],
                                 constant FragmentUniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float x = uv.x * 10.0; // Scale for visualization
    
    ComplexType waveValue;
    float t = uniforms.time;
    float amp = uniforms.amplitude;
    float freq = uniforms.frequency;
    
    // Constants for quantum mechanics
    float hbar = 1.0; // Normalized Planck's constant
    float mass = 1.0; // Normalized mass
    
    // Variables for phase color calculation
    float phase = 0.0;
    
    // Calculate wave function
    switch (uniforms.waveFunction) {
        case 0: // Free particle
            waveValue = free_particle(x, freq, 0.5, t, mass, hbar);
            break;
        case 1: // Infinite well
            waveValue = infinite_well(x + 5.0, 10.0, int(freq), t, mass, hbar);
            break;
        case 2: // Harmonic oscillator
            waveValue = harmonic_oscillator(x, int(freq), 1.0, t, mass, hbar);
            break;
        case 3: // Hydrogen atom (radial part only, 1D visualization)
            waveValue = hydrogen_atom(abs(x), 2, 0, t, hbar);
            break;
        default:
            waveValue = free_particle(x, freq, 0.5, t, mass, hbar);
    }
    
    // Calculate probability density
    float probability = waveValue.real * waveValue.real + waveValue.imag * waveValue.imag;
    probability *= amp * 5.0; // Scale for visibility
    
    // Check if point is within the waveform
    bool isWavePoint = (uv.y > -probability && uv.y < probability);
    
    // Choose color based on settings
    float3 color;
    if (isWavePoint) {
        switch (uniforms.colorScheme) {
            case 0: // Blue
                color = float3(0.0, 0.5, 1.0);
                break;
            case 1: // Green
                color = float3(0.0, 1.0, 0.5);
                break;
            case 2: // Rainbow based on position
                color = float3(0.5 + 0.5 * sin(x),
                              0.5 + 0.5 * sin(x + 2.0),
                              0.5 + 0.5 * sin(x + 4.0));
                break;
            case 3: // Phase coloring
                phase = atan2(waveValue.imag, waveValue.real);
                color = float3(0.5 + 0.5 * sin(phase),
                              0.5 + 0.5 * sin(phase + 2.0),
                              0.5 + 0.5 * sin(phase + 4.0));
                break;
            default:
                color = float3(0.0, 0.5, 1.0);
        }
    } else {
        // Background with grid
        float grid = (fmod(abs(uv.x * 10.0), 1.0) < 0.02 || fmod(abs(uv.y * 10.0), 1.0) < 0.02) ? 0.2 : 0.0;
        color = float3(grid);
    }
    
    return float4(color, 1.0);
}

// 3D quantum waveform visualization
fragment float4 quantumWaveform3D(VertexOut in [[stage_in]],
                                 constant FragmentUniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    
    // Create a 2D grid for visualization
    float x = uv.x * 10.0;
    float y = uv.y * 10.0;
    float r = sqrt(x*x + y*y);
    
    ComplexType waveValue;
    float t = uniforms.time;
    float amp = uniforms.amplitude;
    float freq = uniforms.frequency;
    
    // Pre-declare variables for the switch statement
    float xWell = 0.0, yWell = 0.0;
    ComplexType xPart, yPart;
    
    // Constants for quantum mechanics
    float hbar = 1.0; // Normalized Planck's constant
    float mass = 1.0; // Normalized mass
    
    // Phase for color calculation
    float phase = 0.0;
    
    // Calculate wave function based on selected type
    switch (uniforms.waveFunction) {
        case 0: // Free particle (2D circular)
            waveValue = free_particle(r, freq, 0.5, t, mass, hbar);
            break;
        case 1: // Infinite well (2D)
            // Convert to coordinates within a square well
            xWell = x + 5.0;
            yWell = y + 5.0;
            if (xWell < 0.0 || xWell > 10.0 || yWell < 0.0 || yWell > 10.0) {
                waveValue.real = 0.0;
                waveValue.imag = 0.0;
            } else {
                xPart = infinite_well(xWell, 10.0, int(freq), t, mass, hbar);
                yPart = infinite_well(yWell, 10.0, int(freq), t, mass, hbar);
                waveValue.real = xPart.real * yPart.real - xPart.imag * yPart.imag;
                waveValue.imag = xPart.real * yPart.imag + xPart.imag * yPart.real;
            }
            break;
        case 2: // Harmonic oscillator (2D)
            xPart = harmonic_oscillator(x, int(freq), 1.0, t, mass, hbar);
            yPart = harmonic_oscillator(y, int(freq), 1.0, t, mass, hbar);
            waveValue.real = xPart.real * yPart.real - xPart.imag * yPart.imag;
            waveValue.imag = xPart.real * yPart.imag + xPart.imag * yPart.real;
            break;
        case 3: // Hydrogen atom (spherical)
            waveValue = hydrogen_atom(r, 2, 0, t, hbar);
            break;
        default:
            waveValue = free_particle(r, freq, 0.5, t, mass, hbar);
    }
    
    // Calculate probability density
    float probability = waveValue.real * waveValue.real + waveValue.imag * waveValue.imag;
    probability *= amp; // Scale for visibility
    
    // Display as a heatmap
    float3 color;
    
    switch (uniforms.colorScheme) {
        case 0: // Blue intensity
            color = float3(0.0, 0.0, probability);
            break;
        case 1: // Green intensity
            color = float3(0.0, probability, 0.0);
            break;
        case 2: // Heatmap (blue to red)
            color = float3(probability, probability * (1.0 - probability), 1.0 - probability);
            break;
        case 3: // Phase coloring with probability intensity
            phase = atan2(waveValue.imag, waveValue.real);
            color = float3(0.5 + 0.5 * sin(phase),
                         0.5 + 0.5 * sin(phase + 2.0),
                         0.5 + 0.5 * sin(phase + 4.0)) * probability;
            break;
        default:
            color = float3(0.0, 0.0, probability);
    }
    
    // Add grid
    float grid = (fmod(abs(x), 1.0) < 0.02 || fmod(abs(y), 1.0) < 0.02) ? 0.2 : 0.0;
    color += float3(grid);
    
    return float4(color, 1.0);
} 
