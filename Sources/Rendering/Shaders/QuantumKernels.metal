#include <metal_stdlib>
using namespace metal;

// Import shared structures and utilities
#import "ShaderTypes.h"
#import "ShaderUtils.h"
#import "ComplexUtils.h"

// Compute kernel for quantum state evolution
kernel void quantum_evolution(device ComplexType *waveFunction [[buffer(0)]],
                            device const float *potential [[buffer(1)]],
                            constant QuantumParameters &params [[buffer(2)]],
                            uint id [[thread_position_in_grid]]) {
    if (id >= params.gridSize) return;
    
    // Get current state
    ComplexType psi = waveFunction[id];
    float V = potential[id];
    
    // Calculate spatial derivatives using finite differences
    uint left = (id > 0) ? id - 1 : params.gridSize - 1;
    uint right = (id < params.gridSize - 1) ? id + 1 : 0;
    
    ComplexType psi_left = waveFunction[left];
    ComplexType psi_right = waveFunction[right];
    
    float dx = (params.domain.y - params.domain.x) / float(params.gridSize);
    float dx2 = dx * dx;
    
    // Kinetic energy term: -ℏ²/2m ∇²ψ
    ComplexType d2psi = complex_add(
        complex_sub(psi_left, complex_mul_scalar(psi, 2.0)),
        psi_right
    );
    d2psi = complex_mul_scalar(d2psi, 1.0 / dx2);
    
    ComplexType kinetic = complex_mul_scalar(d2psi, 
        -0.5 * params.hbar * params.hbar / params.mass
    );
    
    // Potential energy term: Vψ
    ComplexType potential_term = complex_mul_scalar(psi, V);
    
    // Time evolution: iℏ∂ψ/∂t = Hψ = (-ℏ²/2m ∇² + V)ψ
    float dt = 0.001; // Small time step
    ComplexType H_psi = complex_add(kinetic, potential_term);
    ComplexType i_H_psi = complex_mul_i(H_psi);
    ComplexType dPsi = complex_mul_scalar(i_H_psi, -dt / params.hbar);
    
    // Update wave function
    waveFunction[id] = complex_add(psi, dPsi);
}

// Calculate probability density
kernel void probability_density(device const ComplexType *waveFunction [[buffer(0)]],
                             device float *probDensity [[buffer(1)]],
                             constant QuantumParameters &params [[buffer(2)]],
                             uint id [[thread_position_in_grid]]) {
    if (id >= params.gridSize) return;
    
    ComplexType psi = waveFunction[id];
    probDensity[id] = complex_abs2(psi);
}

// Calculate energy
kernel void energy_calculation(device const ComplexType *waveFunction [[buffer(0)]],
                            device const float *potential [[buffer(1)]],
                            device float *energy [[buffer(2)]],
                            constant QuantumParameters &params [[buffer(3)]],
                            uint id [[thread_position_in_grid]]) {
    if (id >= params.gridSize) return;
    
    // Calculate kinetic and potential energy contributions
    ComplexType psi = waveFunction[id];
    float V = potential[id];
    
    // Spatial derivatives
    uint left = (id > 0) ? id - 1 : params.gridSize - 1;
    uint right = (id < params.gridSize - 1) ? id + 1 : 0;
    
    ComplexType psi_left = waveFunction[left];
    ComplexType psi_right = waveFunction[right];
    
    float dx = (params.domain.y - params.domain.x) / float(params.gridSize);
    float dx2 = dx * dx;
    
    // Kinetic energy: -ℏ²/2m ∇²ψ
    ComplexType d2psi = complex_add(
        complex_sub(psi_left, complex_mul_scalar(psi, 2.0)),
        psi_right
    );
    d2psi = complex_mul_scalar(d2psi, 1.0 / dx2);
    
    float kineticEnergy = -0.5 * params.hbar * params.hbar * 
        complex_dot(d2psi, psi) / params.mass;
    
    float potentialEnergy = V * complex_abs2(psi);
    
    energy[id] = kineticEnergy + potentialEnergy;
}
