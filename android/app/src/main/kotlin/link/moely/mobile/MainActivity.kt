package link.moely.mobile

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Build
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "link.moely.mobile/wallpaper"
    private val BROWSER_CHANNEL = "link.moely.mobile/browser"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Browser custom channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BROWSER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openInChrome") {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("INVALID_ARGUMENT", "URL is null", null)
                    return@setMethodCallHandler
                }
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    intent.setPackage("com.android.chrome")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }

        // Wallpaper and scan file channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setWallpaper") {
                val path = call.argument<String>("path")
                val type = call.argument<Int>("type") ?: 1 // 1: System, 2: Lock, 3: Both
                
                if (path == null) {
                    result.error("INVALID_ARGUMENT", "Path is null", null)
                    return@setMethodCallHandler
                }

                try {
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File does not exist at $path", null)
                        return@setMethodCallHandler
                    }

                    val bitmap = BitmapFactory.decodeFile(path)
                    if (bitmap == null) {
                        result.error("DECODE_FAILED", "Failed to decode image file to bitmap", null)
                        return@setMethodCallHandler
                    }

                    val wallpaperManager = WallpaperManager.getInstance(applicationContext)
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        when (type) {
                            1 -> {
                                wallpaperManager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_SYSTEM)
                            }
                            2 -> {
                                wallpaperManager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_LOCK)
                            }
                            3 -> {
                                wallpaperManager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK)
                            }
                            else -> {
                                wallpaperManager.setBitmap(bitmap)
                            }
                        }
                    } else {
                        // For older SDKs
                        wallpaperManager.setBitmap(bitmap)
                    }

                    result.success(true)
                } catch (e: Exception) {
                    result.error("SET_WALLPAPER_FAILED", e.localizedMessage, null)
                }
            } else if (call.method == "scanFile") {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGUMENT", "Path is null", null)
                    return@setMethodCallHandler
                }
                try {
                    android.media.MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(path),
                        null
                    ) { _, _ -> }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SCAN_FAILED", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
