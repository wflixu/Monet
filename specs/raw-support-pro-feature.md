# RAW 格式支持 + 内购策略升级

## Context

为 iMonet 添加 RAW 相机格式支持。采用 **freemium（功能可用但弹窗提醒）** 策略：

- RAW 图片**始终可正常浏览**，不做硬性门控
- 每次打开 RAW 图片，显示完整后几秒弹出购买提示
- RAW 提示**每次都弹**，不受 UsageTracker 频率限制（非 RAW 图片不受影响）
- 购买后 RAW 提示不再出现
- 核心体验：摄影师能看 RAW，但提示足够频繁促使其购买

## 涉及修改的文件

| 文件 | 修改内容 |
|---|---|
| `Sources/Shared/Constants.swift` | 新增 RAW 扩展名列表和判断方法 |
| `Sources/iMonetApp.swift` | `indexFolder` 目录扫描包含 RAW |
| `Sources/Views/ImagePreviewView.swift` | RAW 解码 + 加载完成后延时触发购买提示 |
| `Sources/Views/ImageThumbnailView.swift` | RAW 缩略图用 `CGImageSourceCreateThumbnailAtIndex` |
| `Sources/ContentView.swift` | RAW 旋转路由 + RAW 升级通知处理 |
| `Sources/Store/PurchasePromptView.swift` | 购买提示文案升级 |
| `Sources/Store/StoreManager.swift` | 产品名/描述更新 |
| `Sources/Store/UsageTracker.swift` | 新增 `.showRawUpgrade` 通知名 |

## 修改详情

### 1. Constants.swift — RAW 扩展名

```swift
static let rawImageExtensions = [
    "cr2", "cr3", "crw", "nef", "nrw", "arw", "sr2",
    "dng", "raf", "orf", "rw2", "pef", "srw",
    "3fr", "fff", "rwl", "raw"
]

static let allImageExtensions = supportedImageExtensions + rawImageExtensions

static func isRawExtension(_ ext: String) -> Bool {
    rawImageExtensions.contains(ext.lowercased())
}
```

### 2. iMonetApp.swift — 目录扫描包含 RAW

`indexFolder` 过滤条件改为 `Constants.allImageExtensions`，RAW 文件出现在列表中。

### 3. ImagePreviewView.swift — RAW 解码 + 延时提示

**`refreshImage()` 逻辑：**

```
1. 停止旧动画、复位视图状态 (不变)
2. 判断是否 RAW:
   - 是 RAW → 用 CGImageSource 异步解码全分辨率 →
     转为 NSImage(cgImage:size:) 赋给 currentImage
   - 否 → 现有 NSImage(contentsOf:) + 动画检测 (不变)
3. RAW 加载完成后，如果 !storeManager.isPurchased:
   延时 5 秒后 post Notification.Name("showRawUpgrade")
```

**RAW 异步解码（避免阻塞主线程）：**

```swift
// 在 refreshImage() 中，如果 isRaw:
currentImage = nil
Task {
    let cgImage = await decodeRAW(at: url)  // 后台解码
    if let cg = cgImage {
        await MainActor.run {
            self.currentImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            // 解码完成后，未购买则延时弹窗
            if !storeManager.isPurchased {
                try? await Task.sleep(for: .seconds(5))
                NotificationCenter.default.post(name: .showRawUpgrade, object: nil)
            }
        }
    }
}

nonisolated func decodeRAW(at url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil)
    else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceShouldAllowFloat: true,
        kCGImageSourceShouldCacheImmediately: false
    ]
    return CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
}
```

**关键设计点：**
- `nonisolated func` 在后台线程解码，不阻塞 UI
- `kCGImageSourceShouldAllowFloat: true` 保留完整动态范围
- `kCGImageSourceShouldCacheImmediately: false` 避免内存膨胀
- RAW 解码结果通过 `NSImage(cgImage:size:)` 桥接，无需改动 `iMonetImageView`
- 延时 5 秒给用户充足时间浏览，再弹提示

### 4. ImageThumbnailView.swift — RAW 缩略图

RAW 缩略图用 `CGImageSourceCreateThumbnailAtIndex` 提取嵌入式 JPEG 预览（快、轻量、120px 足矣）：

```swift
// 对于 RAW 文件：
let options: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: false,  // 优先用嵌入式缩略图
    kCGImageSourceThumbnailMaxPixelSize: 360              // 3x 显示尺寸
]
```

- 嵌入式 JPEG 预览几乎瞬间提取（<10ms）
- 非 RAW 缩略图保持原有 `NSImage(contentsOf:)` 逻辑不变

### 5. ContentView.swift

**旋转：** RAW 走 display-only 旋转（不改写文件）：

```swift
if animatedExtensions.contains(ext) || Constants.isRawExtension(ext) {
    // display-only rotation
}
```

**通知处理：** 新增 `.showRawUpgrade` 监听，直接触发购买弹窗，绕过 UsageTracker：

```swift
.onReceive(NotificationCenter.default.publisher(for: .showRawUpgrade)) { _ in
    if !storeManager.isPurchased {
        withAnimation { showPurchasePrompt = true }
    }
}
```

**额外防范：** `checkPurchasePrompt()` 中 RAW 提示不被重复触发 — 如果 `showPurchasePrompt` 已经是 true 且来源是 RAW，不再检查 UsageTracker。

### 6. PurchasePromptView.swift — 文案升级

```
"iMonet Pro"
"浏览 RAW 专业相机格式，获得完整体验："
  ✓ 支持 Canon / Nikon / Sony / Fujifilm 等主流相机 RAW 格式
  ✓ 不再显示专业功能提示
  ✓ 后续专业功能免费更新
  ✓ 支持独立开发者持续维护 iMonet

[年度支持] 按年获得所有专业功能，自动续期
[永久支持] 一次购买，永久获得所有当前和未来的专业功能
```

所有新文案使用 `String(localized:)`。

### 7. StoreManager.swift — 产品名

- yearly `displayName`: `"年度支持"` — `description`: `"按年获得所有专业功能，自动续期"`
- lifetime `displayName`: `"永久支持"` — `description`: `"一次购买，永久获得所有专业功能"`

### 8. UsageTracker.swift — 新增通知名

```swift
extension Notification.Name {
    static let showRawUpgrade = Notification.Name("showRawUpgrade")
}
```

## 门控策略（修正后）

| 场景 | 未购买 | 已购买 |
|---|---|---|
| 打开 RAW 图片 | ✅ 正常浏览，5 秒后弹提示 | ✅ 正常浏览，无提示 |
| RAW 缩略图 | ✅ 正常显示（嵌入式预览） | ✅ 正常显示 |
| RAW 旋转 | ✅ display-only | ✅ display-only |
| 非 RAW 图片 | ✅ 正常浏览，按 UsageTracker 规则 | ✅ 正常浏览 |
| RAW 弹窗频率 | 每次打开都弹 | 永不弹 |
| 非 RAW 弹窗频率 | 15次+7天规则 | 永不弹 |

## 验证

1. 打开含 RAW 的文件夹 → RAW 文件出现在列表中
2. 未购买状态下点 RAW → 图片正常加载显示
3. RAW 显示 5 秒后 → 购买提示弹出（含新文案）
4. 切换到下一张 RAW → 再次正常显示，5 秒后再次弹提示
5. 切换到非 RAW 图片 → 正常浏览，不弹 RAW 提示
6. 已购买状态下点 RAW → 正常显示，无提示
7. RAW 旋转 → display-only，文件不变
8. RAW 缩略图 → 正常显示嵌入式预览
9. 标准格式（PNG/JPEG/GIF）→ 不受影响
10. `swift build` + `swift test` 通过
11. RAW 异步解码不阻塞 UI（解码期间界面可响应）
