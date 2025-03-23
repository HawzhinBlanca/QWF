#ifndef QuantumWaveFunctions_h
#define QuantumWaveFunctions_h

#ifdef __METAL_VERSION__
// Metal compiler will use its built-in paths
#include <metal_stdlib>
using namespace metal;
#else
// For non-Metal environments (IDE, linters)
#include <simd/simd.h>
// Constants for non-Metal context
#ifndef M_PI_F
#define M_PI_F 3.14159265358979323846f
#endif
#endif

// These headers must be included before this file
// to ensure ComplexType is already defined
#include "ShaderTypes.h"
#include "ShaderUtils.h"
#include "ComplexUtils.h"

// MARK: - Wave Function Implementations

// Free particle wave function
inline ComplexType free_particle(float x, float k0, float sigma, float t, float mass, float hbar) {
    float omega = hbar * k0 * k0 / (2.0 * mass);
    
    // Time-dependent width
    float sigma_t = sigma * sqrt(1.0 + pow(hbar * t / (mass * sigma * sigma), 2.0));
    
    // Gaussian wave packet
    float x0 = 0.0; // Center position
    float dx = x - x0 - (hbar * k0 * t / mass);
    float amplitude = exp(-dx * dx / (2.0 * sigma_t * sigma_t)) / pow(2.0 * M_PI_F * sigma_t * sigma_t, 0.25);
    
    // Phase terms
    float phase1 = k0 * dx;
    float phase2 = atan2(hbar * t, 2.0 * mass * sigma * sigma);
    float phase = phase1 - 0.5 * phase2;
    
    return {amplitude * cos(phase), amplitude * sin(phase)};
}

// Infinite potential well (particle in a box)
inline ComplexType infinite_well(float x, float L, int n, float t, float mass, float hbar) {
    // Check if within well
    if (x < 0.0 || x > L) return {0.0, 0.0};
    
    // Spatial part
    float amplitude = sqrt(2.0 / L) * sin(n * M_PI_F * x / L);
    
    // Energy
    float energy = pow(n * M_PI_F * hbar, 2) / (2.0 * mass * L * L);
    
    // Time evolution
    float phase = -energy * t / hbar;
    
    return {amplitude * cos(phase), amplitude * sin(phase)};
}

// Quantum harmonic oscillator
inline ComplexType harmonic_oscillator(float x, int n, float omega, float t, float mass, float hbar) {
    // Characteristic length
    float alpha = sqrt(mass * omega / hbar);
    float xScaled = alpha * x;
    
    // Hermite polynomial using the imported function
    float herm = hermite(n, xScaled);
    
    // Normalization factor (approximation for higher n)
    float norm = 1.0 / sqrt(pow(2.0, n) * factorial(n) * sqrt(M_PI_F)) * pow(alpha, 0.25);
    
    // Spatial part
    float amplitude = norm * herm * exp(-xScaled * xScaled / 2.0);
    
    // Energy and time evolution
    float energy = hbar * omega * (n + 0.5);
    float phase = -energy * t / hbar;
    
    return {amplitude * cos(phase), amplitude * sin(phase)};
}

// Hydrogen atom (radial part only)
inline ComplexType hydrogen_atom(float r, int n, int l, float t, float hbar) {
    // Constants
    float bohrRadius = 5.29177210903e-11; // m
    float rydbergEnergy = 2.1798723611035e-18; // J
    
    // Normalize radius (scale for visualization)
    float rho = 2.0 * r / (n * bohrRadius);
    
    // Associated Laguerre polynomial using the imported function
    float laguerrePoly = assoc_laguerre(n - l - 1, 2 * l + 1, rho);
    
    // Radial wave function
    float norm = sqrt(pow(2.0 / (n * bohrRadius), 3) * factorial(n - l - 1) / (2.0 * n * factorial(n + l)));
    float radial = norm * exp(-rho / 2.0) * pow(rho, l) * laguerrePoly;
    
    // Energy and time evolution
    float energy = -rydbergEnergy / (n * n);
    float phase = -energy * t / hbar;
    
    return {radial * cos(phase), radial * sin(phase)};
}

METAL_FUNC void calculateHarmonicOscillatorState(device float2* psi, const device float* position, int n, int size) {
    // Parameters
    const float alpha = 1.0f; // Related to oscillator frequency
    // Use a defined value for omega instead of leaving it unused
    const float omega = 1.0f;
    
    // Implement the calculation
    for (int i = 0; i < size; i++) {
        float x = position[i];
        psi[i] = harmonic_oscillator(x, n, omega, 0.0f, 1.0f, 1.0f);
    }
}

#endif /* QuantumWaveFunctions_h */ 