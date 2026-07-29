package link.moely.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONArray
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class DailyImagePortraitProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val pendingResult = goAsync()
            updateAppWidget(context, appWidgetManager, appWidgetId, pendingResult)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        pendingResult: BroadcastReceiver.PendingResult? = null
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_daily_image_portrait)

        // Set default pending intent to launch main app when clicked (fallback)
        val defaultIntent = Intent(context, MainActivity::class.java)
        val defaultPI = PendingIntent.getActivity(
            context, appWidgetId * 10, defaultIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_image, defaultPI)

        // Fetch daily random image from cache or moely API in a background thread
        thread {
            try {
                // Try cache first
                val cached = WidgetCacheManager.getAndPopCachedImage(context, isLandscape = false)
                if (cached != null) {
                    val bitmap = BitmapFactory.decodeFile(cached.localPath)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_image, bitmap)
                        views.setTextViewText(R.id.widget_author, "画师: ${cached.author}")
                        
                        // Set specific image detail deep link
                        val clickIntent = Intent(context, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            data = Uri.parse("moely://img/${cached.id}")
                        }
                        val clickPI = PendingIntent.getActivity(
                            context, appWidgetId * 10 + 1, clickIntent,
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
                        )
                        views.setOnClickPendingIntent(R.id.widget_image, clickPI)
                        
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                        return@thread
                    }
                }

                // If cache is empty or fails, fall back to direct request (with portrait filtering)
                val url = URL("https://www.moely.link/index.json")
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.requestMethod = "GET"
                conn.setRequestProperty("User-Agent", getUserAgent(context))

                if (conn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream))
                    val response = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        response.append(line)
                    }
                    reader.close()

                    val jsonArray = JSONArray(response.toString())
                    if (jsonArray.length() > 0) {
                        val indices = (0 until jsonArray.length()).toList().shuffled()
                        var found = false
                        for (randomIndex in indices) {
                            val imgObject = jsonArray.getJSONObject(randomIndex)
                            val imageUrl = imgObject.getString("urls")
                            val id = imgObject.getString("id")
                            val author = imgObject.getString("user")

                            // Check orientation
                            val imgUrl = URL(imageUrl)
                            val imgConn = imgUrl.openConnection() as HttpURLConnection
                            imgConn.connectTimeout = 8000
                            imgConn.readTimeout = 8000
                            imgConn.setRequestProperty("User-Agent", getUserAgent(context))
                            imgConn.setRequestProperty("Accept", "image/webp,image/apng,image/*,*/*;q=0.8")

                            val options = BitmapFactory.Options().apply {
                                inJustDecodeBounds = true
                            }
                            BitmapFactory.decodeStream(imgConn.inputStream, null, options)
                            val width = options.outWidth
                            val height = options.outHeight

                            if (width < height && width > 0) {
                                // Download full image
                                val fullConn = imgUrl.openConnection() as HttpURLConnection
                                fullConn.connectTimeout = 10000
                                fullConn.readTimeout = 10000
                                fullConn.setRequestProperty("User-Agent", getUserAgent(context))
                                val bitmap = BitmapFactory.decodeStream(fullConn.inputStream)
                                if (bitmap != null) {
                                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                                    views.setTextViewText(R.id.widget_author, "画师: $author")
                                    
                                    val clickIntent = Intent(context, MainActivity::class.java).apply {
                                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                        data = Uri.parse("moely://img/$id")
                                    }
                                    val clickPI = PendingIntent.getActivity(
                                        context, appWidgetId * 10 + 1, clickIntent,
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
                                    )
                                    views.setOnClickPendingIntent(R.id.widget_image, clickPI)
                                    
                                    appWidgetManager.updateAppWidget(appWidgetId, views)
                                    found = true
                                    break
                                }
                            }
                        }
                        
                        // If we didn't find any portrait image in shuffled list, do a simple random fallback
                        if (!found) {
                            val randomIndex = (0 until jsonArray.length()).random()
                            val imgObject = jsonArray.getJSONObject(randomIndex)
                            val imageUrl = imgObject.getString("urls")
                            val id = imgObject.getString("id")
                            val author = imgObject.getString("user")
                            val imgUrl = URL(imageUrl)
                            val imgConn = imgUrl.openConnection() as HttpURLConnection
                            imgConn.connectTimeout = 10000
                            imgConn.readTimeout = 10000
                            imgConn.setRequestProperty("User-Agent", getUserAgent(context))
                            val bitmap = BitmapFactory.decodeStream(imgConn.inputStream)
                            if (bitmap != null) {
                                views.setImageViewBitmap(R.id.widget_image, bitmap)
                                views.setTextViewText(R.id.widget_author, "画师: $author")
                                
                                val clickIntent = Intent(context, MainActivity::class.java).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                    data = Uri.parse("moely://img/$id")
                                }
                                val clickPI = PendingIntent.getActivity(
                                    context, appWidgetId * 10 + 1, clickIntent,
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
                                )
                                views.setOnClickPendingIntent(R.id.widget_image, clickPI)
                                
                                appWidgetManager.updateAppWidget(appWidgetId, views)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                // Trigger prefetch to fill queue for next time
                WidgetCacheManager.triggerPrefetch(context, isLandscape = false)
                pendingResult?.finish()
            }
        }
    }
}
