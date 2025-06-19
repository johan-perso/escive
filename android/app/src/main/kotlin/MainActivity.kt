package fr.johanstick.escive

import android.content.ComponentName
import android.content.Context
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.Settings
import android.content.Intent

class MainActivity: FlutterActivity() {
    private val CHANNEL = "music_status"

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
                        // Should redirect to settings
                        result.success(true)
                    }
                    "isNotificationListenerEnabled" -> {
                        result.success(isNotificationListenerEnabled())
                    }
                    "openNotificationListenerSettings" -> {
                        openNotificationListenerSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
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