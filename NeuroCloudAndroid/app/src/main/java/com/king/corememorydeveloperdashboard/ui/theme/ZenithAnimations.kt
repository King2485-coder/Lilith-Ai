package com.king.corememorydeveloperdashboard.ui.theme

import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.ui.unit.dp

// Zenith Pro Material Animation Specifications
object ZenithAnimations {
    
    // Duration Constants
    object Durations {
        const val instant = 0
        const val fast = 100
        const val medium = 200
        const val slow = 300
        const val slower = 400
        const val slowest = 500
        const val pageTransition = 350
        const val fadeIn = 150
        const val fadeOut = 75
        const val slideIn = 250
        const val slideOut = 200
    }
    
    // Easing Functions
    object Easing {
        val standard = CubicBezierEasing(0.4f, 0.0f, 0.2f, 1.0f)
        val accelerate = CubicBezierEasing(0.4f, 0.0f, 1.0f, 1.0f)
        val decelerate = CubicBezierEasing(0.0f, 0.0f, 0.2f, 1.0f)
        val emphasized = CubicBezierEasing(0.2f, 0.0f, 0.0f, 1.0f)
        val emphasizedAccelerate = CubicBezierEasing(0.3f, 0.0f, 0.8f, 0.15f)
        val emphasizedDecelerate = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1.0f)
        val legacy = CubicBezierEasing(0.4f, 0.0f, 0.6f, 1.0f)
        val linearOutSlowIn = CubicBezierEasing(0.0f, 0.0f, 0.2f, 1.0f)
    }
    
    // Spring Configurations
    object Springs {
        val default = SpringConfig(dampingRatio = 0.75f, stiffness = 300f)
        val bouncy = SpringConfig(dampingRatio = 0.5f, stiffness = 400f)
        val smooth = SpringConfig(dampingRatio = 1f, stiffness = 300f)
        val gentle = SpringConfig(dampingRatio = 0.8f, stiffness = 250f)
        val stiff = SpringConfig(dampingRatio = 0.9f, stiffness = 500f)
    }
    
    data class SpringConfig(
        val dampingRatio: Float,
        val stiffness: Float
    )
    
    // Tween Animations
    fun <T> standardTween(durationMillis: Int = Durations.medium): TweenSpec<T> =
        tween(durationMillis = durationMillis, easing = Easing.standard)
    
    fun <T> emphasizedTween(durationMillis: Int = Durations.slow): TweenSpec<T> =
        tween(durationMillis = durationMillis, easing = Easing.emphasized)
    
    fun <T> fastTween(durationMillis: Int = Durations.fast): TweenSpec<T> =
        tween(durationMillis = durationMillis, easing = Easing.accelerate)
    
    fun <T> slowTween(durationMillis: Int = Durations.slower): TweenSpec<T> =
        tween(durationMillis = durationMillis, easing = Easing.decelerate)
    
    // Spring Animations
    fun <T> standardSpring(): SpringSpec<T> = spring(
        dampingRatio = Springs.default.dampingRatio,
        stiffness = Springs.default.stiffness
    )
    
    fun <T> bouncySpring(): SpringSpec<T> = spring(
        dampingRatio = Springs.bouncy.dampingRatio,
        stiffness = Springs.bouncy.stiffness
    )
    
    fun <T> smoothSpring(): SpringSpec<T> = spring(
        dampingRatio = Springs.smooth.dampingRatio,
        stiffness = Springs.smooth.stiffness
    )
    
    // Transition Animations
    val fadeInTransition = fadeIn(
        animationSpec = tween(
            durationMillis = Durations.fadeIn,
            easing = Easing.emphasizedDecelerate
        )
    )
    
    val fadeOutTransition = fadeOut(
        animationSpec = tween(
            durationMillis = Durations.fadeOut,
            easing = Easing.emphasizedAccelerate
        )
    )
    
    val slideInFromRightTransition = slideInHorizontally(
        animationSpec = tween(
            durationMillis = Durations.slideIn,
            easing = Easing.emphasizedDecelerate
        ),
        initialOffsetX = { it }
    )
    
    val slideOutToLeftTransition = slideOutHorizontally(
        animationSpec = tween(
            durationMillis = Durations.slideOut,
            easing = Easing.emphasizedAccelerate
        ),
        targetOffsetX = { -it }
    )
    
    val slideInFromLeftTransition = slideInHorizontally(
        animationSpec = tween(
            durationMillis = Durations.slideIn,
            easing = Easing.emphasizedDecelerate
        ),
        initialOffsetX = { -it }
    )
    
    val slideOutToRightTransition = slideOutHorizontally(
        animationSpec = tween(
            durationMillis = Durations.slideOut,
            easing = Easing.emphasizedAccelerate
        ),
        targetOffsetX = { it }
    )
    
    // Infinite Animations
    val pulseAnimation = infiniteRepeatable<Float>(
        animation = tween(
            durationMillis = 1000,
            easing = Easing.standard
        ),
        repeatMode = RepeatMode.Reverse
    )
    
    val rotateAnimation = infiniteRepeatable<Float>(
        animation = tween(
            durationMillis = 2000,
            easing = LinearEasing
        ),
        repeatMode = RepeatMode.Restart
    )
    
    // Keyframe Animations
    fun scaleKeyframes(durationMillis: Int = Durations.medium) = keyframes<Float> {
        this.durationMillis = durationMillis
        0.0f at 0 with Easing.standard
        1.1f at (durationMillis * 0.6).toInt() with Easing.standard
        1.0f at durationMillis with Easing.standard
    }
    
    fun bounceKeyframes(durationMillis: Int = Durations.slow) = keyframes<Float> {
        this.durationMillis = durationMillis
        0.0f at 0 with Easing.standard
        0.8f at (durationMillis * 0.4).toInt() with Easing.standard
        1.2f at (durationMillis * 0.7).toInt() with Easing.standard
        1.0f at durationMillis with Easing.standard
    }
}

// Extension functions for common animation patterns
fun <T> AnimationSpec<T>.withDelay(delayMillis: Int): AnimationSpec<T> {
    return when (this) {
        is TweenSpec -> tween(
            durationMillis = this.durationMillis,
            delayMillis = delayMillis,
            easing = this.easing
        )
        is SpringSpec -> spring(
            dampingRatio = this.dampingRatio,
            stiffness = this.stiffness,
            visibilityThreshold = this.visibilityThreshold
        )
        else -> this
    }
}