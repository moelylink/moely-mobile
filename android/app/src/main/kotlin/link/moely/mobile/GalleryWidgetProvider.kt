package link.moely.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
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
        val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return

        val isUnlocked = isPremiumUnlocked(context)
        if (!isUnlocked) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        var currentIndex = prefs.getInt("flutter.gallery_current_index_$appWidgetId", 0)

        val imagesList = getGalleryImages(context, appWidgetId)
        if (imagesList.isEmpty()) return

        when (intent.action) {
            ACTION_PREV -> {
                val pendingResult = goAsync()
                currentIndex = if (currentIndex - 1 < 0) imagesList.size - 1 else currentIndex - 1
                prefs.edit().putInt("flutter.gallery_current_index_$appWidgetId", currentIndex).apply()
                updateWidgetState(context, appWidgetManager, appWidgetId, pendingResult)
            }
            ACTION_NEXT -> {
                val pendingResult = goAsync()
                currentIndex = (currentIndex + 1) % imagesList.size
                prefs.edit().putInt("flutter.gallery_current_index_$appWidgetId", currentIndex).apply()
                updateWidgetState(context, appWidgetManager, appWidgetId, pendingResult)
            }
        }
    }

    private fun updateWidgetState(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        pendingResult: BroadcastReceiver.PendingResult? = null
    ) {
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
            pendingResult?.finish()
        } else {
            val scale = getGalleryScale(context, appWidgetId)
            val imagesList = getGalleryImages(context, appWidgetId)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val currentIndex = prefs.getInt("flutter.gallery_current_index_$appWidgetId", 0)
            val title = getGalleryTitle(context, appWidgetId)

            val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
            val configIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                data = Uri.parse("moely://widget/gallery/config?widgetId=$appWidgetId")
            }
            val configPI = PendingIntent.getActivity(
                context, appWidgetId * 10 + 3, configIntent, flag
            )

            var clickPI: PendingIntent? = null
            if (imagesList.isNotEmpty()) {
                val imageUrl = imagesList[currentIndex % imagesList.size]
                val clickIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    data = Uri.parse("moely://widget/gallery/click?widgetId=$appWidgetId&image=${Uri.encode(imageUrl)}")
                }
                clickPI = PendingIntent.getActivity(
                    context, appWidgetId * 10 + 4, clickIntent, flag
                )
            }

            val setupBaseViews = { rv: RemoteViews ->
                rv.setViewVisibility(R.id.lock_overlay, View.GONE)
                rv.setViewVisibility(R.id.gallery_content, View.VISIBLE)
                
                // Show/hide image view depending on scale setting (3 = FIT_CENTER, 6 = CENTER_CROP)
                if (scale == 3) {
                    rv.setViewVisibility(R.id.gallery_image_fit, View.VISIBLE)
                    rv.setViewVisibility(R.id.gallery_image_crop, View.GONE)
                } else {
                    rv.setViewVisibility(R.id.gallery_image_crop, View.VISIBLE)
                    rv.setViewVisibility(R.id.gallery_image_fit, View.GONE)
                }
                
                rv.setTextViewText(R.id.gallery_title, title)
                setupButtons(context, rv, appWidgetId)
                rv.setOnClickPendingIntent(R.id.gallery_title, configPI)
                
                val activeClickPI = clickPI ?: configPI
                rv.setOnClickPendingIntent(R.id.gallery_image_crop, activeClickPI)
                rv.setOnClickPendingIntent(R.id.gallery_image_fit, activeClickPI)
            }

            setupBaseViews(views)

            if (imagesList.isNotEmpty()) {
                val imageUrl = imagesList[currentIndex % imagesList.size]
                views.setTextViewText(R.id.gallery_indicator, "${(currentIndex % imagesList.size) + 1}/${imagesList.size}")
                appWidgetManager.updateAppWidget(appWidgetId, views)

                // Load image asynchronously
                thread {
                    try {
                        val bitmap = if (imageUrl.startsWith("http://") || imageUrl.startsWith("https://")) {
                            decodeSampledBitmapFromUrl(context, imageUrl)
                        } else {
                            decodeSampledBitmapFromFile(imageUrl, 600, 600)
                        }
                        
                        // Create a separate, new RemoteViews instance for thread safety
                        val threadViews = RemoteViews(context.packageName, R.layout.widget_gallery)
                        setupBaseViews(threadViews)
                        threadViews.setTextViewText(R.id.gallery_indicator, "${(currentIndex % imagesList.size) + 1}/${imagesList.size}")

                        val activeImageViewId = if (scale == 3) R.id.gallery_image_fit else R.id.gallery_image_crop
                        if (bitmap != null) {
                            threadViews.setImageViewBitmap(activeImageViewId, bitmap)
                            appWidgetManager.updateAppWidget(appWidgetId, threadViews)
                        } else {
                            threadViews.setTextViewText(R.id.gallery_title, "Null: " + imageUrl.takeLast(25))
                            appWidgetManager.updateAppWidget(appWidgetId, threadViews)
                        }
                    } catch (e: Throwable) {
                        e.printStackTrace()
                        try {
                            val threadViews = RemoteViews(context.packageName, R.layout.widget_gallery)
                            setupBaseViews(threadViews)
                            threadViews.setTextViewText(R.id.gallery_indicator, "${(currentIndex % imagesList.size) + 1}/${imagesList.size}")
                            threadViews.setTextViewText(R.id.gallery_title, "Err: " + e.localizedMessage)
                            appWidgetManager.updateAppWidget(appWidgetId, threadViews)
                        } catch (ex: Throwable) {
                            ex.printStackTrace()
                        }
                    } finally {
                        pendingResult?.finish()
                    }
                }
            } else {
                views.setTextViewText(R.id.gallery_indicator, "无照片")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                pendingResult?.finish()
            }      }
    }

    private fun isPremiumUnlocked(context: Context): Boolean {
        return true
    }

    private fun getGalleryImages(context: Context, appWidgetId: Int): List<String> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        var imagesString = prefs.getString("flutter.gallery_images_$appWidgetId", "") ?: ""
        if (imagesString.isEmpty()) {
            imagesString = prefs.getString("flutter.gallery_images", "") ?: ""
        }
        if (imagesString.isEmpty()) {
            return listOf(
                "https://raw.githubusercontent.com/flutter/website/main/src/assets/images/shared/brand/flutter/logo/flutter-lockup-frame.png",
                "https://picsum.photos/400/400?random=1",
                "https://picsum.photos/400/400?random=2",
                "https://picsum.photos/400/400?random=3"
            )
        }
        return imagesString.split(",").filter { it.isNotEmpty() }
    }

    private fun getGalleryTitle(context: Context, appWidgetId: Int): String {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("flutter.widget_custom_name_$appWidgetId", "")?.takeIf { it.isNotEmpty() }
            ?: prefs.getString("flutter.gallery_title_$appWidgetId", "")?.takeIf { it.isNotEmpty() }
            ?: prefs.getString("flutter.gallery_title", "")?.takeIf { it.isNotEmpty() }
            ?: "自定义画廊"
    }

    private fun getGalleryScale(context: Context, appWidgetId: Int): Int {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val specificScale = prefs.getInt("flutter.gallery_scale_$appWidgetId", -1)
        if (specificScale != -1) return specificScale
        return prefs.getInt("flutter.gallery_scale", 6)
    }

    private fun setupButtons(context: Context, views: RemoteViews, appWidgetId: Int) {
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT

        val prevIntent = Intent(context, GalleryWidgetProvider::class.java).apply {
            action = ACTION_PREV
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val prevPI = PendingIntent.getBroadcast(context, appWidgetId * 10 + 1, prevIntent, flag)
        views.setOnClickPendingIntent(R.id.btn_prev, prevPI)

        val nextIntent = Intent(context, GalleryWidgetProvider::class.java).apply {
            action = ACTION_NEXT
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val nextPI = PendingIntent.getBroadcast(context, appWidgetId * 10 + 2, nextIntent, flag)
        views.setOnClickPendingIntent(R.id.btn_next, nextPI)
    }

    private fun decodeSampledBitmapFromFile(path: String, reqWidth: Int, reqHeight: Int): Bitmap? {
        try {
            val options = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeFile(path, options)

            options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight)
            options.inJustDecodeBounds = false
            return BitmapFactory.decodeFile(path, options)
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun decodeSampledBitmapFromUrl(context: Context, urlString: String): Bitmap? {
        var connection: HttpURLConnection? = null
        try {
            var url = URL(urlString)
            var redirectCount = 0
            val maxRedirects = 5
            
            while (redirectCount < maxRedirects) {
                connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 8000
                connection.readTimeout = 8000
                connection.instanceFollowRedirects = true
                connection.setRequestProperty("User-Agent", getUserAgent(context))
                connection.setRequestProperty("Accept", "image/webp,image/apng,image/*,*/*;q=0.8")
                
                val status = connection.responseCode
                if (status == HttpURLConnection.HTTP_MOVED_TEMP || 
                    status == HttpURLConnection.HTTP_MOVED_PERM || 
                    status == 307 || status == 308) {
                    
                    var newUrl = connection.getHeaderField("Location")
                    if (newUrl != null) {
                        if (newUrl.startsWith("/")) {
                            newUrl = url.protocol + "://" + url.host + newUrl
                        }
                        url = URL(newUrl)
                        redirectCount++
                        connection.disconnect()
                        continue
                    }
                }
                break
            }
            
            val inputStream = connection?.inputStream ?: return null
            val bitmap = BitmapFactory.decodeStream(inputStream)
            inputStream.close()
            connection.disconnect()
            return bitmap
        } catch (t: Throwable) {
            t.printStackTrace()
            connection?.disconnect()
            return null
        }
    }

    private fun calculateInSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
        val height = options.outHeight
        val width = options.outWidth
        var inSampleSize = 1

        if (height > reqHeight || width > reqWidth) {
            val halfHeight = height / 2
            val halfWidth = width / 2

            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }
}
