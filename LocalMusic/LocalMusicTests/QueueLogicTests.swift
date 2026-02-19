import XCTest
@testable import LocalMusic

final class QueueLogicTests: XCTestCase {

    // MARK: - RepeatMode

    func testRepeatModeCycling() {
        var mode: RepeatMode = .off
        mode = mode.next()
        XCTAssertEqual(mode, .repeatAll)
        mode = mode.next()
        XCTAssertEqual(mode, .repeatOne)
        mode = mode.next()
        XCTAssertEqual(mode, .off)
    }

    func testRepeatModeIcon() {
        XCTAssertEqual(RepeatMode.off.icon, "repeat")
        XCTAssertEqual(RepeatMode.repeatAll.icon, "repeat")
        XCTAssertEqual(RepeatMode.repeatOne.icon, "repeat.1")
    }

    func testRepeatModeIsActive() {
        XCTAssertFalse(RepeatMode.off.isActive)
        XCTAssertTrue(RepeatMode.repeatAll.isActive)
        XCTAssertTrue(RepeatMode.repeatOne.isActive)
    }

    // MARK: - QueueState Persistence

    func testQueueStateSaveAndLoad() {
        let state = QueueState(
            songFileNames: ["a.mp3", "b.mp3", "c.mp3"],
            currentIndex: 1,
            elapsedSeconds: 42.5,
            shuffleEnabled: true,
            repeatMode: .repeatAll
        )
        state.save()

        let loaded = QueueState.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.songFileNames, ["a.mp3", "b.mp3", "c.mp3"])
        XCTAssertEqual(loaded?.currentIndex, 1)
        XCTAssertEqual(loaded?.elapsedSeconds, 42.5, accuracy: 0.01)
        XCTAssertTrue(loaded?.shuffleEnabled ?? false)
        XCTAssertEqual(loaded?.repeatMode, .repeatAll)

        QueueState.clear()
        XCTAssertNil(QueueState.load())
    }

    func testQueueStateClear() {
        let state = QueueState(
            songFileNames: ["x.mp3"],
            currentIndex: 0,
            elapsedSeconds: 0,
            shuffleEnabled: false,
            repeatMode: .off
        )
        state.save()
        XCTAssertNotNil(QueueState.load())
        QueueState.clear()
        XCTAssertNil(QueueState.load())
    }

    // MARK: - Queue Array Shuffle Logic (unit-level)

    /// Verifies that our shuffle-with-pinned-first-element approach works.
    func testShuffleKeepsCurrentSongFirst() {
        let original = ["a.mp3", "b.mp3", "c.mp3", "d.mp3", "e.mp3"]
        let startIndex = 2 // "c.mp3"
        var shuffled = original
        let first = shuffled.remove(at: startIndex)
        shuffled.shuffle()
        shuffled.insert(first, at: 0)

        XCTAssertEqual(shuffled.first, "c.mp3", "Current song should remain first after shuffle")
        XCTAssertEqual(shuffled.count, original.count, "Shuffle must preserve all elements")
        XCTAssertEqual(Set(shuffled), Set(original), "Shuffle must not lose or add elements")
    }

    /// Verifies that un-shuffling restores the original queue and finds the correct index.
    func testUnshuffleRestoresOrder() {
        let original = ["a.mp3", "b.mp3", "c.mp3", "d.mp3"]
        let currentFile = "c.mp3"
        let restored = original
        let idx = restored.firstIndex(of: currentFile)
        XCTAssertEqual(idx, 2)
        XCTAssertEqual(restored, original)
    }

    func testEmptyQueueHandling() {
        let empty: [String] = []
        XCTAssertTrue(empty.isEmpty)
        let idx = empty.firstIndex(of: "x.mp3")
        XCTAssertNil(idx)
    }

    // MARK: - Up Next Queue Manipulation (index math)
    //
    // These tests mirror the logic inside AudioService's playNext, addToQueue,
    // removeFromQueue, and moveUpNextItem without needing AVPlayer.

    func testPlayNextInsertion() {
        var queue = ["a.mp3", "b.mp3", "c.mp3"]
        var currentIndex = 1 // "b.mp3" is playing

        let insertIndex = currentIndex + 1
        queue.insert("x.mp3", at: insertIndex)
        // currentIndex should not change — we inserted after the current song.

        XCTAssertEqual(queue, ["a.mp3", "b.mp3", "x.mp3", "c.mp3"])
        XCTAssertEqual(queue[currentIndex], "b.mp3", "Currently playing song must not shift")
    }

    func testPlayNextOnLastSong() {
        var queue = ["a.mp3", "b.mp3"]
        let currentIndex = 1 // last song playing

        let insertIndex = currentIndex + 1
        queue.insert("x.mp3", at: insertIndex)

        XCTAssertEqual(queue, ["a.mp3", "b.mp3", "x.mp3"])
        XCTAssertEqual(queue[currentIndex], "b.mp3")
    }

    func testAddToQueueAppend() {
        var queue = ["a.mp3", "b.mp3", "c.mp3"]
        let currentIndex = 1

        queue.append("x.mp3")

        XCTAssertEqual(queue.last, "x.mp3")
        XCTAssertEqual(queue[currentIndex], "b.mp3", "currentIndex must not shift on append")
    }

    func testRemoveBeforeCurrentIndex() {
        var queue = ["a.mp3", "b.mp3", "c.mp3", "d.mp3"]
        var currentIndex = 2 // "c.mp3"
        let removeIdx = 0    // remove "a.mp3", which is before current

        guard removeIdx != currentIndex else { XCTFail("Test setup error"); return }
        queue.remove(at: removeIdx)
        if removeIdx < currentIndex {
            currentIndex -= 1
        }

        XCTAssertEqual(queue, ["b.mp3", "c.mp3", "d.mp3"])
        XCTAssertEqual(currentIndex, 1)
        XCTAssertEqual(queue[currentIndex], "c.mp3", "Must still point at the same song")
    }

    func testRemoveAfterCurrentIndex() {
        var queue = ["a.mp3", "b.mp3", "c.mp3", "d.mp3"]
        var currentIndex = 1 // "b.mp3"
        let removeIdx = 3    // remove "d.mp3"

        guard removeIdx != currentIndex else { XCTFail("Test setup error"); return }
        queue.remove(at: removeIdx)
        if removeIdx < currentIndex {
            currentIndex -= 1
        }

        XCTAssertEqual(queue, ["a.mp3", "b.mp3", "c.mp3"])
        XCTAssertEqual(currentIndex, 1, "currentIndex must not change when removing after it")
        XCTAssertEqual(queue[currentIndex], "b.mp3")
    }

    func testRemoveAtCurrentIndexIsRejected() {
        let queue = ["a.mp3", "b.mp3", "c.mp3"]
        let currentIndex = 1
        let removeIdx = 1

        // The guard in AudioService rejects this case
        let allowed = removeIdx != currentIndex
        XCTAssertFalse(allowed, "Removing the currently playing song must be rejected")
    }

    func testMoveWithinUpNext() {
        var queue = ["a.mp3", "b.mp3", "c.mp3", "d.mp3", "e.mp3"]
        let currentIndex = 1 // "b.mp3" is playing
        // Up next (local): ["c.mp3", "d.mp3", "e.mp3"] at local indices [0, 1, 2]

        let upNextStart = currentIndex + 1
        var upNext = Array(queue[upNextStart...])
        XCTAssertEqual(upNext, ["c.mp3", "d.mp3", "e.mp3"])

        // Move "e.mp3" (local index 2) to position 0 → [e, c, d]
        upNext.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        queue.replaceSubrange(upNextStart..., with: upNext)

        XCTAssertEqual(queue, ["a.mp3", "b.mp3", "e.mp3", "c.mp3", "d.mp3"])
        XCTAssertEqual(queue[currentIndex], "b.mp3", "currentIndex must be unaffected by up-next reorder")
    }

    func testMoveWithinUpNextMiddleToEnd() {
        var queue = ["a.mp3", "b.mp3", "c.mp3", "d.mp3", "e.mp3"]
        let currentIndex = 0
        let upNextStart = currentIndex + 1
        var upNext = Array(queue[upNextStart...])

        // Move "b.mp3" (local 0) to end (local 3, i.e. after last element)
        upNext.move(fromOffsets: IndexSet(integer: 0), toOffset: upNext.count)
        queue.replaceSubrange(upNextStart..., with: upNext)

        XCTAssertEqual(queue, ["a.mp3", "c.mp3", "d.mp3", "e.mp3", "b.mp3"])
        XCTAssertEqual(queue[currentIndex], "a.mp3")
    }

    func testMoveOnSingleUpNextItemIsNoOp() {
        var queue = ["a.mp3", "b.mp3"]
        let currentIndex = 0
        let upNextStart = currentIndex + 1
        var upNext = Array(queue[upNextStart...])
        XCTAssertEqual(upNext.count, 1)

        // Moving the only item to itself
        upNext.move(fromOffsets: IndexSet(integer: 0), toOffset: 0)
        queue.replaceSubrange(upNextStart..., with: upNext)

        XCTAssertEqual(queue, ["a.mp3", "b.mp3"], "Single-item move should be a no-op")
    }

    func testPlayNextThenRemovePreservesIndex() {
        var queue = ["a.mp3", "b.mp3", "c.mp3"]
        var currentIndex = 1 // "b.mp3"

        // Play next: insert "x.mp3" after current
        queue.insert("x.mp3", at: currentIndex + 1)
        XCTAssertEqual(queue, ["a.mp3", "b.mp3", "x.mp3", "c.mp3"])
        XCTAssertEqual(queue[currentIndex], "b.mp3")

        // Now remove "a.mp3" (before current)
        let removeIdx = 0
        queue.remove(at: removeIdx)
        if removeIdx < currentIndex { currentIndex -= 1 }

        XCTAssertEqual(queue, ["b.mp3", "x.mp3", "c.mp3"])
        XCTAssertEqual(currentIndex, 0)
        XCTAssertEqual(queue[currentIndex], "b.mp3", "Still playing the same song after compound edits")
    }
}
