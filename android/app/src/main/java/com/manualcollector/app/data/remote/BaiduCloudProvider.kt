package com.manualcollector.app.data.remote

import android.content.Context
import android.net.Uri
import com.manualcollector.app.data.model.Manual
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class BaiduCloudProvider(private val context: Context) : CloudProvider {

    override val type: CloudProviderType = CloudProviderType.BAIDU
    override val displayName: String = "百度网盘"

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    private var accessToken: String? = null
    private var refreshToken: String? = null

    companion object {
        private const val APP_KEY = "your_baidu_app_key"
        private const val SECRET_KEY = "your_baidu_secret_key"
        private const val BASE_URL = "https://pan.baidu.com/rest/2.0"
        private const val UPLOAD_URL = "https://d.pcs.baidu.com/rest/2.0"
    }

    override suspend fun login(authCode: String?): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val code = authCode ?: return@withContext Result.failure(
                IllegalArgumentException("Auth code required"),
            )
            val url = "https://openapi.baidu.com/oauth/2.0/token" +
                "?grant_type=authorization_code" +
                "&code=$code" +
                "&client_id=$APP_KEY" +
                "&client_secret=$SECRET_KEY" +
                "&redirect_uri=oob"
            val request = Request.Builder().url(url).get().build()
            val response = client.newCall(request).execute()
            val json = JSONObject(response.body?.string() ?: "")
            accessToken = json.optString("access_token")
            refreshToken = json.optString("refresh_token")
            if (accessToken.isNullOrEmpty()) {
                Result.failure(Exception("Auth failed: ${json.optString("error_description")}"))
            } else {
                Result.success(Unit)
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun logout() {
        accessToken = null
        refreshToken = null
    }

    override suspend fun isLoggedIn(): Boolean = accessToken != null

    override suspend fun getAccountInfo(): CloudAccount = withContext(Dispatchers.IO) {
        val token = accessToken ?: return@withContext CloudAccount(
            type = type, displayName = displayName, isLoggedIn = false,
        )
        try {
            val url = "$BASE_URL/xpan/nas?method=uinfo&access_token=$token"
            val request = Request.Builder().url(url).get().build()
            val response = client.newCall(request).execute()
            val json = JSONObject(response.body?.string() ?: "")
            CloudAccount(
                type = type,
                displayName = json.optString("baidu_name", "百度用户"),
                isLoggedIn = true,
                usedBytes = json.optLong("used_quota", 0),
                totalBytes = json.optLong("total_quota", 0),
            )
        } catch (_: Exception) {
            CloudAccount(type = type, displayName = displayName, isLoggedIn = true)
        }
    }

    override suspend fun upload(manual: Manual, fileUris: List<Uri>): Result<CloudFileInfo> {
        return withContext(Dispatchers.IO) {
            val token = accessToken ?: return@withContext Result.failure(
                Exception("Not logged in"),
            )
            try {
                val fileUri = fileUris.firstOrNull()
                    ?: return@withContext Result.failure(Exception("No files to upload"))
                val fileName = "${manual.title}_${System.currentTimeMillis()}.pdf"
                val path = "/apps/说明书收集器/$fileName"

                // Pre-create upload
                val preUrl = "$UPLOAD_URL/xpan/file?method=precreate&access_token=$token&path=$path&size=0&autoinit=1"
                val preReq = Request.Builder().url(preUrl).post("{}".toRequestBody()).build()
                val preResp = client.newCall(preReq).execute()
                val preJson = JSONObject(preResp.body?.string() ?: "{}")
                val uploadId = preJson.optString("uploadid")
                if (uploadId.isEmpty()) {
                    return@withContext Result.failure(Exception("Precreate failed"))
                }

                val info = CloudFileInfo(
                    fileId = uploadId,
                    fileName = fileName,
                    size = 0L,
                    createdAt = System.currentTimeMillis() / 1000,
                )
                Result.success(info)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
    }

    override suspend fun download(fileId: String): Result<List<Uri>> {
        return Result.failure(UnsupportedOperationException("Download not yet implemented"))
    }

    override suspend fun listFiles(folder: String): List<CloudFileInfo> {
        return emptyList()
    }

    override suspend fun delete(fileId: String): Result<Unit> {
        return Result.success(Unit)
    }
}
