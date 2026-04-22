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

private const val TAG = "AuthViewModel"

class AuthViewModel : ViewModel() {
    
    private val _uiState = MutableStateFlow<AuthUiState>(AuthUiState.Idle)
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()
    
    sealed class AuthUiState {
        object Idle : AuthUiState()
        object Loading : AuthUiState()
        data class Success(val user: User) : AuthUiState()
        data class Error(val message: String) : AuthUiState()
    }
    
    fun signUp(email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = AuthUiState.Loading
            Log.d(TAG, "Starting sign up for email: $email")
            
            withContext(Dispatchers.IO) {
                val result = safeApiCall {
                    RetrofitClient.apiService.createUser(
                        CreateUserRequest(
                            appId = Constants.APP_ID,
                            data = UserData(
                                email = email,
                                password = password
                            )
                        )
                    )
                }
                
                when (result) {
                    is ApiResult.Success -> {
                        Log.d(TAG, "Sign up successful: ${result.data}")
                        _uiState.value = AuthUiState.Success(result.data)
                    }
                    is ApiResult.Error -> {
                        Log.e(TAG, "Sign up error: ${result.message}")
                        _uiState.value = AuthUiState.Error(result.message)
                    }
                    is ApiResult.Loading -> {}
                }
            }
        }
    }
    
    fun signIn(email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = AuthUiState.Loading
            Log.d(TAG, "Starting sign in for email: $email")
            
            withContext(Dispatchers.IO) {
                val result = safeApiCall {
                    RetrofitClient.apiService.loginUser(
                        LoginRequest(
                            appId = Constants.APP_ID,
                            email = email,
                            password = password
                        )
                    )
                }
                
                when (result) {
                    is ApiResult.Success -> {
                        Log.d(TAG, "Sign in successful: ${result.data}")
                        _uiState.value = AuthUiState.Success(result.data)
                    }
                    is ApiResult.Error -> {
                        Log.e(TAG, "Sign in error: ${result.message}")
                        _uiState.value = AuthUiState.Error(result.message)
                    }
                    is ApiResult.Loading -> {}
                }
            }
        }
    }
}