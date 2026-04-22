package com.king.corememorydeveloperdashboard.model

import com.google.gson.annotations.SerializedName

data class UsageLog(
    @SerializedName("id")
    val id: String = "",
    @SerializedName("app_id")
    val appId: String = "",
    @SerializedName("user_id")
    val userId: String = "",
    @SerializedName("api_key_id")
    val apiKeyId: String = "",
    @SerializedName("endpoint")
    val endpoint: String = "",
    @SerializedName("method")
    val method: String = "",
    @SerializedName("status_code")
    val statusCode: Int = 0,
    @SerializedName("latency_ms")
    val latencyMs: Int = 0,
    @SerializedName("request_size")
    val requestSize: Int = 0,
    @SerializedName("response_size")
    val responseSize: Int = 0,
    @SerializedName("error_message")
    val errorMessage: String? = null,
    @SerializedName("metadata")
    val metadata: LogMetadata? = null
)

data class LogMetadata(
    @SerializedName("ip_address")
    val ipAddress: String? = null,
    @SerializedName("user_agent")
    val userAgent: String? = null,
    @SerializedName("request_params")
    val requestParams: Map<String, Any>? = null
)