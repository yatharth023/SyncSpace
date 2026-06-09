//
//  MacRootView.swift
//  SyncSpace
//
//  Top-level macOS layout: NavigationSplitView with the sidebar, a
//  destination column that switches between the main features, and a
//  breathing gradient backdrop tying the experience together.
//

#if os(macOS)
import SwiftUI

public enum MacDestination: String, CaseIterable, Identifiable {
    case focus, tasks, audio, analytics, settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .focus:        return "Focus Session"
        case .tasks:        return "Tasks"
        case .audio:        return "Audio Mixer"
        case .analytics:    return "Analytics"
        case .settings:     return "Settings"
        }
    }

    public var symbol: String {
        switch self {
        case .focus:        return "timer"
        case .tasks:        return "checklist"
        case .audio:        return "slider.vertical.3"
        case .analytics:    return "chart.bar.xaxis"
        case .settings:     return "gearshape"
        }
    }
}

public struct MacRootView: View {
    @Bindable var model: AppModel
    @State private var selection: MacDestination = .focus
    @State private var showInspector: Bool = true

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            MacSidebar(selection: $selection, model: model)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            ZStack {
                BreathingBackground(
                    palette: backgroundPalette,
                    intensity: 0.55,
                    pulse: model.pulse
                )
                .opacity(0.85)

                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(selection.title)
                        .font(.title3.weight(.semibold))
                }
                ToolbarItem(placement: .primaryAction) {
                    ConnectionBadge(
                        status: model.peerManager.status,
                        peerNames: model.peerManager.connectedPeerNames
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .focus:        FocusSessionScreen(model: model)
        case .tasks:        TasksScreen(model: model)
        case .audio:        AudioMixerScreen(model: model)
        case .analytics:    AnalyticsScreen(model: model)
        case .settings:     SettingsScreen(model: model)
        }
    }

    private var backgroundPalette: [Color] {
        switch selection {
        case .focus:        return [AppTheme.electricIndigo, AppTheme.plum, AppTheme.cyan]
        case .tasks:        return [AppTheme.cyan, AppTheme.mint, AppTheme.electricIndigo]
        case .audio:        return [AppTheme.plum, AppTheme.electricIndigo, AppTheme.cyan]
        case .analytics:    return [AppTheme.mint, AppTheme.cyan, AppTheme.electricIndigo]
        case .settings:     return [Color.gray.opacity(0.4), AppTheme.electricIndigo, Color.black]
        }
    }
}
#endif
