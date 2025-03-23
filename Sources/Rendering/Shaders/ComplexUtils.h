//
//  ComplexUtils.h
//  QwantumWaveform
//
//  Created by HAWZHIN on 16/06/2024.
//

#ifndef ComplexUtils_h
#define ComplexUtils_h

// Include this header after ShaderTypes.h and ShaderUtils.h 
// to ensure ComplexType is already defined

#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;
#else
#include <simd/simd.h>
#endif

// Additional complex number operations beyond what's in ShaderUtils.h
// IMPORTANT: We removed duplicate functions that are already defined in ShaderUtils.h:
// - complex_abs2
// - complex_phase

// Add two complex numbers
inline ComplexType complex_add(ComplexType a, ComplexType b) {
    return {a.real + b.real, a.imag + b.imag};
}

// Subtract two complex numbers
inline ComplexType complex_sub(ComplexType a, ComplexType b) {
    return {a.real - b.real, a.imag - b.imag};
}

// Scale a complex number
inline ComplexType complex_scale(ComplexType z, float scale) {
    return {z.real * scale, z.imag * scale};
}

// Multiply a complex number by a scalar
inline ComplexType complex_mul_scalar(ComplexType a, float s) {
    return {a.real * s, a.imag * s};
}

// Multiply a complex number by i (imaginary unit)
inline ComplexType complex_mul_i(ComplexType a) {
    return {-a.imag, a.real};
}

// Calculate the dot product of two complex numbers
inline float complex_dot(ComplexType a, ComplexType b) {
    return a.real * b.real + a.imag * b.imag;
}

// Create a wave packet at position x with wave number k0 and width sigma
inline ComplexType complex_wave_packet(float x, float x0, float k0, float sigma) {
    float dx = x - x0;
    float gauss = exp(-dx * dx / (2.0 * sigma * sigma));
    float phase = k0 * x;
    
    return {gauss * cos(phase), gauss * sin(phase)};
}

// Complex exponential function
inline ComplexType complex_exp(float phase) {
    return {cos(phase), sin(phase)};
}

// Get the magnitude of a complex number using existing complex_abs2
inline float complex_abs(ComplexType z) {
    return sqrt(complex_abs2(z));
}

// Calculate complex exponential e^(i*θ)
inline ComplexType complex_exp_i(float theta) {
    return {cos(theta), sin(theta)};
}

// Helper function for quantum calculations
inline int calc_factorial(int n) {
    int result = 1;
    for (int i = 2; i <= n; i++) {
        result *= i;
    }
    return result;
}

#endif /* ComplexUtils_h */ 