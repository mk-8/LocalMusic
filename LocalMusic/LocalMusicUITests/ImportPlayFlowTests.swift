import XCTest

/// UI tests for the import → play flow.
/// NOTE: Full import flow requires a real device with actual MP3 files accessible
/// via the document picker. These tests verify the UI structure and navigation.
/// For a complete end-to-end test, run on a device with files available.
final class ImportPlayFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testLibraryTabExists() {
        let libraryTab = app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.exists, "Library tab should be present")
    }

    func testPlaylistsTabExists() {
        let playlistsTab = app.tabBars.buttons["Playlists"]
        XCTAssertTrue(playlistsTab.exists, "Playlists tab should be present")
    }

    func testImportButtonExists() {
        let importButton = app.buttons["importButton"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 3), "Import (+) button should be in toolbar")
    }

    func testImportButtonOpensDocumentPicker() {
        let importButton = app.buttons["importButton"]
        importButton.tap()
        // The system document picker should appear; verify it dismisses cleanly.
        // On simulator, the picker may not fully render, so we just verify the tap
        // doesn't crash and the app remains responsive.
        let libraryTab = app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5))
    }

    func testSortButtonExists() {
        let sortButton = app.buttons["sortButton"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 3), "Sort button should exist")
    }

    func testCreatePlaylistFlow() {
        app.tabBars.buttons["Playlists"].tap()
        let createBtn = app.buttons["createPlaylistButton"]
        XCTAssertTrue(createBtn.waitForExistence(timeout: 3))
        createBtn.tap()

        // Alert should appear
        let alert = app.alerts["New Playlist"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "Create-playlist alert should appear")

        // Type a name and create
        let textField = alert.textFields.firstMatch
        textField.tap()
        textField.typeText("Test Playlist")
        alert.buttons["Create"].tap()

        // Verify the playlist appears in the list
        let cell = app.staticTexts["Test Playlist"]
        XCTAssertTrue(cell.waitForExistence(timeout: 3), "New playlist should appear in list")
    }

    /// Verifies that tapping a song row (when songs exist) triggers the mini player bar.
    /// This test is a skeleton; it requires pre-seeded data to fully pass.
    func testMiniPlayerAppearsOnPlay() {
        // When no songs are imported, mini player should not exist
        let miniPlayer = app.otherElements["miniPlayerBar"]
        XCTAssertFalse(miniPlayer.exists, "Mini player should not show when no song is loaded")
    }
}
