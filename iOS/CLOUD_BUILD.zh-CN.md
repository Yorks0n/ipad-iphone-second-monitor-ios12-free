# 只有一台新版 Mac 时，为 iOS 12 iPad 构建并安装

本仓库的 iOS 客户端最低支持 iOS 12.0。Xcode 27 不能编译这个部署目标；本方案用 GitHub Actions 的 macOS 14 / Xcode 15.4 编译，把签名留在你自己的 Mac 上完成。GitHub 不需要接收证书或私钥。需要已加入 **Apple Developer Program** 的付费开发者团队，才能创建 Ad Hoc 描述文件。

## 1. 在开发者账户准备签名

1. 将 iPad 用 Lightning 线接到 Mac，在 Finder 中找到设备并取得它的 UDID。也可在 Apple Developer 网站的设备注册流程中查看取得 UDID 的说明。
2. 在 [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/) 注册这台 iPad。
3. 为应用注册一个唯一的显式 App ID，例如 `com.yourname.LegacyPadDisplay`。记下这个 Bundle ID；后面的 GitHub 构建输入必须完全相同。
4. 在这台 Mac 的“钥匙串访问”创建证书签名请求（CSR），然后在开发者网站创建 **Apple Distribution** 证书，下载 `.cer` 并双击导入钥匙串。确认它和私钥一起出现在“我的证书”中。已有可用的 Apple Distribution 身份时可直接使用。
5. 在开发者网站创建 **Ad Hoc** 描述文件，选择刚注册的 App ID、Apple Distribution 证书和这台 iPad，下载 `.mobileprovision` 文件。

Apple 说明：[创建 CSR](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request)、[注册设备](https://developer.apple.com/help/account/devices/register-a-single-device)、[创建 Ad Hoc 描述文件](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile)。

## 2. 在 GitHub 编译

1. 把包含 `.github/workflows/build-ios12.yml` 的仓库推送到你自己的 GitHub 仓库。保留仓库的 `iOS/` 目录即可；云端构建不需要 `Mac/` 子模块。
2. 打开该仓库的 **Actions → Build iOS 12 client → Run workflow**，在 `bundle_id` 中填入第 1 步的 Bundle ID。
3. 构建成功后，从此次运行的 **Artifacts** 下载 `LegacyPadDisplay-unsigned`。解压 GitHub 下载包，得到 `LegacyPadDisplay-unsigned.zip`。这个文件里面是未签名的 `.app`，不能直接装到 iPad。

工作流只在手动触发时运行。GitHub 的 `macos-14` 环境目前带有 Xcode 15.4；该环境预计在 2026 年 11 月停止支持，届时须换用仍提供兼容 Xcode 的构建环境。

## 3. 在本机签名 IPA

先列出钥匙串中的签名身份：

```bash
security find-identity -v -p codesigning
```

找到 `Apple Distribution: ... (TEAMID)` 的完整名称，然后从仓库根目录运行：

```bash
bash iOS/sign-adhoc.sh \
  ~/Downloads/LegacyPadDisplay-unsigned.zip \
  ~/Downloads/LegacyPadDisplay-AdHoc.mobileprovision \
  'Apple Distribution: Your Name (TEAMID)' \
  'YOUR_IPAD_UDID' \
  ~/Downloads/LegacyPadDisplay.ipa
```

把示例文件名、签名身份和 UDID 换成自己的值。脚本会检查 iOS 最低版本、Bundle ID 和描述文件中的 iPad UDID，然后签名 App、制作 IPA。私钥始终留在本机钥匙串中。

## 4. 装到 iPad

在这台 Mac 安装并打开 [Apple Configurator](https://apps.apple.com/app/apple-configurator/id1037126344)，连接并信任 iPad，选择设备，使用 **Add → Apps → Choose from my Mac** 选中 `LegacyPadDisplay.ipa`。Apple 的[安装说明](https://support.apple.com/guide/apple-configurator-mac/add-apps-to-a-device-cad4cd08c03/mac)提供了界面步骤。首次打开如果出现不受信任的开发者提示，到 iPad 的“设置 → 通用 → 描述文件与设备管理”中信任开发者。

启动后应显示 `Listening on :9000`。接下来按仓库根目录 README 的说明，在 Mac 上运行 OpenDisplay，并用 Lightning 或同一 Wi-Fi 连接。
