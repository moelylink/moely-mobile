package link.moely.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class GalleryWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PREV = "link.moely.mobile.action.GALLERY_PREV"
        const val ACTION_NEXT = "link.moely.mobile.action.GALLERY_NEXT"

        // Mock list of beautiful gallery images for fallback
        val FALLBACK_IMAGES = listOf(
            "https://www.moely.link/images/img1.jpg",
            "https://www.moely.link/images/img2.jpg",
            "https://www.moely.link/images/img3.jpg",
            "https://www.moely.link/images/img4.jpg"
        )
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidgetState(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisWidget = ComponentName(context, GalleryWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)

        val isUnlocked = isPremiumUnlocked(context)
        if (!isUnlocked) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        var currentIndex = prefs.getInt("flutter.gallery_current_index", 0)

        // Read dynamic image list from preferences (JSON or comma separated)
        val imagesList = getGalleryImages(context)

        when (intent.action) {
            ACTION_PREV -> {
                currentIndex = if (currentIndex - 1 < 0) imagesList.size - 1 else currentIndex - 1
                prefs.edit().putInt("flutter.gallery_current_index", currentIndex).apply()
                for (id in appWidgetIds) {
                    updateWidgetState(context, appWidgetManager, id)
                }
            }
            ACTION_NEXT -> {
                currentIndex = (currentIndex + 1) % imagesList.size
                prefs.edit().putInt("flutter.gallery_current_index", currentIndex).apply()
                for (id in appWidgetIds) {
                    updateWidgetState(context, appWidgetManager, id)
                }
            }
        }
    }

    private fun updateWidgetState(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_gallery)
        val isUnlocked = isPremiumUnlocked(context)

        if (!isUnlocked) {
            views.setViewVisibility(R.id.lock_overlay, View.VISIBLE)
            views.setViewVisibility(R.id.gallery_content, View.GONE)
            
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                data = Uri.parse("moely://premium")
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 20, launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.lock_overlay, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } else {
            views.setViewVisibility(R.id.lock_overlay, View.GONE)
            views.setViewVisibility(R.id.gallery_content, View.VISIBLE)
            
            val imagesList = getGalleryImages(context)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val currentIndex = prefs.getInt("flutter.gallery_current_index", 0)
            
            if (imagesList.isNotEmpty()) {
                val imageUrl = imagesList[currentIndex % imagesList.size]
                views.setTextViewText(R.id.gallery_indicator, "${(currentIndex % imagesList.size) + 1}/${imagesList.size}")
                
                // Load image asynchronously
                thread {
                    try {
                        val imgUrl = URL(imageUrl)
                        val imgConn = imgUrl.openConnection() as HttpURLConnection
                        imgConn.connectTimeout = 8000
                        imgConn.readTimeout = 8000
                        imgConn.setRequestProperty("User-Agent", "Mozilla/5.0")
                        val bitmap = BitmapFactory.decodeStream(imgConn.inputStream)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.gallery_image, bitmap)
                            appWidgetManager.updateAppWidget(appWidgetId, views)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            } else {
                views.setTextViewText(R.id.gallery_indicator, "无照片")
            }

            setupButtons(context, views)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun isPremiumUnlocked(context: Context): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.is_premium_unlocked", false)
    }

    private fun getGalleryImages(context: Context): List<String> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val imagesString = prefs.getString("flutter.gallery_images", "") ?: ""
        if (imagesString.isEmpty()) {
            // Provide a list of default image urls (from index.json or fallback links)
            return listOf(
                "https://raw.githubusercontent.com/flutter/website/main/src/assets/images/shared/brand/flutter/logo/flutter-lockup-frame.png",
                "https://picsum.photos/400/400?random=1",
                "https://picsum.photos/400/400?random=2",
                "https://picsum.photos/400/400?random=3"
            )
        }
        return imagesString.split(",").filter { it.isNotEmpty() }
    }

    private fun setupButtons(context: Context, views: RemoteViews) {
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT

        val prevIntent = Intent(context, GalleryWidgetProvider::class.java).apply { action = ACTION_PREV }
        val prevPI = PendingIntent.getBroadcast(context, 21, prevIntent, flag)
        views.setOnClickPendingIntent(R.id.btn_prev, prevPI)

        val nextIntent = Intent(context, GalleryWidgetProvider::class.java).apply { action = ACTION_NEXT }
        val nextPI = PendingIntent.getBroadcast(context, 22, nextIntent, flag)
        views.setOnClickPendingIntent(R.id.btn_next, nextPI)
    }
}
