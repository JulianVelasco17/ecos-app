package com.ecos.astroapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WidgetBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            AstrosWidget.scheduleDailyRefresh(context)
        }
    }
}
