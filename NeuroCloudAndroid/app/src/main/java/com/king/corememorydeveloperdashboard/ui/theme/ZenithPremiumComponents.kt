package com.king.corememorydeveloperdashboard.ui.theme

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp

// Premium Glassmorphic Card Component
@Composable
fun ZenithGlassCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    enabled: Boolean = true,
    elevation: androidx.compose.ui.unit.Dp = ZenithElevation.card,
    content: @Composable ColumnScope.() -> Unit
) {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.98f else 1f,
        animationSpec = ZenithAnimations.standardSpring(),
        label = "card_scale"
    )
    
    val backgroundColor = zenithGlassSurface()
    val strokeColor = zenithGlassStroke()
    val highlightColor = zenithGlassHighlight()
    
    val cardModifier = if (onClick != null && enabled) {
        modifier
            .scale(scale)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                enabled = enabled
            ) {
                onClick()
            }
    } else {
        modifier.scale(scale)
    }
    
    Card(
        modifier = cardModifier
            .border(
                width = 1.dp,
                color = strokeColor,
                shape = ZenithCustomShapes.card
            )
            .graphicsLayer {
                // Add subtle highlight effect
                shadowElevation = elevation.toPx()
            },
        colors = CardDefaults.cardColors(
            containerColor = backgroundColor
        ),
        shape = ZenithCustomShapes.card,
        elevation = CardDefaults.cardElevation(
            defaultElevation = elevation
        )
    ) {
        // Highlight overlay
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(
                    brush = Brush.horizontalGradient(
                        colors = listOf(
                            Color.Transparent,
                            highlightColor,
                            Color.Transparent
                        )
                    )
                )
        )
        
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(ZenithSpacing.cardPadding),
            content = content
        )
    }
    
    LaunchedEffect(isPressed) {
        if (onClick != null) {
            // Add haptic feedback here if needed
        }
    }
}

// Premium Gradient Button
@Composable
fun ZenithGradientButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    variant: ZenithPremiumButtonVariant = ZenithPremiumButtonVariant.Filled,
    loading: Boolean = false,
    content: @Composable RowScope.() -> Unit
) {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) 0.96f else 1f,
        animationSpec = ZenithAnimations.standardSpring(),
        label = "button_scale"
    )
    
    val alpha by animateFloatAsState(
        targetValue = when {
            !enabled -> 0.38f
            isPressed -> 0.88f
            else -> 1f
        },
        animationSpec = ZenithAnimations.standardTween(),
        label = "button_alpha"
    )
    
    when (variant) {
        ZenithPremiumButtonVariant.Filled -> {
            Button(
                onClick = {
                    if (!loading) onClick()
                },
                modifier = modifier
                    .height(50.dp)
                    .scale(scale)
                    .graphicsLayer { this.alpha = alpha }
                    .background(
                        brush = primaryGradient(),
                        shape = ZenithCustomShapes.button
                    ),
                enabled = enabled && !loading,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent
                ),
                shape = ZenithCustomShapes.button,
                elevation = ButtonDefaults.buttonElevation(
                    defaultElevation = ZenithElevation.button,
                    pressedElevation = ZenithElevation.level1,
                    disabledElevation = ZenithElevation.level0
                ),
                contentPadding = PaddingValues(horizontal = 32.dp)
            ) {
                if (loading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = MaterialTheme.colorScheme.onPrimary,
                        strokeWidth = 2.dp
                    )
                } else {
                    content()
                }
            }
        }
        
        ZenithPremiumButtonVariant.Glass -> {
            Button(
                onClick = {
                    if (!loading) onClick()
                },
                modifier = modifier
                    .height(50.dp)
                    .scale(scale)
                    .graphicsLayer { this.alpha = alpha }
                    .background(
                        color = zenithGlassSurface(),
                        shape = ZenithCustomShapes.button
                    )
                    .border(
                        width = 1.dp,
                        color = zenithGlassStroke(),
                        shape = ZenithCustomShapes.button
                    ),
                enabled = enabled && !loading,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Transparent,
                    contentColor = MaterialTheme.colorScheme.primary,
                    disabledContainerColor = Color.Transparent
                ),
                shape = ZenithCustomShapes.button,
                elevation = ButtonDefaults.buttonElevation(
                    defaultElevation = ZenithElevation.level2
                ),
                contentPadding = PaddingValues(horizontal = 32.dp)
            ) {
                if (loading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = MaterialTheme.colorScheme.primary,
                        strokeWidth = 2.dp
                    )
                } else {
                    content()
                }
            }
        }
        
        else -> {
            // Fallback to existing ZenithButton implementation
            ZenithButton(
                onClick = onClick,
                modifier = modifier,
                enabled = enabled && !loading,
                variant = ZenithButtonVariant.Filled
            ) {
                if (loading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = MaterialTheme.colorScheme.primary,
                        strokeWidth = 2.dp
                    )
                } else {
                    content()
                }
            }
        }
    }
}

// Enhanced Button Variant Enum
enum class ZenithPremiumButtonVariant {
    Filled, Outlined, Text, Tonal, Glass
}

// Premium Floating Action Button
@Composable
fun ZenithPremiumFAB(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    expanded: Boolean = false,
    icon: @Composable () -> Unit,
    text: @Composable (() -> Unit)? = null
) {
    val scale by animateFloatAsState(
        targetValue = if (expanded) 1.1f else 1f,
        animationSpec = ZenithAnimations.bouncySpring(),
        label = "fab_scale"
    )
    
    val backgroundColor = zenithGlassSurface()
    val strokeColor = zenithGlassStroke()
    
    if (expanded && text != null) {
        ExtendedFloatingActionButton(
            onClick = onClick,
            modifier = modifier
                .scale(scale)
                .background(
                    color = backgroundColor,
                    shape = ZenithCustomShapes.fab
                )
                .border(
                    width = 1.dp,
                    color = strokeColor,
                    shape = ZenithCustomShapes.fab
                ),
            shape = ZenithCustomShapes.fab,
            containerColor = Color.Transparent,
            contentColor = MaterialTheme.colorScheme.primary,
            elevation = FloatingActionButtonDefaults.elevation(
                defaultElevation = ZenithElevation.fab,
                pressedElevation = ZenithElevation.fabPressed
            ),
            icon = icon,
            text = text
        )
    } else {
        FloatingActionButton(
            onClick = onClick,
            modifier = modifier
                .size(56.dp)
                .scale(scale)
                .background(
                    color = backgroundColor,
                    shape = ZenithCustomShapes.fab
                )
                .border(
                    width = 1.dp,
                    color = strokeColor,
                    shape = ZenithCustomShapes.fab
                ),
            shape = ZenithCustomShapes.fab,
            containerColor = Color.Transparent,
            contentColor = MaterialTheme.colorScheme.primary,
            elevation = FloatingActionButtonDefaults.elevation(
                defaultElevation = ZenithElevation.fab,
                pressedElevation = ZenithElevation.fabPressed
            ),
            content = icon
        )
    }
}

// Premium Status Indicator
@Composable
fun ZenithStatusIndicator(
    isActive: Boolean,
    modifier: Modifier = Modifier,
    activeText: String = "Active",
    inactiveText: String = "Inactive"
) {
    val backgroundColor by animateColorAsState(
        targetValue = if (isActive) {
            ZenithExtendedColors.successContainer
        } else {
            MaterialTheme.colorScheme.errorContainer
        },
        animationSpec = ZenithAnimations.standardTween(),
        label = "status_background"
    )
    
    val contentColor by animateColorAsState(
        targetValue = if (isActive) {
            ZenithExtendedColors.onSuccessContainer
        } else {
            MaterialTheme.colorScheme.onErrorContainer
        },
        animationSpec = ZenithAnimations.standardTween(),
        label = "status_content"
    )
    
    val scale by animateFloatAsState(
        targetValue = 1f,
        animationSpec = ZenithAnimations.bouncySpring(),
        label = "status_scale"
    )
    
    Box(
        modifier = modifier
            .scale(scale)
            .clip(ZenithCustomShapes.chip)
            .background(backgroundColor)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = if (isActive) activeText else inactiveText,
            style = MaterialTheme.typography.labelSmall,
            color = contentColor
        )
    }
}

// Premium Loading Indicator
@Composable
fun ZenithLoadingIndicator(
    modifier: Modifier = Modifier,
    size: androidx.compose.ui.unit.Dp = 40.dp
) {
    val infiniteTransition = rememberInfiniteTransition(label = "loading")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "loading_rotation"
    )
    
    Box(
        modifier = modifier.size(size),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(
            modifier = Modifier
                .size(size)
                .graphicsLayer { rotationZ = rotation },
            color = MaterialTheme.colorScheme.primary,
            strokeWidth = 3.dp,
            trackColor = MaterialTheme.colorScheme.surfaceVariant
        )
    }
}