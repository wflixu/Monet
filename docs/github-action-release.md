# github action 自动发macOS app 包





针对您的两个核心问题，以下是详细解答和 GitHub Actions 自动化发包的完整方案。

### 第一部分：签名 (Signing) 与 公证 (Notarization) 的关系

#### 1. 它们是什么？
*   **代码签名 (Code Signing)**：
    *   **作用**：证明“我是谁”。它使用开发者证书（Developer ID Certificate）对应用程序进行数字签名，确认应用未被篡改且来源可信。
    *   **执行者**：开发者（你）。
    *   **工具**：`codesign`。
*   **公证 (Notarization)**：
    *   **作用**：证明“我是安全的”。这是 Apple 提供的一项云服务，你将签好名的 App 上传给 Apple，Apple 的自动化系统会扫描恶意软件、检查代码结构。如果通过，Apple 会给你的 App 盖一个“电子印章”（Ticket）。
    *   **执行者**：Apple 服务器。
    *   **工具**：`xcrun notarytool`。

#### 2. 它们的关系是什么？
**公证必须建立在签名的基础之上。**
这是一个严格的先后顺序依赖关系：
1.  **先签名**：你必须先用有效的 Developer ID 证书对 App 进行签名。
2.  **后公证**：你只能将**已签名**的 App 提交给 Apple 进行公证。Apple 会验证签名的有效性，如果签名无效或证书过期，公证直接失败。
3.  **最终分发**：用户下载时，macOS 的 Gatekeeper 会同时检查：
    *   签名是否有效（来源可信）。
    *   是否有有效的公证 Ticket（内容安全）。

#### 3. 不签名能公证吗？
**绝对不能。**
*   如果你尝试提交未签名的 App 给 `notarytool`，Apple 服务器会立即拒绝，报错信息通常类似于 `"The software is not signed"` 或 `"Invalid signature"`。
*   **逻辑链条**：没有签名 -> Apple 无法确认上传者身份 -> 拒绝接收进行安全扫描 -> 公证失败。

---

### 第二部分：GitHub Actions 自动构建、签名、公证并发包流程

要在 GitHub Actions 中实现全自动流程，你需要准备以下**前置条件**（在 Apple Developer 后台操作）：

1.  **导出证书 (.p12)**：
    *   在 macOS 本地 Keychain 中导出你的 "Developer ID Application" 证书及其私钥为 `.p12` 文件。
    *   设置一个导出密码。
2.  **创建 API Key (用于公证)**：
    *   登录 [App Store Connect](https://appstoreconnect.apple.com)。
    *   进入 "Users and Access" -> "Keys"。
    *   创建一个新的 API Key，权限选择 **"Notary Tool"**。
    *   下载生成的 `.p8` 文件，记下 **Key ID**, **Issuer ID**, 和 **Team ID**。
3.  **准备 Entitlements 文件**：
    *   在仓库中提交一个 `.entitlements` 文件（例如 `MyApp.entitlements`）。

#### GitHub Actions Workflow 配置示例

在项目根目录创建 `.github/workflows/release.yml`。

```yaml
name: Build, Sign, Notarize and Release

on:
  push:
    tags:
      - 'v*' # 仅在推送 v1.0.0 这样的标签时触发

jobs:
  build-and-release:
    runs-on: macos-14 # 使用最新的 macOS Runner
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Select Xcode Version
        run: sudo xcode-select -s /Applications/Xcode_16.0.app/Contents/Developer # 根据 runner 支持的版本调整

      - name: Setup Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: '6.0' # 使用 Swift 6.0

      # 1. 导入签名证书
      - name: Import Code Signing Certificate
        env:
          CERTIFICATE_P12: ${{ secrets.MACOS_CERT_P12 }} # 在 GitHub Secrets 中存储 base64 编码的 .p12 文件
          CERTIFICATE_PASSWORD: ${{ secrets.MACOS_CERT_PASSWORD }}
          KEYCHAIN_PASSWORD: 'action_keychain'
        run: |
          # 创建临时 keychain
          security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security set-keychain-settings -lut 21600 build.keychain
          
          # 导入证书
          echo $CERTIFICATE_P12 | base64 --decode > certificate.p12
          security import certificate.p12 -k build.keychain -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" build.keychain

      # 2. 构建 App
      - name: Build Release
        run: |
          swift build -c release --arch arm64 --arch x86_64 # 构建通用二进制
          # 假设产物名称为 MyApp，实际路径需根据你的 Package.swift 调整
          # SwiftPM 默认产物在 .build/apple/Products/Release 或 .build/release
          APP_PATH=".build/apple/Products/Release/MyApp.app"
          if [ ! -d "$APP_PATH" ]; then
             # 兼容旧版 SwiftPM 路径
             APP_PATH=".build/release/MyApp.app"
          fi
          echo "APP_PATH=$APP_PATH" >> $GITHUB_ENV

      # 3. 代码签名 (Signing)
      - name: Code Sign App
        env:
          TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          # 获取证书名称
          CERT_NAME=$(security find-identity -v -s "Developer ID Application" | head -n 1 | awk -F'"' '{print $2}')
          
          if [ -z "$CERT_NAME" ]; then
            echo "Error: Developer ID Certificate not found"
            exit 1
          fi
          
          echo "Signing with: $CERT_NAME"
          
          # 执行签名 (包含 Entitlements)
          codesign --force --options runtime --entitlements "MyApp.entitlements" --sign "$CERT_NAME" "$APP_PATH"
          
          # 验证签名
          codesign --verify --verbose "$APP_PATH"

      # 4. 打包为 ZIP (公证需要 ZIP 或 DMG)
      - name: Zip App
        run: |
          ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" MyApp.zip

      # 5. 公证 (Notarization)
      - name: Notarize App
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }} # 你的 Apple ID 邮箱
          APPLE_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }} # Apple ID 的应用专用密码
          TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
          KEY_ID: ${{ secrets.NOTARY_KEY_ID }}
          ISSUER_ID: ${{ secrets.NOTARY_ISSUER_ID }}
          PRIVATE_KEY: ${{ secrets.NOTARY_PRIVATE_KEY }} # .p8 文件的内容
        run: |
          # 保存 p8 密钥文件
          echo "$PRIVATE_KEY" > AuthKey_${KEY_ID}.p8
          
          # 提交公证
          xcrun notarytool submit MyApp.zip \
            --key-id "$KEY_ID" \
            --issuer "$ISSUER_ID" \
            --key "AuthKey_${KEY_ID}.p8" \
            --team-id "$TEAM_ID" \
            --wait # 等待结果返回
      
      # 6. 绑定公证票据 (Stapling) - 关键步骤，否则离线用户无法运行
      - name: Staple Notarization Ticket
        run: |
          xcrun stapler staple "$APP_PATH"
          # 验证是否绑定成功
          spctl --assess -vv "$APP_PATH"

      # 7. 创建 Release 并上传
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            MyApp.zip
            # 如果需要也可以上传 .app (已 stapler)
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 关键配置说明 (Secrets)

你需要在 GitHub 仓库的 **Settings -> Secrets and variables -> Actions** 中添加以下 Secrets：

| Secret Name                   | 内容描述                                             |
| :---------------------------- | :----------------------------------------------- |
| `MACOS_CERT_P12`              | 将 `.p12` 证书文件运行 `base64 certificate.p12` 得到的字符串。 |
| `MACOS_CERT_PASSWORD`         | 导出 `.p12` 时设置的密码。                                |
| `APPLE_TEAM_ID`               | 你的 Apple Developer Team ID (10位字符)。              |
| `APPLE_ID`                    | 你的 Apple ID 邮箱账号。                                |
| `APPLE_APP_SPECIFIC_PASSWORD` | 在 appleid.apple.com 生成的**应用专用密码** (不是登录密码)。      |
| `NOTARY_KEY_ID`               | 创建 Notary API Key 时生成的 Key ID。                   |
| `NOTARY_ISSUER_ID`            | 创建 Notary API Key 时显示的 Issuer ID。                |
| `NOTARY_PRIVATE_KEY`          | 下载 `.p8` 文件，用文本编辑器打开，复制全部内容填入。                   |
|                               |                                                  |

### 常见问题与注意事项

1.  **为什么需要 Staple (绑定票据)？**
    *   公证成功后，Apple 服务器上有了记录，但用户的 Mac 本地不知道。
    *   `stapler` 命令会将公证成功的“票据”直接嵌入到 App 文件中。
    *   **如果不执行 Staple**：用户必须在联网状态下才能首次打开 App（因为系统要去 Apple 服务器查询），离线环境下会被拦截。执行后，离线也能完美运行。

2.  **Universal Binary (通用二进制)**
    *   示例中使用了 `--arch arm64 --arch x86_64`。SwiftPM 会自动构建包含两种架构的 App，确保在 Intel 和 M 系列芯片 Mac 上都能运行。

3.  **Hardened Runtime (强化运行时)**
    *   公证要求 App 必须启用 "Hardened Runtime"。
    *   在 `codesign` 命令中，`--options runtime` 参数即启用了此功能。
    *   如果你的 App 需要特殊权限（如访问摄像头、文件系统），必须在 `.entitlements` 文件中明确声明，否则签名虽然成功，但运行时会崩溃或被拦截。

4.  **本地测试**
    *   在推送到 GitHub 之前，务必在本地模拟一遍流程：`swift build` -> `codesign` -> `notarytool submit`。确保证书和 entitlements 配置无误，避免在 CI 中反复调试浪费时间和配额。

通过这套流程，每次你推送一个 `v1.x.x` 的 Tag，GitHub Actions 就会自动完成从编译到生成可分发的、经过 Apple 官方认证的 `.zip` 包的全过程。