package com.king.corememorydeveloperdashboard.ui.viewmodels

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.king.corememorydeveloperdashboard.data.ApiResult
import com.king.corememorydeveloperdashboard.data.RetrofitClient
import com.king.corememorydeveloperdashboard.data.safeApiCall
import com.king.corememorydeveloperdashboard.util.Constants
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val TAG = "SettingsViewModel"

class SettingsViewModel : ViewModel() {
    
    fun deleteAccount(userId: String) {
        viewModelScope.launch {
            Log.d(TAG, "Deleting account for user: $userId")
            
            withContext(Dispatchers.IO) {
                val result = safeApiCall {
                    RetrofitClient.apiService.deleteUser(
                        appId = Constants.APP_ID,
                        tableName = "users",
                        userId = userId
                    )
                }
                
                when (result) {
                    is ApiResult.Success -> {
                        Log.d(TAG, "Account deleted successfully")
                    }
                    is ApiResult.Error -> {
                        Log.e(TAG, "Error deleting account: ${result.message}")
                    }
                    is ApiResult.Loading -> {}
                }
            }
        }
    }
}