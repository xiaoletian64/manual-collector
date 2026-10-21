package com.manualcollector.app.data.remote

import android.net.Uri
import com.manualcollector.app.data.model.Manual

enum class CloudProviderType { BAIDU, ALIYUN, WEBDAV }

data class CloudAccount(
    val type: CloudProviderType,
    val displayName: String,
    val isLoggedIn: Boolean = false,
    val usedBytes: Long = 0,
    val totalBytes: Long = 0,
)

data class CloudFileInfo(
    val fileId: String,
    val fileName: String,
    val size: Long,
    val createdAt: Long,
    val downloadUrl: String = "",
)

interface CloudProvider {
    val type: CloudProviderType
    val displayName: String

    suspend fun login(authCode: String? = null): Result<Unit>
    suspend fun logout()
    suspend fun isLoggedIn(): Boolean
    suspend fun getAccountInfo(): CloudAccount
    suspend fun upload(manual: Manual, fileUris: List<Uri>): Result<CloudFileInfo>
    suspend fun download(fileId: String): Result<List<Uri>>
    suspend fun listFiles(folder: String = ""): List<CloudFileInfo>
    suspend fun delete(fileId: String): Result<Unit>
}
