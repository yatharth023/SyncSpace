//
//  SyncSpaceApp.swift
//  SyncSpace
//
//  Single multi-platform target. macOS launches the productivity hub
//  (host); iOS launches the remote dashboard. The same AppModel runs on
//  both, only its `role` and bound services differ.
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
            // SwiftData failure: fall back to in-memory so the UI is still usable.
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
        .windowToolbarStyle(.unified(showsTitle: true))
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
        Text("SyncSpace is available on macOS and iOS.")
            .padding()
        #endif
    }
}
