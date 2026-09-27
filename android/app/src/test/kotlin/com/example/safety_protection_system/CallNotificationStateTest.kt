package com.example.safety_protection_system

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CallNotificationStateTest {
    @Test
    fun repeatedRosterIsANoOp() {
        val state = CallNotificationState()

        val first = state.replaceWithSnapshot(listOf("1A"))
        val repeated = state.replaceWithSnapshot(listOf("1A"))

        assertEquals(setOf("1A"), first.added)
        assertTrue(first.changed)
        assertFalse(repeated.changed)
        assertEquals(setOf("1A"), repeated.active)
        repeat(1_000) {
            assertFalse(state.replaceWithSnapshot(listOf("1A")).changed)
        }
    }

    @Test
    fun flutterAndNativeDuplicateTriggerIsFolded() {
        val state = CallNotificationState()

        assertTrue(state.addCalls(listOf("2B")).changed)
        assertFalse(state.replaceWithSnapshot(listOf("2B")).changed)
        assertFalse(state.addCalls(listOf("2B")).changed)
    }

    @Test
    fun snapshotAddsAndRemovesSeatsIndividually() {
        val state = CallNotificationState()
        state.replaceWithSnapshot(listOf("1A", "2B"))

        val changed = state.replaceWithSnapshot(listOf("2B", "3C"))

        assertEquals(setOf("3C"), changed.added)
        assertEquals(setOf("1A"), changed.removed)
        assertEquals(setOf("2B", "3C"), changed.active)
    }

    @Test
    fun clearCombinedTextProducesSeparateSeatIds() {
        val state = CallNotificationState()
        state.replaceWithSnapshot(listOf("1A", "2B", "3C"))

        val ids = CallNotificationState.parseSeatIds("1A,  3C")
        val changed = state.clearCalls(ids)

        assertEquals(setOf("1A", "3C"), changed.removed)
        assertEquals(setOf("2B"), changed.active)
    }

    @Test
    fun emptySnapshotClearsPersistentNotificationState() {
        val state = CallNotificationState()
        state.replaceWithSnapshot(listOf("4D"))

        val cleared = state.replaceWithSnapshot(emptyList())

        assertTrue(cleared.changed)
        assertEquals(setOf("4D"), cleared.removed)
        assertTrue(cleared.active.isEmpty())
    }
}
