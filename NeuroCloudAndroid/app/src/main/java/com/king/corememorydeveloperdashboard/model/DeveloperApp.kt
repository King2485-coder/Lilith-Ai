package com.king.corememorydeveloperdashboard.model

import com.google.gson.annotations.SerializedName

data class DeveloperApp(
    @SerializedName("id")
    val id: String = "",
    @SerializedName("user_id")
    val userId: String = "",
    @SerializedName("name")
    val name: String = "",
    @SerializedName("description")
    val description: String? = "",
    @SerializedName("is_active")
    val isActive: Boolean = true,
    @SerializedName("plan_type")
    val planType: String = "Free",
    @SerializedName("rate_limit_soft")
    val rateLimitSoft: Int = 1000,
    @SerializedName("rate_limit_hard")
    val rateLimitHard: Int = 5000,
    @SerializedName("settings")
    val settings: AppSettings? = null
)

data class AppSettings(
    @SerializedName("default_memory_type")
    val defaultMemoryType: String? = null,
    @SerializedName("ai_model_preference")
    val aiModelPreference: String? = null,
    @SerializedName("webhook_enabled")
    val webhookEnabled: Boolean? = null
)

data class CreateAppRequest(
    @SerializedName("app_id")
    val appId: String,
    @SerializedName("table_name")
    val tableName: String = "developer_apps",
    @SerializedName("data")
    val data: DeveloperApp
)