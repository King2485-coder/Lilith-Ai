package com.king.corememorydeveloperdashboard.data

import com.king.corememorydeveloperdashboard.model.*
import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    
    @POST("data")
    suspend fun createUser(
        @Body request: CreateUserRequest
    ): Response<User>
    
    @POST("data/login")
    suspend fun loginUser(
        @Body request: LoginRequest
    ): Response<User>
    
    @DELETE("data")
    suspend fun deleteUser(
        @Query("app_id") appId: String,
        @Query("table_name") tableName: String,
        @Query("id") userId: String
    ): Response<Map<String, String>>
    
    @POST("data")
    suspend fun createApp(
        @Body request: CreateAppRequest
    ): Response<DeveloperApp>
    
    @GET("data")
    suspend fun getApps(
        @Query("app_id") appId: String,
        @Query("table_name") tableName: String,
        @Query("user_id") userId: String
    ): Response<List<DeveloperApp>>
    
    @POST("data")
    suspend fun createApiKey(
        @Body request: CreateApiKeyRequest
    ): Response<ApiKey>
    
    @GET("data")
    suspend fun getApiKeys(
        @Query("app_id") appId: String,
        @Query("table_name") tableName: String,
        @Query("app_id") developerAppId: String,
        @Query("user_id") userId: String
    ): Response<List<ApiKey>>
    
    @DELETE("data")
    suspend fun deleteApiKey(
        @Query("app_id") appId: String,
        @Query("table_name") tableName: String,
        @Query("id") keyId: String
    ): Response<Map<String, String>>
    
    @PUT("data")
    suspend fun updateApiKeyStatus(
        @Query("app_id") appId: String,
        @Query("table_name") tableName: String,
        @Query("id") keyId: String,
        @Query("is_active") isActive: Boolean
    ): Response<ApiKey>
    
    @POST("data")
    suspend fun createMemory(
        @Body request: CreateMemoryRequest
    ): Response<MemoryItem>
    
    @GET("data")
    suspend fun getMemories(
        @Query("app_id") appId: String,
        @Query("table_name") tableName: String,
        @Query("app_id") developerAppId: String,
        @Query("user_id") userId: String
    ): Response<List<MemoryItem>>
    
    @GET("data")
    suspend fun getUsageLogs(
        @Query("app_id") appId: String,
        @Query("table_name") tableName: String,
        @Query("app_id") developerAppId: String,
        @Query("user_id") userId: String
    ): Response<List<UsageLog>>
    
    @POST("data")
    suspend fun createWebhook(
        @Body request: CreateWebhookRequest
    ): Response<Webhook>
    
    @GET("data")
    suspend fun getWebhooks(
        @Query("app_id") appId: String,
        @Query("table_name") tableName: String,
        @Query("app_id") developerAppId: String,
        @Query("user_id") userId: String
    ): Response<List<Webhook>>
    
    @FormUrlEncoded
    @POST("aiapi/answertext")
    suspend fun queryAi(
        @Field("app_id") appId: String,
        @Field("query") query: String
    ): Response<AiResponse>
}