package com.example.resona

import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.resona/default_save_location"
    private val requestDirectory = 7134
    private var directoryResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "chooseDirectory" -> {
                        if (directoryResult != null) {
                            result.error("picker_busy", "A folder picker is already open.", null)
                        } else {
                            directoryResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                            }
                            startActivityForResult(intent, requestDirectory)
                        }
                    }
                    "createFile" -> {
                        try {
                            val treeUri = Uri.parse(call.argument<String>("treeUri")!!)
                            val mimeType = call.argument<String>("mimeType")!!
                            val fileName = call.argument<String>("fileName")!!
                            val documentUri = DocumentsContract.createDocument(
                                contentResolver,
                                DocumentsContract.buildDocumentUriUsingTree(
                                    treeUri,
                                    DocumentsContract.getTreeDocumentId(treeUri)
                                ),
                                mimeType,
                                fileName
                            )
                            result.success(documentUri?.toString())
                        } catch (error: Exception) {
                            result.error("create_failed", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android; retained for the folder picker result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestDirectory) return
        val pending = directoryResult ?: return
        directoryResult = null
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (uri == null) {
            pending.success(null)
            return
        }
        val flags = data?.flags ?: 0
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            )
            pending.success(uri.toString())
        } catch (error: Exception) {
            pending.error("permission_failed", error.message, null)
        }
    }
}
