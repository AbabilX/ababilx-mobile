package com.ababilx.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The phone's own lock — fingerprint, face, or the screen PIN / pattern /
 * password — for a locked chat.
 *
 * The framework [BiometricPrompt], not androidx.biometric and not the
 * local_auth plugin: both need a FragmentActivity, and MainActivity is a
 * FlutterActivity that the call lock screen and media send are built around.
 *
 * API 30+ offers biometrics or the screen lock in one prompt; API 29 does the
 * same through setDeviceCredentialAllowed; below that only the screen lock,
 * through KeyguardManager's confirm screen. Every call answers exactly once:
 * "ok", "cancelled", "failed", "unavailable" (no screen lock) or "busy".
 */
class DeviceAuthChannel(private val activity: Activity) {

  private var pending: MethodChannel.Result? = null

  fun attach(engine: FlutterEngine) {
    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "available" -> result.success(isSecure())
          "authenticate" -> authenticate(
            call.argument<String>("title") ?: "",
            call.argument<String>("subtitle") ?: "",
            result,
          )
          else -> result.notImplemented()
        }
      }
  }

  /** The confirm screen's answer below API 29. True when it was ours. */
  fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
    if (requestCode != REQUEST_CONFIRM) return false
    finish(if (resultCode == Activity.RESULT_OK) "ok" else "cancelled")
    return true
  }

  private fun keyguard(): KeyguardManager =
    activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager

  private fun isSecure(): Boolean =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) keyguard().isDeviceSecure
    else keyguard().isKeyguardSecure

  private fun authenticate(title: String, subtitle: String, result: MethodChannel.Result) {
    if (pending != null) {
      result.success("busy")
      return
    }
    if (!isSecure()) {
      result.success("unavailable")
      return
    }
    pending = result
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) prompt(title, subtitle)
      else confirmCredential(title, subtitle)
    } catch (_: Exception) {
      finish("failed")
    }
  }

  @RequiresApi(Build.VERSION_CODES.Q)
  private fun prompt(title: String, subtitle: String) {
    val builder = BiometricPrompt.Builder(activity).setTitle(title)
    if (subtitle.isNotEmpty()) builder.setSubtitle(subtitle)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      builder.setAllowedAuthenticators(
        BiometricManager.Authenticators.BIOMETRIC_WEAK or
          BiometricManager.Authenticators.DEVICE_CREDENTIAL,
      )
    } else {
      @Suppress("DEPRECATION")
      builder.setDeviceCredentialAllowed(true)
    }
    builder.build().authenticate(
      CancellationSignal(),
      activity.mainExecutor,
      object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult?) {
          finish("ok")
        }

        // One wrong finger is onAuthenticationFailed, which leaves the prompt
        // up for another try; only a terminal error lands here.
        override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) {
          finish(
            when (errorCode) {
              BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
              BiometricPrompt.BIOMETRIC_ERROR_CANCELED -> "cancelled"
              else -> "failed"
            },
          )
        }
      },
    )
  }

  private fun confirmCredential(title: String, subtitle: String) {
    @Suppress("DEPRECATION")
    val intent = keyguard().createConfirmDeviceCredentialIntent(title, subtitle.ifEmpty { null })
    if (intent == null) {
      finish("unavailable")
      return
    }
    @Suppress("DEPRECATION")
    activity.startActivityForResult(intent, REQUEST_CONFIRM)
  }

  private fun finish(outcome: String) {
    val result = pending ?: return
    pending = null
    result.success(outcome)
  }

  private companion object {
    const val CHANNEL = "com.ababilx.app/device_auth"
    const val REQUEST_CONFIRM = 7431
  }
}
