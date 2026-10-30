package com.gsu.gsu_fit

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import androidx.activity.result.ActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity is required by the Health Connect plugin.
 *
 * Also hosts two small method channels so the app needs no extra plugins:
 *  - "gsu_fit/files": save/open documents through the system file picker
 *  - "gsu_fit/reminders": local reminders via AlarmManager (see Reminders.kt)
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private var pendingAction: String? = null

    private val documentLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            onDocumentResult(result)
        }

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            val result = pendingResult
            pendingResult = null
            pendingAction = null
            result?.success(granted)
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, FILES_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveDocument" -> saveDocument(call, result)
                "openDocument" -> openDocument(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, REMINDERS_CHANNEL).setMethodCallHandler { call, result ->
            handleReminderCall(call, result)
        }
    }

    // region Files

    private fun saveDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Another request is in progress", null)
            return
        }
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null) {
            result.error("arguments", "bytes is missing", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = call.argument<String>("mimeType") ?: "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "export")
        }
        pendingResult = result
        pendingBytes = bytes
        pendingAction = ACTION_SAVE
        documentLauncher.launch(intent)
    }

    private fun openDocument(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Another request is in progress", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/json",
                    "text/csv",
                    "text/comma-separated-values",
                    "text/plain",
                    "application/octet-stream",
                ),
            )
        }
        pendingResult = result
        pendingAction = ACTION_OPEN
        documentLauncher.launch(intent)
    }

    private fun onDocumentResult(activityResult: ActivityResult) {
        val result = pendingResult ?: return
        val action = pendingAction
        val bytes = pendingBytes
        pendingResult = null
        pendingAction = null
        pendingBytes = null

        val uri: Uri? = activityResult.data?.data
        if (activityResult.resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            if (action == ACTION_SAVE) {
                val output = contentResolver.openOutputStream(uri, "wt")
                    ?: throw IllegalStateException("Cannot open the selected file")
                output.use { it.write(bytes ?: ByteArray(0)) }
                result.success(uri.toString())
            } else {
                val input = contentResolver.openInputStream(uri)
                    ?: throw IllegalStateException("Cannot open the selected file")
                val content = input.use { it.readBytes() }
                result.success(mapOf("name" to displayName(uri), "bytes" to content))
            }
        } catch (error: Exception) {
            result.error("io", error.message, null)
        }
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val name = cursor.getString(0)
                    if (name != null) return name
                }
            }
        return uri.lastPathSegment ?: ""
    }

    // endregion

    // region Reminders

    private fun handleReminderCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> requestNotificationPermission(result)
            "notificationsAllowed" -> result.success(Reminders.notificationsAllowed(this))
            "scheduleRepeating" -> {
                val weekdays = call.argument<List<Number>>("weekdays")?.map { it.toInt() } ?: emptyList()
                Reminders.schedule(
                    this,
                    Reminders.Reminder(
                        id = call.argument<Number>("id")?.toInt() ?: 0,
                        title = call.argument<String>("title") ?: "",
                        body = call.argument<String>("body") ?: "",
                        hour = call.argument<Number>("hour")?.toInt() ?: 9,
                        minute = call.argument<Number>("minute")?.toInt() ?: 0,
                        weekdays = weekdays,
                        atMillis = 0L,
                    ),
                )
                result.success(null)
            }
            "scheduleOnce" -> {
                Reminders.schedule(
                    this,
                    Reminders.Reminder(
                        id = call.argument<Number>("id")?.toInt() ?: 0,
                        title = call.argument<String>("title") ?: "",
                        body = call.argument<String>("body") ?: "",
                        hour = 0,
                        minute = 0,
                        weekdays = emptyList(),
                        atMillis = call.argument<Number>("atMillis")?.toLong() ?: 0L,
                    ),
                )
                result.success(null)
            }
            "cancel" -> {
                Reminders.cancel(this, call.argument<Number>("id")?.toInt() ?: 0)
                result.success(null)
            }
            "cancelAll" -> {
                Reminders.cancelAll(this)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(Reminders.notificationsAllowed(this))
            return
        }
        if (pendingResult != null) {
            result.error("busy", "Another request is in progress", null)
            return
        }
        pendingResult = result
        pendingAction = ACTION_PERMISSION
        permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    // endregion

    companion object {
        private const val FILES_CHANNEL = "gsu_fit/files"
        private const val REMINDERS_CHANNEL = "gsu_fit/reminders"
        private const val ACTION_SAVE = "save"
        private const val ACTION_OPEN = "open"
        private const val ACTION_PERMISSION = "permission"
    }
}
