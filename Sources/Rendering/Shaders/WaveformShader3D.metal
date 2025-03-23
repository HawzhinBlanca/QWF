#include <metal_stdlib>
using namespace metal;

// Import shared definitions and utilities
#import "ShaderTypes.h"
#import "ShaderUtils.h"
#import "ComplexUtils.h"

// Define the RasterizerData structure for vertex shader output
struct RasterizerData {
    float4 position [[position]];
    float2 texCoord;
    float3 normal;
    float height;
};

// MARK: - Vertex Shader

// Vertex shader for 3D quantum visualization
vertex RasterizerData vertex_waveform_3d(uint vertexID [[vertex_id]],
                                        constant Vertex *vertices [[buffer(VertexBuffer)]],
                                        constant Quantum3DUniforms &uniforms [[buffer(UniformBuffer)]]) {
    RasterizerData out;
    
    // Get the current vertex
    Vertex vert = vertices[vertexID];
    
    // Calculate position with model-view-projection transform
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(vert.position, 1.0);
    out.texCoord = vert.texCoord;
    
    // Calculate world normal for lighting
    float3 normal = normalize((uniforms.modelViewMatrix * float4(vert.normal, 0.0)).xyz);
    out.normal = normal;
    
    // Pass the raw height for color mapping
    out.height = vert.position.y;
    
    return out;
}

// MARK: - Fragment Shader

// Fragment shader for 3D quantum visualization
fragment float4 fragment_waveform_3d(RasterizerData in [[stage_in]],
                                    constant Quantum3DUniforms &uniforms [[buffer(UniformBuffer)]]) {
    // Calculate lighting
    float3 lightPosition = uniforms.lightPosition;
    float3 normalizedNormal = normalize(in.normal);
    float3 lightVector = normalize(lightPosition);
    
    // Diffuse lighting
    float diffuse = max(0.0, dot(normalizedNormal, lightVector));
    
    // Ambient lighting
    float ambient = 0.2;
    
    // Color based on visualization type
    float4 color;
    
    switch (uniforms.visualizationType) {
        case QuantumVisualizationProbability:
            // Map from height to probability color (blue -> red)
            color = float4(in.height, 0.2, 1.0 - in.height, 1.0);
            break;
            
        case QuantumVisualizationRealPart:
            // Real part goes from blue (negative) to red (positive)
            color = in.height > 0 ? 
                float4(in.height, 0.0, 0.0, 1.0) : 
                float4(0.0, 0.0, -in.height, 1.0);
            break;
            
        case QuantumVisualizationImaginaryPart:
            // Imaginary part goes from green (negative) to purple (positive)
            color = in.height > 0 ? 
                float4(0.5, 0.0, 0.5, 1.0) * in.height : 
                float4(0.0, -in.height, 0.0, 1.0);
            break;
            
        case QuantumVisualizationPhase:
            // Phase uses HSV color wheel
            color = float4(hsv2rgb(in.height * 2.0 * M_PI_F, 1.0, 1.0), 1.0);
            break;
            
        default:
            // Default grayscale based on height
            color = float4(in.height, in.height, in.height, 1.0);
    }
    
    // Apply lighting
    float3 litColor = color.rgb * (ambient + diffuse);
    
    // Apply time-based effects if animating
    if (uniforms.time > 0.0) {
        // Subtle pulsing effect
        float pulse = 0.05 * sin(uniforms.time * 2.0);
        litColor += pulse;
    }
    
    return float4(litColor, color.a);
}
