// Note: This file does not include internal implementations to avoid redefinitions
// It relies on functions defined in ShaderUtils.h and ComplexUtils.h

#include <metal_stdlib>
using namespace metal;

// Import shared types and utility functions
#import "ShaderTypes.h"
#import "ShaderUtils.h"
#import "ComplexUtils.h"

// Vertex output structure
struct VertexOutput {
    float4 position [[position]];
    float2 texCoord;
    float amplitude;
};

// Vertex input structure
struct VertexInput {
    float2 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
};

// Vertex shader for quantum visualization
vertex VertexOutput quantum_vertex_shader(VertexInput in [[stage_in]],
                                        constant Uniforms &uniforms [[buffer(UniformBuffer)]]) {
    VertexOutput out;
    
    // Apply projection and model-view transforms
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    
    // Calculate amplitude based on position
    out.amplitude = in.position.y;
    
    return out;
}

// Fragment shader for quantum visualization
fragment float4 quantum_fragment_shader(VertexOutput in [[stage_in]],
                                        constant Uniforms &uniforms [[buffer(UniformBuffer)]]) {
    // Determine color based on visualization type, which would be stored in uniforms
    float4 color;
    
    // Simple color gradient based on amplitude and time
    float t = uniforms.time * 0.5;
    float wave = sin(in.texCoord.x * 10.0 + t) * 0.5 + 0.5;
    float norm = (in.amplitude + 1.0) * 0.5; // Normalize amplitude to 0-1 range
    
    // Quantum visualization color schemes - can be extended based on visualization needs
    color = float4(norm, wave, 1.0 - norm, 1.0);
    
    // Apply time-based effects
    float pulse = 0.1 * sin(uniforms.time);
    color.rgb += pulse;
    
    return color;
}

// Basic waveform visualization fragment shader
fragment float4 waveform_fragment_shader(VertexOutput in [[stage_in]],
                                       constant Uniforms &uniforms [[buffer(UniformBuffer)]]) {
    // Basic 2D waveform visualization
    float4 color;
    
    // Get normalized coordinates
    float2 uv = in.texCoord;
    
    // Simple waveform animation
    float frequency = 10.0;
    float amplitude = 0.5;
    float time = uniforms.time;
    
    float wave = sin(uv.x * frequency + time) * amplitude;
    
    // Distance from current point to wave
    float dist = abs(uv.y - 0.5 - wave * 0.5);
    
    // Create a line with smoothed edges
    float line = smoothstep(0.01, 0.0, dist);
    
    // Background grid
    float grid = max(
        step(0.98, fract(uv.x * 10.0)),
        step(0.98, fract(uv.y * 10.0))
    ) * 0.1;
    
    // Combine line and grid
    color = float4(line + grid, line * 0.5 + grid, line * 0.2 + grid, 1.0);
    
    return color;
}

// Quantum 3D visualization fragment shader
fragment float4 quantum_3d_fragment_shader(VertexOutput in [[stage_in]],
                                         constant Uniforms &uniforms [[buffer(UniformBuffer)]]) {
    // 3D quantum visualization with lighting effects
    float3 normalizedPosition = float3(in.texCoord * 2.0 - 1.0, 0.0);
    
    // Generate a dynamic height field based on quantum state
    float time = uniforms.time * 0.5;
    float x = normalizedPosition.x;
    float y = normalizedPosition.y;
    float radius = sqrt(x*x + y*y);
    
    // Simulate quantum wave function amplitude
    float n = 3.0; // Energy level
    float wave = sin(n * 3.14159 * radius - time) * exp(-radius * 2.0);
    
    // Apply color based on wave value
    float4 color;
    
    if (wave > 0.0) {
        // Positive amplitude: red to yellow
        color = float4(1.0, wave * 2.0, 0.0, 1.0);
    } else {
        // Negative amplitude: blue to cyan
        color = float4(0.0, abs(wave) * 2.0, 1.0, 1.0);
    }
    
    // Simple lighting calculation
    float3 lightDir = normalize(float3(0.5, 0.5, 1.0));
    float3 normal = normalize(float3(
        sin(time) * 0.2,
        cos(time) * 0.2, 
        1.0
    ));
    
    float diffuse = max(0.0, dot(normal, lightDir));
    float ambient = 0.3;
    
    color.rgb *= (ambient + diffuse * (1.0 - ambient));
    
    return color;
}
