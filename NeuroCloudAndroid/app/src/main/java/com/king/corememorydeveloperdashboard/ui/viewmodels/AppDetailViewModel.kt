package com.king.corememorydeveloperdashboard.ui.viewmodels

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.king.corememorydeveloperdashboard.data.ApiResult
import com.king.corememorydeveloperdashboard.data.RetrofitClient
import com.king.corememorydeveloperdashboard.data.safeApiCall
import com.king.corememorydeveloperdashboard.model.ApiKey
import com.king.corememorydeveloperdashboard.model.MemoryItem
import com.king.corememorydeveloperdashboard.util.Constants
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val TAG = "AppDetailViewModel"

class AppDetailViewModel : ViewModel() {
    
    private val _uiState = MutableStateFlow<AppDetailUiState>(AppDetailUiState.Loading)
    val uiState: StateFlow<AppDetailUiState> = _uiState.asStateFlow()
    
    sealed class AppDetailUiState {
        object Loading : AppDetailUiState()
        data class Success(
            val apiKeys: List<ApiKey>,
            val memoryItems: List<MemoryItem>
        ) : AppDetailUiState()
        data class Error(val message: String) : AppDetailUiState()
    }
    
    fun loadAppDetails(appId: String, userId: String) {
        viewModelScope.launch {
            _uiState.value = AppDetailUiState.Loading
            Log.d(TAG, "Loading app details for app: $appId")
            
            withContext(Dispatchers.IO) {
                try {
                    val apiKeysResult = safeApiCall {
                        RetrofitClient.apiService.getApiKeys(
                            appId = Constants.APP_ID,
                            tableName = "api_keys",
                            developerAppId = appId,
                            userId = userId
                        )
                    }
                    
                    val memoriesResult = safeApiCall {
                        RetrofitClient.apiService.getMemories(
                            appId = Constants.APP_ID,
                            tableName = "memory_items",
                            developerAppId = appId,
                            userId = userId
                        )
                    }
                    
                    val apiKeys = when (apiKeysResult) {
                        is ApiResult.Success -> apiKeysResult.data
                        else -> emptyList()
                    }
                    
                    val memories = when (memoriesResult) {
                        is ApiResult.Success -> memoriesResult.data
                        else -> emptyList()
                    }
                    
                    Log.d(TAG, "Loaded ${apiKeys.size} API keys and ${memories.size} memory items")
                    _uiState.value = AppDetailUiState.Success(apiKeys, memories)
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Error loading app details", e)
                    _uiState.value = AppDetailUiState.Error(e.message ?: "Unknown error")
                }
            }
        }
    }
}