# v1.x 收尾 + v2.x 启动 执行方案

> ⚠️ **已废弃**：项目已从双线并行回归单线开发，本文档仅作历史归档。
> v1.x 不再维护，main 分支直接以 v2.0.0 往前走。
> Bundle ID 统一为 `com.markdownreader.app`。
>
> 废弃日期：2026-06-08

## 已确认决策

| 决策 | 结论 |
|------|------|
| v1.x 首版号 | **v1.1.0**（新的开始，v1.x 独立维护） |
| v2.x 首版号 | **v2.0.0** |
| macOS 26 WebView API | ✅ 已确认可用 |
| 切分支基准 | **v1.0.10 tag**（当前 main 上的 docs commit 与 v1.x 无关） |
| CI 适配策略 | **各分支硬编码，不参数化**（v2.x 不需知道 v1.x 存在） |
| 文档更新策略 | **只改构建配置 + CLAUDE.md + CHANGELOG**，其余随开发逐步更新 |

## CI 适配关键原理

GitHub Actions tag 触发机制：**从 tag 指向的 commit 读取 workflow 文件**。

- `v1.*` tag → 指向 `release/1.x` 上的 commit → 执行该分支的 `release.yml`（v1.x 配置）
- `v2.*` tag → 指向 `main` 上的 commit → 执行该分支的 `release.yml`（v2.x 配置）

两个分支各有独立的 CI 配置，天然隔离。不需要参数化、不需要版本号前缀判断。v2.x 保持完全干净。

---

## 执行步骤

### Step 1: 提交未跟踪文件到 main

```bash
git checkout main
git add docs/webview-rendering-architecture.md
git commit -m 'docs: 添加 WebView 渲染架构方案文档'
```

### Step 2: 从 v1.0.10 tag 切出 release/1.x 并推送

```bash
git checkout -b release/1.x v1.0.10
git push origin release/1.x
git checkout main
```

从 v1.0.10 tag 切，不含 docs commit（分支策略和 WebView 架构文档对 v1.x 无意义）。

### Step 3: 在 release/1.x 上准备 v1.1.0

切到 release/1.x 分支，做以下改动：

1. **CHANGELOG.md**：添加 v1.1.0 条目（描述为 v1.x 维护线首个稳定版）
2. **docs/branching-strategy.md**：版本号规则从 `v1.0.11、v1.0.12...` 改为 `v1.1.0、v1.1.1...`
3. 打 tag `v1.1.0`
4. 执行 `./release-local.sh 1.1.0` 发布

```bash
git checkout release/1.x
# 编辑 CHANGELOG.md 和 docs/branching-strategy.md
git add -A
git commit -m 'chore(release): 准备 v1.1.0 发布'
git tag v1.1.0
git push origin release/1.x --tags
./release-local.sh 1.1.0
```

### Step 4: 在 main 上初始化 v2.x

回到 main，做以下改动（每处都是直接硬编码 v2.x 值，不搞参数化）：

| 文件 | 改动 | 原因 |
|------|------|------|
| `Package.swift` | `platforms: [.macOS(.v26)]` | 构建必须 |
| `scripts/Info.plist` | `CFBundleIdentifier` → `com.markdownreader.app.v2`；`LSMinimumSystemVersion` → `26` | 构建必须 |
| `build-app.sh` | actool `--minimum-deployment-target` → `26`（第 127 行） | 构建必须 |
| `release.yml` | `BUNDLE_ID` → `com.markdownreader.app.v2`；actool deployment target → `26`（第 194 行） | 发布必须 |
| `CLAUDE.md` | 更新：当前版本 2.0.0-dev、最低部署 macOS 26.0、Bundle ID com.markdownreader.app.v2、技术栈描述 | 项目元信息 |
| `CHANGELOG.md` | 添加 `## [Unreleased]` 占位 | 版本管理惯例 |

提交：

```bash
git checkout main
# 编辑上述 6 个文件
git add -A
git commit -m 'chore: 初始化 v2.x 开发周期'
```

#### 各文件具体改动

**Package.swift**：
```swift
// 改前
platforms: [.macOS(.v15)]

// 改后
platforms: [.macOS(.v26)]
```

**scripts/Info.plist**：
```xml
<!-- 改前 -->
<key>CFBundleIdentifier</key>
<string>com.markdownreader.app</string>
<key>LSMinimumSystemVersion</key>
<string>15.0</string>

<!-- 改后 -->
<key>CFBundleIdentifier</key>
<string>com.markdownreader.app.v2</string>
<key>LSMinimumSystemVersion</key>
<string>26</string>
```

**build-app.sh**（第 127 行附近）：
```bash
# 改前
--minimum-deployment-target 15.0

# 改后
--minimum-deployment-target 26
```

**release.yml**：
```yaml
# 改前
BUNDLE_ID: com.markdownreader.app

# 改后
BUNDLE_ID: com.markdownreader.app.v2
```

以及 CI 中 actool 的 `--minimum-deployment-target 15.0` → `26`。

**CLAUDE.md**：
- 当前版本: 1.0.6 → 2.0.0-dev
- 最低部署: macOS 15.0 (Sequoia) → macOS 26.0
- Bundle ID: `com.markdownreader.app` → `com.markdownreader.app.v2`
- 渲染引擎描述中增加 v2.x WebView 方向说明

**CHANGELOG.md**：在文件顶部添加：
```markdown
## [Unreleased]

### 变更

- 渲染引擎从 Textual 迁移到 cmark-gfm + WebView
- 最低部署目标从 macOS 15.0 提升到 macOS 26
- Bundle ID 变更为 com.markdownreader.app.v2（设置隔离）
```

### Step 5: 清理旧分支

```bash
git branch -d feat/outline-view-and-theme-refactor
git push origin --delete feat/outline-view-and-theme-refactor
```

该分支没有未合并的 commit，可以安全清理。

### Step 6: （后续迭代）在 release/1.x 上添加 v2.x 更新弹窗

不阻塞 v2.x 开发，可独立迭代。需要改造：

1. `UpdateService`：查询 releases 列表，分别匹配 `v1.*` 和 `v2.*` tag
2. `UpdateViewModel`：持有两个 `GitHubRelease?`（`v1Release` + `v2Release`）
3. `UpdateView`：v1.x 更新 + v2.x 下载并列展示

详见 `docs/branching-strategy.md` 中的「v1 → v2 更新合并展示」章节。

---

## 文档更新策略

### 初始化时改的文档（6 个）

已在 Step 4 中列出。

### 不动的文档（及更新时机）

| 文档 | 原因 | 何时更新 |
|------|------|---------|
| `README.md` | 系统要求仍指向 v1.x 代码状态 | v2.0.0 发布时 |
| `docs/architecture.md` | 当前架构描述仍与代码一致（Textual） | Phase 1 完成（WebView 可渲染）后 |
| `docs/design.md` | 设计描述仍与代码一致 | Phase 2 完成（主题迁移）后 |
| `docs/requirements.md` | 需求状态仍与代码一致 | Phase 1-4 完成后，统一更新 |
| `docs/plan.md` | v1.x 开发计划已完成 | 创建新的 v2.x 开发计划替代 |
| `docs/auto-update-design.md` | 更新逻辑尚不变 | Step 6 实施时更新 |
| `docs/find-replace-design.md` | 查找替换功能逻辑不变 | WebView 查找实现时更新 |
| `docs/large-file-rendering-performance.md` | 性能分析，WebView 性能不同 | Phase 1 完成后更新 |
| `docs/codex-theme-migration-feasibility.md` | 主题迁移参考 | Phase 2 实施时参考 |
| `docs/double-click-open-investigation.md` | 与渲染引擎无关 | 不需更新 |
| `docs/releases/*.md` | 发布说明，归档性质 | 不需更新 |

**原则：文档-代码不一致比文档过时更糟糕。每个 Phase 完成后再更新对应文档，文档始终与代码保持一致。**

---

## v2.x 开发阶段参考

来自 `docs/webview-rendering-architecture.md` 的 Phase 规划：

| 阶段 | 内容 | 风险 |
|------|------|------|
| Phase 0 | 将最低部署目标提升到 macOS 26 | 低（Step 4 已完成） |
| Phase 1 | 新建 `WebPage` + `WebView`，加载 cmark-gfm 生成的 HTML | 低 |
| Phase 2 | 迁移主题系统（CSS 变量映射） | 中 |
| Phase 3 | 滚动同步（`webViewScrollPosition` + JS heading 定位） | 低 |
| Phase 4 | 集成 Mermaid + KaTeX | 低 |
| Phase 5 | 移除 Textual 依赖 | 低 |

---

## 风险与注意事项

1. **Step 3 必须在 Step 4 之前完成**：release/1.x 切出并发布 v1.1.0 后，main 才能开始 v2.x 改动。否则如果在 main 上改了 Bundle ID 和部署目标后，v1.* tag 推送时会从 main 构建导致失败。
2. **Info.plist 模板连锁影响**：`build-app.sh` 和 `release.yml` 中的 CI `ci-build` job 都用 sed 替换 Info.plist，改了 CFBundleIdentifier 后两处都必须同步更新。
3. **v2.x Bundle ID 隔离**：`com.markdownreader.app.v2` 意味着 macOS 会隔离 UserDefaults、Keychain、应用支持目录，两个版本可以并存安装，方便对比测试。
