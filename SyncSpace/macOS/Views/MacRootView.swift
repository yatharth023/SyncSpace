//
//  MacRootView.swift
//  SyncSpace
//
//  Mac shell. Toolbar title is now centred with `.principal` placement and
//  proper padding. The ambient backdrop sits at the window root so it
//  doesn't redraw on every sidebar selection.
//

#if os(macOS)
import SwiftUI

public enum MacDestination: String, CaseIterable, Identifiable, Hashable {
    case focus, tasks, audio, analytics, settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .focus:        return "Focus"
        case .tasks:        return "Tasks"
        case .audio:        return "Audio Mixer"
        case .analytics:    return "Analytics"
        case .settings:     return "Settings"
        }
    }

    public var navigationTitle: String {
        switch self {
        case .focus:        return "Focus Session"
        default:            return title
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

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            MacSidebar(selection: $selection, model: model)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            // The PageHeaderCapsule lives in the content area, not the
            // toolbar. macOS 26 (Tahoe) wraps `.principal` toolbar items in
            // its own Liquid Glass capsule, so any custom capsule placed
            // there renders nested — two stacked pill backgrounds and two
            // stacked borders. Hosting the capsule inside the detail view
            // gives us a single, well-padded, content-owned pill.
            VStack(spacing: 0) {
                PageHeaderCapsule(selection.navigationTitle)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.xs)
                detailContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BreathingBackground(intensity: 0.35))
            .overlay(alignment: .bottomTrailing) {
                SyncDebugOverlay(model: model)
            }
        }
        .navigationSplitViewStyle(.balanced)
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
                .frame(width: 460)
            }
        }
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
}
#endif
