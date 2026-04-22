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

private const val TAG = "DashboardViewModel"

class DashboardViewModel : ViewModel() {
    
    private val _uiState = MutableStateFlow<DashboardUiState>(DashboardUiState.Loading)
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()
    
    sealed class DashboardUiState {
        object Loading : DashboardUiState()
        data class Success(val apps: List<DeveloperApp>) : DashboardUiState()
        data class Error(val message: String) : DashboardUiState()
    }
    
    fun loadApps(userId: String) {
        viewModelScope.launch {
            _uiState.value = DashboardUiState.Loading
            Log.d(TAG, "Loading apps for user: $userId")
            
            withContext(Dispatchers.IO) {
                val result = safeApiCall {
                    RetrofitClient.apiService.getApps(
                        appId = Constants.APP_ID,
                        tableName = "developer_apps",
                        userId = userId
                    )
                }
                
                when (result) {
                    is ApiResult.Success -> {
                        Log.d(TAG, "Apps loaded: ${result.data.size}")
                        _uiState.value = DashboardUiState.Success(result.data)
                    }
                    is ApiResult.Error -> {
                        Log.e(TAG, "Error loading apps: ${result.message}")
                        _uiState.value = DashboardUiState.Error(result.message)
                    }
                    is ApiResult.Loading -> {}
                }
            }
        }
    }
    
    fun createApp(userId: String, name: String, description: String) {
        viewModelScope.launch {
            Log.d(TAG, "Creating app: $name")
            
            withContext(Dispatchers.IO) {
                val result = safeApiCall {
                    RetrofitClient.apiService.createApp(
                        CreateAppRequest(
                            appId = Constants.APP_ID,
                            data = DeveloperApp(
                                userId = userId,
                                name = name,
                                description = description,
                                isActive = true,
                                planType = "Free",
                                rateLimitSoft = 1000,
                                rateLimitHard = 5000,
                                settings = AppSettings(
                                    defaultMemoryType = "long_term",
                                    aiModelPreference = "openai_gpt4",
                                    webhookEnabled = true
                                )
                            )
                        )
                    )
                }
                
                when (result) {
                    is ApiResult.Success -> {
                        Log.d(TAG, "App created successfully: ${result.data.id}")
                    }
                    is ApiResult.Error -> {
                        Log.e(TAG, "Error creating app: ${result.message}")
                    }
                    is ApiResult.Loading -> {}
                }
            }
        }
    }
}