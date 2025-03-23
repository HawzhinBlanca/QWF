//
//  ShaderTypes.h
//  QwantumWaveform
//
//  Created by HAWZHIN on 15/03/2025.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Buffer indices
typedef enum {
    VertexBuffer = 0,
    UniformBuffer = 1,
    WaveformDataBuffer = 2,
    ColorDataBuffer = 3
} BufferIndices;

// Vertex descriptor attributes
typedef enum {
    VertexAttributePosition = 0,
    VertexAttributeTexcoord = 1,
    VertexAttributeNormal = 2
} VertexAttributes;

// Vertex structure for 3D rendering
typedef struct {
    vector_float3 position;
    vector_float2 texCoord;
    vector_float3 normal;
} Vertex;

// Uniform structure passed to shaders
typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    vector_float3 lightPosition;
    float time;
} Uniforms;

// Extended uniforms for 3D quantum visualization
typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    vector_float3 lightPosition;
    float time;
    int visualizationType;
    float amplitude;
    float frequency;
    vector_float4 colorScale;
} Quantum3DUniforms;

// Visualization mode
typedef enum {
    VisualizationMode2D = 0,
    VisualizationMode3D = 1
} VisualizationMode;

// Quantum visualization type
typedef enum {
    QuantumVisualizationProbability = 0,
    QuantumVisualizationRealPart = 1,
    QuantumVisualizationImaginaryPart = 2,
    QuantumVisualizationPhase = 3
} QuantumVisualizationType;

// Audio visualization type
typedef enum {
    AudioVisualizationWaveform = 0,
    AudioVisualizationSpectrum = 1
} AudioVisualizationType;

// Color scheme options
typedef enum {
    ColorSchemeClassic = 0,
    ColorSchemeHeatMap = 1,
    ColorSchemeRainbow = 2,
    ColorSchemeGrayscale = 3,
    ColorSchemeNeon = 4
} ColorScheme;

// Waveform types for audio generation
typedef enum {
    WaveformTypeSine = 0,
    WaveformTypeSquare = 1,
    WaveformTypeTriangle = 2,
    WaveformTypeSawtooth = 3,
    WaveformTypeNoise = 4,
    WaveformTypeCustom = 5
} WaveformTypeEnum;

// Data structure for quantum simulation 
typedef struct {
    float energyLevel;
    float particleMass;
    float potentialHeight;
    float simulationTime;
    int systemType;
    int visualizationType;
    float amplitude;
    float frequency;
    
    // Added missing fields needed by the shaders
    uint gridSize;
    vector_float2 domain;
    float hbar;
    float mass;
} QuantumParameters;

#endif /* ShaderTypes_h */
