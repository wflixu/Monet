# 需求分析：打印右键菜单 & 100% 缩放按钮

## 一、需求来源

两个需求均来自社交媒体用户反馈：

1. 右键菜单里缺少"打印"选项
2. 工具栏缺少"100% / 实际大小"按钮（目前有"适配窗口"，但没有一键回到 100% 的按钮）

---

## 二、需求一：右键菜单添加"打印"

### 2.1 现状

当前右键菜单位于 `Sources/Views/ImagePreviewView.swift` 第 39-49 行，仅有 2 项：

| 菜单项 | 功能 |
|--------|------|
| Copy Image Path | 复制图片文件路径到剪贴板 |
| Copy Image | 复制 NSImage 到剪贴板 |

项目目前 **没有任何打印代码**，全文搜索 `NSPrintOperation`、`print:`、`NSPrintInfo` 结果为零。

### 2.2 必要性分析

**需要添加，理由如下：**

- **用户期望**：macOS 系统自带的 Preview.app 右键菜单有 "Print" 选项，这是图片查看器的基本功能。用户看到 iMonet 的右键菜单里缺少"打印"会觉得不完整。
- **使用场景明确**：用户浏览图片时，想打印某张照片/设计稿到实体打印机或生成 PDF，这是自然的工作流。
- **实现成本极低**：macOS 提供了 `NSPrintOperation` API，调用系统原生打印面板，只需要约 10 行代码。
- **无副作用**：打印功能是被动触发的（用户主动点击），不影响现有的浏览体验。不打印就不产生任何开销。

### 2.3 可行性分析

**完全可行，方案如下：**

使用 AppKit 的 `NSPrintOperation` + `NSImageView`：

```
NSImageView(image) → NSPrintOperation(view:) → .run()
```

- `NSPrintOperation(view:)` 是 macOS 10.0+ 就存在的 API，在 macOS 14+ 上可用
- `.run()` 方法自动找到 key window 并弹出打印面板（sheet 形式），**不需手动获取窗口引用**
- `NSImageView.imageScaling = .scaleProportionallyUpOrDown` 可将图片等比缩放填满打印区域
- 默认使用 `NSPrintInfo.shared` 提供标准纸张、边距设置，无需额外配置
- 该方法是同步的（内部运行 nested run loop），从 SwiftUI context menu 回调中调用完全安全
- 用户点击"打印"则提交打印任务，点"取消"则关闭面板 — 两种结果都通过 `NSPrintOperation.run()` 的返回值区分
- **不需要任何新依赖或 import**，`AppKit` 已经是当前文件的已有 import

**结论：可添加，实现简单，无风险。**

---

## 三、需求二：工具栏添加"100%"按钮

### 3.1 现状

当前工具栏位于 `Sources/Views/ToolbarView.swift`，包含 12 个按钮/标签。与缩放相关的控制：

| 按钮 | 功能 | SF Symbol | 代码行 |
|------|------|-----------|--------|
| `-` | 缩小 (×0.8) | `minus.circle` | 40-47 |
| `百分比文本` | 显示当前缩放比例 (如 "150%") | — | 49-51 |
| `+` | 放大 (×1.25) | `plus.circle` | 53-60 |
| `适应窗口` | fitToWindow() | `rectangle.center.inset.filled` | 82-89 |

**没有"100% / 实际大小"按钮。**

缩放逻辑位于 `Sources/Views/ZoomableImageView.swift` 的 `iMonetImageView`（NSView 子类）：

- `magnification: CGFloat` — 当前缩放比例，范围 [0.1, 16.0]（即 10% ~ 1600%）
- `fitToWindow()` (第 224 行) — 计算 `min(视图宽/图片宽, 视图高/图片高)` 使图片完整可见
- `zoomIn()` / `zoomOut()` (第 275-281 行) — 以 ×1.25 / ×0.8 因子缩放
- `offset: CGPoint` — 平移偏移量

工具栏按钮通过 `ContentView.handleToolbarTap(_:)` (第 135-167 行) 分发到 `iMonetImageView` 上的对应方法调用。

**痛点**：当用户放大图片查看细节后，想回到 100%（1:1 像素），需要反复按 + / - 按钮碰运气凑到 100%，体验很差。"适应窗口"也不等于 100% — 对于大图，"适应窗口"会缩得很小。

### 3.2 必要性分析

**需要添加，理由如下：**

- **图片查看器的标准功能**：Photoshop (`Cmd+1`)、Preview.app (`View > Actual Size`)、Figma、浏览器开发者工具等几乎所有图片/设计工具都有"实际大小 (100%/1:1)"的概念。这是用户的肌肉记忆。
- **"适配窗口" ≠ 100%**：对于高分辨率图片（如 4000×3000 照片），"适配窗口"可能只显示 20%-30% 的比例。用户需要 100% 来看真实的像素级细节。
- **已有的 zoom in/out 不够精准**：反复按 +/- 很难恰好到达 100%，每次步进 25% 需要多次点击。
- **实现成本极低**：只需新增一个方法 `actualSize()` 设置 `magnification = 1.0`，加一个按钮即可。

### 3.3 可行性分析

**完全可行，方案如下：**

1. **`iMonetImageView` 添加 `actualSize()` 方法**：
   ```swift
   func actualSize() {
       magnification = 1.0
       offset = .zero
       needsDisplay = true
       onStateChanged?(magnification)
   }
   ```
   与已有的 `fitToWindow()` 模式完全一致，只是把计算得出的 fitMag 替换为硬编码的 `1.0`。

2. **工具栏添加按钮**：遵循现有 12 个按钮的代码模式（`PlainButtonStyle`、SF Symbol `.system(size: 20)`、`.help()` tooltip），图标选 `"1.circle"` 与其他圆形图标一致。

3. **按钮位置**：放在缩放区域（+ 按钮之后、导航按钮之前），逻辑分组为：
   `[-] [100%] [+] [1:1] | [<] [1/10] [>] | [fit]`

4. **状态同步**：`actualSize()` 调用 `onStateChanged?(1.0)`，会通过已有的回调链 `→ ZoomableImageView.onScaleChanged → ImagePreviewView.scale → ContentView.scale → ToolBarView` 自动更新工具栏显示的百分比文本为 "100%"。

5. **边界条件**：
   - 图片比屏幕大：100% 后超出可视区域的部分可以正常拖拽平移（pan 逻辑不受 magnification 值影响）
   - 旋转后再按 100%：offset 重置为 .zero，图片以实际大小居中显示
   - 无图片时：按钮仍然可见但不响应（通过 `monetImageView?` 可选链安全调用）

**结论：可添加，实现简单，3 个文件各改几行代码，无风险。**

---

## 四、总结

| 需求 | 必要性 | 可行性 | 改动量 | 风险 |
|------|--------|--------|--------|------|
| 右键菜单"打印" | ✅ 图片查看器基本功能 | ✅ NSPrintOperation API | 1 个文件，~15 行 | 无 |
| 工具栏"100%"按钮 | ✅ 补充缩放体系的缺失环节 | ✅ magnification = 1.0 | 3 个文件，~20 行 | 无 |

两个需求都建议添加。实现方案在上面已描述清楚，等你确认后开始写代码。

---

## 五、涉及文件清单

| 文件 | 改动内容 |
|------|---------|
| `Sources/Views/ImagePreviewView.swift` | 右键菜单添加 "Print" 按钮 + `printImage(_:)` 方法 |
| `Sources/Views/ZoomableImageView.swift` | `iMonetImageView` 添加 `actualSize()` 方法 |
| `Sources/Views/ToolbarView.swift` | `ToolbarActionIdentifier` 枚举添加 `actualSize` + 工具栏添加按钮 |
| `Sources/Views/ContentView.swift` | `handleToolbarTap` 添加 `.actualSize` 分支 |
