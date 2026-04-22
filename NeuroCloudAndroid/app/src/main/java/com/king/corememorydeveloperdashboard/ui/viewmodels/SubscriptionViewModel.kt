package com.king.corememorydeveloperdashboard.ui.viewmodels

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.android.billingclient.api.ProductDetails
import com.king.corememorydeveloperdashboard.data.BillingManager
import com.king.corememorydeveloperdashboard.data.SubscriptionManager
import com.king.corememorydeveloperdashboard.data.SubscriptionPlan
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch

class SubscriptionViewModel(
    private val billingManager: BillingManager,
    private val subscriptionManager: SubscriptionManager
) : ViewModel() {

    val currentPlan: StateFlow<SubscriptionPlan> = subscriptionManager.currentPlan
    val products: StateFlow<List<ProductDetails>> = billingManager.products
    
    private val _error = MutableSharedFlow<String>()
    val error: SharedFlow<String> = _error.asSharedFlow()

    init {
        viewModelScope.launch {
            billingManager.billingError.collect {
                _error.emit(it)
            }
        }
    }

    fun upgrade(activity: Activity, productId: String) {
        val product = products.value.find { it.productId == productId }
        if (product != null) {
            billingManager.launchBillingFlow(activity, product)
        } else {
            viewModelScope.launch {
                _error.emit("Product not found: $productId")
            }
        }
    }
}