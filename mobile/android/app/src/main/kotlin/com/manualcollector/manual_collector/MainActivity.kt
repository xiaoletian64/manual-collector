package com.manualcollector.manual_collector

import android.graphics.BitmapFactory
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private var exportResult: MethodChannel.Result? = null
    private var exportPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "manual_collector/ui")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dial" -> {
                        try {
                            val phone = call.argument<String>("phone") ?: error("缺少号码")
                            startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone")))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("dial_failed", error.message ?: "无法打开拨号器", null)
                        }
                    }
                    "dynamicColorAvailable" -> {
                        // Material You 动态取色：Android 12+（S）
                        result.success(Build.VERSION.SDK_INT >= 31)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "manual_collector/update")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "info" -> {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                            result.success(mapOf("versionName" to info.versionName, "versionCode" to code))
                        }
                        "install" -> {
                            val file = File(call.argument<String>("path") ?: "").canonicalFile
                            val expected = call.argument<Number>("versionCode")?.toLong()
                            require(file.isFile && file.parentFile == File(cacheDir, "updates").canonicalFile) { "安装包路径无效" }
                            val flags = PackageManager.GET_SIGNATURES
                            val archive = packageManager.getPackageArchiveInfo(file.path, flags) ?: error("安装包无效")
                            val current = packageManager.getPackageInfo(packageName, flags)
                            val newCode = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else archive.versionCode.toLong()
                            val oldCode = if (Build.VERSION.SDK_INT >= 28) current.longVersionCode else current.versionCode.toLong()
                            require(archive.packageName == packageName && newCode == expected && newCode > oldCode) { "安装包版本或包名不符" }
                            val trusted = current.signatures?.map { it.toCharsString() }?.toSet()
                            require(!trusted.isNullOrEmpty() && archive.signatures?.map { it.toCharsString() }?.toSet() == trusted) { "安装包签名不符" }
                            if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                                startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                                result.error("permission", "请允许安装此来源的应用", null)
                            } else {
                                val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                                startActivity(Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                })
                                result.success(null)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("update_failed", error.message ?: "无法安装更新", null) }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "manual_collector/export")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") { result.notImplemented(); return@setMethodCallHandler }
                if (exportResult != null) { result.error("busy", "请先完成当前保存", null); return@setMethodCallHandler }
                val path = call.argument<String>("path")
                if (path == null || !File(path).isFile) { result.error("missing", "PDF 不存在", null); return@setMethodCallHandler }
                exportResult = result
                exportPath = path
                try {
                    startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TITLE, File(path).name)
                    }, 4201)
                } catch (error: Exception) {
                    exportResult = null; exportPath = null
                    result.error("save_failed", "无法打开文件保存窗口", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "manual_collector/ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("invalid_path", "缺少图片路径", null)
                    return@setMethodCallHandler
                }
                executor.execute {
                    val bitmap = BitmapFactory.decodeFile(path)
                    if (bitmap == null) {
                        runOnUiThread { result.error("invalid_image", "图片无法读取", null) }
                        return@execute
                    }
                    val width = bitmap.width.toDouble()
                    val height = bitmap.height.toDouble()
                    val recognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
                    recognizer.process(InputImage.fromBitmap(bitmap, 0))
                        .addOnSuccessListener { text ->
                            val lines = text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                                val box = line.boundingBox ?: return@mapNotNull null
                                mapOf("text" to line.text, "x" to box.left / width,
                                    "y" to box.top / height, "width" to box.width() / width,
                                    "height" to box.height() / height)
                            }
                            result.success(lines)
                        }
                        .addOnFailureListener { result.error("ocr_failed", "识别失败，请重试：${it.localizedMessage}", null) }
                        .addOnCompleteListener { recognizer.close(); bitmap.recycle() }
                }
            }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4201) return
        val result = exportResult ?: return
        val path = exportPath
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || path == null) {
            exportResult = null; exportPath = null
            result.success(false)
            return
        }
        executor.execute {
            try {
                val output = contentResolver.openOutputStream(uri, "wt") ?: error("无法写入文件")
                output.use { target -> File(path).inputStream().use { it.copyTo(target) } }
                runOnUiThread {
                    exportResult = null; exportPath = null
                    result.success(true)
                }
            } catch (error: Exception) {
                runOnUiThread {
                    exportResult = null; exportPath = null
                    result.error("save_failed", "保存失败，请检查目标空间和网络后重试", null)
                }
            }
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }
}
