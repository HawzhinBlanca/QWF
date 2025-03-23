import Combine
import MetalKit
import SwiftUI

// Custom minimal version to replace the real WaveformViewModel
class MinimalViewModel: ObservableObject {
    enum DimMode {
        case d2
        case d3
    }

    enum VisType {
        case wave
        case prob
        case phase
    }

    @Published var dimMode: DimMode = .d2
    @Published var visType: VisType = .wave
    @Published var frequency: Double = 440.0
    @Published var amplitude: Double = 0.5

    func updateWaveform() {
        print("DEBUG: updateWaveform called in minimal view model")
    }
}

@main
struct QuantumWaveformApp: App {
    @StateObject private var viewModel = WaveformViewModel()

    init() {
        print("DEBUG: QwantumWaveform app starting...")
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}

// Keeping this for reference or testing purposes
struct TestWithMinimalViewModel: View {
    @EnvironmentObject var viewModel: MinimalViewModel
    @State private var showMessage = false

    var body: some View {
        VStack(spacing: 20) {
            Text("QwantumWaveform Test")
                .font(.largeTitle)
                .padding()

            Text("Dimension Mode: \(viewModel.dimMode == .d2 ? "2D" : "3D")")
                .padding()

            Button("Force 2D Mode") {
                viewModel.dimMode = .d2
                print("DEBUG: Forced 2D mode")
            }
            .padding()

            Button("Update Waveform") {
                viewModel.updateWaveform()
                print("DEBUG: Update waveform called")
            }
            .padding()

            Button("Test Button") {
                showMessage.toggle()
                print("DEBUG: Button pressed, showMessage = \(showMessage)")
            }
            .padding()

            if showMessage {
                Text("Button was pressed!")
                    .foregroundColor(.green)
                    .padding()
            }
        }
        .onAppear {
            print("DEBUG: TestWithMinimalViewModel appeared")

            // Force 2D mode on startup
            viewModel.dimMode = .d2
            print("DEBUG: Initialized in 2D mode")
        }
    }
}
