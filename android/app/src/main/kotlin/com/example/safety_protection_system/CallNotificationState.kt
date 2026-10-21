package com.example.safety_protection_system

/**
 * Tracks passenger calls independently from Android UI objects.
 *
 * The ESP32 broadcasts a complete roster every 0.5s. Keeping the last set
 * here makes identical broadcasts no-ops, while Flutter/native duplicate
 * triggers are folded into the same state.
 *
 * Includes a suppression window on cleared seats so delayed in-flight frames
 * from Master cannot resurrect calls that the driver already acknowledged.
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
    private val clearedCooldowns = mutableMapOf<String, Long>()

    companion object {
        private const val CLEAR_SUPPRESSION_MS = 3500L

        fun parseSeatIds(raw: String): Set<String> = normalize(raw.split(','))

        private fun normalize(seats: Collection<String>): LinkedHashSet<String> =
            seats.asSequence()
                .map(String::trim)
                .filter(String::isNotEmpty)
                .toCollection(linkedSetOf())
    }

    @Synchronized
    fun replaceWithSnapshot(seats: Collection<String>): Transition {
        val normalized = normalize(seats)
        val now = System.currentTimeMillis()

        // Bersihkan cooldown yang sudah kadaluarsa
        clearedCooldowns.entries.removeAll { it.value <= now }

        // Jika master sudah mengonfirmasi kursi tidak lagi calling, hapus dari cooldown
        val clearedNow = clearedCooldowns.keys.filter { it !in normalized }
        clearedNow.forEach { clearedCooldowns.remove(it) }

        // Saring kursi yang masih dalam masa cooldown penekanan
        val suppressed = normalized.filterTo(linkedSetOf()) { seat ->
            val expireTime = clearedCooldowns[seat]
            expireTime == null || now >= expireTime
        }
        return replace(suppressed)
    }

    @Synchronized
    fun addCalls(seats: Collection<String>): Transition {
        val normalized = normalize(seats)
        val now = System.currentTimeMillis()

        // Bersihkan cooldown yang sudah kadaluarsa
        clearedCooldowns.entries.removeAll { it.value <= now }

        // Jangan masukkan jika kursi masih dalam masa cooldown penekanan
        val allowed = normalized.filterTo(linkedSetOf()) { seat ->
            val expireTime = clearedCooldowns[seat]
            expireTime == null || now >= expireTime
        }

        val next = LinkedHashSet(activeSeats)
        next.addAll(allowed)
        return replace(next)
    }

    @Synchronized
    fun clearCalls(seats: Collection<String>): Transition {
        val normalized = normalize(seats)
        val now = System.currentTimeMillis()
        normalized.forEach { seat ->
            clearedCooldowns[seat] = now + CLEAR_SUPPRESSION_MS
        }
        val next = LinkedHashSet(activeSeats)
        next.removeAll(normalized)
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
}
