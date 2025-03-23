#include <metal_stdlib>
using namespace metal;

// Import shared definitions and utilities
#import "ShaderTypes.h"
#import "ShaderUtils.h"
#import "ComplexUtils.h"

// Quantum dynamics simulation kernel using Schrödinger equation
kernel void quantum_time_evolution(
                                      device ComplexType *waveFunction [[buffer(0)]],
                                      device const float *potential [[buffer(1)]],
                                      constant QuantumParameters &params [[buffer(2)]],
                                      uint id [[thread_position_in_grid]]) {
    if (id >= params.gridSize) return;
    
    // Extract parameters for simulation
    float time = params.simulationTime;
    float mass = params.mass;
    float hbar = params.hbar;
    
    // Initialize the wave function
    ComplexType psi;
    float x = float(id) / float(params.gridSize) * 10.0 - 5.0; // Domain from -5 to 5
    
    // Select wavefunction based on system type
    switch (params.systemType) {
        case 0: { // Free particle
            // Gaussian wave packet
            float k0 = sqrt(2.0 * mass * params.energyLevel * hbar);
            float sigma = 0.5;
            float x0 = -2.0;
            
            // Create wave packet
            float dx = x - x0;
            float gauss = exp(-dx * dx / (2.0 * sigma * sigma));
            float phase = k0 * x;
            
            psi.real = gauss * cos(phase);
            psi.imag = gauss * sin(phase);
            break;
        }
            
        case 1: { // Potential well
            // Stationary state in finite well
            if (fabs(x) < 1.0) {
                // Inside well
                float k = sqrt(2.0 * mass * params.energyLevel * hbar);
                psi.real = cos(k * x);
                psi.imag = 0.0;
            } else {
                // Outside well (decaying exponential)
                float kappa = sqrt(2.0 * mass * (params.potentialHeight - params.energyLevel) * hbar);
                float sign = x > 0 ? -1.0 : 1.0;
                psi.real = exp(sign * kappa * fabs(x));
                psi.imag = 0.0;
            }
            break;
        }
            
        case 2: { // Harmonic oscillator
            // Stationary state
            float omega = sqrt(params.energyLevel * hbar / mass);
            float n = float(params.energyLevel);
            
            // Compute based on Hermite polynomial approximation
            float alpha = sqrt(mass * omega / hbar);
            float hermite = 1.0;
            float x_scaled = alpha * x;
            
            // Simple Hermite polynomial evaluation for n=0, 1, 2
            if (n < 0.5) {
                hermite = 1.0; // H_0(x) = 1
            } else if (n < 1.5) {
                hermite = 2.0 * x_scaled; // H_1(x) = 2x
            } else if (n < 2.5) {
                hermite = 4.0 * x_scaled * x_scaled - 2.0; // H_2(x) = 4x² - 2
            } else {
                // For higher n, use recursive relation or approximation
                hermite = 8.0 * pow(x_scaled, 3) - 12.0 * x_scaled; // H_3(x) approximation
            }
            
            float normalization = 1.0 / sqrt(pow(2.0, n) * calc_factorial(int(n)));
            float wavefunc = normalization * hermite * exp(-x_scaled * x_scaled / 2.0);
            
            psi.real = wavefunc;
            psi.imag = 0.0;
            
            // Add time evolution if needed
            if (time > 0.0) {
                float energy = hbar * omega * (n + 0.5);
                float phase = -energy * time / hbar;
                
                float cos_val = cos(phase);
                float sin_val = sin(phase);
                
                ComplexType time_evolution = {cos_val, sin_val};
                psi = complex_mul(psi, time_evolution);
            }
            
            break;
        }
            
        case 3: { // Hydrogen atom (simplified 1D radial part)
            // Radial part of hydrogen atom wavefunction
            float r = fabs(x) + 0.1; // Avoid r=0 singularity
            float n = float(params.energyLevel);
            float a0 = 0.529e-10; // Bohr radius
            
            // Simple approximation for radial function
            float rho = 2.0 * r / (n * a0);
            float exp_term = exp(-rho / 2.0);
            float polynomial = 1.0;
            
            // For n=1, the polynomial is just 1
            // For n=2, approximating the associated Laguerre polynomial
            if (n > 1.5) {
                polynomial = 1.0 - rho / 2.0;
            }
            
            float normalization = sqrt(pow(2.0 / (n * a0), 3) / (2.0 * n * n));
            float wavefunc = normalization * exp_term * polynomial * rho;
            
            psi.real = wavefunc;
            psi.imag = 0.0;
            break;
        }
            
        default: {
            // Default to sine wave
            psi.real = sin(x);
            psi.imag = 0.0;
        }
    }
    
    // Store the computed wavefunction
    waveFunction[id] = psi;
}

// Compute probability density from wave function
kernel void compute_probability_density(device const ComplexType *waveFunction [[buffer(0)]],
                              device float *probDensity [[buffer(1)]],
                              constant QuantumParameters &params [[buffer(2)]],
                              uint id [[thread_position_in_grid]]) {
    if (id >= params.gridSize) return;
    
    ComplexType psi = waveFunction[id];
    probDensity[id] = psi.real * psi.real + psi.imag * psi.imag; // |ψ|²
} 