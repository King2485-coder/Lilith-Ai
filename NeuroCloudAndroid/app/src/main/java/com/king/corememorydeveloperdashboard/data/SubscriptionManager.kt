package com.king.corememorydeveloperdashboard.data

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class SubscriptionPlan(val id: String, val label: String) {
    FREE("free", "Free"),
    PRO("pro_monthly", "Pro"),
    PREMIUM("premium_monthly", "Premium"),
    LIFETIME("lifetime_unlock", "Lifetime");

    companion object {
        fun fromId(id: String?): SubscriptionPlan {
            return entries.find { it.id == id } ?: FREE
        }
    }
}

class SubscriptionManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("subscription_prefs", Context.MODE_PRIVATE)
    
    private val _currentPlan = MutableStateFlow(getCurrentPlan())
    val currentPlan: StateFlow<SubscriptionPlan> = _currentPlan.asStateFlow()

    fun updatePlan(plan: SubscriptionPlan) {
        prefs.edit().putString("plan_id", plan.id).apply()
        _currentPlan.value = plan
    }

    fun getCurrentPlan(): SubscriptionPlan {
        val planId = prefs.getString("plan_id", SubscriptionPlan.FREE.id)
        return SubscriptionPlan.fromId(planId)
    }

    fun isPro(): Boolean {
        val plan = getCurrentPlan()
        return plan == SubscriptionPlan.PRO || plan == SubscriptionPlan.PREMIUM || plan == SubscriptionPlan.LIFETIME
    }

    fun isPremium(): Boolean {
        val plan = getCurrentPlan()
        return plan == SubscriptionPlan.PREMIUM || plan == SubscriptionPlan.LIFETIME
    }

    fun isLifetime(): Boolean {
        return getCurrentPlan() == SubscriptionPlan.LIFETIME
    }
    
    fun canAccessPremiumFeatures(): Boolean = isPro()
    
    fun canAccessAiFeatures(): Boolean = isPremium()
}