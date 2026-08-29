package com.ababilx.app

/** Loads SQLCipher's native library once, before any Activity opens the DB. */
object SqlCipherLibraryLoader {
    @Volatile
    private var loaded = false

    @Synchronized
    fun load() {
        if (loaded) return
        System.loadLibrary("sqlcipher")
        loaded = true
    }
}
