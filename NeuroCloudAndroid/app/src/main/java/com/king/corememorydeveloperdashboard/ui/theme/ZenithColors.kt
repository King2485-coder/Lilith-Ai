package com.king.corememorydeveloperdashboard.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Zenith Pro Material Custom Colors
object ZenithColors {
    // Glass Surface Colors
    val glassSurfaceLight = Color(0xE6FFFFFF)
    val glassSurfaceDark = Color(0xD91C1C1E)
    
    // Glass Stroke Colors
    val glassStrokeLight = Color(0x1F000000)
    val glassStrokeDark = Color(0x33FFFFFF)
    
    // Glass Highlight Colors
    val glassHighlightLight = Color(0xFFFFFFFF)
    val glassHighlightDark = Color(0x26FFFFFF)
    
    // Shadow Colors
    val softShadow = Color(0x14585AD6)
    val mediumShadow = Color(0x1F585AD6)
    val hardShadow = Color(0x29585AD6)
    val primaryGlow = Color(0x40585AD6)
    
    // Interactive State Colors
    val rippleLight = Color(0x1F585AD6)
    val rippleDark = Color(0x1F5E5CE6)
    val hoverLight = Color(0x0A585AD6)
    val hoverDark = Color(0x14585AD6)
    val focusLight = Color(0x1F585AD6)
    val focusDark = Color(0x29585AD6)
    val pressedLight = Color(0x29585AD6)
    val pressedDark = Color(0x33585AD6)
    val selectedLight = Color(0x80E5E4FF)
    val selectedDark = Color(0x80453A7B)
    
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
    
    // Primary Palette
    object Primary {
        val primary50 = Color(0xFFF0F0FF)
        val primary100 = Color(0xFFE5E4FF)
        val primary200 = Color(0xFFD0CDFF)
        val primary300 = Color(0xFFB8B3FF)
        val primary400 = Color(0xFFA19AFF)
        val primary500 = Color(0xFF5856D6)
        val primary600 = Color(0xFF4D4BC4)
        val primary700 = Color(0xFF413FB1)
        val primary800 = Color(0xFF36359E)
        val primary900 = Color(0xFF2B2A8A)
        val primary950 = Color(0xFF1A0E5C)
    }
    
    // Secondary Palette
    object Secondary {
        val secondary50 = Color(0xFFF7F4FF)
        val secondary100 = Color(0xFFE8DEF8)
        val secondary200 = Color(0xFFD0C4E8)
        val secondary300 = Color(0xFFB8A9D8)
        val secondary400 = Color(0xFF9F8FC8)
        val secondary500 = Color(0xFF625B71)
        val secondary600 = Color(0xFF564F66)
        val secondary700 = Color(0xFF4A445B)
        val secondary800 = Color(0xFF3E3850)
        val secondary900 = Color(0xFF332D45)
        val secondary950 = Color(0xFF1D192B)
    }
    
    // Tertiary Palette
    object Tertiary {
        val tertiary50 = Color(0xFFFFF0F3)
        val tertiary100 = Color(0xFFFFD8E4)
        val tertiary200 = Color(0xFFFFBAC7)
        val tertiary300 = Color(0xFFFF9CAB)
        val tertiary400 = Color(0xFFEF7B8E)
        val tertiary500 = Color(0xFF7D5260)
        val tertiary600 = Color(0xFF6F4754)
        val tertiary700 = Color(0xFF613D48)
        val tertiary800 = Color(0xFF53323C)
        val tertiary900 = Color(0xFF452730)
        val tertiary950 = Color(0xFF31111D)
    }
    
    // Neutral Palette
    object Neutral {
        val neutral50 = Color(0xFFFEFBFF)
        val neutral100 = Color(0xFFF8F8FC)
        val neutral200 = Color(0xFFF1F1F5)
        val neutral300 = Color(0xFFEAEAEE)
        val neutral400 = Color(0xFFE3E3E7)
        val neutral500 = Color(0xFF79747E)
        val neutral600 = Color(0xFF6C686F)
        val neutral700 = Color(0xFF5F5B62)
        val neutral800 = Color(0xFF524F55)
        val neutral900 = Color(0xFF454248)
        val neutral950 = Color(0xFF1C1B1F)
    }
}

// Extension functions for easy access to theme-aware colors
@Composable
fun zenithGlassSurface() = if (isSystemInDarkTheme()) ZenithColors.glassSurfaceDark else ZenithColors.glassSurfaceLight

@Composable
fun zenithGlassStroke() = if (isSystemInDarkTheme()) ZenithColors.glassStrokeDark else ZenithColors.glassStrokeLight

@Composable
fun zenithGlassHighlight() = if (isSystemInDarkTheme()) ZenithColors.glassHighlightDark else ZenithColors.glassHighlightLight

@Composable
fun zenithRippleColor() = if (isSystemInDarkTheme()) ZenithColors.rippleDark else ZenithColors.rippleLight

@Composable
fun zenithHoverColor() = if (isSystemInDarkTheme()) ZenithColors.hoverDark else ZenithColors.hoverLight

@Composable
fun zenithFocusColor() = if (isSystemInDarkTheme()) ZenithColors.focusDark else ZenithColors.focusLight

@Composable
fun zenithPressedColor() = if (isSystemInDarkTheme()) ZenithColors.pressedDark else ZenithColors.pressedLight

@Composable
fun zenithSelectedColor() = if (isSystemInDarkTheme()) ZenithColors.selectedDark else ZenithColors.selectedLight