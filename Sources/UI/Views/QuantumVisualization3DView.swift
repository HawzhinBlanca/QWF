//
//  QuantumVisualization3DView.swift
//  QwantumWaveform
//
//  Created by HAWZHIN on 15/03/2025.
//

import Metal
import MetalKit
import SwiftUI
import simd

/// An advanced 3D visualization component for quantum wave functions
struct QuantumVisualization3DView: View {
    @ObservedObject var viewModel: WaveformViewModel

    // Debugging state
    @State private var rendererStatus: String = "Not initialized"
    @State private var lastRenderTime: Date = Date()
    @State private var frameCount: Int = 0
    @State private var fps: Double = 0.0

    // 3D interaction state
    @State private var rotationAngle: Float = 0
    @State private var showWireframe: Bool = false

    // Animation
    @State private var isAnimating: Bool = true

    // Flag to indicate if 3D is temporarily disabled
    private let is3DDisabled = false

    // Timer for FPS calculation
    @State private var fpsTimer: Timer? = nil

    var body: some View {
        // Only show 3D visualization if in 3D mode
        if viewModel.dimensionMode == .threeDimensional && !is3DDisabled {
            ZStack {
                // Metal 3D view
                MetalView3D(
                    viewModel: viewModel,
                    rotationAngle: $rotationAngle,
                    showWireframe: $showWireframe,
                    isAnimating: $isAnimating
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Rotate around y-axis based on horizontal movement
                            let deltaX = Float(value.translation.width)
                            rotationAngle += deltaX * 0.01
                            viewModel.rotateVisualization(byAngle: deltaX * 0.01)
                        }
                )

                // Debug info overlay (top right)
                VStack(alignment: .trailing) {
                    if frameCount > 0 {
                        Text("FPS: \(Int(fps))")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                    }

                    Text(rendererStatus)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                // Controls (bottom center)
                HStack(spacing: 20) {
                    // System type selector
                    Picker("System", selection: $viewModel.visualSystemType) {
                        Text("Free Particle").tag(0)
                        Text("Potential Well").tag(1)
                        Text("Harmonic Osc").tag(2)
                        Text("Hydrogen").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)

                    // Visualization controls
                    HStack(spacing: 12) {
                        // Toggle wireframe
                        Button(action: {
                            showWireframe.toggle()
                            viewModel.renderer3D?.toggleWireframe(showWireframe)
                        }) {
                            Image(
                                systemName: showWireframe
                                    ? "square.grid.3x3.fill" : "square.grid.3x3"
                            )
                            .foregroundColor(showWireframe ? .yellow : .white)
                        }

                        // Toggle animation
                        Button(action: {
                            isAnimating.toggle()
                            viewModel.setAnimation(isAnimating)
                        }) {
                            Image(systemName: isAnimating ? "pause.circle" : "play.circle")
                                .foregroundColor(isAnimating ? .yellow : .white)
                        }
                    }
                    .font(.title2)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .onAppear {
                // Initialize the renderer and check its status
                checkRendererStatus()

                // Start FPS timer
                fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    let now = Date()
                    let timeDiff = now.timeIntervalSince(lastRenderTime)
                    if timeDiff > 0 {
                        fps = Double(frameCount) / timeDiff
                        frameCount = 0
                        lastRenderTime = now
                    }
                }
            }
            .onDisappear {
                fpsTimer?.invalidate()
                fpsTimer = nil
            }
        } else {
            // Placeholder when not in 3D mode or 3D is disabled
            VStack {
                Text(
                    is3DDisabled
                        ? "3D visualization is temporarily disabled"
                        : "Switch to 3D mode to view 3D visualization"
                )

                Button("Initialize 3D Renderer") {
                    viewModel.setupRenderer3D()
                    checkRendererStatus()
                }
                .buttonStyle(.bordered)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
        }
    }

    private func checkRendererStatus() {
        if let renderer = viewModel.renderer3D {
            rendererStatus = "Renderer: Active"
        } else {
            rendererStatus = "Renderer: Not initialized"
            viewModel.initializeRenderer3D()
        }
    }
}

/// Metal view for 3D visualization using WaveformRenderer3D
struct MetalView3D: NSViewRepresentable {
    var viewModel: WaveformViewModel
    @Binding var rotationAngle: Float
    @Binding var showWireframe: Bool
    @Binding var isAnimating: Bool

    func makeCoordinator() -> Coordinator {
        print("MetalView3D: Creating coordinator")
        return Coordinator(self)
    }

    func makeNSView(context: Context) -> MTKView {
        print("MetalView3D: Creating MTKView")

        // Create a Metal view
        let mtkView = MTKView()

        // Configure basic Metal view properties
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("ERROR: Metal is not supported on this device")
            return MTKView()
        }

        mtkView.device = device
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.preferredFramesPerSecond = 60

        // Connect our renderer
        viewModel.connectRenderer3D(to: mtkView)

        // Update coordinator state
        context.coordinator.updateState(
            rotationAngle: rotationAngle,
            wireframe: showWireframe,
            animating: isAnimating
        )

        print("MetalView3D: MTKView created and connected to WaveformRenderer3D")
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Check if any parameters changed
        if rotationAngle != context.coordinator.rotationAngle {
            viewModel.renderer3D?.rotate(byAngle: rotationAngle - context.coordinator.rotationAngle)
            context.coordinator.rotationAngle = rotationAngle
        }

        if showWireframe != context.coordinator.wireframe {
            viewModel.renderer3D?.toggleWireframe(showWireframe)
            context.coordinator.wireframe = showWireframe
        }

        if isAnimating != context.coordinator.animating {
            viewModel.setAnimation(isAnimating)
            context.coordinator.animating = isAnimating
        }

        // Force redraw if needed
        nsView.needsDisplay = true

        // Count frames for FPS calculation
        viewModel.incrementFrameCount()
    }

    class Coordinator: NSObject {
        var parent: MetalView3D
        var rotationAngle: Float = 0
        var wireframe: Bool = false
        var animating: Bool = true

        init(_ parent: MetalView3D) {
            self.parent = parent
            super.init()
        }

        func updateState(rotationAngle: Float, wireframe: Bool, animating: Bool) {
            self.rotationAngle = rotationAngle
            self.wireframe = wireframe
            self.animating = animating
        }
    }
}

// Preview
struct QuantumVisualization3DView_Previews: PreviewProvider {
    static var previews: some View {
        QuantumVisualization3DView(viewModel: WaveformViewModel())
            .frame(width: 800, height: 600)
            .preferredColorScheme(.dark)
    }
}
