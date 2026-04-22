package com.dexati.analytics

import android.content.Context
import android.util.Log
import com.dexati.analytics.DeviceInfo
import org.json.JSONObject
import java.io.BufferedOutputStream
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

object UserApi {

    //private const val BASE_URL = "https://aichat.dexati.com/analytics/log"
    private const val TAG = "UserApi"

    fun logUserAnalytics(
        appId: String,
        uid: String,
        context: Context,
        base_url:String
    ) {
        val uuid = DeviceInfo.getUserGeneratedId(context)
        val launchNumber = DeviceInfo.getLaunchNumber(context)
        val os = DeviceInfo.getOS()
        val osVersion = DeviceInfo.getOSVersion()
        val appVersion = DeviceInfo.getAppVersion(context)

        Log.i(TAG, "Preparing to log user analytics")

        Thread {
            try {
                val url = URL(base_url)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                val jsonBody = JSONObject().apply {
                    put("app_id", appId)
                    if (!uid.isNullOrEmpty()) {
                        put("uid", uid)
                    }
                    put("uuid", uuid)
                    put("launchnumber", launchNumber)
                    put("os", os)
                    put("osversion", osVersion)
                    put("appversion", appVersion)
                }

                Log.d(TAG, "Sending payload: $jsonBody")

                BufferedOutputStream(connection.outputStream).use { output ->
                    output.write(jsonBody.toString().toByteArray())
                    output.flush()
                }

                val responseCode = connection.responseCode
                val response = if (responseCode in 200..299) {
                    BufferedReader(InputStreamReader(connection.inputStream)).use { it.readText() }
                } else {
                    BufferedReader(InputStreamReader(connection.errorStream)).use { it.readText() }
                }

                Log.i(TAG, "Response Code: $responseCode")
                Log.d(TAG, "Response Body: $response")

                connection.disconnect()

            } catch (e: Exception) {
                Log.e(TAG, "Error logging user analytics: ${e.localizedMessage}", e)
            }
        }.start()
    }
}