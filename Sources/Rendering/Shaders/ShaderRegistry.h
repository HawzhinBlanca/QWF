//
//  ShaderRegistry.h
//  QwantumWaveform
//
//  Created for improved shader organization
//

#ifndef ShaderRegistry_h
#define ShaderRegistry_h

// This file serves as a central registry for all shader functions
// and ensures consistent naming and documentation

// Include all shader-related headers
#include "ShaderTypes.h"

// Shader function names - having these as constants ensures consistent naming
// between Swift code and Metal shaders

// Basic shader functions
#define SHADER_FUNC_BASIC_VERTEX           "basicVertex"
#define SHADER_FUNC_BASIC_FRAGMENT         "basicFragment"
#define SHADER_FUNC_DEBUG_GRID             "debugGridFragment"

// Waveform visualization shader functions
#define SHADER_FUNC_WAVEFORM_2D            "waveform2DFragment"
#define SHADER_FUNC_WAVEFORM_3D_VERTEX     "waveform3DVertex"
#define SHADER_FUNC_WAVEFORM_3D_FRAGMENT   "waveform3DFragment"

// Quantum visualization shader functions
#define SHADER_FUNC_QUANTUM_WAVE_VERTEX    "quantumWaveVertex"
#define SHADER_FUNC_QUANTUM_WAVE_FRAGMENT  "quantumWaveFragment"
#define SHADER_FUNC_QUANTUM_COMPUTE        "quantumCompute"
#define SHADER_FUNC_QUANTUM_KERNELS        "quantumKernels"

// This struct can be used to help Swift code find shader functions
typedef struct {
    const char* name;
    const char* description;
    int type;  // 0 = vertex, 1 = fragment, 2 = compute
} ShaderFunctionInfo;

// Shader function registry - can be used for runtime shader function lookup
static const ShaderFunctionInfo shaderFunctions[] = {
    {SHADER_FUNC_BASIC_VERTEX,         "Basic vertex shader for simple rendering", 0},
    {SHADER_FUNC_BASIC_FRAGMENT,       "Basic fragment shader with colorful pattern", 1},
    {SHADER_FUNC_DEBUG_GRID,           "Debug grid pattern for testing", 1},
    {SHADER_FUNC_WAVEFORM_2D,          "2D waveform visualization", 1},
    {SHADER_FUNC_WAVEFORM_3D_VERTEX,   "3D waveform vertex transformation", 0},
    {SHADER_FUNC_WAVEFORM_3D_FRAGMENT, "3D waveform color and lighting", 1},
    {SHADER_FUNC_QUANTUM_WAVE_VERTEX,  "Quantum wave vertex shader", 0},
    {SHADER_FUNC_QUANTUM_WAVE_FRAGMENT,"Quantum wave visualization", 1},
    {SHADER_FUNC_QUANTUM_COMPUTE,      "Quantum state computation", 2},
    {SHADER_FUNC_QUANTUM_KERNELS,      "Quantum simulation kernels", 2}
};

#endif /* ShaderRegistry_h */ 