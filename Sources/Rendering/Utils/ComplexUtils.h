//
//  ComplexUtils.h
//  QwantumWaveform
//
//  Created by HAWZHIN on 15/03/2025.
//

#ifndef ComplexUtils_h
#define ComplexUtils_h

#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;

struct Complex {
    float real;
    float imag;
};
#else
#include <simd/simd.h>
typedef struct {
    float real;
    float imag;
} Complex;
#endif

#import "ShaderTypes.h"

// Helper function for quantum calculations
inline int calc_factorial(int n) {
    int result = 1;
    for (int i = 2; i <= n; i++) {
        result *= i;
    }
    return result;
}

// Complex number operations
inline Complex complex_add(Complex a, Complex b) {
    Complex result;
    result.real = a.real + b.real;
    result.imag = a.imag + b.imag;
    return result;
}

inline Complex complex_mul(Complex a, Complex b) {
    Complex result;
    result.real = a.real * b.real - a.imag * b.imag;
    result.imag = a.real * b.imag + a.imag * b.real;
    return result;
}

inline float complex_abs(Complex a) {
    return sqrt(a.real * a.real + a.imag * a.imag);
}

inline float complex_phase(Complex a) {
    return atan2(a.imag, a.real);
}

inline Complex complex_exp(float phase) {
    Complex result;
    result.real = cos(phase);
    result.imag = sin(phase);
    return result;
}

// Additional complex number operations not in ShaderUtils.h
inline ComplexType complex_add(ComplexType a, ComplexType b) {
    return {a.real + b.real, a.imag + b.imag};
}

inline ComplexType complex_sub(ComplexType a, ComplexType b) {
    return {a.real - b.real, a.imag - b.imag};
}

inline ComplexType complex_scale(ComplexType z, float scale) {
    return {z.real * scale, z.imag * scale};
}

inline ComplexType complex_mul_scalar(ComplexType a, float s) {
    return {a.real * s, a.imag * s};
}

inline ComplexType complex_mul_i(ComplexType a) {
    return {-a.imag, a.real};
}

inline float complex_dot(ComplexType a, ComplexType b) {
    return a.real * b.real + a.imag * b.imag;
}

// Advanced quantum utilities
inline ComplexType complex_wave_packet(float x, float x0, float k0, float sigma) {
    float dx = x - x0;
    float gauss = exp(-dx * dx / (2.0 * sigma * sigma));
    float phase = k0 * x;
    
    return {gauss * cos(phase), gauss * sin(phase)};
}

// Functions for quantum eigenstates
inline float harmonic_oscillator_eigenstate(int n, float x, float omega, float hbar, float mass) {
    float alpha = sqrt(mass * omega / hbar);
    float prefactor = 1.0 / sqrt(pow(2.0, n) * calc_factorial(n));
    float expterm = exp(-alpha * x * x / 2.0);
    
    // Hermite polynomial calculation would go here (for simplicity, implemented elsewhere)
    
    return prefactor * expterm;
}

#endif /* ComplexUtils_h */ 