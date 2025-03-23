//
//  MetalConfiguration.swift
//  QwantumWaveform
//
//  Created by HAWZHIN on 14/03/2025.
//


import Foundation
import Metal

/// Manages Metal configuration and shader loading
class MetalConfiguration {
    static let shared = MetalConfiguration()
    
    // Metal device
    let device: MTLDevice
    
    // Library containing shader functions
    let defaultLibrary: MTLLibrary
    
    // Common sampler state
    let defaultSamplerState: MTLSamplerState
    
    private init() {
        // Get default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        
        // Load default shader library
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load default Metal library")
        }
        self.defaultLibrary = library
        
        // Create common sampler state
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        
        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            fatalError("Failed to create sampler state")
        }
        self.defaultSamplerState = samplerState
    }
}