package com.king.corememorydeveloperdashboard.data

import android.util.Log
import com.google.gson.JsonSyntaxException
import retrofit2.HttpException
import retrofit2.Response
import java.io.IOException

private const val TAG = "ApiHelper"

suspend fun <T> safeApiCall(
    apiCall: suspend () -> Response<T>
): ApiResult<T> {
    return try {
        val response = apiCall()
        Log.d(TAG, "API Response Code: ${response.code()}")
        
        when {
            response.isSuccessful && response.body() != null -> {
                Log.d(TAG, "API Success: ${response.body()}")
                ApiResult.Success(response.body()!!)
            }
            response.code() == 401 -> {
                Log.e(TAG, "Unauthorized: Session expired")
                ApiResult.Error("Session expired. Please login again", 401)
            }
            response.code() == 403 -> {
                Log.e(TAG, "Forbidden: Access denied")
                ApiResult.Error("Access denied", 403)
            }
            response.code() == 404 -> {
                Log.e(TAG, "Not Found: Resource not found")
                ApiResult.Error("Resource not found", 404)
            }
            response.code() >= 500 -> {
                Log.e(TAG, "Server Error: ${response.code()}")
                ApiResult.Error("Server error. Please try again later", response.code())
            }
            else -> {
                Log.e(TAG, "API Error: ${response.message()}")
                ApiResult.Error("Error: ${response.message()}", response.code())
            }
        }
    } catch (e: IOException) {
        Log.e(TAG, "Network Error", e)
        ApiResult.Error("No internet connection")
    } catch (e: HttpException) {
        Log.e(TAG, "HTTP Exception", e)
        ApiResult.Error("Network error: ${e.message()}", e.code())
    } catch (e: JsonSyntaxException) {
        Log.e(TAG, "JSON Parse Error", e)
        ApiResult.Error("Invalid response format")
    } catch (e: Exception) {
        Log.e(TAG, "Unexpected Error", e)
        ApiResult.Error("Unexpected error: ${e.localizedMessage}")
    }
}