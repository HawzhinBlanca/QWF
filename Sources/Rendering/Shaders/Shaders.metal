#include <metal_stdlib>
using namespace metal;

// Structures matching the ones in WaveformRenderer3D.swift
struct Vertex {
    float4 position [[position]];
    float4 color;
    float2 texCoord;
};

struct Uniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float time;
    uint colorScheme;
};

struct Complex {
    float real;
    float imag;
};

struct QuantumSimParams {
    float time;
    float hbar;
    float mass;
    float potentialHeight;
    uint systemType;
    uint energyLevel;
    uint gridSize;
    uint reserved;
    float2 domain;
};

// Vertex shader for 3D visualization
vertex Vertex vertexShader3D(const device Vertex* vertices [[buffer(0)]],
                             constant Uniforms& uniforms [[buffer(1)]],
                             uint vid [[vertex_id]]) {
    Vertex out = vertices[vid];
    
    // Apply view and projection transformations
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * out.position;
    
    return out;
}

// Fragment shader for 3D visualization
fragment float4 fragmentShader3D(Vertex in [[stage_in]],
                                constant Uniforms& uniforms [[buffer(0)]]) {
    // Apply simple lighting based on position
    float ambient = 0.2;
    float diffuse = max(0.0, 1.0 - abs(in.position.y));
    
    // Color based on input color and lighting
    float4 finalColor = in.color * (ambient + diffuse);
    finalColor.a = 1.0;  // Ensure full opacity
    
    return finalColor;
}

// Compute shader for quantum wavefunction
kernel void compute_quantum_wavefunction(device Complex* waveFunction [[buffer(0)]],
                                         constant QuantumSimParams& params [[buffer(1)]],
                                         uint index [[thread_position_in_grid]]) {
    if (index >= params.gridSize) return;
    
    // Calculate position in domain
    float domainRange = params.domain.y - params.domain.x;
    float x = params.domain.x + (float(index) / float(params.gridSize)) * domainRange;
    
    // Basic quantum parameters
    float amplitude = 1.0;
    float frequency = 5.0 * float(params.energyLevel);
    float omega = 2.0 * M_PI_F * frequency;  // Angular frequency
    float phase = params.time * 3.0;  // Speed up time evolution
    
    // Calculate position relative to domain center for envelope functions
    float center = (params.domain.x + params.domain.y) * 0.5;
    float position = x - center;
    float width = domainRange * 0.25;  // 25% of domain width
    
    // Gaussian envelope factor
    float gaussian = exp(-(position * position) / (2.0 * width * width));
    
    // Create complex value based on system type
    switch (params.systemType) {
        case 0: { // Harmonic oscillator (Gaussian packet)
            float n = float(params.energyLevel);
            // Simple harmonic oscillator approximation
            float hermite = 1.0;
            if (n > 0) {
                // Very basic Hermite polynomial approximation for n=1,2
                if (n == 1) hermite = 2.0 * position / width;
                else hermite = 4.0 * (position * position) / (width * width) - 2.0;
            }
            
            waveFunction[index].real = amplitude * hermite * gaussian * cos(omega * params.time);
            waveFunction[index].imag = amplitude * hermite * gaussian * sin(omega * params.time);
            break;
        }
            
        case 1: { // Square well with interference pattern
            // Superposition of two waves
            float wave1 = sin(omega * (x - 0.1 * domainRange) - phase);
            float wave2 = sin(omega * (x + 0.1 * domainRange) + phase);
            waveFunction[index].real = amplitude * gaussian * (wave1 + wave2) * 0.5;
            waveFunction[index].imag = amplitude * gaussian * (cos(omega * x) * sin(phase));
            break;
        }
            
        case 2: { // Superposition state with beats
            float beat = sin(0.2 * omega * x) * sin(omega * x - phase);
            waveFunction[index].real = amplitude * gaussian * beat;
            waveFunction[index].imag = amplitude * gaussian * cos(1.1 * omega * x - 0.9 * phase);
            break;
        }
            
        default: { // Default wavepacket
            waveFunction[index].real = amplitude * gaussian * sin(omega * x + phase);
            waveFunction[index].imag = amplitude * gaussian * cos(omega * x + phase * 0.5);
        }
    }
} 