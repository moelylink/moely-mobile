package link.moely.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews

class PetWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_FEED = "link.moely.mobile.action.PET_FEED"
        const val ACTION_INTERACT = "link.moely.mobile.action.PET_INTERACT"
        const val ACTION_STATUS = "link.moely.mobile.action.PET_STATUS"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_pet)
            val isUnlocked = isPremiumUnlocked(context)

            if (!isUnlocked) {
                views.setViewVisibility(R.id.lock_overlay, View.VISIBLE)
                views.setViewVisibility(R.id.pet_content, View.GONE)
                
                // Click on lock redirects to Premium screen in main app
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    data = Uri.parse("moely://premium")
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 10, launchIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setOnClickPendingIntent(R.id.lock_overlay, pendingIntent)
            } else {
                views.setViewVisibility(R.id.lock_overlay, View.GONE)
                views.setViewVisibility(R.id.pet_content, View.VISIBLE)
                setupButtons(context, views)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisWidget = ComponentName(context, PetWidgetProvider::class.java)
        val views = RemoteViews(context.packageName, R.layout.widget_pet)

        val isUnlocked = isPremiumUnlocked(context)
        if (!isUnlocked) {
            views.setViewVisibility(R.id.lock_overlay, View.VISIBLE)
            views.setViewVisibility(R.id.pet_content, View.GONE)
            appWidgetManager.updateAppWidget(thisWidget, views)
            return
        }

        views.setViewVisibility(R.id.lock_overlay, View.GONE)
        views.setViewVisibility(R.id.pet_content, View.VISIBLE)
        setupButtons(context, views)

        when (intent.action) {
            ACTION_FEED -> {
                views.setTextViewText(R.id.pet_bubble_text, "🍲 唔嘛唔嘛...真好喝！好感度 +10")
                views.setTextViewText(R.id.pet_emoji, "😸")
                appWidgetManager.updateAppWidget(thisWidget, views)
            }
            ACTION_INTERACT -> {
                val quotes = listOf("✨ 喵呜~ 贴贴主人！", "🎵 喵喵喵~ 今天天气真好！", "💤 呼噜呼噜...好舒服", "🐾 主人，快陪我玩吧~")
                views.setTextViewText(R.id.pet_bubble_text, quotes.random())
                views.setTextViewText(R.id.pet_emoji, "😻")
                appWidgetManager.updateAppWidget(thisWidget, views)
            }
            ACTION_STATUS -> {
                views.setTextViewText(R.id.pet_bubble_text, "📊 饥饿: 10% | 心情: 极佳 | 状态: 散步中")
                views.setTextViewText(R.id.pet_emoji, "🦁")
                appWidgetManager.updateAppWidget(thisWidget, views)
            }
        }
    }

    private fun isPremiumUnlocked(context: Context): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.is_premium_unlocked", false)
    }

    private fun setupButtons(context: Context, views: RemoteViews) {
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT

        // Feed button intent
        val feedIntent = Intent(context, PetWidgetProvider::class.java).apply { action = ACTION_FEED }
        val feedPI = PendingIntent.getBroadcast(context, 11, feedIntent, flag)
        views.setOnClickPendingIntent(R.id.btn_feed, feedPI)

        // Interact button intent
        val interactIntent = Intent(context, PetWidgetProvider::class.java).apply { action = ACTION_INTERACT }
        val interactPI = PendingIntent.getBroadcast(context, 12, interactIntent, flag)
        views.setOnClickPendingIntent(R.id.btn_interact, interactPI)

        // Status button intent
        val statusIntent = Intent(context, PetWidgetProvider::class.java).apply { action = ACTION_STATUS }
        val statusPI = PendingIntent.getBroadcast(context, 13, statusIntent, flag)
        views.setOnClickPendingIntent(R.id.btn_status, statusPI)
    }
}
