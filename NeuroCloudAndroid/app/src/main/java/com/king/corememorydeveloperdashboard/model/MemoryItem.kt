package com.king.corememorydeveloperdashboard.model

import com.google.gson.annotations.SerializedName

data class MemoryItem(
    @SerializedName("id")
    val id: String = "",
    @SerializedName("app_id")
    val appId: String = "",
    @SerializedName("user_id")
    val userId: String = "",
    @SerializedName("end_user_id")
    val endUserId: String = "",
    @SerializedName("content")
    val content: String = "",
    @SerializedName("memory_type")
    val memoryType: String = "",
    @SerializedName("visibility")
    val visibility: String = "",
    @SerializedName("importance_score")
    val importanceScore: Double = 0.0,
    @SerializedName("confidence_score")
    val confidenceScore: Double = 0.0,
    @SerializedName("access_count")
    val accessCount: Int = 0,
    @SerializedName("last_accessed_at")
    val lastAccessedAt: String? = null,
    @SerializedName("decay_factor")
    val decayFactor: Double = 0.0,
    @SerializedName("metadata")
    val metadata: MemoryMetadata? = null,
    @SerializedName("embedding_id")
    val embeddingId: String? = null,
    @SerializedName("is_deleted")
    val isDeleted: Boolean = false
)

data class MemoryMetadata(
    @SerializedName("created_at")
    val createdAt: String? = null,
    @SerializedName("last_accessed")
    val lastAccessed: String? = null,
    @SerializedName("source")
    val source: String? = null,
    @SerializedName("tags")
    val tags: List<String>? = null
)

data class CreateMemoryRequest(
    @SerializedName("app_id")
    val appId: String,
    @SerializedName("table_name")
    val tableName: String = "memory_items",
    @SerializedName("data")
    val data: MemoryItem
)