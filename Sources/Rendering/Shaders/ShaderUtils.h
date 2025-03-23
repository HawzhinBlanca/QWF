//
//  ShaderUtils.h
//  QwantumWaveform
//
//  Created by HAWZHIN on 15/03/2025.
//

#ifndef ShaderUtils_h
#define ShaderUtils_h

// Note: Metal headers are automatically included when this file is processed
// by the Metal compiler, so we don't need explicit #include <metal_stdlib>
// This header will be used by Metal shader files (.metal extension)

#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;
#else
// Fallback for non-Metal contexts
#include <simd/simd.h>
#endif

// Complex number structure for GPU calculations
typedef struct {
    float real;
    float imag;
} ComplexType;

// Complex number operations
inline ComplexType complex_mul(ComplexType a, ComplexType b) {
    ComplexType result;
    result.real = a.real * b.real - a.imag * b.imag;
    result.imag = a.real * b.imag + a.imag * b.real;
    return result;
}

inline ComplexType complex_conj(ComplexType z) {
    return {z.real, -z.imag};
}

inline float complex_abs2(ComplexType z) {
    return z.real * z.real + z.imag * z.imag;
}

inline float complex_phase(ComplexType z) {
    return atan2(z.imag, z.real);
}

// Color conversion functions
#ifdef __METAL_VERSION__
inline float3 hsv2rgb(float h, float s, float v) {
    float3 c = float3(h, s, v);
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return v * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), s);
}
#endif

// Waveform generation functions
inline float sine_wave(float phase, float amplitude) {
    return amplitude * sin(phase);
}

inline float square_wave(float phase, float amplitude) {
#ifdef __METAL_VERSION__
    return amplitude * (fmod(phase, 2.0 * M_PI_F) < M_PI_F ? 1.0 : -1.0);
#else
    return amplitude * (fmod(phase, 2.0 * M_PI) < M_PI ? 1.0 : -1.0);
#endif
}

inline float triangle_wave(float phase, float amplitude) {
#ifdef __METAL_VERSION__
    float t = fmod(phase, 2.0 * M_PI_F) / (2.0 * M_PI_F);
#else
    float t = fmod(phase, 2.0 * M_PI) / (2.0 * M_PI);
#endif
    return amplitude * (2.0 * fabs(2.0 * t - 1.0) - 1.0);
}

inline float sawtooth_wave(float phase, float amplitude) {
#ifdef __METAL_VERSION__
    float t = fmod(phase, 2.0 * M_PI_F) / (2.0 * M_PI_F);
#else
    float t = fmod(phase, 2.0 * M_PI) / (2.0 * M_PI);
#endif
    return amplitude * (2.0 * t - 1.0);
}

// MARK: - Utility Functions

// Helper function for factorial
inline float factorial(int n) {
    if (n <= 1) return 1.0;
    
    float result = 1.0;
    for (int i = 2; i <= n; i++) {
        result *= i;
    }
    return result;
}

// Hermite polynomial for quantum harmonic oscillator
inline float hermite(int n, float x) {
    if (n == 0) return 1.0;
    if (n == 1) return 2.0 * x;
    
    float h0 = 1.0;
    float h1 = 2.0 * x;
    float h2 = 0.0;
    
    for (int i = 1; i < n; i++) {
        h2 = 2.0 * x * h1 - 2.0 * i * h0;
        h0 = h1;
        h1 = h2;
    }
    
    return h1;
}

// Associated Laguerre polynomial for hydrogen atom
inline float assoc_laguerre(int n, int alpha, float x) {
    if (n == 0) return 1.0;
    if (n == 1) return 1.0 + float(alpha) - x;
    
    float l0 = 1.0;
    float l1 = 1.0 + float(alpha) - x;
    float l2 = 0.0;
    
    for (int i = 1; i < n; i++) {
        float k = float(i);
        float a = float(alpha);
        l2 = ((2.0 * k + 1.0 + a - x) * l1 - (k + a) * l0) / (k + 1.0);
        l0 = l1;
        l1 = l2;
    }
    
    return l1;
}

#endif /* ShaderUtils_h */ 