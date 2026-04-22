package com.king.corememorydeveloperdashboard.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

val ZenithShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(28.dp)
)

// Custom Zenith Shapes
object ZenithCustomShapes {
    val card = RoundedCornerShape(20.dp)
    val button = RoundedCornerShape(25.dp)
    val chip = RoundedCornerShape(16.dp)
    val modal = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    val bottomSheet = RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp)
    val textField = RoundedCornerShape(12.dp)
    val fab = RoundedCornerShape(16.dp)
    val full = RoundedCornerShape(50)
}