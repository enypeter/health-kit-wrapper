package com.healthconnectreporter.manager

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class HealthConnectManager(
    private val context: Context,
    private val client: HealthConnectClient?,
) : MethodChannel.MethodCallHandler {

    var activity: Activity? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    /**
     * Set by the plugin: launches the Health Connect permission contract for
     * the given permissions and completes [result] with the grant outcome.
     */
    var onRequestPermissions: ((Set<String>, MethodChannel.Result) -> Unit)? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSdkStatus"          -> getSdkStatus(result)
            "requestPermissions"    -> requireClient(result) { requestPermissions(call, result) }
            "hasPermissions"        -> requireClient(result) { hasPermissions(call, result) }
            "getGrantedPermissions" -> requireClient(result) { getGrantedPermissions(result) }
            "revokeAllPermissions"  -> requireClient(result) { revokeAllPermissions(result) }
            "openHealthApp"         -> openHealthApp(result)
            "installHealthConnect"  -> installHealthConnect(result)
            "getDeviceInfo"         -> getDeviceInfo(result)
            else                    -> result.notImplemented()
        }
    }

    private inline fun requireClient(result: MethodChannel.Result, block: () -> Unit) {
        if (client == null) {
            result.error("UNAVAILABLE", "Health Connect is not available on this device", null)
        } else {
            block()
        }
    }

    // ── SDK availability ────────────────────────────────────────
    private fun getSdkStatus(result: MethodChannel.Result) {
        val status = HealthConnectClient.getSdkStatus(
            context,
            "com.google.android.apps.healthdata"
        )
        val statusStr = when (status) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "notInstalled"
            else -> "unavailable"
        }
        result.success(statusStr)
    }

    // ── Permission request ──────────────────────────────────────
    private fun requestPermissions(call: MethodCall, result: MethodChannel.Result) {
        val readTypes = call.argument<List<String>>("readTypes") ?: emptyList()
        val writeTypes = call.argument<List<String>>("writeTypes") ?: emptyList()

        val permissions = mutableSetOf<String>()
        readTypes.forEach { t -> permissionForType(t, read = true)?.let { permissions.add(it) } }
        writeTypes.forEach { t -> permissionForType(t, read = false)?.let { permissions.add(it) } }

        scope.launch(Dispatchers.Main) {
            try {
                val granted = client!!.permissionController.getGrantedPermissions()
                val missing = permissions - granted

                if (missing.isEmpty()) {
                    result.success(true)
                    return@launch
                }

                val launch = onRequestPermissions
                if (launch == null) {
                    result.error("NO_ACTIVITY", "No foreground Activity to request permissions", null)
                    return@launch
                }

                // Delegate to the plugin, which owns the Activity and the
                // ActivityResult callback that resolves [result].
                launch(missing, result)
            } catch (e: Exception) {
                result.error("PERMISSION_ERROR", e.message, null)
            }
        }
    }

    // ── Check permissions ───────────────────────────────────────
    private fun hasPermissions(call: MethodCall, result: MethodChannel.Result) {
        val readTypes = call.argument<List<String>>("readTypes") ?: emptyList()
        val writeTypes = call.argument<List<String>>("writeTypes") ?: emptyList()

        scope.launch {
            try {
                val granted = client!!.permissionController.getGrantedPermissions()
                val required = mutableSetOf<String>()
                readTypes.forEach { t -> permissionForType(t, true)?.let { required.add(it) } }
                writeTypes.forEach { t -> permissionForType(t, false)?.let { required.add(it) } }

                val hasAll = required.all { it in granted }
                kotlinx.coroutines.withContext(Dispatchers.Main) {
                    result.success(hasAll)
                }
            } catch (e: Exception) {
                kotlinx.coroutines.withContext(Dispatchers.Main) {
                    result.error("PERMISSION_ERROR", e.message, null)
                }
            }
        }
    }

    // ── Get all granted ─────────────────────────────────────────
    private fun getGrantedPermissions(result: MethodChannel.Result) {
        scope.launch {
            try {
                val granted = client!!.permissionController.getGrantedPermissions()
                val readableNames = granted.mapNotNull { permissionToTypeName(it) }
                kotlinx.coroutines.withContext(Dispatchers.Main) {
                    result.success(readableNames)
                }
            } catch (e: Exception) {
                kotlinx.coroutines.withContext(Dispatchers.Main) {
                    result.error("PERMISSION_ERROR", e.message, null)
                }
            }
        }
    }

    // ── Revoke all ──────────────────────────────────────────────
    private fun revokeAllPermissions(result: MethodChannel.Result) {
        scope.launch {
            try {
                client!!.permissionController.revokeAllPermissions()
                kotlinx.coroutines.withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                kotlinx.coroutines.withContext(Dispatchers.Main) {
                    result.error("REVOKE_ERROR", e.message, null)
                }
            }
        }
    }

    // ── Open Health Connect app ──────────────────────────────────
    private fun openHealthApp(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }
        try {
            val intent = context.packageManager
                .getLaunchIntentForPackage("com.google.android.apps.healthdata")
            if (intent != null) {
                act.startActivity(intent)
                result.success(true)
            } else {
                // Health Connect not installed — open Play Store listing
                installHealthConnect(result)
            }
        } catch (e: Exception) {
            result.error("OPEN_ERROR", e.message, null)
        }
    }

    // ── Install Health Connect from Play Store ─────────────────
    private fun installHealthConnect(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }
        try {
            val playStoreIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("market://details?id=com.google.android.apps.healthdata")
            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            act.startActivity(playStoreIntent)
            result.success(true)
        } catch (e: Exception) {
            // Play Store not available — try browser
            try {
                val browserIntent = Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata")
                ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                act.startActivity(browserIntent)
                result.success(true)
            } catch (e2: Exception) {
                result.error("INSTALL_ERROR", "Could not open Play Store or browser", null)
            }
        }
    }

    // ── Device info for health app suggestions ─────────────────
    private fun getDeviceInfo(result: MethodChannel.Result) {
        result.success(mapOf(
            "manufacturer" to Build.MANUFACTURER.lowercase(),
            "brand"        to Build.BRAND.lowercase(),
            "model"        to Build.MODEL,
            "sdkVersion"   to Build.VERSION.SDK_INT,
        ))
    }

    // ── Permission type mapping ──────────────────────────────────
    private fun permissionForType(typeName: String, read: Boolean): String? {
        val recordClass = when (typeName) {
            "steps"                -> StepsRecord::class
            "distance"             -> DistanceRecord::class
            "floors"               -> FloorsClimbedRecord::class
            "activeCalories"       -> ActiveCaloriesBurnedRecord::class
            "totalCalories"        -> TotalCaloriesBurnedRecord::class
            "exercise"             -> ExerciseSessionRecord::class
            "speed"                -> SpeedRecord::class
            "power"                -> PowerRecord::class
            "sleep"                -> SleepSessionRecord::class
            "heartRate"            -> HeartRateRecord::class
            "restingHeartRate"     -> RestingHeartRateRecord::class
            "heartRateVariability" -> HeartRateVariabilityRmssdRecord::class
            "oxygenSaturation"     -> OxygenSaturationRecord::class
            "bloodPressure"        -> BloodPressureRecord::class
            "bloodGlucose"         -> BloodGlucoseRecord::class
            "respiratoryRate"      -> RespiratoryRateRecord::class
            "vo2Max"               -> Vo2MaxRecord::class
            "bodyTemperature"      -> BodyTemperatureRecord::class
            "height"               -> HeightRecord::class
            "weight"               -> WeightRecord::class
            "bodyFat"              -> BodyFatRecord::class
            "leanBodyMass"         -> LeanBodyMassRecord::class
            "boneMass"             -> BoneMassRecord::class
            "basalMetabolicRate"   -> BasalMetabolicRateRecord::class
            "nutrition"            -> NutritionRecord::class
            "hydration"            -> HydrationRecord::class
            else                   -> return null
        }
        return if (read) HealthPermission.getReadPermission(recordClass)
        else HealthPermission.getWritePermission(recordClass)
    }

    private fun permissionToTypeName(permission: String): String? {
        return when {
            permission.contains("Steps")                -> "steps"
            permission.contains("Distance")             -> "distance"
            permission.contains("FloorsClimbed")        -> "floors"
            permission.contains("ActiveCalories")       -> "activeCalories"
            permission.contains("TotalCalories")        -> "totalCalories"
            permission.contains("ExerciseSession")      -> "exercise"
            permission.contains("SleepSession")         -> "sleep"
            permission.contains("HeartRateVariability")  -> "heartRateVariability"
            permission.contains("RestingHeartRate")      -> "restingHeartRate"
            permission.contains("HeartRate")             -> "heartRate"
            permission.contains("OxygenSaturation")     -> "oxygenSaturation"
            permission.contains("BloodPressure")        -> "bloodPressure"
            permission.contains("BloodGlucose")         -> "bloodGlucose"
            permission.contains("RespiratoryRate")      -> "respiratoryRate"
            permission.contains("Vo2Max")               -> "vo2Max"
            permission.contains("BodyTemperature")      -> "bodyTemperature"
            permission.contains("Height")               -> "height"
            permission.contains("Weight")               -> "weight"
            permission.contains("BodyFat")              -> "bodyFat"
            permission.contains("LeanBodyMass")         -> "leanBodyMass"
            permission.contains("BoneMass")             -> "boneMass"
            permission.contains("BasalMetabolicRate")   -> "basalMetabolicRate"
            permission.contains("Nutrition")            -> "nutrition"
            permission.contains("Hydration")            -> "hydration"
            else                                        -> null
        }
    }
}
