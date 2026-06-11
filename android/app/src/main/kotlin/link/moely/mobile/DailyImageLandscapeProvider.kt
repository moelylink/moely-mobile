package link.moely.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONArray
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class DailyImageLandscapeProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_daily_image_landscape)

        // Set pending intent to launch main app when clicked
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 2, intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_image, pendingIntent)

        // Fetch daily random image from moely API in a background thread
        thread {
            try {
                val url = URL("https://www.moely.link/index.json")
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.requestMethod = "GET"
                conn.setRequestProperty("User-Agent", "Mozilla/5.0")

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
                        val randomIndex = (0 until jsonArray.length()).random()
                        val imgObject = jsonArray.getJSONObject(randomIndex)
                        val imageUrl = imgObject.getString("urls")
                        val author = imgObject.getString("user")

                        val imgUrl = URL(imageUrl)
                        val imgConn = imgUrl.openConnection() as HttpURLConnection
                        imgConn.connectTimeout = 10000
                        imgConn.readTimeout = 10000
                        imgConn.setRequestProperty("User-Agent", "Mozilla/5.0")
                        
                        val bitmap = BitmapFactory.decodeStream(imgConn.inputStream)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_image, bitmap)
                            views.setTextViewText(R.id.widget_author, "画师: $author")
                            appWidgetManager.updateAppWidget(appWidgetId, views)
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
