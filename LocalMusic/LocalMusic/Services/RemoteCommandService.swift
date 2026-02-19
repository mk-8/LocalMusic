import MediaPlayer

/// Registers MPRemoteCommandCenter handlers so the app responds to
/// lock-screen / Control Center / headphone controls.
/// Call `setup()` once at app launch.
@MainActor
enum RemoteCommandService {
    static func setup() {
        let center = MPRemoteCommandCenter.shared()
        let audio = AudioService.shared

        center.playCommand.addTarget { _ in
            audio.play()
            return .success
        }
        center.pauseCommand.addTarget { _ in
            audio.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            audio.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { _ in
            audio.next()
            return .success
        }
        center.previousTrackCommand.addTarget { _ in
            audio.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            audio.seek(to: posEvent.positionTime)
            return .success
        }
    }
}
