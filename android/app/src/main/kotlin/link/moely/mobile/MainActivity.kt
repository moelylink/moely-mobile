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
import android.util.Log
import java.io.File

class MainActivity : FlutterActivity() {
    private val TAG = "MoelyWidget"
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
                    Log.i(TAG, "[pinWidget] Request received. providerName=$providerName")
                    Log.i(TAG, "[pinWidget] Device Info: Manufacturer=${Build.MANUFACTURER}, Brand=${Build.BRAND}, Model=${Build.MODEL}, SDK_INT=${Build.VERSION.SDK_INT}, Release=${Build.VERSION.RELEASE}")
                    
                    if (providerName == null) {
                        Log.e(TAG, "[pinWidget] Failed: providerName is null")
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
                        Log.e(TAG, "[pinWidget] Failed: Unknown providerName=$providerName")
                        result.error("INVALID_PROVIDER", "Unknown provider: $providerName", null)
                        return@setMethodCallHandler
                    }
                    
                    val shortcutPermissionGranted = checkShortcutPermission(applicationContext)
                    val launcherPkg = getDefaultLauncherPackage()
                    Log.i(TAG, "[pinWidget] Default Launcher: $launcherPkg, AppOps Shortcut Permission Granted: $shortcutPermissionGranted")

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val myProvider = ComponentName(applicationContext, cls)
                        val isSupported = appWidgetManager.isRequestPinAppWidgetSupported
                        Log.i(TAG, "[pinWidget] AppWidgetManager.isRequestPinAppWidgetSupported: $isSupported for component ${myProvider.flattenToShortString()}")
                        
                        if (isSupported) {
                            try {
                                Log.i(TAG, "[pinWidget] Executing requestPinAppWidget(provider=${myProvider.shortClassName}, null, null)...")
                                // 传 null 作为 successCallback：
                                // 在 Android 14、ColorOS 14、MIUI、OriginOS 等定制系统中，跨进程传递 FLAG_MUTABLE PendingIntent
                                // 极易触发系统桌面安全沙箱拦截导致请求静默抛弃。传 null 时由系统桌面接管添加流程，组件放置后系统会自动回调 onUpdate。
                                val pinned = appWidgetManager.requestPinAppWidget(myProvider, null, null)
                                Log.i(TAG, "[pinWidget] requestPinAppWidget call returned: $pinned")
                                result.success(pinned)
                            } catch (e: Exception) {
                                Log.e(TAG, "[pinWidget] Exception during requestPinAppWidget: ${e.javaClass.name} - ${e.message}", e)
                                result.success(false)
                            }
                        } else {
                            Log.w(TAG, "[pinWidget] isRequestPinAppWidgetSupported is false for launcher: $launcherPkg")
                            result.success(false)
                        }
                    } else {
                        Log.w(TAG, "[pinWidget] SDK_INT ${Build.VERSION.SDK_INT} < API 26 (Android O), requestPinAppWidget not supported")
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

    private fun getDefaultLauncherPackage(): String {
        return try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
            }
            val resolveInfo = packageManager.resolveActivity(intent, 0)
            resolveInfo?.activityInfo?.packageName ?: "unknown"
        } catch (e: Exception) {
            Log.w(TAG, "[getDefaultLauncherPackage] Failed to resolve default launcher: ${e.message}")
            "error: ${e.message}"
        }
    }

    private fun checkShortcutPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            Log.d(TAG, "[checkShortcutPermission] SDK < KITKAT, return true")
            return true
        }
        val manufacturer = Build.MANUFACTURER.lowercase()
        val appOpsManager = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        
        // 1. 小米 / 红米 (MIUI / HyperOS)：10017 为其私有 OP_INSTALL_SHORTCUT
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi")) {
            try {
                val checkOpNoThrow = appOpsManager.javaClass.getMethod(
                    "checkOpNoThrow",
                    java.lang.Integer.TYPE,
                    java.lang.Integer.TYPE,
                    java.lang.String::class.java
                )
                val mode = checkOpNoThrow.invoke(
                    appOpsManager,
                    10017,
                    android.os.Process.myUid(),
                    context.packageName
                ) as Int
                val allowed = mode == AppOpsManager.MODE_ALLOWED
                Log.i(TAG, "[checkShortcutPermission] Xiaomi/Redmi OP 10017 check mode=$mode (allowed=$allowed)")
                return allowed
            } catch (e: Exception) {
                Log.w(TAG, "[checkShortcutPermission] Xiaomi/Redmi OP 10017 reflection failed: ${e.message}")
            }
        }

        // 2. Vivo / iQOO (OriginOS)：部分版本使用 OP 10017 作为桌面快捷方式管控
        if (manufacturer.contains("vivo") || manufacturer.contains("iqoo")) {
            try {
                val checkOpNoThrow = appOpsManager.javaClass.getMethod(
                    "checkOpNoThrow",
                    java.lang.Integer.TYPE,
                    java.lang.Integer.TYPE,
                    java.lang.String::class.java
                )
                val mode = checkOpNoThrow.invoke(
                    appOpsManager,
                    10017,
                    android.os.Process.myUid(),
                    context.packageName
                ) as Int
                val allowed = mode == AppOpsManager.MODE_ALLOWED
                Log.i(TAG, "[checkShortcutPermission] Vivo/iQOO OP 10017 check mode=$mode (allowed=$allowed)")
                if (!allowed) {
                    return false
                }
            } catch (e: Exception) {
                Log.w(TAG, "[checkShortcutPermission] Vivo/iQOO OP 10017 reflection failed: ${e.message}")
            }
        }

        // 其他定制系统或未能反射获取时，默认返回 true，由底层 API requestPinAppWidget 真实状态处理
        Log.d(TAG, "[checkShortcutPermission] Default fallback return true for manufacturer=$manufacturer")
        return true
    }

    private fun openShortcutPermissionSettings(context: Context) {
        val packageName = context.packageName
        val manufacturer = Build.MANUFACTURER.lowercase()
        var success = false
        Log.i(TAG, "[openShortcutPermissionSettings] Opening settings for manufacturer: $manufacturer, pkg: $packageName")

        // 1. 小米 / 红米 (MIUI / HyperOS)
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi")) {
            try {
                val intent = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                    setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.AppPermissionsEditorActivity")
                    putExtra("extra_pkgname", packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                success = true
                Log.i(TAG, "[openShortcutPermissionSettings] Started MIUI AppPermissionsEditorActivity")
            } catch (e: Exception) {
                try {
                    val intent = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                        putExtra("extra_pkgname", packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    success = true
                    Log.i(TAG, "[openShortcutPermissionSettings] Started miui.intent.action.APP_PERM_EDITOR")
                } catch (e2: Exception) {
                    Log.w(TAG, "[openShortcutPermissionSettings] Failed to launch MIUI perm editor: ${e2.message}")
                }
            }
        }

        // 2. Vivo / iQOO (OriginOS)
        if (!success && (manufacturer.contains("vivo") || manufacturer.contains("iqoo"))) {
            // 尝试拉起 OriginOS 权限详情页
            try {
                val intent = Intent("permission.intent.action.softPermissionDetail").apply {
                    putExtra("packagename", packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                success = true
                Log.i(TAG, "[openShortcutPermissionSettings] Started Vivo softPermissionDetail")
            } catch (e: Exception) {
                try {
                    val intent = Intent().apply {
                        component = ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.SoftPermissionDetailActivity")
                        putExtra("packagename", packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    success = true
                    Log.i(TAG, "[openShortcutPermissionSettings] Started Vivo SoftPermissionDetailActivity")
                } catch (e2: Exception) {
                    try {
                        val intent = Intent().apply {
                            component = ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.PurviewTabActivity")
                            putExtra("packagename", packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        success = true
                        Log.i(TAG, "[openShortcutPermissionSettings] Started Vivo PurviewTabActivity")
                    } catch (e3: Exception) {
                        Log.w(TAG, "[openShortcutPermissionSettings] Failed to launch Vivo perm manager: ${e3.message}")
                    }
                }
            }
        }

        // 3. OPPO / OnePlus / Realme (ColorOS / Realme UI)
        if (!success && (manufacturer.contains("oppo") || manufacturer.contains("oneplus") || manufacturer.contains("realme"))) {
            try {
                val intent = Intent().apply {
                    component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.PermissionTopActivity")
                    putExtra("package_name", packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                success = true
                Log.i(TAG, "[openShortcutPermissionSettings] Started ColorOS PermissionTopActivity")
            } catch (e: Exception) {
                try {
                    val intent = Intent().apply {
                        component = ComponentName("com.oplus.securitypermission", "com.oplus.securitypermission.permission.PermissionTopActivity")
                        putExtra("package_name", packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    success = true
                    Log.i(TAG, "[openShortcutPermissionSettings] Started OPlus PermissionTopActivity")
                } catch (e2: Exception) {
                    Log.w(TAG, "[openShortcutPermissionSettings] Failed to launch ColorOS/OPlus perm manager: ${e2.message}")
                }
            }
        }

        // 4. 华为 / 荣耀 (HarmonyOS / EMUI / MagicOS)
        if (!success && (manufacturer.contains("huawei") || manufacturer.contains("honor"))) {
            try {
                val intent = Intent().apply {
                    component = ComponentName("com.huawei.systemmanager", "com.huawei.permissionmanager.ui.MainActivity")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                success = true
                Log.i(TAG, "[openShortcutPermissionSettings] Started Huawei permissionmanager MainActivity")
            } catch (e: Exception) {
                Log.w(TAG, "[openShortcutPermissionSettings] Failed to launch Huawei systemmanager: ${e.message}")
            }
        }

        // 5. 通用兜底：打开系统标准应用详情页（可直达权限设置）
        if (!success) {
            try {
                val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                Log.i(TAG, "[openShortcutPermissionSettings] Fallback to ACTION_APPLICATION_DETAILS_SETTINGS")
            } catch (e: Exception) {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    Log.i(TAG, "[openShortcutPermissionSettings] Fallback to ACTION_SETTINGS")
                } catch (e2: Exception) {
                    Log.e(TAG, "[openShortcutPermissionSettings] Failed to launch settings: ${e2.message}")
                }
            }
        }
    }
}
