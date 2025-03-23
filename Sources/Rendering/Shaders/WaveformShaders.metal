#include <metal_stdlib>
using namespace metal;

// Uniform structure passed from Swift
struct WaveformUniforms {
    float2 viewportSize;
    float devicePixelRatio;
};

// Vertex shader output for waveform/spectrum
struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// Waveform vertex shader
vertex VertexOut waveformVertex(
    const device float* vertices [[buffer(0)]],
    const device WaveformUniforms& uniforms [[buffer(1)]],
    uint vertexID [[vertex_id]]
) {
    VertexOut out;
    
    // Get the y value from the buffer (waveform amplitude)
    float amplitude = vertices[vertexID];
    
    // Calculate normalized x position based on vertex ID
    float x = float(vertexID) / 1024.0; // Assuming 1024 samples, adjust as needed
    
    // Position in clip space
    float2 pixelSpacePosition = float2(x * uniforms.viewportSize.x, 
                                     (amplitude * 0.5 + 0.5) * uniforms.viewportSize.y);
    
    // Apply device pixel ratio for high DPI displays
    pixelSpacePosition *= uniforms.devicePixelRatio;
    
    // Convert to normalized device coordinates (-1 to 1)
    out.position = float4((pixelSpacePosition.x / uniforms.viewportSize.x) * 2.0 - 1.0,
                        (pixelSpacePosition.y / uniforms.viewportSize.y) * 2.0 - 1.0,
                        0.0, 1.0);
    
    // Set color based on amplitude (blue-green gradient)
    // More intense blue for higher amplitudes
    out.color = float4(0.0, 0.5 + amplitude * 0.5, 1.0, 1.0);
    
    return out;
}

// Spectrum vertex shader
vertex VertexOut spectrumVertex(
    const device float* vertices [[buffer(0)]],
    const device WaveformUniforms& uniforms [[buffer(1)]],
    uint vertexID [[vertex_id]]
) {
    VertexOut out;
    
    // Each line is defined by 2 vertices (bottom and top)
    bool isTop = (vertexID % 2) == 1;
    
    // Get x and y from buffer
    float x = vertices[vertexID * 2];
    float y = vertices[vertexID * 2 + 1];
    
    // Position in clip space
    float2 pixelSpacePosition = float2(x * uniforms.viewportSize.x, 
                                     y * uniforms.viewportSize.y);
    
    // Apply device pixel ratio for high DPI displays
    pixelSpacePosition *= uniforms.devicePixelRatio;
    
    // Convert to normalized device coordinates (-1 to 1)
    out.position = float4((pixelSpacePosition.x / uniforms.viewportSize.x) * 2.0 - 1.0,
                        (pixelSpacePosition.y / uniforms.viewportSize.y) * 2.0 - 1.0,
                        0.0, 1.0);
    
    // Set color based on frequency (rainbow gradient)
    float hue = x; // 0.0 to 1.0 across frequency spectrum
    float3 rgb = float3(0.0);
    
    // Simple HSV to RGB conversion for rainbow effect
    float h = hue * 6.0;
    float i = floor(h);
    float f = h - i;
    float p = 0.0;
    float q = 1.0 - f;
    float t = f;
    
    if (i == 0.0) rgb = float3(1.0, t, p);
    else if (i == 1.0) rgb = float3(q, 1.0, p);
    else if (i == 2.0) rgb = float3(p, 1.0, t);
    else if (i == 3.0) rgb = float3(p, q, 1.0);
    else if (i == 4.0) rgb = float3(t, p, 1.0);
    else rgb = float3(1.0, p, q);
    
    // Make top point full brightness, bottom point darker
    float brightness = isTop ? 1.0 : 0.3;
    out.color = float4(rgb * brightness, 1.0);
    
    return out;
}

// Fragment shader for waveform
fragment float4 waveformFragment(VertexOut in [[stage_in]]) {
    return in.color;
}

// Fragment shader for spectrum
fragment float4 spectrumFragment(VertexOut in [[stage_in]]) {
    return in.color;
} 