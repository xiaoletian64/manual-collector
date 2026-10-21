# OTA 发布

默认清单：`http://124.222.88.195/manual-collector/android/latest.json`。只下载版本信息和 APK，不上传说明书。

## 发布步骤

1. 修改 `mobile/pubspec.yaml` 的版本号，例如 `0.1.2+3`。build number 必须严格递增。
2. 使用 `flutter build apk --release --target-platform android-arm64` 构建安卓 ARM64 APK。不要跳过 pub/tooling 生成步骤，否则开发测试插件可能残留到发布注册表。使用同一签名密钥。当前安装包沿用开发机 debug 签名，仅适用于测试分发；必须保管好该密钥。正式发行应先规划稳定的 release 签名，不能直接用另一签名覆盖当前安装。
3. 执行 `python3 tool/ota/prepare_release.py <APK> --aapt <AndroidSDK/build-tools/36.0.0/aapt> --output <发布目录> --notes '更新说明'`。脚本从 APK 读取真实包名和版本、生成 SHA-256。
4. 将输出 `manual-collector/android/` 中的 APK 上传到服务器对应网站目录。**先完整上传 APK（临时名称上传后原子改名），再上传并原子替换 latest.json**，避免客户端拿到不完整文件。保留旧版 APK。
5. 检查清单 URL 返回 JSON，APK URL 可下载，SHA-256 与清单一致。用旧版本在模拟器验证升级后本地书柜仍在。

这是静态文件服务，无需数据库。不要覆盖服务器其他站点配置。已使用本机 SSH 别名 `wo_fuwuqi` 完成服务器发布。

## 接入 Nginx（片段，合并到现有站点）

```
location /manual-collector/android/ {
    root /srv/manual-collector-ota;
    autoindex off;
    add_header Cache-Control "no-cache" always;
}
```

该 root 对应 `/srv/manual-collector-ota/manual-collector/android/latest.json`。实际路径需根据服务器已有站点确认。

## 校验与边界

- App 启动时静默检查，有新版本在更新图标显示红点；也可手动“软件更新”检查；版本比较使用 versionCode。
- 下载可取消、失败可重试；流式落盘，大小及 SHA-256 校验通过后再安装。
- 安装前校验包名、严格递增版本号、与当前 App 相同的签名；系统仍需用户确认安装。未知来源权限由系统设置授予后返回重试。
- HTTP 清单与哈希本身不提供来源认证；攻击者可能干扰更新提示或阻断下载，但不同签名安装包会被拒绝。应尽快给站点配置有效 HTTPS，并在构建时设置 `UPDATE_MANIFEST_URL`。不要关闭 TLS 校验。
- `--dart-define=UPDATE_MANIFEST_URL=https://域名/manual-collector/android/latest.json` 可改变服务地址，APK 路径限定与清单同源；禁止重定向。
- iOS 通过 TestFlight/App Store 分发更新，不能套用安卓 APK 安装流程。

参考：[Android 安装权限](https://developer.android.com/reference/android/content/pm/PackageManager#canRequestPackageInstalls())、[Apple 分发说明](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)。

## 本次验证

- 静态分析通过，5 项测试通过（包含损坏包、大小不符、下载取消、重定向拒绝和 404）。
- Android 0.1.1+2 构建成功并覆盖安装到模拟器，原有 2 页说明书仍保留。
- 实际更新页面正确读取 0.1.1 (2)，服务清单 404 时显示可重试状态。
- iOS 模拟器构建通过。
- 发布产物已生成在仓库根目录 `output/ota/manual-collector/android/`。
- 早期 0.1.1 构建时尚未部署；最新发布与实际升级验证见下方记录。

## 当前服务器发布命令

本机 SSH 别名 `wo_fuwuqi` 指向用户提供的服务器，使用现有 SSH 认证。静态目录是 `/www/server/nginx/html/manual-collector/android/`，由已有默认 Nginx 站点提供，不需要修改其他应用的配置。

```sh
python3 mobile/tool/ota/publish_release.py output/ota/manual-collector/android
```

发布脚本核对本地与服务器 SHA-256，先上传临时目录，然后加锁、原子发布 APK 和清单；拒绝版本号回退或同一版本号更换不同内容。

## 0.1.2+3 发布记录

- 已通过 SSH 发布，公网版本清单返回 200。
- Android release 构建通过（沿用旧版开发签名，兼容此前测试版覆盖更新），文件大小 72,478,399 字节。
- SHA-256：`758e50d5f9f99565c761c96bb206b534e71e799717d5174567250237e423fb83`。
- 服务器未改动已有站点配置；使用默认站点根目录下的独立子目录。
- 当前仍是 HTTP 下载，安装包通过哈希、包名、递增版本和旧版相同签名验证；HTTPS 证书问题尚未处理。
- 完整 OTA 实测通过：模拟器上的 0.1.1+2 从公网服务器检测并下载 0.1.2+3，授予安装权限后由系统安装器确认覆盖升级。
- 安装器显示 App installed；系统包信息为 versionCode=3、versionName=0.1.2。
- 升级后原有说明书及两页 PDF 保留，中文文字层仍可读取。
- 新版再次检查更新显示“当前已是最新版本”。操作截图保存于 `output/qa/09-ota-available.png` 至 `14-ota-current.png`。
