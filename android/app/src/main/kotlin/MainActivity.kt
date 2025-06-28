package fr.johanstick.escive

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "escive_native_bridge"

    companion object { // https://docs.kustom.rocks/docs/developers/send_variables_broadcast/
        const val KUSTOM_ACTION = "org.kustom.action.SEND_VAR"
        const val KUSTOM_ACTION_EXT_NAME = "org.kustom.action.EXT_NAME"
        const val KUSTOM_ACTION_VAR_NAME = "org.kustom.action.VAR_NAME"
        const val KUSTOM_ACTION_VAR_VALUE = "org.kustom.action.VAR_VALUE"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentMusicStatus" -> {
                        val status = getCurrentMusicStatus()
                        result.success(status)
                    }
                    "requestNotificationAccess" -> {
                        result.success(true)
                    }
                    "isNotificationListenerEnabled" -> {
                        result.success(isNotificationListenerEnabled())
                    }
                    "openNotificationListenerSettings" -> {
                        openNotificationListenerSettings()
                        result.success(true)
                    }
                    "sendKustomVariable" -> {
                        val extName = call.argument<String>("extName")
                        val varName = call.argument<String>("varName")
                        val varValue = call.argument<String>("varValue")
                        
                        if (extName != null && varName != null && varValue != null) {
                            sendKustomVariable(extName, varName, varValue)
                            result.success("Sent to Kustom")
                        } else {
                            result.error("INVALID_ARGUMENTS", "Arguments extName, varName, and varValue are required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sendKustomVariable(extName: String, varName: String, varValue: String) {
        val intent = Intent(KUSTOM_ACTION).apply {
            putExtra(KUSTOM_ACTION_EXT_NAME, extName)
            putExtra(KUSTOM_ACTION_VAR_NAME, varName)
            putExtra(KUSTOM_ACTION_VAR_VALUE, varValue)
        }
        sendBroadcast(intent)
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val packageName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat?.contains(packageName) == true
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }

    private fun getCurrentMusicStatus(): Map<String, Any>? {
        val mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager

        try {
            val activeSessions = mediaSessionManager.getActiveSessions(
                ComponentName(this, NotificationListener::class.java)
            )

            var latestController: MediaController? = null
            var latestTime = 0L

            for (controller in activeSessions) {
                val playbackState = controller.playbackState
                if (playbackState?.state == PlaybackState.STATE_PLAYING) {
                    if (playbackState.lastPositionUpdateTime > latestTime) {
                        latestTime = playbackState.lastPositionUpdateTime
                        latestController = controller
                    }
                }
            }

            latestController?.let { controller ->
                val metadata = controller.metadata
                val playbackState = controller.playbackState

                val artwork = metadata?.getBitmap("android.media.metadata.ART") 
                    ?: metadata?.getBitmap("android.media.metadata.ALBUM_ART")

                val artworkBytes: Any = artwork?.let { bitmap ->
                    val stream = java.io.ByteArrayOutputStream()
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
                    stream.toByteArray()
                } ?: byteArrayOf()

                return mapOf(
                    "title" to (metadata?.getString("android.media.metadata.TITLE") ?: "N/A"),
                    "artist" to (metadata?.getString("android.media.metadata.ARTIST") ?: "N/A"),
                    "album" to (metadata?.getString("android.media.metadata.ALBUM") ?: "N/A"),
                    "state" to when(playbackState?.state) {
                        PlaybackState.STATE_PLAYING -> "playing"
                        PlaybackState.STATE_PAUSED -> "paused"
                        else -> "N/A"
                    },
                    "source" to controller.packageName,
                    "progress" to (playbackState?.position ?: 0L),
                    "duration" to (metadata?.getLong("android.media.metadata.DURATION") ?: 0L),
                    "artwork" to artworkBytes
                )
            }
        } catch (e: SecurityException) {
            return null
        }

        return null
    }
}