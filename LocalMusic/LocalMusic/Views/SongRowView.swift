import SwiftUI

struct SongRowView: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            artworkThumbnail
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title ?? "Unknown")
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(song.artist ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formattedDuration)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .accessibilityIdentifier("songRow_\(song.fileName ?? "")")
    }

    @ViewBuilder
    private var artworkThumbnail: some View {
        if let data = song.artworkData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var formattedDuration: String {
        let total = Int(song.duration)
        guard total > 0 else { return "--:--" }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
