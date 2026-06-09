//
//  iOSRootView.swift
//  SyncSpace
//
//  iPhone companion top-level. TabView between Dashboard / Mix / Tasks
//  / Settings. Dashboard is the primary glanceable surface.
//

#if os(iOS)
import SwiftUI

public struct iOSRootView: View {
    @Bindable var model: AppModel
    @State private var selectedTab: iOSTab = .dashboard

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            BreathingBackground(
                palette: paletteForTab,
                intensity: model.timer.isRunning ? 0.85 : 0.5,
                pulse: model.pulse
            )

            TabView(selection: $selectedTab) {
                DashboardScreen(model: model)
                    .tabItem { Label("Focus", systemImage: "scope") }
                    .tag(iOSTab.dashboard)

                RemoteMixerScreen(model: model)
                    .tabItem { Label("Mix", systemImage: "slider.vertical.3") }
                    .tag(iOSTab.mixer)

                RemoteTasksScreen(model: model)
                    .tabItem { Label("Tasks", systemImage: "checklist") }
                    .tag(iOSTab.tasks)

                iOSSettingsScreen(model: model)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(iOSTab.settings)
            }
            .tint(AppTheme.accent)
        }
        .preferredColorScheme(.dark)
    }

    private var paletteForTab: [Color] {
        switch selectedTab {
        case .dashboard:    return [AppTheme.electricIndigo, AppTheme.plum, AppTheme.cyan]
        case .mixer:        return [AppTheme.plum, AppTheme.cyan, AppTheme.electricIndigo]
        case .tasks:        return [AppTheme.cyan, AppTheme.mint, AppTheme.electricIndigo]
        case .settings:     return [Color.gray.opacity(0.5), AppTheme.electricIndigo, Color.black]
        }
    }
}

enum iOSTab: Hashable {
    case dashboard, mixer, tasks, settings
}
#endif
