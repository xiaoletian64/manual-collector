# 说明书柜

Flutter 应用，当前仅推进 Android；iOS 暂停开发和验收。把纸质产品说明书归档为保留原图、带 OCR 文字层的可搜索 PDF。

## 已实现

- 系统相机拍摄、相册多选导入；最多每本 100 页。
- 页面预览、排序、旋转、删除；导入后自动存为本地草稿。
- Android 中文 ML Kit（模型打包随应用提供），iOS Apple Vision；无需 API Key。
- 识别失败可重试，也可确认后保存原图；不伪造识别结果。
- PDF 保留扫描图，逐行叠加不可见的 Unicode 文字，支持普通 PDF 阅读器搜索和复制。
- 书柜按名称/型号/正文搜索、分类、修改资料、删除。
- 内置 PDF 阅读、缩放、页内搜索并定位、查看/复制识别文字。
- 导出菜单提供“保存到本地 / 文件库”和“发送到网盘或其他应用”。文件库保存使用系统文件选择器，支持本地文件夹与系统已接入的文件服务；取消不提示成功，写入失败可重试。网盘最终上传状态由服务提供方管理。
- SQLite 保存元数据和 OCR；扫描图和 PDF 保存在应用文档目录，重启后可恢复。

## 运行

需要 Flutter 3.41 / Dart 3.11 或兼容更新版、Android SDK。安卓构建辅助脚本还使用 Python 3 和 curl，将锁定版本的 PDFium 官方二进制缓存到本项目，避免 Dart 下载器在代理环境下握手失败；不会关闭 TLS 校验或修改依赖源码。iOS 需要 macOS、Xcode 和 CocoaPods。

```sh
cd mobile
flutter pub get
flutter run -d <device-id>
bash tool/build_android.sh  # ARM64 安卓测试包，使用终端的 JAVA_HOME
flutter build ios --simulator --debug --no-codesign
```

`android/` 和 `ios/`（仓库根目录）是旧原生原型；本目录下的同名目录才是 Flutter 工程的平台宿主。旧文件未删除。

## 验证

```sh
flutter analyze
flutter test
flutter test integration_test/archive_flow_test.dart -d <device-id>
dart run tool/verify_pdf.dart
python3 tool/check_pdf.py  # 需安装 pymupdf、pypdf
```

- 存储测试：草稿与发布隔离、中文全文搜索、特殊字符搜索、页面排序、删除关联数据、关闭数据库后恢复。
- 集成测试脚本（尚未自动执行）：现场绘制中英文样张，调用真实平台 OCR，生成 PDF，用 PDF 引擎重新提取文字，重新打开数据库，再进入阅读器查找。
- `tool/verify_pdf.dart` 生成三页受控样本，含竖版、横版与没有 OCR 的页面，用于外部提取和渲染校验；测试图片不打包进应用。

## 数据与限制

全部资料保存在本机。卸载应用会删除本地数据，请通过“导出 PDF”备份。导出的 PDF 自带文字层，离开本应用也能查找。

当前导入入口为照片，不包括已有 PDF 文件；尚未实现自动裁边/透视校正、云同步、跨设备同步和 AI 问答。OCR 可能存在漏字或误字，关键参数和安全说明以原图为准。修改归档名称会改变书柜和导出文件名；已生成 PDF 的内部标题元数据保持生成时的名称。

拍照使用系统相机，模拟器适合验证导入及阅读，实际相机清晰度、权限与设备中断恢复还需在手机上验收。测试 APK 使用调试签名，不是商店发行包。

## 实现

`lib/services/library_repository.dart` 负责事务和持久化；`image_service.dart` 在 isolate 中校正 EXIF、限制长边为 2600 像素并转 JPEG；`ocr_service.dart` 调用统一平台接口，返回归一化行框；`searchable_pdf.dart` 在 isolate 中构建 PDF，用渲染模式 3 写入不可见文字，并内嵌子集化中文字体。

字体为 Noto Sans SC，许可见 `assets/fonts/OFL.txt`。PDF 生成不依赖运行时网络下载字体。

## 本次验证记录（2026-10-01）

- Dart 静态分析通过，3 项存储/界面测试通过。
- Android ARM64 调试包构建并在 Android 14 模拟器安装成功。
- 实际操作验证：相册导入两页中英文图片 → 原生中文 OCR → 生成 PDF → 重启恢复 → 书柜正文搜索 → 阅读器搜索高亮 → 打开系统 PDF 分享面板。
- 从模拟器提取生成的 PDF，用独立 PDF 引擎确认两页、中文文字层与搜索框范围，并渲染核对原图。
- 三页受控样本另外覆盖横版、竖版、无识别文字页面和原始 JPEG 保真。
- iOS 模拟器构建通过；尚未进行 iPhone 真机运行验收。
- 未验证手机实拍、复杂反光/弯曲纸张、大批量 100 页压力场景。

测试安装包位于根目录 `output/app/`，操作截图位于 `output/qa/`。

### 文件保存实现

Android 使用 [Storage Access Framework](https://developer.android.com/training/data-storage/shared/documents-files) 的 `ACTION_CREATE_DOCUMENT`，以流复制 PDF；iOS 使用 [UIDocumentPickerViewController](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init(forexporting:ascopy:)) 导出副本。无需申请全盘存储权限。此入口每次由用户选择保存位置；尚未接入特定网盘 API、后台自动上传或固定目标目录的一键同步。

## OTA 更新

Android 启动时静默检查更新，新版通过顶部更新图标红点提示。点击“软件更新”可手动检查、查看更新说明、下载并交给系统确认安装。下载按大小与 SHA-256 校验，安装前校验包名、版本与签名。iOS 页面说明通过 TestFlight/App Store 更新。

默认服务器为 `124.222.88.195`，已发布 Android `0.1.2+3`。版本清单位于 `/manual-collector/android/latest.json`，安装包约 69.1 MiB。发布目录与操作见 [OTA 发布说明](tool/ota/README.md)。
