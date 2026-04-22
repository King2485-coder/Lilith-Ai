package com.king.corememorydeveloperdashboard.model

import com.google.gson.annotations.SerializedName

data class User(
    @SerializedName("id")
    val id: String = "",
    @SerializedName("email")
    val email: String = "",
    @SerializedName("provider")
    val provider: String = "",
    @SerializedName("created_at")
    val createdAt: String? = null
)

data class CreateUserRequest(
    @SerializedName("app_id")
    val appId: String,
    @SerializedName("table_name")
    val tableName: String = "users",
    @SerializedName("data")
    val data: UserData
)

data class UserData(
    @SerializedName("email")
    val email: String,
    @SerializedName("password")
    val password: String,
    @SerializedName("provider")
    val provider: String = "email"
)

data class LoginRequest(
    @SerializedName("app_id")
    val appId: String,
    @SerializedName("email")
    val email: String,
    @SerializedName("password")
    val password: String,
    @SerializedName("provider")
    val provider: String = "email"
)