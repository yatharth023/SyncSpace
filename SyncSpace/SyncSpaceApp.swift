//
//  SyncSpaceApp.swift
//  SyncSpace
//
//  Single multi-platform target. macOS launches the productivity hub (host);
//  iOS launches the remote dashboard. Theme is applied at the Scene root so
//  every window reacts immediately to changes in Settings.
//

import SwiftUI
import SwiftData

@main
struct SyncSpaceApp: App {

    private let modelContainer: ModelContainer = {
        let schema = Schema([TaskRecord.self, SessionRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallback]))
                ?? (try! ModelContainer(for: schema))
        }
    }()

    @State private var model: AppModel = {
        #if os(macOS)
        return AppModel(role: .host)
        #else
        return AppModel(role: .remote)
        #endif
    }()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .modelContainer(modelContainer)
                .appearancePreference()
                .task {
                    #if os(macOS)
                    model.attach(modelContext: modelContainer.mainContext)
                    model.startAudio()
                    #endif
                    model.startNetworking()
                }
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 760)
        // showsTitle:false — the page title now lives in the in-content
        // PageHeaderCapsule. Letting the system also render it in the
        // toolbar produced a competing title chip on macOS 26 (Tahoe).
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Session") {
                Button(model.timer.isRunning ? "Pause" : "Start") {
                    if model.timer.isRunning { model.pauseTimer() } else { model.startTimer() }
                }
                .keyboardShortcut("p", modifiers: [.command])
                Button("Reset") { model.resetTimer() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("Skip") { model.skipTimer() }
                    .keyboardShortcut(".", modifiers: [.command])
            }
        }
        #endif
    }
}

private struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        #if os(macOS)
        MacRootView(model: model)
        #elseif os(iOS)
        iOSRootView(model: model)
        #else
        Text("SyncSpace is available on macOS and iOS.").padding()
        #endif
    }
}
