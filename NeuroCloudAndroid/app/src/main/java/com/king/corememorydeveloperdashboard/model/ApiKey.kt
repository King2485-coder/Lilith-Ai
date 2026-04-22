package com.king.corememorydeveloperdashboard.model

import com.google.gson.annotations.SerializedName

data class ApiKey(
    @SerializedName("id")
    val id: String = "",
    @SerializedName("app_id")
    val appId: String = "",
    @SerializedName("user_id")
    val userId: String = "",
    @SerializedName("key_type")
    val keyType: String = "",
    @SerializedName("key_hash")
    val keyHash: String = "",
    @SerializedName("key_prefix")
    val keyPrefix: String = "",
    @SerializedName("permissions")
    val permissions: List<String>? = null,
    @SerializedName("is_active")
    val isActive: Boolean = true,
    @SerializedName("last_used_at")
    val lastUsedAt: String? = null,
    @SerializedName("expires_at")
    val expiresAt: String? = null
)

data class CreateApiKeyRequest(
    @SerializedName("app_id")
    val appId: String,
    @SerializedName("table_name")
    val tableName: String = "api_keys",
    @SerializedName("data")
    val data: ApiKey
)