package com.king.corememorydeveloperdashboard

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.king.corememorydeveloperdashboard.data.PreferencesManager
import com.king.corememorydeveloperdashboard.data.SubscriptionManager
import com.king.corememorydeveloperdashboard.data.BillingManager
import com.king.corememorydeveloperdashboard.ui.navigation.AppNavigation
import com.king.corememorydeveloperdashboard.ui.theme.ZenithTheme
import android.content.Context
import android.content.SharedPreferences
import com.dexati.analytics.UserApi

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        var sharedPreferences: SharedPreferences = getSharedPreferences("prefs", Context.MODE_PRIVATE)
        var userId = sharedPreferences.getString("user_id", "")
        UserApi.logUserAnalytics("39539b23-fdc2-425c-9d80-85cd22464b9a",userId!!, applicationContext,"https://api.lastapp.ai/")
        enableEdgeToEdge()
        
        val prefsManager = PreferencesManager(this)
        val subscriptionManager = SubscriptionManager(this)
        val billingManager = BillingManager(this, subscriptionManager)
        
        setContent {
            ZenithTheme {
                Surface(
                    modifier = Modifier
                        .fillMaxSize()
                        .systemBarsPadding()
                ) {
                    AppNavigation(
                        prefsManager = prefsManager,
                        subscriptionManager = subscriptionManager,
                        billingManager = billingManager
                    )
                }
            }
        }
    }
}