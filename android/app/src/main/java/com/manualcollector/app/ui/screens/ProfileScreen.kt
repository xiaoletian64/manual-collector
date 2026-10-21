package com.manualcollector.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun ProfileScreen() {
    var isCloudConnected by remember { mutableStateOf(false) }
    var isPremium by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        // Profile header
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.large,
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    imageVector = Icons.Filled.Person,
                    contentDescription = null,
                    modifier = Modifier.size(64.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "说明书收集器",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = "v1.0.0",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Cloud backup section
        SettingsSection(title = "云备份") {
            SettingsRow(
                icon = Icons.Filled.Storage,
                title = "百度网盘",
                subtitle = if (isCloudConnected) "已连接" else "未连接",
                trailing = {
                    TextButton(onClick = { isCloudConnected = !isCloudConnected }) {
                        Text(if (isCloudConnected) "断开" else "连接")
                    }
                },
            )
            HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
            SettingsRow(
                icon = if (isCloudConnected) Icons.Filled.Cloud else Icons.Filled.CloudOff,
                title = "自动同步",
                subtitle = "扫描后自动上传到云端",
                trailing = {
                    @Suppress("UNUSED_EXPRESSION")
                    androidx.compose.material3.Switch(
                        checked = isCloudConnected,
                        onCheckedChange = { isCloudConnected = it },
                    )
                },
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Subscription section
        SettingsSection(title = "订阅管理") {
            SettingsRow(
                icon = Icons.Filled.Star,
                title = "高级会员",
                subtitle = if (isPremium) "已订阅" else "免费版",
                trailing = {
                    TextButton(onClick = { isPremium = !isPremium }) {
                        Text(if (isPremium) "管理" else "升级")
                    }
                },
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        // About section
        SettingsSection(title = "关于") {
            SettingsRow(
                icon = Icons.Filled.Info,
                title = "版本信息",
                subtitle = "1.0.0 (build 1)",
            )
            HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
            SettingsRow(
                icon = Icons.Filled.Info,
                title = "开源许可",
                subtitle = "Apache 2.0",
                onClick = {},
            )
        }
    }
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable () -> Unit,
) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp),
        )
        Card(
            shape = MaterialTheme.shapes.medium,
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface,
            ),
        ) {
            content()
        }
    }
}

@Composable
private fun SettingsRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    trailing: @Composable (() -> Unit)? = null,
    onClick: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(24.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (trailing != null) {
            trailing()
        }
    }
}
