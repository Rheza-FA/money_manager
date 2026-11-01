package com.example.money_manager

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Low-latency tactile haptic engine modeled after iOS Taptic Engine transients.
 *
 * Uses hardware-calibrated LRA braking primitives ([VibrationEffect.Composition])
 * on Android 11+ (API 30+), predefined hardware effects on Android 10 (API 29),
 * and crisp two-stage micro-impulses on non-primitive actuators so both quick
 * clicks and held presses feel like real mechanical switches.
 */
class TactileHapticChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val manager =
            context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
        manager?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    private val hasVibrator: Boolean = vibrator?.hasVibrator() == true
    private val hasAmplitudeControl: Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            vibrator?.hasAmplitudeControl() == true

    private val supportsClickPrimitive: Boolean
    private val supportsTickPrimitive: Boolean
    private val supportsClickEffect: Boolean
    private val supportsTickEffect: Boolean
    private val supportsHeavyClickEffect: Boolean
    private val supportsDoubleClickEffect: Boolean

    private val touchVibrationAttributes: VibrationAttributes? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH)
        } else {
            null
        }

    private val touchAudioAttributes: AudioAttributes = AudioAttributes.Builder()
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
        .build()

    // Pre-composed immutable effects to guarantee zero per-tap allocation & minimum latency.
    private val pressDownEffect: VibrationEffect?
    private val releaseUpEffect: VibrationEffect?
    private val tapClickEffect: VibrationEffect?
    private val primaryClickEffect: VibrationEffect?
    private val softDetentEffect: VibrationEffect?
    private val destructiveEffect: VibrationEffect?
    private val successEffect: VibrationEffect?
    private val errorEffect: VibrationEffect?

    init {
        val vib = vibrator
        if (vib != null && hasVibrator && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val supported = vib.arePrimitivesSupported(
                VibrationEffect.Composition.PRIMITIVE_CLICK,
                VibrationEffect.Composition.PRIMITIVE_TICK,
            )
            supportsClickPrimitive = supported.size >= 1 && supported[0]
            supportsTickPrimitive = supported.size >= 2 && supported[1]

            val effectSupport = vib.areEffectsSupported(
                VibrationEffect.EFFECT_CLICK,
                VibrationEffect.EFFECT_TICK,
                VibrationEffect.EFFECT_HEAVY_CLICK,
                VibrationEffect.EFFECT_DOUBLE_CLICK,
            )
            supportsClickEffect = effectSupport.size >= 1 &&
                effectSupport[0] == Vibrator.VIBRATION_EFFECT_SUPPORT_YES
            supportsTickEffect = effectSupport.size >= 2 &&
                effectSupport[1] == Vibrator.VIBRATION_EFFECT_SUPPORT_YES
            supportsHeavyClickEffect = effectSupport.size >= 3 &&
                effectSupport[2] == Vibrator.VIBRATION_EFFECT_SUPPORT_YES
            supportsDoubleClickEffect = effectSupport.size >= 4 &&
                effectSupport[3] == Vibrator.VIBRATION_EFFECT_SUPPORT_YES
        } else {
            supportsClickPrimitive = false
            supportsTickPrimitive = false
            supportsClickEffect = false
            supportsTickEffect = false
            supportsHeavyClickEffect = false
            supportsDoubleClickEffect = false
        }

        pressDownEffect = buildPressDownEffect()
        releaseUpEffect = buildReleaseUpEffect()
        tapClickEffect = buildTapClickEffect()
        primaryClickEffect = buildPrimaryClickEffect()
        softDetentEffect = buildSoftDetentEffect()
        destructiveEffect = buildDestructiveEffect()
        successEffect = buildSuccessEffect()
        errorEffect = buildErrorEffect()

        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pressDown" -> {
                playEffect(pressDownEffect)
                result.success(null)
            }
            "releaseUp" -> {
                playEffect(releaseUpEffect)
                result.success(null)
            }
            "tapClick" -> {
                playEffect(tapClickEffect)
                result.success(null)
            }
            "primaryClick" -> {
                playEffect(primaryClickEffect)
                result.success(null)
            }
            "softDetent" -> {
                playEffect(softDetentEffect)
                result.success(null)
            }
            "destructive" -> {
                playEffect(destructiveEffect)
                result.success(null)
            }
            "success" -> {
                playEffect(successEffect)
                result.success(null)
            }
            "error" -> {
                playEffect(errorEffect)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun playEffect(effect: VibrationEffect?) {
        val vib = vibrator ?: return
        if (!hasVibrator || effect == null) return

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                touchVibrationAttributes != null
            ) {
                vib.vibrate(effect, touchVibrationAttributes)
            } else {
                if (!isLegacyTouchHapticsEnabled()) return
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    @Suppress("DEPRECATION")
                    vib.vibrate(effect, touchAudioAttributes)
                }
            }
        } catch (_: Throwable) {
            // Safely ignore OEM/device-specific vibration restrictions.
        }
    }

    @Suppress("DEPRECATION")
    private fun isLegacyTouchHapticsEnabled(): Boolean {
        return try {
            Settings.System.getInt(
                context.contentResolver,
                Settings.System.HAPTIC_FEEDBACK_ENABLED,
                1,
            ) != 0
        } catch (_: Throwable) {
            true
        }
    }

    private fun buildPressDownEffect(): VibrationEffect? {
        if (!hasVibrator) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (supportsClickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.85f)
                    .compose()
            }
            if (supportsTickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, 1.0f)
                    .compose()
            }
            if (supportsClickEffect) {
                return VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasAmplitudeControl) {
            return VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return if (hasAmplitudeControl) {
                VibrationEffect.createOneShot(10L, 230)
            } else {
                VibrationEffect.createOneShot(11L, VibrationEffect.DEFAULT_AMPLITUDE)
            }
        }
        return null
    }

    private fun buildReleaseUpEffect(): VibrationEffect? {
        if (!hasVibrator) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (supportsTickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.80f)
                    .compose()
            }
            if (supportsClickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.58f)
                    .compose()
            }
            if (supportsTickEffect) {
                return VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return if (hasAmplitudeControl) {
                VibrationEffect.createOneShot(7L, 175)
            } else {
                VibrationEffect.createOneShot(7L, VibrationEffect.DEFAULT_AMPLITUDE)
            }
        }
        return null
    }

    private fun buildTapClickEffect(): VibrationEffect? {
        if (!hasVibrator) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (supportsClickPrimitive && supportsTickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.85f)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.80f, 62)
                    .compose()
            }
            if (supportsClickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.85f)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.58f, 62)
                    .compose()
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return if (hasAmplitudeControl) {
                VibrationEffect.createWaveform(
                    longArrayOf(0L, 10L, 62L, 7L),
                    intArrayOf(0, 230, 0, 175),
                    -1,
                )
            } else {
                VibrationEffect.createWaveform(
                    longArrayOf(0L, 11L, 65L, 7L),
                    -1,
                )
            }
        }
        return null
    }

    private fun buildPrimaryClickEffect(): VibrationEffect? {
        if (!hasVibrator) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (supportsClickPrimitive && supportsTickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.95f)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.82f, 64)
                    .compose()
            }
            if (supportsClickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.95f)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.62f, 64)
                    .compose()
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return if (hasAmplitudeControl) {
                VibrationEffect.createWaveform(
                    longArrayOf(0L, 10L, 64L, 7L),
                    intArrayOf(0, 250, 0, 180),
                    -1,
                )
            } else {
                VibrationEffect.createWaveform(
                    longArrayOf(0L, 11L, 65L, 7L),
                    -1,
                )
            }
        }
        return null
    }

    private fun buildSoftDetentEffect(): VibrationEffect? {
        if (!hasVibrator) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (supportsTickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.68f)
                    .compose()
            }
            if (supportsClickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.48f)
                    .compose()
            }
            if (supportsTickEffect) {
                return VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return if (hasAmplitudeControl) {
                VibrationEffect.createOneShot(6L, 145)
            } else {
                VibrationEffect.createOneShot(6L, VibrationEffect.DEFAULT_AMPLITUDE)
            }
        }
        return null
    }

    private fun buildDestructiveEffect(): VibrationEffect? {
        if (!hasVibrator) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (supportsClickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 1.0f)
                    .compose()
            }
            if (supportsHeavyClickEffect) {
                return VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasAmplitudeControl) {
            return VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return if (hasAmplitudeControl) {
                VibrationEffect.createOneShot(12L, 255)
            } else {
                VibrationEffect.createOneShot(12L, VibrationEffect.DEFAULT_AMPLITUDE)
            }
        }
        return null
    }

    private fun buildSuccessEffect(): VibrationEffect? {
        if (!hasVibrator) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (supportsClickPrimitive) {
                return VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.65f)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 1.0f, 54)
                    .compose()
            }
            if (supportsDoubleClickEffect) {
                return VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return if (hasAmplitudeControl) {
                VibrationEffect.createWaveform(
                    longArrayOf(0L, 8L, 54L, 10L),
                    intArrayOf(0, 170, 0, 250),
                    -1,
                )
            } else {
                VibrationEffect.createWaveform(
                    longArrayOf(0L, 8L, 56L, 10L),
                    -1,
                )
            }
        }
        return null
    }

    private fun buildErrorEffect(): VibrationEffect? {
        if (!hasVibrator) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && supportsClickPrimitive) {
            val comp = VibrationEffect.startComposition()
                .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.90f)
                .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.90f, 48)
            if (supportsTickPrimitive) {
                comp.addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.72f, 48)
            } else {
                comp.addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.60f, 48)
            }
            return comp.compose()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return if (hasAmplitudeControl) {
                VibrationEffect.createWaveform(
                    longArrayOf(0L, 9L, 48L, 9L, 48L, 7L),
                    intArrayOf(0, 235, 0, 235, 0, 170),
                    -1,
                )
            } else {
                VibrationEffect.createWaveform(
                    longArrayOf(0L, 9L, 50L, 9L, 50L, 7L),
                    -1,
                )
            }
        }
        return null
    }

    private companion object {
        const val CHANNEL_NAME = "neymo/haptics"
    }
}
