import SwiftUI

struct UpNextView: View {
    @EnvironmentObject private var audio: AudioService
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    private let db = DBService()

    private var upNextFileNames: [String] {
        let start = audio.currentIndex + 1
        guard start < audio.activeQueue.count else { return [] }
        return Array(audio.activeQueue[start...])
    }

    var body: some View {
        NavigationStack {
            List {
                nowPlayingSection
                upNextSection
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !upNextFileNames.isEmpty {
                        Button(isEditing ? "Finish" : "Edit") {
                            isEditing.toggle()
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("upNextView")
    }

    // MARK: - Now Playing Section

    @ViewBuilder
    private var nowPlayingSection: some View {
        if let song = audio.currentSong {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color.accentColor)
                        .imageScale(.small)
                    SongRowView(song: song)
                }
                .listRowBackground(Color.accentColor.opacity(0.08))
            } header: {
                Text("Now Playing")
            }
        }
    }

    // MARK: - Up Next Section

    @ViewBuilder
    private var upNextSection: some View {
        Section {
            if upNextFileNames.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "text.append")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Queue is empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(Array(upNextFileNames.enumerated()), id: \.offset) { localIndex, fileName in
                    if let song = db.song(byFileName: fileName) {
                        SongRowView(song: song)
                            .onTapGesture {
                                let globalIndex = audio.currentIndex + 1 + localIndex
                                audio.skipToQueueIndex(globalIndex)
                            }
                    } else {
                        // Fallback for a fileName with no DB record (shouldn't normally happen)
                        Label(fileName, systemImage: "music.note")
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    // Translate local offsets to global indices, delete from highest first
                    // to avoid index shifting during removal.
                    let globalIndices = offsets
                        .map { audio.currentIndex + 1 + $0 }
                        .sorted(by: >)
                    for idx in globalIndices {
                        audio.removeFromQueue(at: idx)
                    }
                }
                .onMove { source, destination in
                    audio.moveUpNextItem(from: source, to: destination)
                }
            }
        } header: {
            if !upNextFileNames.isEmpty {
                Text("\(upNextFileNames.count) song\(upNextFileNames.count == 1 ? "" : "s") up next")
            }
        }
    }
}

