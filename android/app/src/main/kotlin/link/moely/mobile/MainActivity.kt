package link.moely.mobile

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "link.moely.mobile/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
            } else {
                result.notImplemented()
            }
        }
    }
}
