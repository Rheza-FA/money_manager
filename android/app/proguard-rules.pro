# -----------------------------------------------------------------------------
# ML Kit Bundled Latin Text Recognition & Firebase Component Discovery (R8 Full Mode)
# -----------------------------------------------------------------------------
# Transitive `com.google.firebase:firebase-components:16.1.0` specifies only
# `-keep class * implements com.google.firebase.components.ComponentRegistrar`
# without `<init>()`. Under AGP 8+/9+ R8 fullMode, R8 strips the default no-arg
# constructors of `CommonComponentRegistrar`, `VisionCommonRegistrar`, and
# `TextRegistrar` (instantiated reflectively by `ComponentDiscovery`), causing
# `MlKitInitProvider` to register 0 components and dead-code-eliminating the
# OCR pipeline in release builds.
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    <init>();
    public java.util.List getComponents();
}

# Preserve no-arg constructors on `@DynamiteApi` entry points (such as
# `BundledLatinTextRecognizerCreator` and `BundledTextRecognizerCreator`)
# instantiated reflectively by `DynamiteModule.instantiate(...)`, as well as
# local Dynamite `ModuleDescriptor` reflection constants.
-keep @com.google.android.gms.common.util.DynamiteApi public class * {
    <init>();
    public <fields>;
    public <methods>;
}
-keep class com.google.android.gms.dynamite.descriptors.** {
    <init>();
    public static <fields>;
}

# Preserve JNI bridge classes, callbacks, and exception constructors (including
# parameterized `<init>(byte[])` and `<init>(int, String)`) invoked from
# `libmlkit_google_ocr_pipeline.so`.
-keep class com.google.android.libraries.vision.visionkit.pipeline.alt.** {
    *;
}
-keep @com.google.android.apps.common.proguard.UsedBy* class * {
    <init>(...);
    <fields>;
    <methods>;
}
