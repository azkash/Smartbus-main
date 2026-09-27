package com.example.safety_protection_system

/**
 * Tracks passenger calls independently from Android UI objects.
 *
 * The ESP32 broadcasts a complete roster every second. Keeping the last set
 * here makes identical broadcasts no-ops, while Flutter/native duplicate
 * triggers are folded into the same state.
 */
class CallNotificationState {
    data class Transition(
        val active: Set<String>,
        val added: Set<String>,
        val removed: Set<String>,
    ) {
        val changed: Boolean get() = added.isNotEmpty() || removed.isNotEmpty()
    }

    private val activeSeats = linkedSetOf<String>()

    @Synchronized
    fun replaceWithSnapshot(seats: Collection<String>): Transition =
        replace(normalize(seats))

    @Synchronized
    fun addCalls(seats: Collection<String>): Transition {
        val next = LinkedHashSet(activeSeats)
        next.addAll(normalize(seats))
        return replace(next)
    }

    @Synchronized
    fun clearCalls(seats: Collection<String>): Transition {
        val next = LinkedHashSet(activeSeats)
        next.removeAll(normalize(seats).toSet())
        return replace(next)
    }

    @Synchronized
    fun snapshot(): Set<String> = LinkedHashSet(activeSeats)

    private fun replace(next: Collection<String>): Transition {
        val normalized = LinkedHashSet(next)
        val added = normalized.filterTo(linkedSetOf()) { it !in activeSeats }
        val removed = activeSeats.filterTo(linkedSetOf()) { it !in normalized }

        if (added.isNotEmpty() || removed.isNotEmpty()) {
            activeSeats.clear()
            activeSeats.addAll(normalized)
        }

        return Transition(
            active = LinkedHashSet(activeSeats),
            added = added,
            removed = removed,
        )
    }

    companion object {
        fun parseSeatIds(raw: String): Set<String> = normalize(raw.split(','))

        private fun normalize(seats: Collection<String>): LinkedHashSet<String> =
            seats.asSequence()
                .map(String::trim)
                .filter(String::isNotEmpty)
                .toCollection(linkedSetOf())
    }
}
