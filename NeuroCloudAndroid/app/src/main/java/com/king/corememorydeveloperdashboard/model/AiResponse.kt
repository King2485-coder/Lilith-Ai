package com.king.corememorydeveloperdashboard.model

import com.google.gson.annotations.SerializedName

data class AiResponse(
    @SerializedName("action")
    val action: String? = null,
    @SerializedName("operation_type")
    val operationType: String? = null,
    @SerializedName("result")
    val result: AiResult? = null,
    @SerializedName("context_suggestions")
    val contextSuggestions: List<String>? = null,
    @SerializedName("usage_impact")
    val usageImpact: UsageImpact? = null
)

data class AiResult(
    @SerializedName("memory_id")
    val memoryId: String? = null,
    @SerializedName("content")
    val content: String? = null,
    @SerializedName("type")
    val type: String? = null,
    @SerializedName("importance_score")
    val importanceScore: Double? = null,
    @SerializedName("confidence")
    val confidence: Double? = null,
    @SerializedName("metadata")
    val metadata: MemoryMetadata? = null,
    @SerializedName("relationships")
    val relationships: List<Relationship>? = null
)

data class Relationship(
    @SerializedName("related_memory_id")
    val relatedMemoryId: String? = null,
    @SerializedName("relationship_type")
    val relationshipType: String? = null,
    @SerializedName("strength")
    val strength: Double? = null
)

data class UsageImpact(
    @SerializedName("tokens_used")
    val tokensUsed: Int? = null,
    @SerializedName("storage_bytes")
    val storageBytes: Int? = null,
    @SerializedName("quota_remaining")
    val quotaRemaining: Int? = null
)