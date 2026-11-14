# MoonCard · 月卡：裂界列车

原生 Swift / SwiftUI / RealityKit 的 iOS 3D 抽卡 RPG **早期可玩原型**。
融合列车伙伴家园、漫画式战斗反馈、领地成长。没有 Unity / Godot，也没有服务器或付费抽卡。

## 当前实现

- 横屏启动，三个真正的 3D 场景：星轨列车、裂界前线、月影领地。
- 六名数据化角色，三名初始伙伴；招募、重复转星屑、三人编队与交换槽位。
- 左侧摇杆移动，三人切换、三段攻击、冷却技能、0.28 秒闪避保护。
- 敌人追击、攻击蓄力预警、三波战斗和最终巨像；全队倒下失败。
- 击败全部敌人结算一次：基础 90 物资 + 160 星晶；撤退不结算。
- 三类固定地块建筑，最高三级；升级改变 3D 外观并提供攻击或远征收益加成。
- JSON 原子存档、后台暂停；损坏或未知版本存档保留原文件，临时游玩不覆盖。
- 原生漫画文字面板、透明材质 HUD；角色和建筑为程序生成的体素风占位模型。
- 首批三位初始伙伴的漫画立绘，已用于抽卡结果、旅伴名册、队员头像与连击 / 技能特写。

## 明确边界

这是验证玩法循环的 v0.1，不是完成品。尚未实现高品质角色美术、骨骼动作、其余三名角色立绘、
可自由行走的列车内交互、开放世界、自由摆放建筑、军团战争、故事关卡、音频、商店、账号与联网。
列车与领地目前为可查看和操作菜单的 3D 场景；移动控制只在战斗中开放。
星屑目前只有积累用途，没有兑换；技能使用队伍共享冷却，避免换人绕过冷却。
相机当前固定俯视透视角度，尚无手动旋转。目标 60 FPS，实机性能尚待测量。

## 本地构建（Mac）

需要 Xcode（支持 iOS 17 SDK 或更新版本）和 XcodeGen。

```sh
brew install xcodegen
xcodegen generate
open MoonCard.xcodeproj
```

选择 MoonCard scheme 和 iPhone 模拟器运行。真机需要在 Signing & Capabilities 选择自己的开发团队；
Bundle ID 如有冲突可在 project.yml 修改。项目不需要相机权限，使用 RealityKit 的 non-AR 模式。
生成的工程可以重新生成；项目配置以 project.yml 为准。

```sh
swift test
xcodebuild -project MoonCard.xcodeproj -scheme MoonCard -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions `.github/workflows/ios.yml` 在 macOS 上运行核心规则测试，生成工程并编译模拟器应用。
产物为 **模拟器 .app**，不是可以安装到 iPhone 的 IPA；签名与 TestFlight 发布尚未配置。

## 操作

1. 列车 → 召集伙伴：消耗 160 星晶招募；名册可调整三人队伍。
2. 出发远征 → 左侧摇杆移动；右侧攻击 / 裂界技 / 闪避；点击队员切换。
3. 红色地面预警代表敌人蓄力；离开范围或闪避规避伤害。
4. 三波胜利 → 返回领地 → 升级建筑 → 再次远征。
5. 改变场景、招募、编队、建设、胜利与进入后台时保存；战斗中途进度不保存。

## 招募规则

普通 98%、传说 2%；各品质内等概率。连续 59 抽无传说，第 60 抽必得传说，
任意传说重置计数。普通池 4 人（每人基础 24.5%），传说池 2 人（每人基础 1%）。
重复普通给 5 星屑、重复传说给 20 星屑。首次安装给 1600 星晶；所有货币仅为本地游戏数据。

## 结构

- `Core/GameCore.swift`：无 UI 依赖的战斗、招募、领地、存档模型。
- `App/GameStore.swift`：应用状态、玩法连接、结算和持久化。
- `App/WorldView.swift`：RealityKit 场景、程序模型和显示帧同步。
- `App/GameScreen.swift`：SwiftUI HUD、摇杆和管理页面。
- `Tests/MoonCardCoreTests`：确定性随机测试、战斗边界、存档和经济规则测试。
- `Docs/ACCEPTANCE.md`：实机验收清单与当前限制。

参考：[Apple RealityKit 相机与灯光](https://developer.apple.com/documentation/realitykit/scene-content-lights-and-cameras)。
