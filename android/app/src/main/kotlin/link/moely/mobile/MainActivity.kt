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
import android.os.Bundle
import android.util.Log
import java.io.File
import com.airbnb.lottie.LottieAnimationView
import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewTreeObserver

class MainActivity : FlutterActivity() {
    private val TAG = "MoelyWidget"
    private val CHANNEL = "link.moely.mobile/wallpaper"
    private val BROWSER_CHANNEL = "link.moely.mobile/browser"

    private var nativeSplashContainer: FrameLayout? = null
    private var systemSplashScreenView: android.window.SplashScreenView? = null
    private var isLottieDrawn = false
    private var isFlutterUiDisplayed = false
    private var isSplashDismissed = false
    private var pendingDismiss = false

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }

    private fun getStatusBarHeight(): Int {
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else dpToPx(24f)
    }

    private fun dismissSystemSplashScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            systemSplashScreenView?.let { view ->
                view.remove()
                systemSplashScreenView = null
            }
        }
    }

    private fun setupNativeLottieSplash() {
        val isNight = (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
        val bgColor = if (isNight) Color.parseColor("#222222") else Color.parseColor("#FFFFFF")

        val container = FrameLayout(this).apply {
            setBackgroundColor(bgColor)
            isClickable = true
            isFocusable = true
        }

        val sizePx = dpToPx(320f)
        val lottieView = LottieAnimationView(this).apply {
            setAnimation("moely_loader.json")
            repeatCount = 0
            layoutParams = FrameLayout.LayoutParams(sizePx, sizePx).apply {
                gravity = Gravity.CENTER
            }
        }
        container.addView(lottieView)

        val skipButton = TextView(this).apply {
            text = "跳过"
            textSize = 13f
            setTextColor(if (isNight) Color.WHITE else Color.parseColor("#222222"))
            setPadding(
                dpToPx(14f),
                dpToPx(6f),
                dpToPx(14f),
                dpToPx(6f)
            )
            val bgDrawable = GradientDrawable().apply {
                cornerRadius = dpToPx(16f).toFloat()
                setColor(if (isNight) Color.parseColor("#20FFFFFF") else Color.parseColor("#15000000"))
                setStroke(
                    dpToPx(1f),
                    if (isNight) Color.parseColor("#30FFFFFF") else Color.parseColor("#25000000")
                )
            }
            background = bgDrawable
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.TOP or Gravity.END
                topMargin = getStatusBarHeight() + dpToPx(16f)
                marginEnd = dpToPx(16f)
            }
            setOnClickListener {
                dismissNativeSplash()
            }
        }
        container.addView(skipButton)

        this.nativeSplashContainer = container
        addContentView(
            container,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        // 核心锁相：在 Lottie 容器完成测量布局、即将绘制首帧的瞬间移出系统原生启动遮罩，杜绝黑屏空窗期
        container.viewTreeObserver.addOnPreDrawListener(object : ViewTreeObserver.OnPreDrawListener {
            override fun onPreDraw(): Boolean {
                if (container.viewTreeObserver.isAlive) {
                    container.viewTreeObserver.removeOnPreDrawListener(this)
                }
                isLottieDrawn = true
                dismissSystemSplashScreen()
                return true
            }
        })

        // 超时兜底（1.5s）：避免极端系统异常导致原生 Splash 未能释放
        container.postDelayed({
            dismissSystemSplashScreen()
        }, 1500)

        lottieView.addAnimatorListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                dismissNativeSplash()
            }
        })

        lottieView.playAnimation()
    }

    private fun dismissNativeSplash() {
        if (isSplashDismissed) return
        if (!isFlutterUiDisplayed) {
            // 若 Flutter 首帧尚未完成，挂起等待首帧上屏的一瞬间平滑移交
            pendingDismiss = true
            return
        }
        isSplashDismissed = true
        nativeSplashContainer?.let { container ->
            container.animate()
                .alpha(0f)
                .setDuration(350)
                .withEndAction {
                    (container.parent as? ViewGroup)?.removeView(container)
                    nativeSplashContainer = null
                }
                .start()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupNativeLottieSplash()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                if (isLottieDrawn) {
                    splashScreenView.remove()
                } else {
                    this.systemSplashScreenView = splashScreenView
                }
            }
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        isFlutterUiDisplayed = true
        if (pendingDismiss) {
            dismissNativeSplash()
        }
    }

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
                        val appWidgetManager = AppWidgetManager.getInstance(this@MainActivity)
                        val myProvider = ComponentName(applicationContext, cls)
                        val isSupported = appWidgetManager.isRequestPinAppWidgetSupported
                        val hasWindowFocus = this@MainActivity.hasWindowFocus()
                        Log.i(TAG, "[pinWidget] AppWidgetManager.isRequestPinAppWidgetSupported: $isSupported, hasWindowFocus=$hasWindowFocus for component ${myProvider.flattenToShortString()}")
                        
                        if (isSupported) {
                            try {
                                // 构造指向 WidgetPinCallbackReceiver 的标准广播 PendingIntent。
                                // Android 12+ (API 31+) 跨进程回调必须指定 FLAG_MUTABLE，以便系统桌面填充 EXTRA_APPWIDGET_ID。
                                val callbackIntent = Intent(applicationContext, WidgetPinCallbackReceiver::class.java).apply {
                                    action = WidgetPinCallbackReceiver.ACTION_PIN_WIDGET_SUCCESS
                                    putExtra("provider_class", cls.name)
                                }
                                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                                } else {
                                    PendingIntent.FLAG_UPDATE_CURRENT
                                }
                                val successCallback = PendingIntent.getBroadcast(
                                    this@MainActivity,
                                    cls.name.hashCode(),
                                    callbackIntent,
                                    flags
                                )

                                Log.i(TAG, "[pinWidget] Executing requestPinAppWidget WITHOUT preview extras, with successCallback PendingIntent...")
                                var pinned = false
                                try {
                                    // 不传 EXTRA_APPWIDGET_PREVIEW：ColorOS / OriginOS 等国产系统在处理
                                    // 含 RemoteViews 的 extras Bundle 时存在 Parcel 兼容问题，会导致
                                    // Launcher 侧 getPinItemRequest() 返回 null 进而静默 finish()。
                                    // 预览 extras 属于可选装饰，去掉不影响弹窗核心功能。
                                    pinned = appWidgetManager.requestPinAppWidget(myProvider, null, successCallback)
                                } catch (se: SecurityException) {
                                    Log.w(TAG, "[pinWidget] requestPinAppWidget with callback failed with SecurityException: ${se.message}")
                                    pinned = appWidgetManager.requestPinAppWidget(myProvider, null, null)
                                } catch (e: Exception) {
                                    Log.w(TAG, "[pinWidget] requestPinAppWidget failed: ${e.message}")
                                    try {
                                        pinned = appWidgetManager.requestPinAppWidget(myProvider, null, null)
                                    } catch (e2: Exception) {
                                        Log.e(TAG, "[pinWidget] All requestPinAppWidget attempts failed: ${e2.message}")
                                    }
                                }

                                Log.i(TAG, "[pinWidget] requestPinAppWidget call returned: $pinned")

                                // 仅在桌面上已有该 Provider 的现有实例时，才发送刷新广播以同步它们的数据。
                                // 避免在 requestPinAppWidget 的 Binder 请求尚未被 Launcher 处理时，
                                // 过早触发 ACTION_APPWIDGET_UPDATE 广播干扰 pin 确认弹窗的调起。
                                val currentIds = appWidgetManager.getAppWidgetIds(myProvider)
                                if (currentIds.isNotEmpty()) {
                                    val initialUpdateIntent = Intent(applicationContext, cls).apply {
                                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, currentIds)
                                    }
                                    sendBroadcast(initialUpdateIntent)
                                    Log.i(TAG, "[pinWidget] Dispatched initial ACTION_APPWIDGET_UPDATE broadcast for provider ${cls.simpleName}, currentIds count=${currentIds.size}")
                                } else {
                                    Log.i(TAG, "[pinWidget] No existing instances for ${cls.simpleName}, skipping pre-pin broadcast to avoid interfering with pin confirmation")
                                }

                                // 增加 1.2s 和 2.8s 延迟兜底刷新：应对用户点击系统弹窗添加后，个别系统 Launcher 不触发 callback 的场景
                                val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                                mainHandler.postDelayed({
                                    try {
                                        val updatedIds = appWidgetManager.getAppWidgetIds(myProvider)
                                        if (updatedIds.isNotEmpty()) {
                                            val delayedIntent = Intent(applicationContext, cls).apply {
                                                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, updatedIds)
                                            }
                                            sendBroadcast(delayedIntent)
                                            Log.i(TAG, "[pinWidget] Fallback delayed (1.2s) update dispatched for ${cls.simpleName}, count=${updatedIds.size}")
                                        }
                                    } catch (e: Exception) {
                                        Log.w(TAG, "[pinWidget] Fallback delayed update error: ${e.message}")
                                    }
                                }, 1200)

                                mainHandler.postDelayed({
                                    try {
                                        val finalIds = appWidgetManager.getAppWidgetIds(myProvider)
                                        if (finalIds.isNotEmpty()) {
                                            val delayedIntent2 = Intent(applicationContext, cls).apply {
                                                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, finalIds)
                                            }
                                            sendBroadcast(delayedIntent2)
                                            Log.i(TAG, "[pinWidget] Fallback delayed (2.8s) update dispatched for ${cls.simpleName}, count=${finalIds.size}")
                                        }
                                    } catch (e: Exception) {
                                        Log.w(TAG, "[pinWidget] Final fallback delayed update error: ${e.message}")
                                    }
                                }, 2800)

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
                            // 自动兜底：对已识别到的桌面微件主动派发一次刷新广播，确保未初始化微件点亮
                            val providersToSync = listOf(
                                GalleryWidgetProvider::class.java to galleryProvider,
                                PetWidgetProvider::class.java to petProvider,
                                MoelyWidgetProvider::class.java to moelyProvider,
                                DailyImagePortraitProvider::class.java to portraitProvider,
                                DailyImageLandscapeProvider::class.java to landscapeProvider
                            )
                            for ((cls, comp) in providersToSync) {
                                val activeIds = appWidgetManager.getAppWidgetIds(comp)
                                if (activeIds != null && activeIds.isNotEmpty()) {
                                    val syncIntent = Intent(applicationContext, cls).apply {
                                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, activeIds)
                                    }
                                    sendBroadcast(syncIntent)
                                }
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
                "getDeviceRomInfo" -> {
                    result.success(getDeviceRomInfo())
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

    private fun getDeviceRomInfo(): Map<String, String> {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val model = Build.MODEL
        
        var romType = "other"
        var romName = "Android 原生系统"

        when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || brand.contains("xiaomi") || brand.contains("redmi") -> {
                romType = "hyperos"
                romName = "小米 HyperOS / MIUI"
            }
            manufacturer.contains("oppo") || manufacturer.contains("oneplus") || manufacturer.contains("realme") || brand.contains("oppo") || brand.contains("oneplus") || brand.contains("realme") -> {
                romType = "coloros"
                romName = "OPPO ColorOS / Realme UI"
            }
            manufacturer.contains("vivo") || manufacturer.contains("iqoo") || brand.contains("vivo") || brand.contains("iqoo") -> {
                romType = "originos"
                romName = "vivo OriginOS"
            }
            manufacturer.contains("honor") || brand.contains("honor") -> {
                romType = "magicos"
                romName = "荣耀 MagicOS"
            }
            manufacturer.contains("huawei") || brand.contains("huawei") -> {
                romType = "harmonyos"
                romName = "华为 HarmonyOS / EMUI"
            }
            manufacturer.contains("samsung") || brand.contains("samsung") -> {
                romType = "oneui"
                romName = "三星 One UI"
            }
        }

        return mapOf(
            "romType" to romType,
            "romName" to romName,
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to model
        )
    }

    private fun checkShortcutPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            Log.d(TAG, "[checkShortcutPermission] SDK < KITKAT, return true")
            return true
        }
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val appOpsManager = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        
        // 1. 小米 / 红米 (MIUI / HyperOS)：10017 为其私有 OP_INSTALL_SHORTCUT 真实受管控
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || brand.contains("xiaomi") || brand.contains("redmi")) {
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
                // MODE_DEFAULT (3) 表示权限尚未被用户明确设置，HyperOS/MIUI 会在首次
                // requestPinAppWidget 时自动弹出授权对话框，不应误判为"已拒绝"。
                val allowed = mode == AppOpsManager.MODE_ALLOWED || mode == AppOpsManager.MODE_DEFAULT
                Log.i(TAG, "[checkShortcutPermission] Xiaomi/Redmi OP 10017 check mode=$mode (allowed=$allowed, MODE_DEFAULT=${AppOpsManager.MODE_DEFAULT})")
                return allowed
            } catch (e: Exception) {
                Log.w(TAG, "[checkShortcutPermission] Xiaomi/Redmi OP 10017 reflection failed: ${e.message}")
            }
        }

        // 2. 其他定制系统（ColorOS, OriginOS, MagicOS, One UI, HarmonyOS 等）：
        // 其系统桌面并没有将桌面微件管控暴露在私有 10017/65 上，盲目检查会造成误杀。
        // 在 Android 8.0+ 上，只要底层桌面支持 isRequestPinAppWidgetSupported，默认放行请求，由桌面原生交互接管。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val isSupported = appWidgetManager.isRequestPinAppWidgetSupported
                Log.i(TAG, "[checkShortcutPermission] isRequestPinAppWidgetSupported=$isSupported for manufacturer=$manufacturer")
                return isSupported
            } catch (e: Exception) {
                Log.w(TAG, "[checkShortcutPermission] AppWidgetManager check failed: ${e.message}")
            }
        }

        // 其他定制系统或未能反射获取时，默认返回 true，由底层 API requestPinAppWidget 真实状态处理
        Log.d(TAG, "[checkShortcutPermission] Default fallback return true for manufacturer=$manufacturer")
        return true
    }

    private fun openShortcutPermissionSettings(context: Context) {
        val packageName = context.packageName
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        var success = false
        Log.i(TAG, "[openShortcutPermissionSettings] Opening settings for manufacturer: $manufacturer, brand: $brand, pkg: $packageName")

        // 1. 小米 / 红米 (MIUI / HyperOS)
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || brand.contains("xiaomi") || brand.contains("redmi")) {
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
        if (!success && (manufacturer.contains("vivo") || manufacturer.contains("iqoo") || brand.contains("vivo") || brand.contains("iqoo"))) {
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
        if (!success && (manufacturer.contains("oppo") || manufacturer.contains("oneplus") || manufacturer.contains("realme") || brand.contains("oppo") || brand.contains("oneplus") || brand.contains("realme"))) {
            val intents = listOf(
                Intent().apply {
                    component = ComponentName("com.oplus.securitypermission", "com.oplus.securitypermission.permission.PermissionTopActivity")
                    putExtra("package_name", packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
                Intent().apply {
                    component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.PermissionTopActivity")
                    putExtra("package_name", packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
                Intent().apply {
                    component = ComponentName("com.oplus.safecenter", "com.oplus.safecenter.permission.PermissionTopActivity")
                    putExtra("package_name", packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
                Intent().apply {
                    component = ComponentName("com.coloros.safecenter", "com.coloros.privacypermissionsentry.PermissionTopActivity")
                    putExtra("package_name", packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
                Intent("coloros.intent.action.APPDETAIL").apply {
                    putExtra("packageName", packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
            for (intent in intents) {
                try {
                    context.startActivity(intent)
                    success = true
                    Log.i(TAG, "[openShortcutPermissionSettings] Started ColorOS/OPlus activity: ${intent.component?.className ?: intent.action}")
                    break
                } catch (e: Exception) {
                    // Try next
                }
            }
        }

        // 4. 荣耀 (MagicOS)
        if (!success && (manufacturer.contains("honor") || brand.contains("honor"))) {
            val honorIntents = listOf(
                Intent().apply {
                    component = ComponentName("com.hihonor.systemmanager", "com.hihonor.permissionmanager.ui.MainActivity")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
                Intent().apply {
                    component = ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.mainscreen.MainScreenActivity")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
                Intent().apply {
                    component = ComponentName("com.huawei.systemmanager", "com.huawei.permissionmanager.ui.MainActivity")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
            for (intent in honorIntents) {
                try {
                    context.startActivity(intent)
                    success = true
                    Log.i(TAG, "[openShortcutPermissionSettings] Started Honor MagicOS: ${intent.component?.className}")
                    break
                } catch (e: Exception) {
                    // Try next
                }
            }
        }

        // 5. 华为 (HarmonyOS / EMUI)
        if (!success && (manufacturer.contains("huawei") || brand.contains("huawei"))) {
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

        // 6. 三星 (One UI)
        if (!success && (manufacturer.contains("samsung") || brand.contains("samsung"))) {
            try {
                val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                success = true
                Log.i(TAG, "[openShortcutPermissionSettings] Started Samsung One UI Application Details")
            } catch (e: Exception) {
                Log.w(TAG, "[openShortcutPermissionSettings] Failed to launch Samsung settings: ${e.message}")
            }
        }

        // 7. 通用兜底：打开系统标准应用详情页（可直达权限设置）
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
