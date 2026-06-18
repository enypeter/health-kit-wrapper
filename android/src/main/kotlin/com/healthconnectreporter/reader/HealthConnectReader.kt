package com.healthconnectreporter.reader

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.aggregate.AggregationResult
import androidx.health.connect.client.records.*
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Energy
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneOffset

/**
 * HealthConnectReader
 *
 * Mirrors HealthKitReporter reader approach:
 *   - sampleQuery     → readRecords (raw individual records)
 *   - statisticsQuery → aggregate   (totals/averages — THE accurate method)
 *   - sourceQuery     → metadata.dataOrigin (which app wrote the data)
 *
 * KEY DESIGN DECISIONS:
 *   1. Calories always use .inKilocalories — never raw doubles
 *   2. Aggregate is preferred over manual sample summation
 *   3. Source/origin is always included in responses for dedup visibility
 *   4. All timestamps returned as epochMillis for Dart compatibility
 */
class HealthConnectReader(
    private val client: HealthConnectClient?
) : MethodChannel.MethodCallHandler {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (client == null) {
            result.error("UNAVAILABLE", "Health Connect is not available on this device", null)
            return
        }
        val startMs = call.argument<Number>("startTimestamp")?.toLong()
        val endMs   = call.argument<Number>("endTimestamp")?.toLong()

        if (startMs == null || endMs == null) {
            result.error("INVALID_ARGS", "startTimestamp and endTimestamp are required", null)
            return
        }

        val from = Instant.ofEpochMilli(startMs)
        val to   = Instant.ofEpochMilli(endMs)

        scope.launch {
            try {
                val data: Any = when (call.method) {
                    // ── Aggregate queries (preferred for totals) ────────
                    "aggregateSteps"           -> aggregateSteps(from, to)
                    "aggregateCalories"        -> aggregateCalories(from, to)
                    "aggregateDistance"        -> aggregateDistance(from, to)
                    "aggregateFloors"          -> aggregateFloors(from, to)
                    "aggregateActivity"        -> aggregateActivity(from, to)

                    // ── Sample queries (raw records with source info) ───
                    "readSteps"                -> readSteps(from, to)
                    "readSleep"                -> readSleep(from, to)
                    "readHeartRate"            -> readHeartRate(from, to)
                    "readRestingHeartRate"     -> readRestingHeartRate(from, to)
                    "readHeartRateVariability" -> readHeartRateVariability(from, to)
                    "readOxygenSaturation"     -> readOxygenSaturation(from, to)
                    "readBloodPressure"        -> readBloodPressure(from, to)
                    "readBloodGlucose"         -> readBloodGlucose(from, to)
                    "readRespiratoryRate"      -> readRespiratoryRate(from, to)
                    "readVo2Max"               -> readVo2Max(from, to)
                    "readBodyTemperature"      -> readBodyTemperature(from, to)
                    "readWeight"               -> readWeight(from, to)
                    "readHeight"               -> readHeight(from, to)
                    "readBodyFat"              -> readBodyFat(from, to)
                    "readLeanBodyMass"         -> readLeanBodyMass(from, to)
                    "readExerciseSessions"     -> readExerciseSessions(from, to)
                    "readNutrition"            -> readNutrition(from, to)
                    "readHydration"            -> readHydration(from, to)

                    else -> { result.notImplemented(); return@launch }
                }
                kotlinx.coroutines.withContext(Dispatchers.Main) { result.success(data) }
            } catch (e: Exception) {
                kotlinx.coroutines.withContext(Dispatchers.Main) {
                    result.error("READ_ERROR", e.message, null)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // AGGREGATE QUERIES — use these for totals, not manual sums
    // Health Connect's aggregate handles deduplication automatically
    // ─────────────────────────────────────────────────────────────

    private suspend fun aggregateSteps(from: Instant, to: Instant): Map<String, Any> {
        val result = client!!.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(from, to)
            )
        )
        return mapOf(
            "total"       to (result[StepsRecord.COUNT_TOTAL] ?: 0L),
            "dataOrigins" to result.dataOrigins.map { it.packageName },
        )
    }

    private suspend fun aggregateCalories(from: Instant, to: Instant): Map<String, Any> {
        val result = client!!.aggregate(
            AggregateRequest(
                metrics = setOf(
                    ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                    TotalCaloriesBurnedRecord.ENERGY_TOTAL,
                    BasalMetabolicRateRecord.BASAL_CALORIES_TOTAL,
                ),
                timeRangeFilter = TimeRangeFilter.between(from, to)
            )
        )
        // CRITICAL: always use .inKilocalories — never .inCalories
        return mapOf(
            "activeKcal"  to (result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0),
            "totalKcal"   to (result[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories ?: 0.0),
            "basalKcal"   to (result[BasalMetabolicRateRecord.BASAL_CALORIES_TOTAL]?.inKilocalories ?: 0.0),
            "dataOrigins" to result.dataOrigins.map { it.packageName },
        )
    }

    private suspend fun aggregateDistance(from: Instant, to: Instant): Map<String, Any> {
        val result = client!!.aggregate(
            AggregateRequest(
                metrics = setOf(DistanceRecord.DISTANCE_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(from, to)
            )
        )
        return mapOf(
            "meters"      to (result[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0),
            "dataOrigins" to result.dataOrigins.map { it.packageName },
        )
    }

    private suspend fun aggregateFloors(from: Instant, to: Instant): Map<String, Any> {
        val result = client!!.aggregate(
            AggregateRequest(
                metrics = setOf(FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(from, to)
            )
        )
        return mapOf(
            "total"       to (result[FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL] ?: 0.0),
            "dataOrigins" to result.dataOrigins.map { it.packageName },
        )
    }

    // Combined activity aggregate — single round-trip for dashboard
    private suspend fun aggregateActivity(from: Instant, to: Instant): Map<String, Any> {
        val result = client!!.aggregate(
            AggregateRequest(
                metrics = setOf(
                    StepsRecord.COUNT_TOTAL,
                    DistanceRecord.DISTANCE_TOTAL,
                    FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL,
                    ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                    TotalCaloriesBurnedRecord.ENERGY_TOTAL,
                ),
                timeRangeFilter = TimeRangeFilter.between(from, to)
            )
        )
        return mapOf(
            "steps"        to (result[StepsRecord.COUNT_TOTAL] ?: 0L),
            "distanceM"    to (result[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0),
            "floors"       to (result[FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL] ?: 0.0),
            "activeKcal"   to (result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0),
            "totalKcal"    to (result[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories ?: 0.0),
            "dataOrigins"  to result.dataOrigins.map { it.packageName },
        )
    }

    // ─────────────────────────────────────────────────────────────
    // SAMPLE QUERIES — raw records with full metadata
    // Use when you need per-sample timestamps, source attribution,
    // or data types that don't have aggregate metrics
    // ─────────────────────────────────────────────────────────────

    private suspend fun readSteps(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(StepsRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "count"      to r.count,
                "startMs"    to r.startTime.toEpochMilli(),
                "endMs"      to r.endTime.toEpochMilli(),
                "zoneOffset" to (r.startZoneOffset?.totalSeconds ?: 0),
                "source"     to r.metadata.dataOrigin.packageName,
                "device"     to (r.metadata.device?.model ?: ""),
            )
        }
    }

    // Sleep — returns full session with stage breakdown
    // This is the most complex data type — sessions contain nested stage arrays
    private suspend fun readSleep(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(SleepSessionRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { session ->
            mapOf(
                "startMs"         to session.startTime.toEpochMilli(),
                "endMs"           to session.endTime.toEpochMilli(),
                "durationMinutes" to java.time.Duration.between(
                    session.startTime, session.endTime
                ).toMinutes(),
                "title"           to (session.title ?: ""),
                "notes"           to (session.notes ?: ""),
                "source"          to session.metadata.dataOrigin.packageName,
                "device"          to (session.metadata.device?.model ?: ""),
                "stages"          to session.stages.map { stage ->
                    mapOf(
                        "stage"           to sleepStageToString(stage.stage),
                        "startMs"         to stage.startTime.toEpochMilli(),
                        "endMs"           to stage.endTime.toEpochMilli(),
                        "durationMinutes" to java.time.Duration.between(
                            stage.startTime, stage.endTime
                        ).toMinutes(),
                    )
                },
                // Computed breakdown for convenience
                "breakdown"       to computeSleepBreakdown(session.stages),
            )
        }
    }

    private fun computeSleepBreakdown(stages: List<SleepSessionRecord.Stage>): Map<String, Long> {
        val breakdown = mutableMapOf(
            "deepMinutes"  to 0L,
            "remMinutes"   to 0L,
            "lightMinutes" to 0L,
            "awakeMinutes" to 0L,
            "asleepMinutes" to 0L,
        )
        stages.forEach { stage ->
            val mins = java.time.Duration.between(stage.startTime, stage.endTime).toMinutes()
            when (stage.stage) {
                SleepSessionRecord.STAGE_TYPE_DEEP    -> breakdown["deepMinutes"]   = breakdown["deepMinutes"]!!   + mins
                SleepSessionRecord.STAGE_TYPE_REM     -> breakdown["remMinutes"]    = breakdown["remMinutes"]!!    + mins
                SleepSessionRecord.STAGE_TYPE_LIGHT   -> breakdown["lightMinutes"]  = breakdown["lightMinutes"]!!  + mins
                SleepSessionRecord.STAGE_TYPE_AWAKE   -> breakdown["awakeMinutes"]  = breakdown["awakeMinutes"]!!  + mins
                SleepSessionRecord.STAGE_TYPE_SLEEPING-> breakdown["asleepMinutes"] = breakdown["asleepMinutes"]!! + mins
            }
        }
        return breakdown
    }

    private fun sleepStageToString(stage: Int): String = when (stage) {
        SleepSessionRecord.STAGE_TYPE_AWAKE    -> "awake"
        SleepSessionRecord.STAGE_TYPE_SLEEPING -> "asleep"
        SleepSessionRecord.STAGE_TYPE_OUT_OF_BED -> "outOfBed"
        SleepSessionRecord.STAGE_TYPE_LIGHT    -> "light"
        SleepSessionRecord.STAGE_TYPE_DEEP     -> "deep"
        SleepSessionRecord.STAGE_TYPE_REM      -> "rem"
        SleepSessionRecord.STAGE_TYPE_UNKNOWN  -> "unknown"
        else                                   -> "unknown"
    }

    // Heart rate — returns all samples within sessions
    private suspend fun readHeartRate(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(HeartRateRecord::class, TimeRangeFilter.between(from, to))
        ).records.flatMap { record ->
            record.samples.map { sample ->
                mapOf(
                    "bpm"     to sample.beatsPerMinute,
                    "timeMs"  to sample.time.toEpochMilli(),
                    "source"  to record.metadata.dataOrigin.packageName,
                    "device"  to (record.metadata.device?.model ?: ""),
                )
            }
        }
    }

    private suspend fun readRestingHeartRate(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(RestingHeartRateRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "bpm"     to r.beatsPerMinute,
                "timeMs"  to r.time.toEpochMilli(),
                "source"  to r.metadata.dataOrigin.packageName,
                "device"  to (r.metadata.device?.model ?: ""),
            )
        }
    }

    // HRV — RMSSD on Android (SDNN is iOS/Apple Watch specific)
    private suspend fun readHeartRateVariability(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(HeartRateVariabilityRmssdRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "rmssdMs" to r.heartRateVariabilityMillis,
                "timeMs"  to r.time.toEpochMilli(),
                "source"  to r.metadata.dataOrigin.packageName,
                "device"  to (r.metadata.device?.model ?: ""),
            )
        }
    }

    private suspend fun readOxygenSaturation(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(OxygenSaturationRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "percentage" to r.percentage.value,
                "timeMs"     to r.time.toEpochMilli(),
                "source"     to r.metadata.dataOrigin.packageName,
                "device"     to (r.metadata.device?.model ?: ""),
            )
        }
    }

    // Blood pressure — systolic + diastolic always returned as pair
    private suspend fun readBloodPressure(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(BloodPressureRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "systolicMmhg"  to r.systolic.inMillimetersOfMercury,
                "diastolicMmhg" to r.diastolic.inMillimetersOfMercury,
                "bodyPosition"  to r.bodyPosition.toString(),
                "measurementLoc" to r.measurementLocation.toString(),
                "timeMs"        to r.time.toEpochMilli(),
                "source"        to r.metadata.dataOrigin.packageName,
                "device"        to (r.metadata.device?.model ?: ""),
            )
        }
    }

    private suspend fun readBloodGlucose(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(BloodGlucoseRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "mmolPerL"      to r.level.inMillimolesPerLiter,
                "mgPerDl"       to r.level.inMilligramsPerDeciliter,
                "mealType"      to r.mealType.toString(),
                "specimenSource" to r.specimenSource.toString(),
                "relationToMeal" to r.relationToMeal.toString(),
                "timeMs"        to r.time.toEpochMilli(),
                "source"        to r.metadata.dataOrigin.packageName,
                "device"        to (r.metadata.device?.model ?: ""),
            )
        }
    }

    private suspend fun readRespiratoryRate(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(RespiratoryRateRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "rate"   to r.rate,
                "timeMs" to r.time.toEpochMilli(),
                "source" to r.metadata.dataOrigin.packageName,
                "device" to (r.metadata.device?.model ?: ""),
            )
        }
    }

    private suspend fun readVo2Max(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(Vo2MaxRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "vo2Max"         to r.vo2MillilitersPerMinuteKilogram,
                "measurementMethod" to r.measurementMethod.toString(),
                "timeMs"         to r.time.toEpochMilli(),
                "source"         to r.metadata.dataOrigin.packageName,
                "device"         to (r.metadata.device?.model ?: ""),
            )
        }
    }

    private suspend fun readBodyTemperature(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(BodyTemperatureRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "celsius"        to r.temperature.inCelsius,
                "measurementLoc" to r.measurementLocation.toString(),
                "timeMs"         to r.time.toEpochMilli(),
                "source"         to r.metadata.dataOrigin.packageName,
                "device"         to (r.metadata.device?.model ?: ""),
            )
        }
    }

    private suspend fun readWeight(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(WeightRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "kg"     to r.weight.inKilograms,
                "lbs"    to r.weight.inPounds,
                "timeMs" to r.time.toEpochMilli(),
                "source" to r.metadata.dataOrigin.packageName,
                "device" to (r.metadata.device?.model ?: ""),
            )
        }
    }

    private suspend fun readHeight(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(HeightRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "meters" to r.height.inMeters,
                "cm"     to r.height.inMeters * 100,
                "timeMs" to r.time.toEpochMilli(),
                "source" to r.metadata.dataOrigin.packageName,
                "device" to (r.metadata.device?.model ?: ""),
            )
        }
    }

    private suspend fun readBodyFat(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(BodyFatRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "percentage" to r.percentage.value,
                "timeMs"     to r.time.toEpochMilli(),
                "source"     to r.metadata.dataOrigin.packageName,
                "device"     to (r.metadata.device?.model ?: ""),
            )
        }
    }

    private suspend fun readLeanBodyMass(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(LeanBodyMassRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "kg"     to r.mass.inKilograms,
                "timeMs" to r.time.toEpochMilli(),
                "source" to r.metadata.dataOrigin.packageName,
                "device" to (r.metadata.device?.model ?: ""),
            )
        }
    }

    // Exercise sessions — full session with laps + speed/power series
    private suspend fun readExerciseSessions(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(ExerciseSessionRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { session ->
            mapOf(
                "exerciseType"    to exerciseTypeString(session.exerciseType),
                "title"           to (session.title ?: ""),
                "notes"           to (session.notes ?: ""),
                "startMs"         to session.startTime.toEpochMilli(),
                "endMs"           to session.endTime.toEpochMilli(),
                "durationMinutes" to java.time.Duration.between(
                    session.startTime, session.endTime
                ).toMinutes(),
                "source"          to session.metadata.dataOrigin.packageName,
                "device"          to (session.metadata.device?.model ?: ""),
                "laps"            to session.laps.map { lap ->
                    mapOf(
                        "startMs"  to lap.startTime.toEpochMilli(),
                        "endMs"    to lap.endTime.toEpochMilli(),
                        "lengthM"  to (lap.length?.inMeters ?: 0.0),
                    )
                },
                "segments"        to session.segments.map { seg ->
                    mapOf(
                        "type"    to seg.segmentType.toString(),
                        "startMs" to seg.startTime.toEpochMilli(),
                        "endMs"   to seg.endTime.toEpochMilli(),
                        "reps"    to (seg.repetitions ?: 0),
                    )
                },
            )
        }
    }

    private suspend fun readNutrition(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(NutritionRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "name"          to (r.name ?: ""),
                "mealType"      to r.mealType.toString(),
                "energyKcal"    to (r.energy?.inKilocalories ?: 0.0),
                "proteinG"      to (r.protein?.inGrams ?: 0.0),
                "carbohydratesG" to (r.totalCarbohydrate?.inGrams ?: 0.0),
                "fatG"          to (r.totalFat?.inGrams ?: 0.0),
                "fiberG"        to (r.dietaryFiber?.inGrams ?: 0.0),
                "sugarG"        to (r.sugar?.inGrams ?: 0.0),
                "sodiumMg"      to (r.sodium?.inGrams?.times(1000) ?: 0.0),
                "startMs"       to r.startTime.toEpochMilli(),
                "endMs"         to r.endTime.toEpochMilli(),
                "source"        to r.metadata.dataOrigin.packageName,
            )
        }
    }

    private suspend fun readHydration(from: Instant, to: Instant): List<Map<String, Any>> {
        return client!!.readRecords(
            ReadRecordsRequest(HydrationRecord::class, TimeRangeFilter.between(from, to))
        ).records.map { r ->
            mapOf(
                "volumeLiters"  to r.volume.inLiters,
                "volumeMl"      to r.volume.inLiters * 1000,
                "startMs"       to r.startTime.toEpochMilli(),
                "endMs"         to r.endTime.toEpochMilli(),
                "source"        to r.metadata.dataOrigin.packageName,
            )
        }
    }

    private fun exerciseTypeString(type: Int): String = when (type) {
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING             -> "running"
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL   -> "running"
        ExerciseSessionRecord.EXERCISE_TYPE_WALKING             -> "walking"
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING              -> "cycling"
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY   -> "cycling"
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER -> "swimming"
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL       -> "swimming"
        ExerciseSessionRecord.EXERCISE_TYPE_HIKING              -> "hiking"
        ExerciseSessionRecord.EXERCISE_TYPE_YOGA                -> "yoga"
        ExerciseSessionRecord.EXERCISE_TYPE_DANCING             -> "dancing"
        ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL          -> "elliptical"
        ExerciseSessionRecord.EXERCISE_TYPE_ROWING              -> "rowing"
        ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE      -> "rowing"
        ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING      -> "stair_climbing"
        ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING_MACHINE -> "stair_climbing"
        ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING   -> "strength_training"
        ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING       -> "weightlifting"
        ExerciseSessionRecord.EXERCISE_TYPE_CALISTHENICS        -> "calisthenics"
        ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING -> "high_intensity_interval_training"
        ExerciseSessionRecord.EXERCISE_TYPE_PILATES             -> "pilates"
        ExerciseSessionRecord.EXERCISE_TYPE_BOXING              -> "boxing"
        ExerciseSessionRecord.EXERCISE_TYPE_MARTIAL_ARTS        -> "martial_arts"
        ExerciseSessionRecord.EXERCISE_TYPE_TENNIS              -> "tennis"
        ExerciseSessionRecord.EXERCISE_TYPE_BADMINTON           -> "badminton"
        ExerciseSessionRecord.EXERCISE_TYPE_GOLF                -> "golf"
        ExerciseSessionRecord.EXERCISE_TYPE_FOOTBALL_AMERICAN   -> "american_football"
        ExerciseSessionRecord.EXERCISE_TYPE_SOCCER              -> "soccer"
        ExerciseSessionRecord.EXERCISE_TYPE_BASKETBALL          -> "basketball"
        ExerciseSessionRecord.EXERCISE_TYPE_VOLLEYBALL          -> "volleyball"
        ExerciseSessionRecord.EXERCISE_TYPE_BASEBALL            -> "baseball"
        ExerciseSessionRecord.EXERCISE_TYPE_SOFTBALL            -> "softball"
        ExerciseSessionRecord.EXERCISE_TYPE_RUGBY               -> "rugby"
        ExerciseSessionRecord.EXERCISE_TYPE_ICE_HOCKEY          -> "ice_hockey"
        ExerciseSessionRecord.EXERCISE_TYPE_TABLE_TENNIS        -> "table_tennis"
        ExerciseSessionRecord.EXERCISE_TYPE_RACQUETBALL         -> "racquetball"
        ExerciseSessionRecord.EXERCISE_TYPE_SQUASH              -> "squash"
        ExerciseSessionRecord.EXERCISE_TYPE_ICE_SKATING         -> "skating"
        ExerciseSessionRecord.EXERCISE_TYPE_SKATING             -> "skating"
        ExerciseSessionRecord.EXERCISE_TYPE_SURFING             -> "surfing"
        ExerciseSessionRecord.EXERCISE_TYPE_SKIING              -> "skiing"
        ExerciseSessionRecord.EXERCISE_TYPE_SNOWBOARDING        -> "skiing"
        ExerciseSessionRecord.EXERCISE_TYPE_WHEELCHAIR          -> "wheelchair"
        ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT       -> "other"
        else                                                    -> "other"
    }
}
