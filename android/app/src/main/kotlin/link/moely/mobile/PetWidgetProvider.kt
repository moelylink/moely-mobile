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
                setupKanbanWidget(context, views)
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
            
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                data = Uri.parse("moely://premium")
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 10, launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.lock_overlay, pendingIntent)
            
            appWidgetManager.updateAppWidget(thisWidget, views)
            return
        }

        views.setViewVisibility(R.id.lock_overlay, View.GONE)
        views.setViewVisibility(R.id.pet_content, View.VISIBLE)
        setupKanbanWidget(context, views)
        appWidgetManager.updateAppWidget(thisWidget, views)
    }

    private fun isPremiumUnlocked(context: Context): Boolean {
        // Shared premium check matching main app
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.is_premium_unlocked", false)
    }

    private fun setupKanbanWidget(context: Context, views: RemoteViews) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val emoji = prefs.getString("flutter.pet_emoji", "😸") ?: "😸"
        val bubbleText = prefs.getString("flutter.pet_bubble_text", "你好呀，今天又是美好的一天！") ?: "你好呀，今天又是美好的一天！"

        views.setTextViewText(R.id.pet_emoji, emoji)
        views.setTextViewText(R.id.pet_bubble_text, bubbleText)
        
        // Hide the native action buttons to make widget look clean
        views.setViewVisibility(R.id.pet_action_bar, View.GONE)

        // Set pending intent to launch in-app KanbanScreen when clicking anywhere on the pet content
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            data = Uri.parse("moely://kanban")
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 20, launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.pet_content, pendingIntent)
    }
}
