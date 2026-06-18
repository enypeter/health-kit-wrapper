package com.healthconnectreporter

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.activity.result.contract.ActivityResultContract
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import com.healthconnectreporter.manager.HealthConnectManager
import com.healthconnectreporter.reader.HealthConnectReader
import com.healthconnectreporter.observer.HealthConnectObserver
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Self-contained Health Connect plugin.
 *
 * The host app needs no special Activity or permission wiring: this plugin
 * drives the Health Connect permission flow itself via the [ActivityPluginBinding]
 * (registering a [PluginRegistry.ActivityResultListener] and launching the
 * permission contract intent with `startActivityForResult`).
 */
class HealthConnectReporterPlugin :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var context: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private lateinit var managerChannel: MethodChannel
    private lateinit var readerChannel: MethodChannel
    private lateinit var observerEventChannel: EventChannel

    private lateinit var managerHandler: HealthConnectManager
    private lateinit var readerHandler: HealthConnectReader
    private lateinit var observerHandler: HealthConnectObserver

    // Health Connect permission request/parse contract.
    private val permissionContract: ActivityResultContract<Set<String>, Set<String>> =
        PermissionController.createRequestPermissionResultContract()

    // In-flight permission request state.
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPermissions: Set<String>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        val sdkStatus = HealthConnectClient.getSdkStatus(
            context, "com.google.android.apps.healthdata"
        )
        val client = if (sdkStatus == HealthConnectClient.SDK_AVAILABLE) {
            HealthConnectClient.getOrCreate(context)
        } else {
            null
        }

        managerHandler = HealthConnectManager(context, client)
        readerHandler = HealthConnectReader(client)
        observerHandler = HealthConnectObserver(client)

        // The manager delegates the actual permission launch back to the plugin,
        // which owns the Activity and the result callback.
        managerHandler.onRequestPermissions = { permissions, result ->
            launchPermissionRequest(permissions, result)
        }

        managerChannel = MethodChannel(
            binding.binaryMessenger,
            "com.healthkitwrapper/manager"
        ).also { it.setMethodCallHandler(managerHandler) }

        readerChannel = MethodChannel(
            binding.binaryMessenger,
            "com.healthkitwrapper/reader"
        ).also { it.setMethodCallHandler(readerHandler) }

        observerEventChannel = EventChannel(
            binding.binaryMessenger,
            "com.healthkitwrapper/observer"
        ).also { it.setStreamHandler(observerHandler) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        managerChannel.setMethodCallHandler(null)
        readerChannel.setMethodCallHandler(null)
        observerEventChannel.setStreamHandler(null)
        observerHandler.cancelAll()
    }

    // ── ActivityAware ───────────────────────────────────────────
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        managerHandler.activity = binding.activity
        binding.addActivityResultListener(this)
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        managerHandler.activity = null
    }

    // ── Permission flow ─────────────────────────────────────────
    private fun launchPermissionRequest(
        permissions: Set<String>,
        result: MethodChannel.Result,
    ) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "No foreground Activity to request permissions", null)
            return
        }
        if (pendingResult != null) {
            result.error("ALREADY_PENDING", "A permission request is already in progress", null)
            return
        }
        pendingResult = result
        pendingPermissions = permissions
        try {
            val intent: Intent = permissionContract.createIntent(act, permissions)
            act.startActivityForResult(intent, PERMISSION_REQUEST_CODE)
        } catch (e: Exception) {
            pendingResult = null
            pendingPermissions = null
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val result = pendingResult
        val requested = pendingPermissions ?: emptySet()
        pendingResult = null
        pendingPermissions = null
        if (result == null) return true
        val granted = permissionContract.parseResult(resultCode, data)
        result.success(requested.all { it in granted })
        return true
    }

    companion object {
        private const val PERMISSION_REQUEST_CODE = 1339
    }
}
