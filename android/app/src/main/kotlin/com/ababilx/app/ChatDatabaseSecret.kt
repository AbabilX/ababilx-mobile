package com.ababilx.app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Protects the SQLCipher passphrase with a non-exportable Android Keystore key. */
object ChatDatabaseSecret {
    private const val KEY_ALIAS = "ababilx.chat.database.v1"
    private const val FILE_NAME = "ababilx_chat_secret_v1"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val IV_BYTES = 12

    @Volatile
    private var cached: String? = null

    @Synchronized
    fun get(context: Context): String {
        cached?.let { return it }
        val appContext = context.applicationContext
        val file = File(appContext.noBackupFilesDir, FILE_NAME)
        val value = if (file.exists()) {
            decrypt(file.readBytes(), key())
        } else {
            createAndPersist(file, key())
        }
        cached = value
        return value
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    private fun createAndPersist(file: File, key: SecretKey): String {
        val raw = ByteArray(32).also(SecureRandom()::nextBytes)
        val encoded = Base64.encodeToString(raw, Base64.NO_WRAP)
        raw.fill(0)
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.ENCRYPT_MODE, key)
        }
        val sealed = cipher.iv + cipher.doFinal(encoded.toByteArray(Charsets.UTF_8))
        val temporary = File(file.parentFile, "$FILE_NAME.tmp")
        temporary.outputStream().use { output ->
            output.write(sealed)
            output.fd.sync()
        }
        check(temporary.renameTo(file)) { "Could not persist encrypted database secret" }
        return encoded
    }

    private fun decrypt(sealed: ByteArray, key: SecretKey): String {
        require(sealed.size > IV_BYTES) { "Encrypted database secret is invalid" }
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(
                Cipher.DECRYPT_MODE,
                key,
                GCMParameterSpec(128, sealed.copyOfRange(0, IV_BYTES)),
            )
        }
        val plaintext = cipher.doFinal(sealed.copyOfRange(IV_BYTES, sealed.size))
        return plaintext.toString(Charsets.UTF_8).also { plaintext.fill(0) }
    }
}
