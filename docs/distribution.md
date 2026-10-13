# 本地 fork 的构建与配套工具发布

维护仓库：`https://github.com/orut34iop/Capsomnia`。
应用更新功能已删除。CLI & Skill 下载仅访问此 fork 的 Release，允许 GitHub 自身的
Release 资产 CDN 重定向，拒绝上游仓库和其他下载站点，不做上游回退。

## 当前状态

- 应用和特权辅助程序的源码在本仓库，可本地构建、签名和安装。
- `Vendor/CapsomniaControl` 与 `Vendor/MacStateCore` 是随仓库保存的库快照，
  应用构建不会在线拉取它们；其中的原始来源和许可证用于溯源。
- 完整的 cpsm、MacReady CLI 与对应 Skill 尚未迁入本 fork，也没有 Tools Release。
- 当前配套工具构建脚本仍要求本地兄弟目录 `../cpsm`、`../MacReady`，不会自行下载。
  在源码迁入并维护之前，不能据此宣称配套工具已由本 fork 提供。

## 本机应用构建

先运行 `security find-identity -v -p codesigning` 检查有效签名身份。
使用本机唯一有效的 Apple 开发身份；有多个身份时显式设置 `APP_SIGN_ID`。
身份检查或签名失败必须停止，不得以 ad-hoc 签名回退。

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build-app.sh
```

本机验证安装包可用 `SKIP_SIGNING=true ./scripts/build-pkg.sh` 构建。
这里跳过的是外层安装包的发行签名，`build-app.sh` 仍必须为应用和 helper
使用有效 Apple 证书签名；它不代表已公证、可公开发行的包。

## CLI 与 Skill 的后续发布条件

1. 把完整 CLI 和 Skill 源码纳入本 fork 维护，保留原始许可证，并审查其中的下载和更新来源。
2. 调整配套工具构建脚本，使其使用此 fork 的源码而非未管理的兄弟目录。
3. 构建带有 `CapsomniaToolsInstallFormat: 2` 标记的 `Capsomnia-Tools.pkg`。
4. 使用 fork 维护者团队 `B829A49G4D` 的 Developer ID Installer 证书签名；
   本机 Apple Development 证书不能代替安装包发行证书。应用会拒绝原作者团队的包。
5. 需要发行时完成公证和安装验证，再发布到本 fork 的 Release。
   此次本地改动没有创建或上传 GitHub Release。

应用的下载地址为：

`https://github.com/orut34iop/Capsomnia/releases/latest/download/Capsomnia-Tools.pkg`

因此用于 `latest` 的 Release 必须包含此资产。没有发布时，应用显示“当前 fork 尚未发布可用的 CLI & Skill 安装包”。
源码配置见 `resources/Info.plist`、`Sources/Capsomnia/ForkToolsSource.swift` 和
`Sources/Capsomnia/AppConstants.swift`。
