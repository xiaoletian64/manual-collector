# 说明书收集器 (Manual Collector) — 设计与方案文档 v1.0

> 设计基线：Google Material Design 3 (Material You, M3) + Android 12+ Dynamic Color
> 输出日期：2026-04-28
> 范围：交互设计规范 + 完整技术方案
> **架构边界：OCR 全本地 (隐私优先) + 向量检索本地 + AI 问答走云端 LLM API**

---

## 📐 Part 1: 基于 Material Design 3 的交互设计规范

Material Design 3 核心四原则在说明书 App 的落地：

| M3 原则 | 应用方式 |
|---|---|
| **Material You / Dynamic Color** | 随用户壁纸提取主色 (Android 12+），在 iOS 上用一个柔和的"纸感色系"作 fallback |
| **Adaptive Layout** | 手机/平板/折叠屏自适应，说明书较大屏幕使用 Master-Detail 双栏 |
| **Expressive Motion** | 关键转场使用 Emphasized easing，拍照 → 识别通过有"赞"的反弹动效 |
| **Accessible by Default** | 大触摸目标 (48dp+)、强对比、TalkBack/VoiceOver 全支持 |

### 1.1 颜色系统 (M3 Color Roles)

**Light 主题（默认）：**
```
Primary     : #6750A4 (紫，主操作)
OnPrimary   : #FFFFFF
PrimaryContainer : #EADDFF  (浅紫容器，卡片背景)
OnPrimaryContainer: #21005D
Secondary   : #625B71
SecondaryContainer : #E8DEF8
Surface     : #FEF7FF  (整体背景，纸感)
SurfaceVariant : #E7E0EC
Outline     : #79747E
OutlineVariant : #CAC4D0
Error       : #B3261E
Background  : #FEF7FF
```

**Dark 主题：**
```
Primary     : #D0BCFF
OnPrimary   : #381E72
Surface     : #141218
SurfaceVariant : #49454F
Outline     : #938F99
Background  : #141218
```

**动态色**（Android 12+）:
- `@android:color/system_accent1_500` 作为 Primary
- iOS 通过 fallback 静态色保持品牌一致性

### 1.2 形状系统 (Shape)

| 形状类别 | 圆角 (dp) | 用途 |
|---|---|---|
| Shape.Small | 8 | Chip、按钮 |
| Shape.Medium | 12 | 卡片、文本字段 |
| Shape.Large | 16 | 大卡片、底部 Sheet |
| Shape.ExtraLarge | 28 | FAB、底部抽屉 |
| Shape.Full | 50% | Avatar、FAB mini |

### 1.3 字体系统 (Type Scale)

| 角色 | 字号 | 行高 | 字重 |
|---|---|---|---|
| Display Large | 57/64 | 64 | 400 |
| Headline Large | 32/40 | 40 | 400 |
| Headline Medium | 28/36 | 36 | 400 |
| Title Large | 22/28 | 28 | 400 |
| Title Medium | 16/24 | 24 | 500 |
| Body Large | 16/24 | 24 | 400 |
| Body Medium | 14/20 | 20 | 400 |
| Label Large | 14/20 | 20 | 500 |
| Label Small | 11/16 | 16 | 500 |

### 1.4 信息架构 (IA)

底部 4 Tab + 浮动按钮：

```
┌─────────────────────────────────┐
│         TopAppBar               │  ← 搜索 + 用户头像
├─────────────────────────────────┤
│                                 │
│         主内容区                │
│                                 │
├─────────────────────────────────┤
│ [书柜] [扫描] [问答] [我]      │  ← NavigationBar 4 Tab
└─────────────────────────────────┘
       ⓞ FAB (居中凸起)
```

### 1.5 核心 5 屏交互详解

#### Screen 1: 书柜 (Home/Library/书柜)

- **顶部:** SearchBar（M3 搜索栏，含搜索 + 语音输入图标）
- **筛选 Chip 行:** [全部] [厨电] [数码] [家具] [汽车] [其他]
- **主体:** LazyVGrid 2 列卡片
  - 每张卡片包含：
    - 封面（拍照首图缩略，48dp 圆角）
    - 产品名称 (Title Medium)
    - 型号 (Body Small, color: OnSurfaceVariant)
    - 完整性进度环 (12dp round)
    - 长按 = 上下文菜单 [编辑/同步/删除/导出 PDF]
- **FAB (右下角):** extended FAB "扫描新说明书"
- **下拉刷新:** 同步网盘状态
- **空状态:** 插画 + "拍下第一张说明书，开启 AI 助手" + 主按钮"开始扫描"

#### Screen 2: 扫描 (Scan)

进入相机预览，3 种模式（顶端 SegmentedButton 切换）：

1. **拍照模式** — 单页拍
2. **连拍模式** — 自动翻页检测，每页一拍
3. **文档模式** — 一次摄入多页（按住+移动扫描头）

**实时反馈：**
- 检测到文档吗？→ 边框蓝色高亮 + 自动对焦
- OCR 识别成功？→ 边框绿色 + 顶部 Toast "已识别 N 字"
- 暗光？→ 提示 "请增加光线" + 自动开手电
- 模糊？→ 边框黄色 → 按住屏幕锁定对焦 + 引导

**底部操作区 (紧凑的 BottomBar):**
- [翻页箭头 + 当前页/总页]  [ thumbnails 缩略图列表 ]  [完成]

#### Screen 3: 评估 → 完整性卡片

拍照完成跳到评估卡片（Modal Bottom Sheet 升级为全屏 Card）：

```
┌──────────────────────────────┐
│  说明书电子版的完整性评分   │
│        ████████░░ 80%       │
│  ✅ 已识别：标题、型号、规格  │
│  ⚠️  疑似遗漏：安全须知章节  │
│ + 拍 [安全须知]这一页       │  ← Secondary Button
│ ✓ 这样就够了 → 保存到书柜   │  ← Primary Button
└──────────────────────────────┘
```

**评估的 5 个维度（系统内部评分）：**
1. **像素级:** 清晰度/对比度/倾斜角（OpenCV Laplacian + skew angle）
2. **文字级:** 块数/平均置信度/字数
3. **结构级:** 是否含目录、章节标题层级、表格
4. **关键内容:** "安全须知"、"规格参数"、"故障排除"、"保修条款"4 个关键词检出率
5. **页数完整性:** 是否含首页/末页、目录页数是否对齐

#### Screen 4: AI 问答 (Ask)

- 顶部：选中的产品（Chip + 切换按钮）
- 主体：消息流（用户右侧气泡、AI 左侧带"原文引用"卡片）
- AI 回答中含：
  - 文本回答（LLM 生成）
  - **原文引用卡**（小卡片：第 X 页，原文段落 + 跳转按钮）
  - "没在说明书中找到" 兜底
- 底部：TextField + 语音问 + 快捷问题 ListHeader（如 "怎么开机"、"滤网多久换")

#### Screen 5: 我 (Profile)

- 用户头像 / 登录 / 同步状态
- 网盘授权卡片（百度网盘/OneDrive/WebDAV，各自一个 ListItem）
- 订阅状态（Pro 卡片，购买/管理）
- 设置：暗黑模式、归属分类、AI 模型选择、清缓存
- 反馈、隐私政策、版本号

### 1.6 关键动效

| 触发 | 类型 | 用途 |
|---|---|---|
| FAB → 扫描页 | Container Transform | 圆形 FAB 扩展为全屏相机 |
| 卡片 → 详情 | Shared Element | 卡片缩略图 → 大图渐变 |
| 评分进度环 | Tween + Rebound | 80% 弹簧回弹动效 |
| 同步网盘 | Linear 进度环 | 圆形进度环 |
| AI 思考 | 3 个点的呼吸动效 | 加载指示 |

### 1.7 关键交互流程图（用户旅程）

```
启动 → 权限申请 → [书柜空]
    ↓ FAB
[扫描模式] → 拍照预览 → 拍 N 页
    ↓ 完成
[本地 OCR → 评估完整性 80%]
    ↓ 提示"漏 1 页"
[补拍 OR 保存]
    ↓
[产品分类（自动+可编辑）] → [保存到书柜]
    ↓
[同步到百度网盘 OAuth] → [完成]
```

---

## 🛠 Part 2: 端侧技术方案 — 全力本地化

### 2.1 核心原则

| 维度 | 策略 | 方案 |
|---|---|---|
| OCR | **100% 本地，绝不上传图片** | iOS Vision Framework + Android ML Kit Text V2 |
| 向量 Embedding | **本地 ONNX Runtime (bge-small-zh)，离线可用** | ONNX Runtime Mobile |
| 向量检索 | **本地 sqlite-vec，不依赖网络** | sqlite-vec |
| 完整性评估 | **本地规则引擎** | 5维评分 (像素/文字/章节/结构/页数) |
| LLM 问答 (生成式) | **云端 API** (DeepSeek / GLM-4 / Qwen 可选) | OpenAI 兼容协议，用户配置 API key |
| 网盘同步 | 必须联网 | OAuth 授权后云端传输 |
| 用户登录 | 必须联网 | 苹果 Sign in / Google 一键登录 + 自有账号 |

### 2.2 端侧 OCR 方案对比与选型

| 方案 | 平台 | 大小 | 中文准率 | 离线 | 是否仍维护 | 选定 |
|---|---|---|---|---|---|---|
| Apple Vision Framework | iOS | 0（系统库） | 95-97% | ✅ | ✅ Apple 持续维护 | ✅ iOS 主用 |
| Google ML Kit Text Recognition v2 | Android | ~10MB | 96% | ✅ (打包模型) | ✅ | ✅ Android 主用 |
| Tesseract 5 + chi_sim | 跨平台 | ~50MB | 88-93% | ✅ | ✅ | ❌ 准确率不足 |
| PaddleOCR Lite | 跨平台 | ~20MB | 96-98% | ✅ | ✅ | ⚠️ 可作为 Pro 选项 |
| ncnn + MMOCR models | 跨平台 | ~30MB | 96%+ | ✅ | ✅ | ⚠️ 备选 |

→ **MVP 推荐：iOS Vision + Android ML Kit 双栈，纯系统内置能力，零依赖、零包大小、零隐私上传。**

→ **Pro 用户：可选下载 PaddleOCR Lite 模型提升中文表格/特殊字符准确率。**

### 2.3 端侧预处理流水线

```
原图 (CMSampleBuffer)
   ↓
[1] 边缘检测 (Vision VNDetectBarcodesRequestRevision 或 OpenCV findContours)
   ↓
[2] 四点透视矫正 (getPerspectiveTransform + warpPerspective)
   ↓
[3] 阴影去除 (CLAHE / Local Adaptive Histogram)
   ↓
[4] 增强对比度 + 二值化（自适应阈值，OpenCV adaptiveThreshold）
   ↓
[5] 倾斜矫正 (Hough Transform 找文本行角度 → 旋转)
   ↓
[6] 降噪 + 锐化 (Bilateral filter + Unsharp Mask)
   ↓
增强图 (UIImage/Bitmap)
   ↓
[OCR Engine]
   ↓
[文本块 + 置信度 + 位置 BBox]
   ↓
[结构化输出: 章节标题 / 表格 / 段落]
```

### 2.4 完整性评估算法（端侧 Rule-based）

```kotlin
data class CompletenessInput(
    val ocrPages: List<OcrPage>,         // 每页文本+置信度
    val imageSize: List<Size>,            // 每页图片尺寸
    val imageQualityScores: List<Float>,  // 清晰度评分
)

data class CompletenessReport(
    val overallScore: Int,        // 0-100
    val detectedSections: List<Section>,   // 检测到的章节
    val missingSections: List<String>,    // 疑似缺失章节
    val lowConfidenceWords: Int,           // 低置信度字数
    val recommendation: String,           // 文字建议
)

fun evaluate(input: CompletenessInput): CompletenessReport {
    val scores = mutableListOf<Float>()

    // 维度1: 像素 (20%)
    val pixelScore = input.imageQualityScores.average().coerceIn(0f, 100f)
    scores += pixelScore * 0.2f

    // 维度2: 文字置信度 (20%)
    val avgConf = input.ocrPages.flatMap { it.words }.map { it.confidence }.average()
    scores += (avgConf * 100) * 0.2f

    // 维度3: 章节覆盖 (40%) — 4 个关键章节词
    val allText = input.ocrPages.joinToString(" ") { it.text }
    val keySections = listOf("安全须知", "规格参数", "使用方法", "故障排除", "保修条款")
    val hits = keySections.count { allText.contains(it) }
    scores += (hits.toFloat() / keySections.size * 100) * 0.4f

    // 维度4: 结构完整性 (10%) — 检测标题层级、目录存在
    val hasTOC = allText.contains("目录") || allText.contains("contents")
    val hasNumberedHeaders = Regex("""^\s*(\d+\.\d*\s+|第[一二三四五六七八九十]+章\s+)""", RegexOption.MULTILINE)
        .containsMatchIn(allText)
    val structScore = (if (hasTOC) 50 else 0) + (if (hasNumberedHeaders) 50 else 0)
    scores += structScore * 0.1f

    // 维度5: 页数合理性 (10%) — 推断总页数与图片数吻合否
    val tocMatch = Regex("""共\s*(\d+)\s*页""").find(allText)
    val declaredPages = tocMatch?.groupValues?.get(1)?.toIntOrNull() ?: 0
    val actualPages = input.ocrPages.size
    val pageScore = if (declaredPages == 0) 50f
                    else (actualPages.toFloat() / declaredPages).coerceIn(0f, 1f) * 100
    scores += pageScore * 0.1f

    val overall = scores.sum().toInt()

    // 缺失章节建议
    val missing = keySections.filterNot { allText.contains(it) }

    return CompletenessReport(
        overallScore = overall,
        detectedSections = ...,
        missingSections = missing,
        lowConfidenceWords = input.ocrPages.flatMap { it.words }.count { it.confidence < 0.7 },
        recommendation = buildRecommendation(overall, missing)
    )
}
```

### 2.5 端侧 AI 问答架构（默认全本地）

**目标：** 用户不依赖云端即可对自己说明书进行问答；只有当用户允许并已联网时，可选调用云端 LLM 增强。

#### 2.5.1 三层架构

```
┌──────────────────────────────────────┐
│  用户提问 (Text / Voice)               │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│  Layer 1: 端侧意图分类 (TinyBERT 100MB) │
│  → 识别"产品/章节关键词 + 问句类型"      │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│  Layer 2: 端侧向量检索 (sqlite-vec)     │
│  → 在该用户的说明书块数据库 Top-K         │
└────────────┬─────────────────────────┘
             ↓
┌──────────────────────────────────────┐
│  Layer 3A: 端侧 LLM 推理 (Qwen2.5-1.5B │
│  Q4 量化, ~900MB)                       │
│  → 输入: 检索片段 + 提问 → 输出: 回答     │
└────────────┬─────────────────────────┘
             ↓
[回答 + 原文引用页码]
```

**Layer 3A 失败 / 用户可选 Layer 3B：**
```
┌──────────────────────────────────────┐
│  Layer 3B: 云端 LLM 增强 (可选)         │
│  → 用户提供 API Key 时调用 DeepSeek V3  │
│  → 不上传原文图片，仅上传 OCR 切片文本    │
└──────────────────────────────────────┘
```

#### 2.5.2 端侧模型与库选型

| 层级 | iOS | Android | 大小 |
|---|---|---|---|
| 意图分类 | CoreML + BERT-mini (40MB) | TensorFlow Lite + MobileBERT (80MB) | 持续 |
| 向量检索 | sqlite-vec (Swift Package) | sqlite-vec (AAR) | 1MB |
| Embedding | bge-small-zh-v1.5 ONNX (95MB) | bge-small-zh-v1.5 tflite (95MB) | 一次性下载 |
| 生成式 LLM | MLC-LLM + Qwen2.5-1.5B Q4 (~900MB) | MLC-LLM / llama.cpp Android (~900MB) | 一次性下载，用户首次问问答时下载 |
| 备选 LLM | Apple On-Device Foundation Models (iOS 18+, 3B) | Google Gemini Nano (Pixel 8+/Android 14 AICore) | 系统提供 |
| 语音问 | Apple Speech Framework on-device | Android SpeechRecognizer on-device | 系统提供 |

> **注：iOS 18+ 可使用 Apple Foundation Models 内置 3B 模型，免打包 900MB 模型权重，节省 90% 体积。Android 14+ Pixel 设备可优先选择 Gemini Nano（系统服务），其他设备 fallback 到 MLC-LLM。**

#### 2.5.3 端侧 RAG 流程

```
[说明书入库时] 一次预处理（在主线程异步）:
  For each OCR page:
    1. 切块 (按段落 / 表格行 / 标题块)
    2. embedding: bge-small-zh → 512 维向量
    3. 入 sqlite-vec 数据库（产品类别, 产品ID, 页码, 块内容, 向量）

[用户提问时] 实时:
  Step 1: 提问 → bge-small-zh → 512 维查询向量
  Step 2: sqlite-vec 限制产品ID + 限制类别 = Top-5 检索
  Step 3: 构造 prompt:
         模板：
         "你是一个说明书助手。仅基于以下说明书内容回答。
           如果信息不在原文中，回答 '未在说明书中找到'。
          ===
          [基于产品 X 的相关段落, 页码 Y]
          {chunk1}
          {chunk2}
          {chunk3}
          ===
          问: {user_question}
          答: "
  Step 4: MLC-LLM 生成 (max_tokens=300)
  Step 5: 后处理 — 提取"页码 Y"作为引用卡
```

#### 2.5.4 端侧能力 vs 云端能力对比

| 任务 | 端侧能否完成 | 备注 |
|---|---|---|
| 中文 OCR | ✅ | ML Kit 中文 96% |
| 完整性评估 | ✅ | 纯规则 |
| 向量检索 | ✅ | sqlite-vec 512d OK |
| 中文 Embedding | ✅ | bge-small-zh ONNX |
| "怎么开机" 简单问答 | ✅ | 1.5B 模型够用 |
| "面临 f1 故障代码 E7 怎么解决"复杂问答 | ⚠️ | 1.5B 答错率较高，需云端增强 |
| 跨说明书泛化、对比 | ❌ | 必须云端 |

### 2.6 网盘同步（百度网盘集成）

#### 2.6.1 注册流程

1. 注册百度开发者账号 (pan.baidu.com/union/console)
2. 应用实名 — 类型选"个人移动应用"
3. 应用名 "说明书收集器"，平台勾选 iOS+Android
4. 获取 AppKey + SecretKey + AppDir（沙箱目录）
5.iOS 集成 BaiduPCSClientSDK.iOS (Pods)；Android 集成 BaiduPCSClientSDK.Android (Gradle)
6.实现 OAuth 授权码模式跳转 → ASWebAuthenticationSession (iOS) / CustomTabs (Android)
7.调用上传接口 (分片上传 + precreate + superfile2 完整流程)
8.配置回调地址 → Apple/Google 商店审核备注中清晰说明"百度授权通过系统浏览器而非内嵌 WKWebView"

#### 2.6.2 网盘文件结构

```
/apps/手册收集器/  (网盘沙箱根)
   ├── _manifest.json  (元数据)
   ├── products/
   │   ├── {productId}_海尔冰箱_ERS-305Wbn/
   │   │   ├── meta.json  (累积评分、产品类别、模型)
   │   │   ├── pages/  (按页保存的原图)
   │   │   │   ├── 1.jpg
   │   │   │   └── 2.jpg
   │   │   ├── ocr/   (OCR 文本块)
   │   │   │   ├── 1.json
   │   │   │   └── 2.json
   │   │   └── manual.pdf  (合成的电子版)
   │   └── ...
   └── _app_state.json
```

#### 2.6.3 多网盘抽象层

```kotlin
interface CloudProvider {
    val id: String               // "baidu" / "onedrive" / "webdav"
    val displayName: String
    val icon: ImageVector
    fun authenticate(context: Context): OAuthResult
    fun upload(localUri: Uri, remotePath: String): UploadResult
    fun download(remotePath: String): Uri?
    fun list(remotePath: String): List<RemoteFile>
    fun delete(remotePath: String): Boolean
}

class BaiduCloudProvider : CloudProvider { ... }
class OneDriveCloudProvider : CloudProvider { ... }    // Microsoft Graph API
class WebDAVCloudProvider : CloudProvider { ... }      // 坚果云 / Nextcloud
```

---

## ⚙️ Part 3: 项目骨架与实施路径

### 3.1 推荐技术栈

```
┌─────────────────────────────────────────────┐
│  跨端方案：KMP (Kotlin Multiplatform)         │
│  - commonMain: 业务逻辑/数据层/RAG/向量层     │
│  - iosMain: Vision/CoreML/MLC-LLM/SwiftUI     │
│  - androidMain: MLKit/TFLite/Compose          │
└─────────────────────────────────────────────┘

或：

┌─────────────────────────────────────────────┐
│  分端方案：各自原生                            │
│  iOS: Swift + SwiftUI + Vision + CoreML      │
│  Android: Kotlin + Compose Material 3 + ML Kit│
└─────────────────────────────────────────────┘

→ MVP 选择"分端方案"：
   1.团队招人阈值低
   2.系统库 (Vision / ML Kit) 接入更自然
   3.包尺寸更小 (不要 KMP 互操作桥 30-50MB 开销)
```

### 3.2 项目目录结构

```
说明书app/
├── Manual_Collector_评估报告.md         (已有)
├── DESIGN.md                            (本文档)
├── .stitch/designs/                    (设计稿 HTML 缩略图)
├── android/                             (待)
│   ├── app/
│   │   ├── src/main/java/com/manualcollector/
│   │   │   ├── ui/             (Compose 屏幕: Library/Scan/Ask/Profile)
│   │   │   ├── data/            (Room/Repository/向量库)
│   │   │   ├── ocr/             (ML Kit 封装)
│   │   │   ├── nlp/             (Embedding + LLM)
│   │   │   ├── cloud/            (Baidu/OneDrive/WebDAV)
│   │   │   └── util/
│   │   └── build.gradle.kts
│   └── ...
├── ios/                                 (待)
│   ├── ManualCollector.xcodeproj
│   ├── ManualCollector/
│   │   ├── Library/             (SwiftUI 书柜)
│   │   ├── Scan/                (Vision OCR)
│   │   ├── Ask/                 (LLM 问答)
│   │   ├── Profile/
│   │   ├── Core/
│   │   │   ├── OCRService.swift
│   │   │   ├── CompletenessEvaluator.swift
│   │   │   ├── RAGService.swift
│   │   │   ├── CloudProvider.swift
│   │   │   └── EmbeddingService.swift
│   │   └── MLModels/  (CoreML 模型)
│   └── Podfile
├── shared/                             (待，可选 KMP 共用模型/算法)
└── docs/
    └── architecture.svg
```

### 3.3 4-Week 验证路线图

| Week | 关键产出 | 验收 |
|---|---|---|
| W1 | 项目建立、CI/CD、Material 3 Theme 配置、底部 4 Tab 框架 | 跑通空书柜 + 4 Tab 切换 |
| W2 | iOS 端 OCR 调通、Android 端 OCR 调通、评估算法 v1 | 拍 1 页 → 显示 OCR 文本 + 评分 0-100 |
| W3 | 端侧 embedding (bge-small) + sqlite-vec 接入 + RAG demo | 拍 1 本说明书 → 提问 → 拿到引用回答 |
| W3 | MLC-LLM Qwen2.5-1.5B 接入 (iOS+Android) | 离线回答 |
| W4 | 百度网盘 OAuth + 上传 demo | 拍完 → 同步到网盘沙箱目录 |

### 3.4 关键决策清单（需用户确认）

1. **是否先用 KMP 还是分端原生？** 推荐：分端原生（理由见 3.1）。
2. **是否首发只 iOS？** 推荐：iOS 先行 1 个月，方便下年 App Store 上架时优先敲定设计；Android 同步开发但稍后上架。
3. **LLM 的大小选型？** 推荐：Qwen2.5-1.5B Q4 (~900MB)。手机只容纳 1.5B 量级。Pro 用户可选云端 RAG。
4. **M3 动态色是否启用？** 推荐：Android 12+ 启用 Dynamic Color，iOS 用静态浅紫。
5. **百度网盘是否独家？** 推荐：先接百度独家，3 个月后接 WebDAV/OneDrive。
6. **是否提供云 OCR 升级？** 推荐：MVP 不提供，避免隐私合规风险。

---

## ✅ 交付清单

| 文件 | 状态 |
|---|---|
| Manual_Collector_评估报告.md | ✅ 已生成 (前次) |
| DESIGN.md (本文档) | ✅ 已生成 |
| Material 3 主题/颜色/形状/字体 | ✅ |
| 5 个核心屏幕交互描述 | ✅ |
| 端侧 OCR 方案选型 + 评估算法 | ✅ |
| 端侧 RAG + LLM 架构 | ✅ |
| 百度网盘接入流程 + 文件结构 | ✅ |
| 4 周验证路线图 | ✅ |
| 项目骨架结构 | ✅ |

## 后续可继续推进

- 撰写 PRD v1.0 详细文档
- 撰写技术架构图 (mermaid)
- 选定 React Native/Flutter vs 原生（已推荐原生）
- iOS 工程脚手架搭建 (Xcode project)
- Android 工程脚手架搭建 (Compose Material 3 Theme)
- 启动 GitHub Actions CI 配置

