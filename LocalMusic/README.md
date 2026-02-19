# LocalMusic — Offline MP3 Player for iOS

A native SwiftUI app that lets you import MP3 files from your device and play them
offline with full background playback and lock-screen controls.

## Features

- **Library** — Import MP3/M4A files via the system document picker. Metadata (title,
  artist, artwork, duration) is extracted automatically. Search and sort your library.
- **Playlists** — Create, rename, and reorder playlists. A song can appear multiple
  times in the same playlist.
- **Now Playing** — Full-screen view with artwork, scrubber, play/pause, next/prev,
  shuffle, and repeat (off / all / one).
- **Background Playback** — Plays audio when the app is backgrounded. Lock-screen and
  Control Center controls work via `MPRemoteCommandCenter`.
- **Resume** — Saves the current queue, position, and settings to `UserDefaults`; restores
  on next launch.
- **Core Data** — Songs, Playlists, and PlaylistItems are persisted with Core Data.

## Requirements

| Tool       | Minimum Version |
|------------|----------------|
| Xcode      | 15.0+          |
| iOS Target | 17.0+          |
| XcodeGen   | 2.38+          |
| macOS      | 14 (Sonoma)+   |

## Quick Start

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Generate the Xcode Project

```bash
cd LocalMusic
xcodegen generate
```

This creates `LocalMusic.xcodeproj` from `project.yml`.

### 3. Open in Xcode

```bash
open LocalMusic.xcodeproj
```

### 4. Configure Signing

1. Select the **LocalMusic** target in Xcode.
2. Go to **Signing & Capabilities**.
3. Choose your **Team** and set a unique **Bundle Identifier**
   (e.g., `com.yourname.localmusic`).
4. Ensure **Background Modes → Audio, AirPlay, and Picture in Picture** is checked
   (this should already be set via Info.plist).

### 5. Build & Run

- Select an iOS 17+ simulator or a connected device.
- Press **⌘R** to build and run.

## Running Tests

### Unit Tests

```bash
xcodebuild test \
  -project LocalMusic.xcodeproj \
  -scheme LocalMusicTests \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

### UI Tests

```bash
xcodebuild test \
  -project LocalMusic.xcodeproj \
  -scheme LocalMusicUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

## CI

The `.github/workflows/ci.yml` workflow runs on every push/PR to `main`:
1. Installs XcodeGen
2. Generates the Xcode project
3. Builds the app
4. Runs unit tests

## Project Structure

```
LocalMusic/
├── .github/workflows/ci.yml         # GitHub Actions CI
├── project.yml                       # XcodeGen project spec
├── LocalMusic/
│   ├── Info.plist                    # Background audio + document types
│   ├── LocalMusic.entitlements
│   ├── App/
│   │   └── LocalMusicApp.swift       # @main entry point
│   ├── Models/
│   │   ├── LocalMusic.xcdatamodeld/  # Core Data model (Song, Playlist, PlaylistItem)
│   │   ├── RepeatMode.swift          # off / repeatAll / repeatOne
│   │   └── QueueState.swift          # Codable struct persisted to UserDefaults
│   ├── Services/
│   │   ├── CoreDataStack.swift       # NSPersistentContainer wrapper
│   │   ├── DBService.swift           # CRUD operations
│   │   ├── MetadataService.swift     # AVAsset metadata extraction
│   │   ├── AudioService.swift        # AVPlayer singleton + queue management
│   │   └── RemoteCommandService.swift# MPRemoteCommandCenter handlers
│   ├── ViewModels/
│   │   ├── LibraryViewModel.swift
│   │   ├── NowPlayingViewModel.swift
│   │   └── PlaylistViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift         # Tab bar + mini player
│   │   ├── LibraryView.swift         # Song list with search/sort/import
│   │   ├── NowPlayingView.swift      # Full-screen playback controls
│   │   ├── PlaylistsView.swift       # Playlist list + create
│   │   ├── PlaylistDetailView.swift  # Playlist songs + reorder/add
│   │   ├── SongRowView.swift         # Reusable song row
│   │   └── DocumentPicker.swift      # UIDocumentPicker wrapper
│   └── Resources/
│       └── Assets.xcassets/
├── LocalMusicTests/
│   ├── DBServiceTests.swift          # Core Data CRUD tests
│   └── QueueLogicTests.swift         # RepeatMode + QueueState tests
└── LocalMusicUITests/
    └── ImportPlayFlowTests.swift     # UI navigation + import flow tests
```

## Acceptance Tests Checklist

### Import & Library
- [ ] Tap **+** in Library → document picker opens
- [ ] Select one or more MP3 files → files appear in Library with correct title, artist, duration
- [ ] Artwork thumbnail displays if the MP3 has embedded art
- [ ] Search by title or artist filters the list
- [ ] Sort by Title / Artist / Date Added changes order
- [ ] Swipe-to-delete removes song from library and disk

### Playback
- [ ] Tap a song in Library → playback starts, mini player bar appears
- [ ] Mini player shows title, artist, play/pause, next buttons
- [ ] Tap mini player → full Now Playing screen opens
- [ ] Play/pause button works
- [ ] Next/previous buttons work
- [ ] Scrubber reflects current position and allows seeking

### Shuffle & Repeat
- [ ] Toggle shuffle → songs play in random order
- [ ] Toggle shuffle off → original order restored
- [ ] Cycle repeat: off → repeat all → repeat one → off
- [ ] Repeat one replays the current track
- [ ] Repeat all loops back to first song after last

### Playlists
- [ ] Create a new playlist via Playlists tab
- [ ] Navigate into playlist → add songs via + menu
- [ ] Same song can be added multiple times
- [ ] Reorder songs via Edit mode drag handles
- [ ] Delete songs from playlist via swipe
- [ ] Tap song in playlist → plays from that position

### Background Playback & Lock Screen
- [ ] Start playback, press Home/swipe up → audio continues
- [ ] Lock screen shows song title, artist, artwork
- [ ] Lock screen play/pause works
- [ ] Lock screen next/previous works
- [ ] Lock screen scrubber works
- [ ] Control Center shows correct info and responds to controls

### Resume
- [ ] Play a song, seek to middle, force-quit app
- [ ] Relaunch → app shows the same song, scrubber at saved position
- [ ] Tap play → resumes from saved position

### Manual Verification Steps for Background + Lock Screen

1. Build and run on a **physical device** (simulators have limited audio session support).
2. Import at least 3 MP3 files.
3. Start playing a song.
4. Press the **Home button** (or swipe up) — verify audio keeps playing.
5. Lock the device — verify the lock screen shows:
   - Song title and artist
   - Album artwork (if present)
   - Play/pause, forward, backward controls
   - A working scrubber/progress bar
6. Use the lock screen controls to pause, skip, and seek.
7. Open **Control Center** and verify the same controls work there.
8. Use wired/Bluetooth headphones and test the play/pause button on the headset.
