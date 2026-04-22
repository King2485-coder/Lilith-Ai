package com.king.corememorydeveloperdashboard.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.king.corememorydeveloperdashboard.data.BillingManager
import com.king.corememorydeveloperdashboard.data.PreferencesManager
import com.king.corememorydeveloperdashboard.data.SubscriptionManager
import com.king.corememorydeveloperdashboard.ui.screens.*
import com.king.corememorydeveloperdashboard.ui.viewmodels.SubscriptionViewModel

@Composable
fun AppNavigation(
    prefsManager: PreferencesManager,
    billingManager: BillingManager,
    subscriptionManager: SubscriptionManager
) {
    val navController = rememberNavController()
    
    val startDestination = when {
        !prefsManager.isOnboardingCompleted() -> "onboarding"
        !prefsManager.isLoggedIn() -> "signin"
        else -> "dashboard"
    }
    
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable("onboarding") {
            OnboardingScreen(
                onComplete = {
                    prefsManager.setOnboardingCompleted(true)
                    navController.navigate("signin") {
                        popUpTo("onboarding") { inclusive = true }
                    }
                }
            )
        }

        composable("signin") {
            SignInScreen(
                prefsManager = prefsManager,
                onNavigateToSignUp = { navController.navigate("signup") },
                onSignInSuccess = {
                    navController.navigate("dashboard") {
                        popUpTo("signin") { inclusive = true }
                    }
                }
            )
        }

        composable("signup") {
            SignUpScreen(
                prefsManager = prefsManager,
                onNavigateToSignIn = { navController.popBackStack() },
                onSignUpSuccess = {
                    navController.navigate("dashboard") {
                        popUpTo("signup") { inclusive = true }
                    }
                }
            )
        }

        composable("dashboard") {
            DashboardScreen(
                prefsManager = prefsManager,
                subscriptionManager = subscriptionManager,
                onNavigateToAppDetail = { appId ->
                    navController.navigate("app_detail/$appId")
                },
                onNavigateToSettings = {
                    navController.navigate("settings")
                },
                onNavigateToSubscription = {
                    navController.navigate("subscription")
                },
                onLogout = {
                    prefsManager.clearUserData()
                    navController.navigate("signin") {
                        popUpTo("dashboard") { inclusive = true }
                    }
                }
            )
        }

        composable("settings") {
            SettingsScreen(
                prefsManager = prefsManager,
                subscriptionManager = subscriptionManager,
                onNavigateBack = { navController.popBackStack() },
                onNavigateToSubscription = { navController.navigate("subscription") },
                onLogout = {
                    prefsManager.clearUserData()
                    navController.navigate("signin") {
                        popUpTo("dashboard") { inclusive = true }
                    }
                },
                onDeleteAccount = {
                    prefsManager.clearUserData()
                    navController.navigate("signin") {
                        popUpTo("dashboard") { inclusive = true }
                    }
                }
            )
        }

        composable(
            route = "app_detail/{appId}",
            arguments = listOf(navArgument("appId") { type = NavType.StringType })
        ) { backStackEntry ->
            val appId = backStackEntry.arguments?.getString("appId") ?: ""
            AppDetailScreen(
                appId = appId,
                prefsManager = prefsManager,
                onNavigateBack = { navController.popBackStack() },
                onNavigateToApiKeys = { id: String ->
                    navController.navigate("api_key_management/$id")
                }
            )
        }

        composable(
            route = "api_key_management/{appId}",
            arguments = listOf(navArgument("appId") { type = NavType.StringType })
        ) { backStackEntry ->
            val appId = backStackEntry.arguments?.getString("appId") ?: ""
            ApiKeyManagementScreen(
                appId = appId,
                prefsManager = prefsManager,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable("subscription") {
            val viewModel = SubscriptionViewModel(billingManager, subscriptionManager)
            SubscriptionScreen(
                viewModel = viewModel,
                onBack = { navController.popBackStack() }
            )
        }
    }
}
