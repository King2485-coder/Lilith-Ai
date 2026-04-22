package com.king.corememorydeveloperdashboard.ui.viewmodels

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.king.corememorydeveloperdashboard.data.ApiResult
import com.king.corememorydeveloperdashboard.data.RetrofitClient
import com.king.corememorydeveloperdashboard.data.safeApiCall
import com.king.corememorydeveloperdashboard.model.*
import com.king.corememorydeveloperdashboard.util.Constants
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.*

private const val TAG = "ApiKeyViewModel"

class ApiKeyViewModel : ViewModel() {
    
    private val _uiState = MutableStateFlow<ApiKeyUiState>(ApiKeyUiState.Loading)
    val uiState: StateFlow<ApiKeyUiState> = _uiState.asStateFlow()
    
    sealed class ApiKeyUiState {
        object Loading : ApiKeyUiState()
        data class Success(val apiKeys: List<ApiKey>) : ApiKeyUiState()
        data class Error(val message: String) : ApiKeyUiState()
    }
    
    fun loadApiKeys(appId: String, userId: String) {
        viewModelScope.launch {
            _uiState.value = ApiKeyUiState.Loading
            Log.d(TAG, "Loading API keys for app: $appId")
            
            withContext(Dispatchers.IO) {
                val result = safeApiCall {
                    RetrofitClient.apiService.getApiKeys(
                        appId = Constants.APP_ID,
                        tableName = "api_keys",
                        developerAppId = appId,
                        userId = userId
                    )
                }
                
                when (result) {
                    is ApiResult.Success -> {
                        Log.d(TAG, "API keys loaded: ${result.data.size}")
                        _uiState.value = ApiKeyUiState.Success(result.data)
                    }
                    is ApiResult.Error -> {
                        Log.e(TAG, "Error loading API keys: ${result.message}")
                        _uiState.value = ApiKeyUiState.Error(result.message)
                    }
                    is ApiResult.Loading -> {}
                }
            }
        }
    }
    
    fun createApiKey(
        appId: String,
        userId: String,
        keyType: String,
        permissions: List<String>,
        expirationDays: Int,
        onSuccess: (String) -> Unit
    ) {
        viewModelScope.launch {
            Log.d(TAG, "Creating API key for app: $appId")
            
            withContext(Dispatchers.IO) {
                val keyPrefix = generateKeyPrefix(keyType)
                val keyHash = generateSecureKey()
                val fullKey = "$keyPrefix$keyHash"
                
                val expirationDate = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, expirationDays)
                }.time
                
                val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.getDefault())
                
                val apiKey = ApiKey(
                    appId = appId,
                    userId = userId,
                    keyType = keyType,
                    keyHash = keyHash,
                    keyPrefix = keyPrefix,
                    permissions = permissions,
                    isActive = true,
                    expiresAt = dateFormat.format(expirationDate)
                )
                
                val result = safeApiCall {
                    RetrofitClient.apiService.createApiKey(
                        CreateApiKeyRequest(
                            appId = Constants.APP_ID,
                            data = apiKey
                        )
                    )
                }
                
                when (result) {
                    is ApiResult.Success -> {
                        Log.d(TAG, "API key created successfully")
                        onSuccess(fullKey)
                        loadApiKeys(appId, userId) // Refresh the list
                    }
                    is ApiResult.Error -> {
                        Log.e(TAG, "Error creating API key: ${result.message}")
                        _uiState.value = ApiKeyUiState.Error(result.message)
                    }
                    is ApiResult.Loading -> {}
                }
            }
        }
    }
    
    fun deleteApiKey(keyId: String) {
        viewModelScope.launch {
            Log.d(TAG, "Deleting API key: $keyId")
            
            withContext(Dispatchers.IO) {
                val result = safeApiCall {
                    RetrofitClient.apiService.deleteApiKey(
                        appId = Constants.APP_ID,
                        tableName = "api_keys",
                        keyId = keyId
                    )
                }
                
                when (result) {
                    is ApiResult.Success -> {
                        Log.d(TAG, "API key deleted successfully")
                        // Refresh the current list by removing the deleted key
                        val currentState = _uiState.value
                        if (currentState is ApiKeyUiState.Success) {
                            val updatedKeys = currentState.apiKeys.filter { it.id != keyId }
                            _uiState.value = ApiKeyUiState.Success(updatedKeys)
                        }
                    }
                    is ApiResult.Error -> {
                        Log.e(TAG, "Error deleting API key: ${result.message}")
                        _uiState.value = ApiKeyUiState.Error(result.message)
                    }
                    is ApiResult.Loading -> {}
                }
            }
        }
    }
    
    fun toggleApiKeyStatus(keyId: String, newStatus: Boolean) {
        viewModelScope.launch {
            Log.d(TAG, "Toggling API key status: $keyId to $newStatus")
            
            withContext(Dispatchers.IO) {
                val result = safeApiCall {
                    RetrofitClient.apiService.updateApiKeyStatus(
                        appId = Constants.APP_ID,
                        tableName = "api_keys",
                        keyId = keyId,
                        isActive = newStatus
                    )
                }
                
                when (result) {
                    is ApiResult.Success -> {
                        Log.d(TAG, "API key status updated successfully")
                        // Update the current list
                        val currentState = _uiState.value
                        if (currentState is ApiKeyUiState.Success) {
                            val updatedKeys = currentState.apiKeys.map { key ->
                                if (key.id == keyId) key.copy(isActive = newStatus) else key
                            }
                            _uiState.value = ApiKeyUiState.Success(updatedKeys)
                        }
                    }
                    is ApiResult.Error -> {
                        Log.e(TAG, "Error updating API key status: ${result.message}")
                        _uiState.value = ApiKeyUiState.Error(result.message)
                    }
                    is ApiResult.Loading -> {}
                }
            }
        }
    }
    
    private fun generateKeyPrefix(keyType: String): String {
        return when (keyType) {
            "production" -> "cm_prod_"
            "development" -> "cm_dev_"
            "testing" -> "cm_test_"
            else -> "cm_"
        }
    }
    
    private fun generateSecureKey(): String {
        val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        val random = SecureRandom()
        return (1..32)
            .map { chars[random.nextInt(chars.length)] }
            .joinToString("")
    }
}