import SwiftUI

@main
struct PCDashboardApp: App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            CanvasFrame {
                RootView()
            }
            .environment(store)
            .preferredColorScheme(store.settings.style == .paper ? .light : .dark)
            .tint(Design.make(store.settings.style, store.settings.accent).accent)
            .onChange(of: phase) { _, p in store.scenePhase(p) }
            .onAppear { DemoOrientation.apply() }
        }
    }
}

/// For screenshots: `-canvas 1024x768` draws the app at an exact screen size
/// (the iPad 6th generation in landscape) inside whatever simulator is running.
struct CanvasFrame<Content: View>: View {
    @ViewBuilder var content: () -> Content

    private var canvas: CGSize? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-canvas"), i + 1 < args.count else { return nil }
        let parts = args[i + 1].split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }

    var body: some View {
        if let c = canvas {
            ZStack(alignment: .topLeading) {
                Color(white: 0.12).ignoresSafeArea()
                content()
                    .frame(width: c.width, height: c.height)
                    .clipped()
                    .environment(\.horizontalSizeClass, .regular)
                    .environment(\.verticalSizeClass, .regular)
            }
            .ignoresSafeArea()
        } else {
            content()
        }
    }
}

enum DemoOrientation {
    /// `-landscape` turns the simulator sideways for screenshots.
    static func apply() {
        guard ProcessInfo.processInfo.arguments.contains("-landscape") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
        }
    }
}
