package link.moely.mobile

import android.app.PendingIntent
import android.app.WallpaperManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONArray
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

import android.util.Log
import java.util.concurrent.atomic.AtomicInteger

class MoelyWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "MoelyWidget"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.i(TAG, "[MoelyWidgetProvider] onUpdate triggered. widgetIds count=${appWidgetIds.size}: ${appWidgetIds.joinToString()}")
        if (appWidgetIds.isEmpty()) return

        val pendingResult = goAsync()
        val remaining = AtomicInteger(appWidgetIds.size)

        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId) {
                if (remaining.decrementAndGet() == 0) {
                    Log.i(TAG, "[MoelyWidgetProvider] All pending widget updates finished.")
                    pendingResult?.finish()
                }
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        onComplete: () -> Unit
    ) {
        val views = RemoteViews(context.packageName, R.layout.moely_widget_layout)

        // Set pending intent to launch main app when clicked
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_image, pendingIntent)

        // 立即提交首帧占位视图，防止桌面小组件在网络拉取期间显示未初始化的全黑空状态
        views.setTextViewText(R.id.widget_author, "壁纸同步中...")
        appWidgetManager.updateAppWidget(appWidgetId, views)

        // Start thread to fetch daily random image safely without blocking main thread
        thread {
            try {
                Log.i(TAG, "[MoelyWidgetProvider] Fetching index.json for widgetId=$appWidgetId")
                val url = URL("https://www.moely.link/index.json")
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.requestMethod = "GET"
                conn.setRequestProperty("User-Agent", getUserAgent(context))

                val responseCode = conn.responseCode
                Log.i(TAG, "[MoelyWidgetProvider] index.json responseCode=$responseCode")

                if (responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream))
                    val response = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        response.append(line)
                    }
                    reader.close()

                    val jsonArray = JSONArray(response.toString())
                    if (jsonArray.length() > 0) {
                        val randomIndex = (0 until jsonArray.length()).random()
                        val imgObject = jsonArray.getJSONObject(randomIndex)
                        val imageUrl = imgObject.getString("urls")
                        val author = imgObject.getString("user")
                        Log.i(TAG, "[MoelyWidgetProvider] Selected image url=$imageUrl, author=$author")

                        val imgUrl = URL(imageUrl)
                        val imgConn = imgUrl.openConnection() as HttpURLConnection
                        imgConn.connectTimeout = 10000
                        imgConn.readTimeout = 10000
                        imgConn.setRequestProperty("User-Agent", getUserAgent(context))
                        imgConn.setRequestProperty("Accept", "image/webp,image/apng,image/*,*/*;q=0.8")
                        
                        val bitmap = BitmapFactory.decodeStream(imgConn.inputStream)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_image, bitmap)
                            views.setTextViewText(R.id.widget_author, "画师: $author")
                            
                            appWidgetManager.updateAppWidget(appWidgetId, views)
                            Log.i(TAG, "[MoelyWidgetProvider] Successfully updated widgetId=$appWidgetId")
                        } else {
                            Log.w(TAG, "[MoelyWidgetProvider] Failed to decode bitmap stream for widgetId=$appWidgetId")
                        }
                    }
                } else {
                    Log.w(TAG, "[MoelyWidgetProvider] Failed to fetch index.json, HTTP code=$responseCode")
                }
            } catch (e: Exception) {
                Log.e(TAG, "[MoelyWidgetProvider] Exception updating widgetId=$appWidgetId: ${e.message}", e)
            } finally {
                onComplete()
            }
        }
    }
}
