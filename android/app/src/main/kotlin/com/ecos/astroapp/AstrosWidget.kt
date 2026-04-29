package com.ecos.astroapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Calendar

class AstrosWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleDailyRefresh(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelDailyRefresh(context)
    }

    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
            val prefs = HomeWidgetPlugin.getData(context)
            val frase = prefs.getString("widget_frase", "Cargando tu lectura de hoy...") ?: ""

            val views = RemoteViews(context.packageName, R.layout.astros_widget)
            views.setTextViewText(R.id.widget_frase, frase)

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_frase, pending)
            views.setOnClickPendingIntent(R.id.widget_title, pending)
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        fun scheduleDailyRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = buildRefreshIntent(context)

            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 7)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
            }

            alarmManager.setInexactRepeating(
                AlarmManager.RTC,
                calendar.timeInMillis,
                AlarmManager.INTERVAL_DAY,
                pending
            )
        }

        fun cancelDailyRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(buildRefreshIntent(context))
        }

        private fun buildRefreshIntent(context: Context): PendingIntent {
            val intent = Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
                data = Uri.parse("ecos://widget/refresh")
            }
            return PendingIntent.getBroadcast(
                context, 1001, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
