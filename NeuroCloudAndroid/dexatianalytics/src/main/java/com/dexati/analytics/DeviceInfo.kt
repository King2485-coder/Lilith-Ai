package com.dexati.analytics

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.util.UUID

object DeviceInfo {

    private const val PREFS_NAME = "user_prefs"
    private const val KEY_USER_ID = "user_generated_id"
    private const val KEY_LAUNCH_NUMBER = "launch_number"

    fun getUserGeneratedId(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var userId = prefs.getString(KEY_USER_ID, null)
        if (userId == null) {
            userId = UUID.randomUUID().toString()
            prefs.edit().putString(KEY_USER_ID, userId).apply()
        }
        return userId
    }

    fun getLaunchNumber(context: Context): Int {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentLaunch = prefs.getInt(KEY_LAUNCH_NUMBER, 0) + 1
        prefs.edit().putInt(KEY_LAUNCH_NUMBER, currentLaunch).apply()
        return currentLaunch
    }

    fun getOS(): String = "Android"

    fun getOSVersion(): String = Build.VERSION.RELEASE ?: "Unknown"

    fun getAppVersion(context: Context): String {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            packageInfo.versionName ?: "Unknown"
        } catch (e: PackageManager.NameNotFoundException) {
            "Unknown"
        }
    }
}
