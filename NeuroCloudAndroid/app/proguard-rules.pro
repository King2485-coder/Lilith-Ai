-keepclasseswithmembernames class * {
    native <methods>;
}

-keep class kotlin.Metadata { *; }
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations

-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}

-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**

-keep class * implements com.google.gson.TypeAdapter
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

-keep class com.king.corememorydeveloperdashboard.model.** { *; }
-keep class com.king.corememorydeveloperdashboard.data.** { *; }

-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

-keep class androidx.compose.** { *; }
-keep class androidx.lifecycle.** { *; }

-keep class **.BuildConfig { *; }
-allowaccessmodification
-repackageclasses