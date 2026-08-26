package com.leostumpf.zonecraft

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/**
 * The app's only platform code. Two jobs, both things Flutter has no
 * plugin-free answer for and that we deliberately did not take a dependency
 * for (receive_sharing_intent and file_picker were both rejected: two more
 * dependencies for ~200 lines of Kotlin we can read):
 *
 *  1. **Receiving a file.** ACTION_SEND from another app's share sheet and
 *     ACTION_VIEW from a file manager. The `content:` uri is read-granted to
 *     *this task* only and can be revoked the moment the sender finishes, so
 *     it is copied into cacheDir here and Dart is handed a plain path plus the
 *     provider's display name. That name matters: `parseExternalGeometry`
 *     sniffs its extension and `_syntheticLayers` names the layer after its
 *     stem.
 *
 *  2. **Saving a file.** ACTION_CREATE_DOCUMENT, because
 *     `file_selector_android` implements openFile but throws
 *     UnimplementedError from getSaveLocation — which is why an export could
 *     be shared everywhere but saved nowhere.
 *
 * Delivery is **pull, not push**: Dart asks with `takeSharedFile` at startup
 * and again on every resume (see data/platform_files.dart). onNewIntent is
 * always delivered before onResume, so that is race-free and needs no
 * EventChannel and no "is the engine attached yet" guard.
 *
 * Nothing here touches the network and nothing leaves the device. No
 * permission is required for either job.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "com.leostumpf.zonecraft/files"

        /** Ours alone; the plugins in this app use small low numbers. */
        const val REQ_CREATE_DOCUMENT = 0x5A43 // "ZC"

        /**
         * Dart reads the whole file into memory to decode it, so this bounds
         * memory as much as disk. The largest thing this app produces — a
         * 119 000-point state boundary — is a few MB; the cap only stops a
         * hostile provider streaming forever.
         */
        const val MAX_IMPORT_BYTES = 64L * 1024 * 1024

        const val SHARED_DIR = "shared_imports"
    }

    /** All uri I/O runs here; MethodChannel replies are posted back to main. */
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** A file another app handed us, waiting for Dart to pull it. */
    private var pendingImport: Uri? = null

    /**
     * True when the activity is being rebuilt from a saved state: the system
     * re-delivers the launch intent, and importing it a second time would
     * duplicate every layer. A fresh share always arrives via onNewIntent.
     */
    private var restored = false

    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveSource: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Assigned before super, which is what builds the delegate and calls
        // configureFlutterEngine below.
        restored = savedInstanceState != null
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onMethodCall)
        if (!restored) rememberImport(intent)
    }

    override fun onNewIntent(intent: Intent) {
        // super first, so the plugin registry — and therefore app_links, which
        // is how zonecraft:// position links arrive — still sees it. Then
        // setIntent, which the framework's onNewIntent does not do for us.
        super.onNewIntent(intent)
        setIntent(intent)
        rememberImport(intent)
    }

    private fun rememberImport(intent: Intent?) {
        pendingImport = incomingUri(intent) ?: return
    }

    /** The file this intent carries, or null if it carries none of ours. */
    private fun incomingUri(intent: Intent?): Uri? {
        if (intent == null) return null
        val uri = when (intent.action) {
            Intent.ACTION_SEND -> extraStream(intent)
            Intent.ACTION_VIEW -> intent.data
            else -> null
        } ?: return null
        // A zonecraft:// VIEW intent is the position deep link, not a file.
        // Leave it entirely to app_links — openInputStream on it would throw.
        return when (uri.scheme?.lowercase()) {
            "content", "file" -> uri
            else -> null
        }
    }

    @Suppress("DEPRECATION")
    private fun extraStream(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takeSharedFile" -> takeSharedFile(result)
            "saveFile" -> startSave(call, result)
            else -> result.notImplemented()
        }
    }

    /** Hands Dart the pending file once, then forgets it. */
    private fun takeSharedFile(result: MethodChannel.Result) {
        val uri = pendingImport
        pendingImport = null
        if (uri == null) {
            result.success(null)
            return
        }
        io.execute {
            val payload = try {
                copyToCache(uri)
            } catch (e: Exception) {
                null
            }
            main.post {
                if (payload == null) {
                    result.error("read_failed", "Could not read the shared file", null)
                } else {
                    result.success(payload)
                }
            }
        }
    }

    private fun copyToCache(uri: Uri): Map<String, Any?> {
        val name = displayName(uri)
        val dir = File(cacheDir, SHARED_DIR)
        dir.mkdirs()
        dir.listFiles()?.forEach { it.delete() } // one at a time; never grows
        val out = File(dir, cacheName(name))
        var total = 0L
        val input = contentResolver.openInputStream(uri)
            ?: throw IOException("no stream for $uri")
        input.use { source ->
            out.outputStream().use { sink ->
                val buf = ByteArray(64 * 1024)
                while (true) {
                    val n = source.read(buf)
                    if (n <= 0) break
                    total += n
                    if (total > MAX_IMPORT_BYTES) {
                        out.delete()
                        throw IOException("file larger than $MAX_IMPORT_BYTES bytes")
                    }
                    sink.write(buf, 0, n)
                }
            }
        }
        return mapOf(
            "path" to out.absolutePath,
            "name" to name,
            "mimeType" to contentResolver.getType(uri),
        )
    }

    /** The provider's display name — what the import shows and sniffs on. */
    private fun displayName(uri: Uri): String {
        if (uri.scheme == "content") {
            try {
                contentResolver.query(
                    uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
                )?.use { c ->
                    val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (i >= 0 && c.moveToFirst()) {
                        val n = c.getString(i)
                        if (!n.isNullOrBlank()) return n
                    }
                }
            } catch (e: Exception) {
                // A provider is free to refuse the query; fall through.
            }
        }
        val last = uri.lastPathSegment?.substringAfterLast('/')
        return if (last.isNullOrBlank()) "shared" else last
    }

    /** A display name is text someone else chose; the cache file name is not. */
    private fun cacheName(name: String): String {
        val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_").takeLast(120)
        return if (safe.isBlank() || safe == "." || safe == "..") "shared" else safe
    }

    private fun startSave(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSaveResult != null) {
            // A second reply on one Result crashes the channel.
            result.error("busy", "A save is already in progress", null)
            return
        }
        val source = call.argument<String>("sourcePath")
        val name = call.argument<String>("suggestedName")
        val mime = call.argument<String>("mimeType") ?: "application/octet-stream"
        if (source == null || name == null) {
            result.error("bad_args", "sourcePath and suggestedName are required", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mime
            putExtra(Intent.EXTRA_TITLE, name)
        }
        pendingSaveResult = result
        pendingSaveSource = source
        try {
            startActivityForResult(intent, REQ_CREATE_DOCUMENT)
        } catch (e: ActivityNotFoundException) {
            pendingSaveResult = null
            pendingSaveSource = null
            result.error("no_picker", "No file picker on this device", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Always first: FlutterActivity forwards to the plugin registry, which
        // is how geolocator's permission screen and file_selector's picker get
        // their results back.
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_CREATE_DOCUMENT) return
        val result = pendingSaveResult ?: return
        val source = pendingSaveSource
        pendingSaveResult = null
        pendingSaveSource = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null || source == null) {
            result.success(null) // backed out of the picker — not an error
            return
        }
        io.execute {
            val written = try {
                contentResolver.openOutputStream(uri)?.use { sink ->
                    File(source).inputStream().use { it.copyTo(sink) }
                } != null
            } catch (e: Exception) {
                false
            }
            val name = if (written) displayName(uri) else null
            main.post {
                if (written) result.success(name)
                else result.error("write_failed", "Could not write the file", null)
            }
        }
    }

    override fun onDestroy() {
        // Never leave a Dart future hanging on a picker we are about to lose.
        pendingSaveResult?.success(null)
        pendingSaveResult = null
        pendingSaveSource = null
        io.shutdown()
        super.onDestroy()
    }
}
