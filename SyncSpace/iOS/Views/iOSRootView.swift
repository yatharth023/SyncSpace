//
//  iOSRootView.swift
//  SyncSpace
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
        .background(BreathingBackground(intensity: 0.30))
        .overlay(alignment: .topTrailing) {
            SyncDebugOverlay(model: model)
                .padding(.top, DS.Spacing.md)
        }
        .sheet(
            isPresented: Binding<Bool>.optional($model.lastCompletedSession)
        ) {
            if let type = model.lastCompletedSession {
                SessionCompletionSheet(
                    sessionType: type,
                    onStartBreak: { model.startBreakAfterCompletion(minutes: 5) },
                    onStartNewSession: { model.restartLastSession() },
                    onDismiss: { model.dismissCompletion() }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
            }
        }
    }
}

enum iOSTab: Hashable {
    case dashboard, mixer, tasks, settings
}
#endif
