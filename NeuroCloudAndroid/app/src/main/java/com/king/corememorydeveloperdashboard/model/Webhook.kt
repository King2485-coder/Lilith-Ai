package com.king.corememorydeveloperdashboard.model

import com.google.gson.annotations.SerializedName

data class Webhook(
    @SerializedName("id")
    val id: String = "",
    @SerializedName("app_id")
    val appId: String = "",
    @SerializedName("user_id")
    val userId: String = "",
    @SerializedName("url")
    val url: String = "",
    @SerializedName("events")
    val events: List<String>? = null,
    @SerializedName("is_active")
    val isActive: Boolean = true,
    @SerializedName("secret")
    val secret: String = "",
    @SerializedName("retry_count")
    val retryCount: Int = 0,
    @SerializedName("last_triggered_at")
    val lastTriggeredAt: String? = null,
    @SerializedName("last_status")
    val lastStatus: Int? = null,
    @SerializedName("metadata")
    val metadata: WebhookMetadata? = null
)

data class WebhookMetadata(
    @SerializedName("custom_headers")
    val customHeaders: Map<String, String>? = null,
    @SerializedName("signing_algorithm")
    val signingAlgorithm: String? = null
)

data class CreateWebhookRequest(
    @SerializedName("app_id")
    val appId: String,
    @SerializedName("table_name")
    val tableName: String = "webhooks",
    @SerializedName("data")
    val data: Webhook
)