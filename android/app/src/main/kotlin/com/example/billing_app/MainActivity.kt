package com.example.billing_app

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.billing_app/whatsapp_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareToWhatsApp") {
                val phone = call.argument<String>("phone")
                val filePath = call.argument<String>("filePath")
                if (phone != null && filePath != null) {
                    try {
                        val file = File(filePath)
                        val authority = "${packageName}.flutter.share_provider"
                        val fileUri: Uri = FileProvider.getUriForFile(context, authority, file)

                        val intent = Intent(Intent.ACTION_SEND)
                        intent.type = "application/pdf"
                        intent.putExtra(Intent.EXTRA_STREAM, fileUri)
                        
                        var cleanPhone = phone.replace("+", "").replace(" ", "").trim()
                        if (cleanPhone.length == 10) {
                            cleanPhone = "91$cleanPhone"
                        }
                        
                        intent.putExtra("jid", "$cleanPhone@s.whatsapp.net")
                        intent.setPackage("com.whatsapp")
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Phone and FilePath must not be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
