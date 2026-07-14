# Flutter-specific ProGuard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Socket.IO client
-keep class io.socket.** { *; }

# Preserve annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
