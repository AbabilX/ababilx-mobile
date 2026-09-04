package com.ababilx.app.mediasend

private const val MB = 1024L * 1024L

/**
 * How hard a picture is squeezed before it leaves the phone.
 *
 * Signal's two levels, carrying its own numbers (`PushMediaConstraints`
 * `MediaConfig.LEVEL_2` and `LEVEL_3`): a longest-side target is tried in
 * order and the first encode that lands under the byte cap wins. A photo that
 * is already small keeps every pixel it had; a 12 MP one is not sent whole.
 *
 * [STANDARD] is the default, and deliberately so — the person picking is
 * rarely the person paying for the download.
 */
enum class MediaQuality(
    val code: Int,
    val maxBytes: Long,
    val sizeTargets: IntArray,
    val jpegQuality: Int,
) {
    STANDARD(0, (1.5 * MB).toLong(), intArrayOf(2048, 1600, 1024, 768, 512), 75),
    HIGH(1, 3 * MB, intArrayOf(4096, 3072, 2048, 1600, 1024, 768, 512), 75);

    /** Largest side this level will ever send. */
    val largestTarget: Int get() = sizeTargets.first()

    companion object {
        fun fromCode(code: Int): MediaQuality =
            if (code == HIGH.code) HIGH else STANDARD
    }
}
