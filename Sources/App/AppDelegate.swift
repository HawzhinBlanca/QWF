import Combine
import SwiftUI

#if os(macOS)
    import AppKit

    class AppDelegate: NSObject, NSApplicationDelegate {
        private var preferences = UserPreferences.shared
        private var notificationHandler: NotificationHandler?
        private var statusItem: NSStatusItem?
        private var cancellables = Set<AnyCancellable>()

        func applicationDidFinishLaunching(_ notification: Notification) {
            // Register Metal library
            _ = MetalConfiguration.shared

            // Initialize performance monitoring
            #if DEBUG
                setupPerformanceMonitoring()
            #endif

            // Initialize menu bar if needed
            setupMenuBarExtra()

            // Listen for termination to save preferences
            NSApp.publisher(for: \.isActive)
                .sink { [weak self] isActive in
                    if !isActive {
                        self?.saveState()
                    }
                }
                .store(in: &cancellables)
        }

        func applicationWillTerminate(_ notification: Notification) {
            saveState()
        }

        // MARK: - Private Methods

        private func setupMenuBarExtra() {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            if let button = statusItem?.button {
                button.image = NSImage(
                    systemSymbolName: "waveform", accessibilityDescription: "Quantum Waveform")

                let menu = NSMenu()

                let performanceItem = NSMenuItem(
                    title: "Show Performance", action: #selector(togglePerformanceMonitor),
                    keyEquivalent: "p")
                performanceItem.target = self
                menu.addItem(performanceItem)

                menu.addItem(NSMenuItem.separator())

                let quitItem = NSMenuItem(
                    title: "Quit Quantum Waveform", action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q")
                menu.addItem(quitItem)

                statusItem?.menu = menu
            }
        }

        private func setupPerformanceMonitoring() {
            // Start monitoring
            _ = PerformanceMonitor.shared

            // Schedule periodic FPS reports
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                let report = PerformanceMonitor.shared.getPerformanceReport()
                print("Performance: \(report)")
            }
        }

        private func saveState() {
            // Save any application state before termination
            // This will be called from applicationWillTerminate
        }

        // MARK: - Actions

        @objc private func togglePerformanceMonitor() {
            // Create a floating window with performance stats
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            // Create and pass a view model to PerformanceView
            let performanceViewModel = PerformanceViewModel()
            window.contentView = NSHostingView(
                rootView: PerformanceView(viewModel: performanceViewModel))
            window.title = "Performance Monitor"
            window.makeKeyAndOrderFront(nil)
            window.center()

            // Keep window on top
            window.level = .floating
        }
    }
#endif
