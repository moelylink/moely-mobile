package link.moely.mobile

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Build
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.app.AppOpsManager
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "link.moely.mobile/wallpaper"
    private val BROWSER_CHANNEL = "link.moely.mobile/browser"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Widget custom channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "link.moely.mobile/widget").setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            when (call.method) {
                "pinWidget" -> {
                    val providerName = call.argument<String>("providerName")
                    if (providerName == null) {
                        result.error("INVALID_ARGUMENT", "providerName is null", null)
                        return@setMethodCallHandler
                    }
                    val cls = when (providerName) {
                        "MoelyWidgetProvider" -> MoelyWidgetProvider::class.java
                        "DailyImagePortraitProvider" -> DailyImagePortraitProvider::class.java
                        "DailyImageLandscapeProvider" -> DailyImageLandscapeProvider::class.java
                        "PetWidgetProvider" -> PetWidgetProvider::class.java
                        "GalleryWidgetProvider" -> GalleryWidgetProvider::class.java
                        else -> null
                    }
                    if (cls == null) {
                        result.error("INVALID_PROVIDER", "Unknown provider: $providerName", null)
                        return@setMethodCallHandler
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val myProvider = ComponentName(applicationContext, cls)
                        if (appWidgetManager.isRequestPinAppWidgetSupported) {
                            val intent = Intent(applicationContext, cls).apply {
                                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            }
                            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            } else {
                                PendingIntent.FLAG_UPDATE_CURRENT
                            }
                            val successCallback = PendingIntent.getBroadcast(
                                applicationContext,
                                100,
                                intent,
                                flags
                            )
                            appWidgetManager.requestPinAppWidget(myProvider, null, successCallback)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.error("NOT_SUPPORTED", "Requires Android O (API 26) or higher", null)
                    }
                }
                "isPremiumUnlocked" -> {
                    val isUnlocked = prefs.getBoolean("flutter.is_premium_unlocked", false)
                    result.success(isUnlocked)
                }
                "setPremiumUnlocked" -> {
                    val value = call.argument<Boolean>("value") ?: false
                    prefs.edit().putBoolean("flutter.is_premium_unlocked", value).apply()
                    
                    // Trigger widgets update to reflect premium status immediately
                    val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                    
                    val petProvider = ComponentName(applicationContext, PetWidgetProvider::class.java)
                    val petIds = appWidgetManager.getAppWidgetIds(petProvider)
                    val petIntent = Intent(applicationContext, PetWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, petIds)
                    }
                    sendBroadcast(petIntent)
                    
                    val galleryProvider = ComponentName(applicationContext, GalleryWidgetProvider::class.java)
                    val galleryIds = appWidgetManager.getAppWidgetIds(galleryProvider)
                    val galleryIntent = Intent(applicationContext, GalleryWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, galleryIds)
                    }
                    sendBroadcast(galleryIntent)

                    result.success(true)
                }
                "updateWidget" -> {
                    val providerName = call.argument<String>("providerName")
                    if (providerName == null) {
                        result.error("INVALID_ARGUMENT", "providerName is null", null)
                        return@setMethodCallHandler
                    }
                    val cls = when (providerName) {
                        "MoelyWidgetProvider" -> MoelyWidgetProvider::class.java
                        "DailyImagePortraitProvider" -> DailyImagePortraitProvider::class.java
                        "DailyImageLandscapeProvider" -> DailyImageLandscapeProvider::class.java
                        "PetWidgetProvider" -> PetWidgetProvider::class.java
                        "GalleryWidgetProvider" -> GalleryWidgetProvider::class.java
                        else -> null
                    }
                    if (cls != null) {
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val myProvider = ComponentName(applicationContext, cls)
                        val ids = appWidgetManager.getAppWidgetIds(myProvider)
                        val intent = Intent(applicationContext, cls).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                        }
                        sendBroadcast(intent)
                        result.success(true)
                    } else {
                        result.error("INVALID_PROVIDER", "Unknown provider: $providerName", null)
                    }
                }
                "updatePetStatus" -> {
                    val emoji = call.argument<String>("emoji") ?: "🐱"
                    val bubbleText = call.argument<String>("bubbleText") ?: ""
                    prefs.edit()
                        .putString("flutter.pet_emoji", emoji)
                        .putString("flutter.pet_bubble_text", bubbleText)
                        .apply()
                    
                    // Trigger widgets update
                    val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                    val petProvider = ComponentName(applicationContext, PetWidgetProvider::class.java)
                    val petIds = appWidgetManager.getAppWidgetIds(petProvider)
                    val petIntent = Intent(applicationContext, PetWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, petIds)
                    }
                    sendBroadcast(petIntent)
                    result.success(true)
                }
                "setGalleryImages" -> {
                    val images = call.argument<List<String>>("images") ?: emptyList()
                    val widgetId = call.argument<Int>("widgetId") ?: -1
                    val title = call.argument<String>("title") ?: ""
                    val scale = call.argument<Int>("scale") ?: 6
                    
                    val imagesString = images.joinToString(",")
                    
                    if (widgetId != -1) {
                        prefs.edit()
                            .putString("flutter.gallery_images_$widgetId", imagesString)
                            .putString("flutter.gallery_title_$widgetId", title)
                            .putString("flutter.widget_custom_name_$widgetId", title)
                            .putInt("flutter.gallery_scale_$widgetId", scale)
                            .putInt("flutter.gallery_current_index_$widgetId", 0)
                            .apply()
                    } else {
                        prefs.edit()
                            .putString("flutter.gallery_images", imagesString)
                            .putString("flutter.gallery_title", title)
                            .putInt("flutter.gallery_scale", scale)
                            .putInt("flutter.gallery_current_index", 0)
                            .apply()
                    }

                    // Trigger widget update to reflect immediately
                    val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                    val galleryProvider = ComponentName(applicationContext, GalleryWidgetProvider::class.java)
                    val galleryIds = if (widgetId != -1) {
                        intArrayOf(widgetId)
                    } else {
                        appWidgetManager.getAppWidgetIds(galleryProvider)
                    }
                    val galleryIntent = Intent(applicationContext, GalleryWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, galleryIds)
                    }
                    sendBroadcast(galleryIntent)

                    result.success(true)
                }
                "getGalleryImages" -> {
                    val widgetId = call.argument<Int>("widgetId") ?: -1
                    
                    val imagesString = if (widgetId != -1) {
                        prefs.getString("flutter.gallery_images_$widgetId", "")?.takeIf { it.isNotEmpty() }
                            ?: prefs.getString("flutter.gallery_images", "") ?: ""
                    } else {
                        prefs.getString("flutter.gallery_images", "") ?: ""
                    }
                    
                    val title = if (widgetId != -1) {
                        prefs.getString("flutter.gallery_title_$widgetId", "")?.takeIf { it.isNotEmpty() }
                            ?: prefs.getString("flutter.gallery_title", "") ?: ""
                    } else {
                        prefs.getString("flutter.gallery_title", "") ?: ""
                    }
                    
                    val scale = if (widgetId != -1) {
                        val specific = prefs.getInt("flutter.gallery_scale_$widgetId", -1)
                        if (specific != -1) specific else prefs.getInt("flutter.gallery_scale", 6)
                    } else {
                        prefs.getInt("flutter.gallery_scale", 6)
                    }
                    
                    val imagesList = if (imagesString.isEmpty()) {
                        emptyList<String>()
                    } else {
                        imagesString.split(",").filter { it.isNotEmpty() }
                    }
                    
                    val configMap = mapOf(
                        "images" to imagesList,
                        "title" to title,
                        "scale" to scale
                    )
                    result.success(configMap)
                }
                "getActiveGalleryWidgets" -> {
                    val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                    val thisWidget = ComponentName(applicationContext, GalleryWidgetProvider::class.java)
                    val ids = appWidgetManager.getAppWidgetIds(thisWidget)
                    val list = ids.map { id ->
                        val title = prefs.getString("flutter.widget_custom_name_$id", "")?.takeIf { it.isNotEmpty() }
                            ?: prefs.getString("flutter.gallery_title_$id", "")?.takeIf { it.isNotEmpty() }
                            ?: prefs.getString("flutter.gallery_title", "")?.takeIf { it.isNotEmpty() }
                            ?: "自定义画廊"
                        mapOf("id" to id, "title" to title)
                    }
                    result.success(list)
                }
                "getAllActiveWidgets" -> {
                    try {
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val list = mutableListOf<Map<String, Any>>()
                        
                        if (appWidgetManager != null) {
                            // 1. Gallery
                            val galleryProvider = ComponentName(applicationContext, GalleryWidgetProvider::class.java)
                            appWidgetManager.getAppWidgetIds(galleryProvider)?.forEach { id ->
                                val customName = prefs.getString("flutter.widget_custom_name_$id", "")?.takeIf { it.isNotEmpty() }
                                    ?: prefs.getString("flutter.gallery_title_$id", "")?.takeIf { it.isNotEmpty() }
                                    ?: prefs.getString("flutter.gallery_title", "")?.takeIf { it.isNotEmpty() }
                                    ?: "自定义画廊"
                                list.add(mapOf(
                                    "id" to id,
                                    "type" to "gallery",
                                    "provider" to "GalleryWidgetProvider",
                                    "customName" to customName
                                ))
                            }
                            
                            // 2. Pet
                            val petProvider = ComponentName(applicationContext, PetWidgetProvider::class.java)
                            appWidgetManager.getAppWidgetIds(petProvider)?.forEach { id ->
                                val customName = prefs.getString("flutter.widget_custom_name_$id", "")?.takeIf { it.isNotEmpty() }
                                    ?: "随机探索看板娘"
                                list.add(mapOf(
                                    "id" to id,
                                    "type" to "pet",
                                    "provider" to "PetWidgetProvider",
                                    "customName" to customName
                                ))
                            }
                            
                            // 3. Moely Classic
                            val moelyProvider = ComponentName(applicationContext, MoelyWidgetProvider::class.java)
                            appWidgetManager.getAppWidgetIds(moelyProvider)?.forEach { id ->
                                val customName = prefs.getString("flutter.widget_custom_name_$id", "")?.takeIf { it.isNotEmpty() }
                                    ?: "萌哩每日一图"
                                list.add(mapOf(
                                    "id" to id,
                                    "type" to "daily_classic",
                                    "provider" to "MoelyWidgetProvider",
                                    "customName" to customName
                                ))
                            }
                            
                            // 4. Portrait Daily Image
                            val portraitProvider = ComponentName(applicationContext, DailyImagePortraitProvider::class.java)
                            appWidgetManager.getAppWidgetIds(portraitProvider)?.forEach { id ->
                                val customName = prefs.getString("flutter.widget_custom_name_$id", "")?.takeIf { it.isNotEmpty() }
                                    ?: "精美竖屏大卡"
                                list.add(mapOf(
                                    "id" to id,
                                    "type" to "daily_portrait",
                                    "provider" to "DailyImagePortraitProvider",
                                    "customName" to customName
                                ))
                            }
                            
                            // 5. Landscape Daily Image
                            val landscapeProvider = ComponentName(applicationContext, DailyImageLandscapeProvider::class.java)
                            appWidgetManager.getAppWidgetIds(landscapeProvider)?.forEach { id ->
                                val customName = prefs.getString("flutter.widget_custom_name_$id", "")?.takeIf { it.isNotEmpty() }
                                    ?: "电影感横屏卡"
                                list.add(mapOf(
                                    "id" to id,
                                    "type" to "daily_landscape",
                                    "provider" to "DailyImageLandscapeProvider",
                                    "customName" to customName
                                ))
                            }
                        }
                        
                        result.success(list)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("NATIVE_ERROR", e.localizedMessage, null)
                    }
                }
                "saveWidgetCustomName" -> {
                    val id = call.argument<Int>("widgetId") ?: -1
                    val customName = call.argument<String>("customName") ?: ""
                    if (id != -1) {
                        prefs.edit().putString("flutter.widget_custom_name_$id", customName).apply()
                        
                        // If it is gallery widget, also set flutter.gallery_title_$id so widget updates
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val galleryProvider = ComponentName(applicationContext, GalleryWidgetProvider::class.java)
                        val galleryIds = appWidgetManager.getAppWidgetIds(galleryProvider)
                        if (galleryIds.contains(id)) {
                            prefs.edit().putString("flutter.gallery_title_$id", customName).apply()
                            val galleryIntent = Intent(applicationContext, GalleryWidgetProvider::class.java).apply {
                                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(id))
                            }
                            sendBroadcast(galleryIntent)
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "checkShortcutPermission" -> {
                    result.success(checkShortcutPermission(applicationContext))
                }
                "openShortcutPermissionSettings" -> {
                    openShortcutPermissionSettings(this)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

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

        // App Info custom channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "link.moely.mobile/app_info").setMethodCallHandler { call, result ->
            if (call.method == "getInstallTimes") {
                try {
                    val packageInfo = packageManager.getPackageInfo(packageName, 0)
                    val map = mapOf(
                        "firstInstallTime" to packageInfo.firstInstallTime,
                        "lastUpdateTime" to packageInfo.lastUpdateTime
                    )
                    result.success(map)
                } catch (e: Exception) {
                    result.error("ERROR", e.localizedMessage, null)
                }
            } else if (call.method == "getWebViewUserAgent") {
                try {
                    val userAgent = android.webkit.WebSettings.getDefaultUserAgent(applicationContext)
                    result.success(userAgent)
                } catch (e: Exception) {
                    result.error("ERROR", e.localizedMessage, null)
                }
            } else if (call.method == "getStorageSpace") {
                try {
                    val path = android.os.Environment.getDataDirectory().path
                    val stat = android.os.StatFs(path)
                    val blockSize = stat.blockSizeLong
                    val totalBlocks = stat.blockCountLong
                    val availableBlocks = stat.availableBlocksLong
                    val map = mapOf(
                        "totalSpace" to totalBlocks * blockSize,
                        "freeSpace" to availableBlocks * blockSize
                    )
                    result.success(map)
                } catch (e: Exception) {
                    result.error("ERROR", e.localizedMessage, null)
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun checkShortcutPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            return true
        }
        val appOpsManager = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        try {
            val checkOpNoThrow = appOpsManager.javaClass.getMethod(
                "checkOpNoThrow",
                java.lang.Integer.TYPE,
                java.lang.Integer.TYPE,
                java.lang.String::class.java
            )
            // 10017 corresponds to OP_INSTALL_SHORTCUT on Xiaomi / MIUI / HyperOS
            val mode = checkOpNoThrow.invoke(
                appOpsManager,
                10017,
                android.os.Process.myUid(),
                context.packageName
            ) as Int
            return mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            // Ignore and fallback
        }
        return true
    }

    private fun openShortcutPermissionSettings(context: Context) {
        val packageName = context.packageName
        val manufacturer = Build.MANUFACTURER.lowercase()
        var success = false

        // 1. Try MIUI specific intent
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi")) {
            try {
                val intent = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                    setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.AppPermissionsEditorActivity")
                    putExtra("extra_pkgname", packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                success = true
            } catch (e: Exception) {
                // fall through
            }
        }

        // 2. Try Huawei specific intent
        if (!success && (manufacturer.contains("huawei") || manufacturer.contains("honor"))) {
            try {
                val intent = Intent().apply {
                    setClassName("com.huawei.systemmanager", "com.huawei.permissionmanager.ui.MainActivity")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                success = true
            } catch (e: Exception) {
                // fall through
            }
        }

        // 3. Try Vivo specific intent
        if (!success && manufacturer.contains("vivo")) {
            try {
                val intent = Intent().apply {
                    setClassName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                success = true
            } catch (e: Exception) {
                // fall through
            }
        }

        // 4. Try Oppo specific intent
        if (!success && manufacturer.contains("oppo")) {
            try {
                val intent = Intent().apply {
                    setClassName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                success = true
            } catch (e: Exception) {
                // fall through
            }
        }

        // 5. General fallback: App Details settings page
        if (!success) {
            try {
                val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            } catch (e: Exception) {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                } catch (e2: Exception) {
                    // Ignore
                }
            }
        }
    }
}
