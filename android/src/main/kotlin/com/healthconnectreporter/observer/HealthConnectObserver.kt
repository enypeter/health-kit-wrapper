package com.healthconnectreporter.observer

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ChangesTokenRequest
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*

/**
 * HealthConnectObserver
 *
 * Mirrors HealthKitReporter's observerQuery + enableBackgroundDelivery.
 *
 * Uses Health Connect ChangesToken API:
 *   1. Register token for data types
 *   2. Poll for changes at configurable interval
 *   3. Push updates to Flutter via EventChannel sink
 *
 * NOTE: Health Connect does not have a push notification model like
 * HealthKit's HKObserverQuery. We implement a polling loop that
 * checks for changes token updates — efficient and battery-friendly
 * when interval is set appropriately (e.g. 15 min background, 30s foreground).
 */
class HealthConnectObserver(
    private val client: HealthConnectClient?
) : EventChannel.StreamHandler {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val activeObservers = mutableMapOf<String, Job>()
    private var eventSink: EventChannel.EventSink? = null

    // Token cache per data type — persists between polls
    private val changeTokens = mutableMapOf<String, String>()

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        eventSink = sink
        if (client == null) {
            sink?.error("UNAVAILABLE", "Health Connect is not available on this device", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any> ?: return

        val types         = args["types"] as? List<String>    ?: return
        val intervalMs    = (args["intervalMs"] as? Int)?.toLong() ?: 30_000L
        val observerId    = args["observerId"] as? String ?: types.joinToString(",")

        startObserving(observerId, types, intervalMs, sink)
    }

    override fun onCancel(arguments: Any?) {
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any>
        val observerId = args?.get("observerId") as? String

        if (observerId != null) {
            cancelObserver(observerId)
        } else {
            cancelAll()
        }
        eventSink = null
    }

    private fun startObserving(
        observerId: String,
        types: List<String>,
        intervalMs: Long,
        sink: EventChannel.EventSink?
    ) {
        // Cancel existing observer with same ID
        activeObservers[observerId]?.cancel()

        val job = scope.launch {
            try {
                // Build the record type set
                val recordTypes = types.mapNotNull { typeNameToClass(it) }.toSet()
                if (recordTypes.isEmpty()) return@launch

                // Register or retrieve existing changes token
                val tokenKey = observerId
                if (!changeTokens.containsKey(tokenKey)) {
                    val token = client!!.getChangesToken(
                        ChangesTokenRequest(recordTypes = recordTypes)
                    )
                    changeTokens[tokenKey] = token
                }

                // Poll loop
                while (isActive) {
                    delay(intervalMs)
                    checkForChanges(observerId, recordTypes, tokenKey, sink)
                }
            } catch (e: CancellationException) {
                // Normal cancellation
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    sink?.error("OBSERVER_ERROR", e.message, null)
                }
            }
        }

        activeObservers[observerId] = job
    }

    private suspend fun checkForChanges(
        observerId: String,
        recordTypes: Set<kotlin.reflect.KClass<out Record>>,
        tokenKey: String,
        sink: EventChannel.EventSink?
    ) {
        try {
            val currentToken = changeTokens[tokenKey] ?: return
            val changesResponse = client!!.getChanges(currentToken)

            if (changesResponse.changesTokenExpired) {
                // Token expired — re-register
                val newToken = client!!.getChangesToken(
                    ChangesTokenRequest(recordTypes = recordTypes)
                )
                changeTokens[tokenKey] = newToken
                return
            }

            val hasChanges = changesResponse.changes.isNotEmpty()

            if (hasChanges) {
                // Categorise changes for the Dart side
                val insertedTypes  = mutableSetOf<String>()
                val deletedTypes   = mutableSetOf<String>()

                changesResponse.changes.forEach { change ->
                    when (change) {
                        is androidx.health.connect.client.changes.UpsertionChange ->
                            insertedTypes.add(classToTypeName(change.record::class) ?: "unknown")
                        is androidx.health.connect.client.changes.DeletionChange ->
                            deletedTypes.add("deleted")
                        else -> {}
                    }
                }

                withContext(Dispatchers.Main) {
                    sink?.success(mapOf(
                        "observerId"   to observerId,
                        "hasChanges"   to true,
                        "insertedTypes" to insertedTypes.toList(),
                        "deletedTypes" to deletedTypes.toList(),
                        "timestampMs"  to System.currentTimeMillis(),
                    ))
                }

                // Advance the token
                changeTokens[tokenKey] = changesResponse.nextChangesToken
            }
        } catch (e: Exception) {
            // Silently handle polling errors — don't crash the stream
        }
    }

    private fun cancelObserver(observerId: String) {
        activeObservers[observerId]?.cancel()
        activeObservers.remove(observerId)
        changeTokens.remove(observerId)
    }

    fun cancelAll() {
        activeObservers.values.forEach { it.cancel() }
        activeObservers.clear()
        changeTokens.clear()
    }

    private fun classToTypeName(klass: kotlin.reflect.KClass<out Record>): String? = when (klass) {
        StepsRecord::class                          -> "steps"
        DistanceRecord::class                       -> "distance"
        FloorsClimbedRecord::class                  -> "floors"
        ActiveCaloriesBurnedRecord::class            -> "activeCalories"
        TotalCaloriesBurnedRecord::class             -> "totalCalories"
        ExerciseSessionRecord::class                 -> "exercise"
        SleepSessionRecord::class                    -> "sleep"
        HeartRateRecord::class                       -> "heartRate"
        RestingHeartRateRecord::class                -> "restingHeartRate"
        HeartRateVariabilityRmssdRecord::class       -> "heartRateVariability"
        OxygenSaturationRecord::class                -> "oxygenSaturation"
        BloodPressureRecord::class                   -> "bloodPressure"
        BloodGlucoseRecord::class                    -> "bloodGlucose"
        RespiratoryRateRecord::class                 -> "respiratoryRate"
        Vo2MaxRecord::class                          -> "vo2Max"
        BodyTemperatureRecord::class                 -> "bodyTemperature"
        WeightRecord::class                          -> "weight"
        HeightRecord::class                          -> "height"
        BodyFatRecord::class                         -> "bodyFat"
        LeanBodyMassRecord::class                    -> "leanBodyMass"
        NutritionRecord::class                       -> "nutrition"
        HydrationRecord::class                       -> "hydration"
        else                                         -> null
    }

    private fun typeNameToClass(typeName: String): kotlin.reflect.KClass<out Record>? = when (typeName) {
        "steps"                -> StepsRecord::class
        "distance"             -> DistanceRecord::class
        "floors"               -> FloorsClimbedRecord::class
        "activeCalories"       -> ActiveCaloriesBurnedRecord::class
        "totalCalories"        -> TotalCaloriesBurnedRecord::class
        "exercise"             -> ExerciseSessionRecord::class
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
        "weight"               -> WeightRecord::class
        "height"               -> HeightRecord::class
        "bodyFat"              -> BodyFatRecord::class
        "leanBodyMass"         -> LeanBodyMassRecord::class
        "nutrition"            -> NutritionRecord::class
        "hydration"            -> HydrationRecord::class
        else                   -> null
    }
}
