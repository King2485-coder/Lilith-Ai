package com.king.corememorydeveloperdashboard.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

// Zenith Pro Material Extended Color System
object ZenithExtendedColors {
    
    // Glass Surface Colors with Alpha
    val glassSurfaceLight = Color(0xE6FFFFFF) // 90% white
    val glassSurfaceDark = Color(0xD91C1C1E) // 85% dark surface
    
    // Glass Stroke Colors
    val glassStrokeLight = Color(0x1F000000) // 12% black
    val glassStrokeDark = Color(0x33FFFFFF) // 20% white
    
    // Glass Highlight Colors
    val glassHighlightLight = Color(0xFFFFFFFF) // Pure white
    val glassHighlightDark = Color(0x26FFFFFF) // 15% white
    
    // Shadow Colors with Primary Tint
    val softShadow = Color(0x14585AD6) // 8% primary
    val mediumShadow = Color(0x1F585AD6) // 12% primary
    val hardShadow = Color(0x29585AD6) // 16% primary
    val primaryGlow = Color(0x40585AD6) // 25% primary
    
    // Interactive State Colors
    val rippleLight = Color(0x1F585AD6) // 12% primary
    val rippleDark = Color(0x1F5E5CE6) // 12% primary dark
    val hoverLight = Color(0x0A585AD6) // 4% primary
    val hoverDark = Color(0x14585AD6) // 8% primary
    val focusLight = Color(0x1F585AD6) // 12% primary
    val focusDark = Color(0x29585AD6) // 16% primary
    val pressedLight = Color(0x29585AD6) // 16% primary
    val pressedDark = Color(0x33585AD6) // 20% primary
    val selectedLight = Color(0x80E5E4FF) // 50% primary container
    val selectedDark = Color(0x80453A7B) // 50% primary container dark
    
    // Success Colors
    val success = Color(0xFF10B981)
    val onSuccess = Color(0xFFFFFFFF)
    val successContainer = Color(0xFFD1FAE5)
    val onSuccessContainer = Color(0xFF022C22)
    
    // Warning Colors
    val warning = Color(0xFFF59E0B)
    val onWarning = Color(0xFFFFFFFF)
    val warningContainer = Color(0xFFFEF3C7)
    val onWarningContainer = Color(0xFF451A03)
    
    // Info Colors
    val info = Color(0xFF3B82F6)
    val onInfo = Color(0xFFFFFFFF)
    val infoContainer = Color(0xFFDBEAFE)
    val onInfoContainer = Color(0xFF172554)
    
    // Gradient Definitions
    object Gradients {
        val primaryGradient = listOf(
            Color(0xFF5856D6),
            Color(0xFF7B79FF)
        )
        
        val primaryContainerGradient = listOf(
            Color(0xFFE5E4FF),
            Color(0xFFF0EFFF)
        )
        
        val overlayGradient = listOf(
            Color(0x00000000),
            Color(0x66000000)
        )
        
        fun cardGradientLight() = listOf(
            Color(0xF2FFFFFF), // 95% white
            Color(0xD9FFFFFF)  // 85% white
        )
        
        fun cardGradientDark() = listOf(
            Color(0xF21C1C1E), // 95% dark surface
            Color(0xD91C1C1E)  // 85% dark surface
        )
    }
}

// Extension functions for theme-aware colors
@Composable
fun extendedGlassSurface() = if (isSystemInDarkTheme()) {
    ZenithExtendedColors.glassSurfaceDark
} else {
    ZenithExtendedColors.glassSurfaceLight
}

@Composable
fun extendedGlassStroke() = if (isSystemInDarkTheme()) {
    ZenithExtendedColors.glassStrokeDark
} else {
    ZenithExtendedColors.glassStrokeLight
}

@Composable
fun extendedGlassHighlight() = if (isSystemInDarkTheme()) {
    ZenithExtendedColors.glassHighlightDark
} else {
    ZenithExtendedColors.glassHighlightLight
}

@Composable
fun extendedRippleColor() = if (isSystemInDarkTheme()) {
    ZenithExtendedColors.rippleDark
} else {
    ZenithExtendedColors.rippleLight
}

@Composable
fun extendedHoverColor() = if (isSystemInDarkTheme()) {
    ZenithExtendedColors.hoverDark
} else {
    ZenithExtendedColors.hoverLight
}

@Composable
fun extendedFocusColor() = if (isSystemInDarkTheme()) {
    ZenithExtendedColors.focusDark
} else {
    ZenithExtendedColors.focusLight
}

@Composable
fun extendedPressedColor() = if (isSystemInDarkTheme()) {
    ZenithExtendedColors.pressedDark
} else {
    ZenithExtendedColors.pressedLight
}

@Composable
fun extendedSelectedColor() = if (isSystemInDarkTheme()) {
    ZenithExtendedColors.selectedDark
} else {
    ZenithExtendedColors.selectedLight
}

@Composable
fun primaryGradient() = Brush.linearGradient(
    colors = ZenithExtendedColors.Gradients.primaryGradient
)

@Composable
fun cardGradient() = Brush.linearGradient(
    colors = if (isSystemInDarkTheme()) {
        ZenithExtendedColors.Gradients.cardGradientDark()
    } else {
        ZenithExtendedColors.Gradients.cardGradientLight()
    }
)