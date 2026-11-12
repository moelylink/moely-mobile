package link.moely.mobile

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log

class WidgetPinCallbackReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "MoelyWidget"
        const val ACTION_PIN_WIDGET_SUCCESS = "link.moely.mobile.action.PIN_WIDGET_SUCCESS"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "[WidgetPinCallbackReceiver] Received broadcast with action: $action")
        
        if (action == ACTION_PIN_WIDGET_SUCCESS) {
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            val providerClassName = intent.getStringExtra("provider_class")
            Log.i(TAG, "[WidgetPinCallbackReceiver] Pin success callback received! widgetId=$widgetId, provider=$providerClassName")

            if (!providerClassName.isNullOrEmpty()) {
                try {
                    val cls = Class.forName(providerClassName)
                    dispatchUpdate(context, cls, widgetId)
                    
                    // 延迟 600ms 再次补发一次更新广播，防止个别国产 Launcher 异步落库延迟导致首次广播时 ID 尚未就绪
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            dispatchUpdate(context, cls, widgetId)
                        } catch (e: Exception) {
                            Log.w(TAG, "[WidgetPinCallbackReceiver] Delayed update failed: ${e.message}")
                        }
                    }, 600)
                } catch (e: Exception) {
                    Log.e(TAG, "[WidgetPinCallbackReceiver] Error dispatching update intent: ${e.message}", e)
                }
            }
        }
    }

    private fun dispatchUpdate(context: Context, cls: Class<*>, widgetId: Int) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val targetIds = if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            intArrayOf(widgetId)
        } else {
            // 国产系统 Launcher 不回传 EXTRA_APPWIDGET_ID 时，主动查询该 Provider 在桌面上的全部有效 ID
            val component = ComponentName(context, cls)
            appWidgetManager.getAppWidgetIds(component)
        }

        if (targetIds.isNotEmpty()) {
            val updateIntent = Intent(context, cls).apply {
                this.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, targetIds)
            }
            context.sendBroadcast(updateIntent)
            Log.i(TAG, "[WidgetPinCallbackReceiver] Dispatched ACTION_APPWIDGET_UPDATE to ${cls.simpleName} for ids: ${targetIds.joinToString()}")
        } else {
            Log.w(TAG, "[WidgetPinCallbackReceiver] No valid widget ids found for provider ${cls.simpleName}")
        }
    }
}
