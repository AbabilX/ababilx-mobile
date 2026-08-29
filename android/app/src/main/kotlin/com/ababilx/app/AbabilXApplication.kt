package com.ababilx.app

import android.app.Application

/**
 * Exists so [CallEventBridge] is installed in every process, including one
 * created by the CallKit broadcast or an FCM push where `main()` never runs.
 */
class AbabilXApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        SqlCipherLibraryLoader.load()
        CallEventBridge.install(this)
    }
}
