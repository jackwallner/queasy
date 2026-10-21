package com.jackwallner.queasy.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.queasy.model.ReliefEpisode
import java.io.File

/** Where the episode log lives. A file on device, an in-memory string in tests. */
interface EpisodeFile {
    fun read(): String?
    fun write(text: String): Boolean
}

/** Write-then-rename, so a crash mid-save never leaves half a log. */
class AtomicEpisodeFile(dir: File) : EpisodeFile {
    private val file = File(dir, "episodes.json")

    override fun read(): String? = file.takeIf { it.exists() }?.readText()

    override fun write(text: String): Boolean = runCatching {
        val tmp = File(file.parentFile, "episodes.json.tmp")
        tmp.writeText(text)
        check(tmp.renameTo(file))
    }.isSuccess
}

/**
 * The SwiftData store of this port: every relief episode, newest first,
 * observable by Compose. Upserts by uuid, like `persistEpisode` on iOS.
 */
class EpisodeStore(private val file: EpisodeFile) {
    var episodes by mutableStateOf(load())
        private set

    /** Set when a save fails; the root screen shows it as the iOS "Not saved" alert. */
    var saveFailure by mutableStateOf<String?>(null)

    fun upsert(episode: ReliefEpisode) {
        val others = episodes.filterNot { it.uuid == episode.uuid }
        commit(others + episode)
    }

    fun delete(uuid: String) = commit(episodes.filterNot { it.uuid == uuid })

    fun replaceAll(next: List<ReliefEpisode>) = commit(next)

    private fun commit(next: List<ReliefEpisode>) {
        val sorted = next.sortedByDescending { it.startedAt }
        episodes = sorted
        if (!file.write(EpisodeCodec.encode(sorted))) {
            saveFailure = "Queasy couldn't save that session. Free up some storage and try again."
        }
    }

    private fun load(): List<ReliefEpisode> =
        file.read()?.let(EpisodeCodec::decode).orEmpty().sortedByDescending { it.startedAt }
}
