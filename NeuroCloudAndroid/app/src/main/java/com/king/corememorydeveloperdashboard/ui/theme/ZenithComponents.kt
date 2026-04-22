package com.king.corememorydeveloperdashboard.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

// Glassmorphic Card Component
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val backgroundColor = zenithGlassSurface()
    val strokeColor = zenithGlassStroke()
    
    val cardModifier = if (onClick != null) {
        modifier
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
    } else {
        modifier
    }
    
    Card(
        modifier = cardModifier
            .border(
                width = 1.dp,
                color = strokeColor,
                shape = ZenithCustomShapes.card
            ),
        colors = CardDefaults.cardColors(
            containerColor = backgroundColor
        ),
        shape = ZenithCustomShapes.card,
        elevation = CardDefaults.cardElevation(
            defaultElevation = ZenithElevation.card
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(ZenithSpacing.cardPadding),
            content = content
        )
    }
}

// Premium Button with Gradient
@Composable
fun ZenithButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    variant: ZenithButtonVariant = ZenithButtonVariant.Filled,
    content: @Composable RowScope.() -> Unit
) {
    when (variant) {
        ZenithButtonVariant.Filled -> {
            val gradient = Brush.linearGradient(
                colors = listOf(
                    Color(0xFF5856D6),
                    Color(0xFF7B79FF)
                )
            )
            
            Button(
                onClick = onClick,
                modifier = modifier
                    .height(50.dp)
                    .background(
                        brush = gradient,
                        shape = ZenithCustomShapes.button
                    ),
                enabled = enabled,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Transparent
                ),
                shape = ZenithCustomShapes.button,
                elevation = ButtonDefaults.buttonElevation(
                    defaultElevation = ZenithElevation.button,
                    pressedElevation = ZenithElevation.level1,
                    disabledElevation = ZenithElevation.level0
                ),
                contentPadding = PaddingValues(horizontal = 32.dp),
                content = content
            )
        }
        ZenithButtonVariant.Outlined -> {
            OutlinedButton(
                onClick = onClick,
                modifier = modifier.height(50.dp),
                enabled = enabled,
                shape = ZenithCustomShapes.button,
                border = ButtonDefaults.outlinedButtonBorder.copy(
                    width = 1.5.dp,
                    brush = Brush.linearGradient(
                        colors = listOf(
                            MaterialTheme.colorScheme.primary,
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.7f)
                        )
                    )
                ),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.primary
                ),
                contentPadding = PaddingValues(horizontal = 32.dp),
                content = content
            )
        }
        ZenithButtonVariant.Text -> {
            TextButton(
                onClick = onClick,
                modifier = modifier.height(50.dp),
                enabled = enabled,
                colors = ButtonDefaults.textButtonColors(
                    contentColor = MaterialTheme.colorScheme.primary
                ),
                contentPadding = PaddingValues(horizontal = 16.dp),
                content = content
            )
        }
        ZenithButtonVariant.Tonal -> {
            Button(
                onClick = onClick,
                modifier = modifier.height(50.dp),
                enabled = enabled,
                shape = ZenithCustomShapes.button,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                ),
                elevation = ButtonDefaults.buttonElevation(
                    defaultElevation = ZenithElevation.level0,
                    pressedElevation = ZenithElevation.level1
                ),
                contentPadding = PaddingValues(horizontal = 32.dp),
                content = content
            )
        }
    }
}

enum class ZenithButtonVariant {
    Filled, Outlined, Text, Tonal
}

// Elevated Card with Shadow
@Composable
fun ElevatedCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val cardModifier = if (onClick != null) {
        modifier.clickable(
            interactionSource = remember { MutableInteractionSource() },
            indication = null
        ) { onClick() }
    } else {
        modifier
    }
    
    Card(
        modifier = cardModifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        shape = ZenithCustomShapes.card,
        elevation = CardDefaults.cardElevation(
            defaultElevation = ZenithElevation.cardElevated
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(ZenithSpacing.cardPadding),
            content = content
        )
    }
}

// Premium Text Field
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ZenithTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: @Composable (() -> Unit)? = null,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null,
    isError: Boolean = false,
    singleLine: Boolean = false,
    variant: ZenithTextFieldVariant = ZenithTextFieldVariant.Outlined
) {
    when (variant) {
        ZenithTextFieldVariant.Filled -> {
            TextField(
                value = value,
                onValueChange = onValueChange,
                modifier = modifier,
                label = label,
                leadingIcon = leadingIcon,
                trailingIcon = trailingIcon,
                isError = isError,
                singleLine = singleLine,
                shape = ZenithCustomShapes.textField,
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    focusedLabelColor = MaterialTheme.colorScheme.primary,
                    unfocusedLabelColor = MaterialTheme.colorScheme.onSurfaceVariant
                )
            )
        }
        ZenithTextFieldVariant.Outlined -> {
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = modifier,
                label = label,
                leadingIcon = leadingIcon,
                trailingIcon = trailingIcon,
                isError = isError,
                singleLine = singleLine,
                shape = ZenithCustomShapes.textField,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline,
                    errorBorderColor = MaterialTheme.colorScheme.error,
                    focusedLabelColor = MaterialTheme.colorScheme.primary,
                    unfocusedLabelColor = MaterialTheme.colorScheme.onSurfaceVariant
                )
            )
        }
    }
}

enum class ZenithTextFieldVariant {
    Filled, Outlined
}

// Status Chip
@Composable
fun StatusChip(
    text: String,
    isActive: Boolean,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null
) {
    val backgroundColor = if (isActive) {
        MaterialTheme.colorScheme.primaryContainer
    } else {
        MaterialTheme.colorScheme.errorContainer
    }
    
    val contentColor = if (isActive) {
        MaterialTheme.colorScheme.onPrimaryContainer
    } else {
        MaterialTheme.colorScheme.onErrorContainer
    }
    
    val chipModifier = if (onClick != null) {
        modifier.clickable(
            interactionSource = remember { MutableInteractionSource() },
            indication = null
        ) { onClick() }
    } else {
        modifier
    }
    
    Box(
        modifier = chipModifier
            .clip(ZenithCustomShapes.chip)
            .background(backgroundColor)
            .padding(horizontal = ZenithSpacing.sm, vertical = ZenithSpacing.xs)
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = contentColor
        )
    }
}

// Premium FAB
@Composable
fun ZenithFAB(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    expanded: Boolean = false,
    icon: @Composable () -> Unit,
    text: @Composable (() -> Unit)? = null
) {
    if (expanded && text != null) {
        ExtendedFloatingActionButton(
            onClick = onClick,
            modifier = modifier,
            shape = ZenithCustomShapes.fab,
            containerColor = MaterialTheme.colorScheme.primaryContainer,
            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
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
            modifier = modifier.size(56.dp),
            shape = ZenithCustomShapes.fab,
            containerColor = MaterialTheme.colorScheme.primaryContainer,
            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            elevation = FloatingActionButtonDefaults.elevation(
                defaultElevation = ZenithElevation.fab,
                pressedElevation = ZenithElevation.fabPressed
            ),
            content = icon
        )
    }
}

// Premium Switch
@Composable
fun ZenithSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    Switch(
        checked = checked,
        onCheckedChange = onCheckedChange,
        modifier = modifier,
        enabled = enabled,
        colors = SwitchDefaults.colors(
            checkedThumbColor = MaterialTheme.colorScheme.onPrimary,
            checkedTrackColor = MaterialTheme.colorScheme.primary,
            uncheckedThumbColor = MaterialTheme.colorScheme.outline,
            uncheckedTrackColor = MaterialTheme.colorScheme.surfaceContainerHighest
        )
    )
}

// Premium Checkbox
@Composable
fun ZenithCheckbox(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    Checkbox(
        checked = checked,
        onCheckedChange = onCheckedChange,
        modifier = modifier,
        enabled = enabled,
        colors = CheckboxDefaults.colors(
            checkedColor = MaterialTheme.colorScheme.primary,
            uncheckedColor = MaterialTheme.colorScheme.outline,
            checkmarkColor = MaterialTheme.colorScheme.onPrimary
        )
    )
}

// Premium Radio Button
@Composable
fun ZenithRadioButton(
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    RadioButton(
        selected = selected,
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        colors = RadioButtonDefaults.colors(
            selectedColor = MaterialTheme.colorScheme.primary,
            unselectedColor = MaterialTheme.colorScheme.outline
        )
    )
}