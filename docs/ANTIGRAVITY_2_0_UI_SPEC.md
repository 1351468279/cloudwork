# Google Antigravity 2.0 移动端交互设计与 UI 规范全书

> **版本**：v2.0.0-SPEC  
> **基准视口**：390 × 844 px (iPhone 14/15/16, Android 典型真机尺寸)  
> **设计基准**：Google Material 3 Expressive & Antigravity 官方深色工程级暗黑模式  
> **文档定位**：为 CloudWork 掌上指挥官与跨端 AI 编码协同系统提供像素级、手势级与动效级的设计与前端落地标准。

---

## 目录
1. [设计哲学与视觉 Token 体系 (Design Tokens)](#1-设计哲学与视觉-token-体系)
2. [移动端视口、安全区与虚拟键盘适配 (Viewport & Safe Area)](#2-移动端视口安全区与虚拟键盘适配)
3. [六大核心交互模块像素级规范 (Component Specs)](#3-六大核心交互模块像素级规范)
   - [3.1 顶栏全局状态与导航 (App Header)](#31-顶栏全局状态与导航-app-header)
   - [3.2 签名式吸附输入底座 (Docked Input Island)](#32-签名式吸附输入底座-docked-input-island)
   - [3.3 悬浮非阻塞排队岛 (Queued Messages Island)](#33-悬浮非阻塞排队岛-queued-messages-island)
   - [3.4 单轮会话统一容器 (Single Turn Container)](#34-单轮会话统一容器-single-turn-container)
   - [3.5 任务与终端控制台抽屉 (Terminal Sheet)](#35-任务与终端控制台抽屉-terminal-sheet)
   - [3.6 移动端代码审查全屏抽屉 (Mobile Diff Reviewer)](#36-移动端代码审查全屏抽屉-mobile-diff-reviewer)
4. [动效缓动函数与手势时序表 (Motion & Timing)](#4-动效缓动函数与手势时序表)
5. [DOM 树结构与 CSS 类名工程规范 (BEM Specs)](#5-dom-树结构与-css-类名工程规范)

---

## 1. 设计哲学与视觉 Token 体系

Antigravity 2.0 舍弃了传统 ChatBot 的轻量化圆泡式外观，采用了 **AI 工业级控制台 (Agentic Console)** 的设计语言：纯净的 Google 深空黑调、微米级发光边框、极高的信息排版密度、以及结构化的折叠式结果呈现。

### 1.1 颜色系统 (Color Tokens)

| Token 变量名 | 默认色值 | 用途与视觉心理 |
| :--- | :--- | :--- |
| `--ga-bg-canvas` | `#131314` | 主画布底色，纯正深空灰黑，消除眼部视觉疲劳 |
| `--ga-bg-surface-1` | `#1e1f20` | 一级表面（输入底座、卡片底色、抽屉面板） |
| `--ga-bg-surface-2` | `#282a2c` | 二级表面（悬浮排队岛、用户提问气泡、代码块背景） |
| `--ga-bg-surface-hover` | `#333538` | 交互高亮与悬停触控状态 |
| `--ga-border-subtle` | `rgba(255, 255, 255, 0.08)` | 1px 微米级高质感边框，形成轻微轮廓区隔 |
| `--ga-border-focus` | `rgba(168, 199, 250, 0.40)` | 输入聚焦与高亮边框 |
| `--ga-text-primary` | `#e3e3e3` | 主阅读文本，高对比度但避免纯白的刺眼感 |
| `--ga-text-secondary` | `#8e918f` | 次要信息（时间戳、Token 数、副标题） |
| `--ga-text-tertiary` | `#5e615f` | 弱化信息（快捷键提示、占位文字、折叠图标） |
| `--ga-accent-blue` | `#a8c7fa` | 谷歌专属软蓝（链接、高亮按钮底色、活动徽章） |
| `--ga-accent-gold` | `#f2c94c` | 标志性琥珀金（关键路径、参数标签、行内代码高亮） |
| `--ga-accent-gold-bg`| `rgba(242, 201, 76, 0.12)` | 琥珀金轻质衬底（行内代码块背景） |
| `--ga-status-green` | `#46a049` | 成功、在线脉冲指示灯、Git Diff 增量行 |
| `--ga-status-red` | `#eb5757` | 失败、强制停止键、Git Diff 删除行 |

### 1.2 圆角体系 (Radius Tokens)

| Token 变量名 | 尺寸 | 应用场景 |
| :--- | :--- | :--- |
| `--ga-radius-xs` | `4px` | 标签芯片、行内代码块 |
| `--ga-radius-sm` | `8px` | 按钮、步骤折叠单行容器、缩略图 |
| `--ga-radius-md` | `12px`| 卡片容器、对话气泡内嵌块、模型切换药丸 |
| `--ga-radius-lg` | `16px`| 悬浮排队岛、工件卡片、代码变更审查卡片 |
| `--ga-radius-xl` | `24px`| 输入底座外壳、底部抽屉顶部边缘圆弧 |
| `--ga-radius-full` | `9999px`| 圆形控制按钮 (发送键、添加附件键、用户头像) |

### 1.3 字体排版体系 (Typography Tokens)

* **品牌与 UI 标题**：`"Google Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`
* **正文与微文字**：`"Google Sans Text", Roboto, "Helvetica Neue", sans-serif`
* **终端、代码与差异比对**：`"JetBrains Mono", "Fira Code", SFMono-Regular, Consolas, monospace`

| 排版角色 | 字体大小 | 字重 | 行高 | 字间距 |
| :--- | :--- | :--- | :--- | :--- |
| **Header Title** | `15px` | 500 (Medium) | 20px | `0.1px` |
| **Subtitle / Meta** | `11px` | 400 (Regular) | 14px | `0.2px` |
| **Body Markdown** | `14px` | 400 (Regular) | 22px | `0.15px` |
| **Code Block** | `12.5px`| 400 (Regular) | 19px | `0px` |
| **Badge / Tag** | `11px` | 500 (Medium) | 16px | `0.3px` |
| **Island Status** | `12px` | 500 (Medium) | 16px | `0.1px` |

---

## 2. 移动端视口、安全区与虚拟键盘适配

移动端开发最严苛的挑战在于**非固定视口**与**软键盘顶起**。Antigravity 2.0 实现了严丝合缝的视口适配模型。

```
390px 真实视口垂直布局
┌───────────────────────────────────────┐ 0px
│ [Header] 56px 高度，固定贴顶，背景微毛玻璃 │
├───────────────────────────────────────┤ 56px
│                                       │
│                                       │
│ [Scrollable Message Canvas]           │
│ 可滚轮主画布，自动下沉避让底部组件        │
│ padding-bottom: calc(140px + safe)    │
│                                       │
│                                       │
├───────────────────────────────────────┤
│ [Queued Messages Island] (条件悬浮 44px)│ 距底座 8px
├───────────────────────────────────────┤
│ [Docked Input Island] (高度 84~168px)  │ 浮动沉底
│ margin: 0 12px 12px 12px              │
└───────────────────────────────────────┘ 844px
  [Home Indicator / Safe Area] 34px
```

### 2.1 CSS 环境变量与动态安全区计算
```css
:root {
  /* 基础高度 */
  --ga-header-height: 56px;
  --ga-bottom-offset: env(safe-area-inset-bottom, 16px);
  --ga-keyboard-height: 0px; /* 由 JS VisualViewport API 动态写入 */
}

/* 消息滚动容器：必须为底部留出充足的空白，防止最后一条消息被输入底座遮挡 */
.chat-scroll-container {
  padding-top: calc(var(--ga-header-height) + 12px);
  padding-bottom: calc(140px + var(--ga-bottom-offset) + var(--ga-keyboard-height));
  overflow-y: auto;
  overscroll-behavior-y: contain; /* 阻止 iOS 橡皮筋穿透 */
  -webkit-overflow-scrolling: touch;
}

/* 输入底座的绝对定位约束 */
.docked-input-island-wrapper {
  position: fixed;
  left: 0;
  right: 0;
  bottom: calc(var(--ga-bottom-offset) + var(--ga-keyboard-height));
  padding: 0 12px;
  z-index: 900;
  pointer-events: none; /* 让外壳透传点击，只有底座内部响应事件 */
  transition: bottom 0.2s cubic-bezier(0.2, 0, 0, 1);
}

.docked-input-island {
  pointer-events: auto;
  background: var(--ga-bg-surface-1);
  border: 1px solid var(--ga-border-subtle);
  border-radius: var(--ga-radius-xl);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.48);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}
```

### 2.2 VisualViewport 键盘高度实时同步 JS 引擎
在 iOS Safari / Android Chrome 中，软键盘弹起时页面窗口高度改变但 `fixed` 容易发生脱节，需通过原生 `visualViewport` 监听：
```javascript
if (window.visualViewport) {
  window.visualViewport.addEventListener('resize', () => {
    const keyboardHeight = Math.max(0, window.innerHeight - window.visualViewport.height);
    document.documentElement.style.setProperty('--ga-keyboard-height', `${keyboardHeight}px`);
    // 自动滑动到最新消息
    scrollToBottom(true);
  });
}
```

---

## 3. 六大核心交互模块像素级规范

### 3.1 顶栏全局状态与导航 (App Header)

```
[ ← ]   AI Coding Remote Con...          [ >_ ] [ 📄 ] [ 💬 ] [ M ]
        ● 家中电脑已连接 (9288)
```

#### DOM 节点结构
```html
<header class="ga-header">
  <div class="ga-header-left">
    <button class="ga-icon-btn" aria-label="返回/会话列表" id="btn-back">
      <span class="material-symbols-outlined">arrow_back</span>
    </button>
    <div class="ga-header-meta">
      <h1 class="ga-header-title">AI Coding Remote Con...</h1>
      <div class="ga-header-status">
        <span class="ga-pulse-dot is-online"></span>
        <span class="ga-status-text">家中电脑已连接 (9288)</span>
      </div>
    </div>
  </div>
  <div class="ga-header-actions">
    <button class="ga-icon-btn" id="btn-open-terminal" title="终端控制台">
      <span class="material-symbols-outlined">terminal</span>
    </button>
    <button class="ga-icon-btn" id="btn-open-diff" title="代码改动审查">
      <span class="material-symbols-outlined">difference</span>
    </button>
    <button class="ga-icon-btn" id="btn-open-drawer" title="会话抽屉">
      <span class="material-symbols-outlined">chat_bubble_outline</span>
    </button>
    <div class="ga-avatar-ring">
      <span class="ga-avatar-letter">M</span>
    </div>
  </div>
</header>
```

#### 关键尺寸与状态机
- **高度**：`56px`，全宽，`padding: 0 12px`
- **背景**：`rgba(19, 19, 20, 0.85)`，伴随 `backdrop-filter: blur(12px)`
- **底边**：`1px solid rgba(255, 255, 255, 0.06)`
- **按钮尺寸**：`36 × 36 px`，圆角 `50%`，图标尺寸 `20px`
- **脉冲指示灯 (`.ga-pulse-dot`)**：
  - 尺寸：`6 × 6 px`，圆角 `50%`
  - 在线状态：`background: #46a049`，带有 1.8s 循环呼吸透明光晕 (`box-shadow: 0 0 0 4px rgba(70, 160, 73, 0.2)`)
  - 离线状态：`background: #eb5757`，无呼吸动效

---

### 3.2 签名式吸附输入底座 (Docked Input Island)

这是整个 Antigravity 2.0 体验最核心的容器，由三层一体化构成：

```
┌─────────────────────────────────────────────────────────────┐
│ ● 2 tasks running (00:15)                                 ^ │  ← 任务运行条 (条件渲染)
├─────────────────────────────────────────────────────────────┤
│ Ask anything, @ to mention, / for actions                   │  ← 自适应弹性文本框
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ [ + ]   [ Gemini 3.8 Flash High ˅ ]                 [ ↑ ]   │  ← 操作底栏 (附件/模型/发射)
└─────────────────────────────────────────────────────────────┘
```

#### 状态与子组件规范

#### (A) 任务运行头 (Task Running Header)
- **触发条件**：当前会话存在运行中的 Agent、Powershell 命令或后台服务。
- **高度**：`30px`，边框下划线 `1px solid rgba(255, 255, 255, 0.06)`。
- **左侧状态指示**：
  - 运转中绿点：`8 × 8 px`，带微型脉冲。
  - 文本：“`2 tasks running (00:15)`”，字体大小 `12px`，色值 `#e3e3e3`。
- **右侧折叠箭头**：`expand_less` 图标，点击直接从底部向上呼出**终端任务控制台抽屉 (Terminal Sheet)**。

#### (B) 弹性输入框 (Elastic Textarea)
- **字体规格**：`14px`，行高 `20px`，色值 `#ffffff`。
- **高度弹性自适应**：
  - 单行默认高：`24px`（仅文本区，不含外边距）。
  - 最大高度限制：`120px`（约 6 行），超过后内部启动滚动条，不撑爆全屏。
  - `overflow-y: auto`，定制透明细滚动条。
- **占位文字 (Placeholder)**：`Ask anything, @ to mention, / for actions`，色值 `#5e615f`。

#### (C) 底部操作条 (Action Footer)
- **高度**：`40px`，横向排列，垂直居中。
- **左侧操作区**：
  - **`+` 附件按钮**：`32 × 32 px` 圆形，点击弹出工具面板（包含拍照上传、代码审查、工件生成快捷触发）。
  - **模型切换药丸 (`.ga-model-pill`)**：
    - 高度：`28px`，圆角：`14px`（半圆胶囊）。
    - 背景：`rgba(255, 255, 255, 0.05)`，边框：`1px solid rgba(255, 255, 255, 0.08)`。
    - 内边距：`4px 10px`。
    - 文本：“`Gemini 3.8 Flash High`”，右侧带 `14px` 的向下小箭头 `expand_more`。
- **右侧发送控制区**：
  - **圆形发送键 (`.ga-send-btn`)**：
    - 尺寸：`34 × 34 px` 圆形。
    - **三态外观**：
      1. **空闲无内容**：背景 `rgba(255, 255, 255, 0.08)`，图标为箭头向上，色值 `#8e918f`，置灰不可点。
      2. **有输入内容**：背景变为亮白色 `#ffffff`，图标变为深黑 `#131314`，激活可点，带 `scale(1.05)` 弹簧反馈。
      3. **Agent 执行中且输入框为空**：图标变为黑色实心方块 `stop`（停止运行键），点击立即向 Daemon 发送中断信号。

---

### 3.3 悬浮非阻塞排队岛 (Queued Messages Island)

这是让 Antigravity 2.0 体验领先传统工具的颠覆性设计：**在 Agent 还在输出长篇思考或执行 10 步命令时，用户不需要“傻等”，可以直接在输入框写下一句，按发送后，立即进入底座上方的排队岛！**

```
┌─────────────────────────────────────────────────────────────┐
│ ☷ [🖼] [🖼] [+2] Queued Messages 1 · Sends after agent ... │
│                                             [ ↗ ] [ ✎ ] [ ✕ ]│
└─────────────────────────────────────────────────────────────┘
```

#### 视觉与定位规范
- **挂载位置**：直接位于 `.docked-input-island` 上方 `8px` 处，随输入底座整体悬浮联动。
- **容器规格**：高度 `44px`，宽度 100%，`border-radius: 14px`。
- **表面材质**：`background: #282a2c`，`border: 1px solid rgba(255, 255, 255, 0.1)`。
- **阴影**：`box-shadow: 0 4px 20px rgba(0, 0, 0, 0.35)`。

#### 内部信息流
1. **缩略图胶囊画廊**：
   - 随附图片缩略图：`24 × 24 px`，圆角 `4px`，内嵌 `object-fit: cover`。
   - 超过 2 张图片展示 `+N` 灰色圆角徽章。
2. **状态提示文字**：
   - 文本：“`Queued Messages 1 · Sends after agent finishes`”。
   - 字号：`12px`，字重：500，颜色：`#a8c7fa`（软蓝发光）。
3. **右侧三合一动作组**：
   - `arrow_forward`（插队直发）：强制中止或插队立即触发。
   - `edit`（编辑）：将内容弹回输入框修改。
   - `delete`（删除）：移出待发队列。

---

### 3.4 单轮会话统一容器 (Single Turn Container)

以往界面最让用户抓狂的是：**执行了 10 条命令行，聊天框里啪啪啪跳出 10 个独立卡片，手机屏幕瞬间被刷屏！**  
Antigravity 2.0 提出了 **Single Turn 统一容器模型**，一轮问答严格封装在同一块流式画布内。

```
┌─────────────────────────────────────────────────────────────┐
│ [User] 你好，帮我检查一下内存泄漏问题                          │ ← 用户提问
├─────────────────────────────────────────────────────────────┤
│ 💭 Thinking Process (展开思考 · 耗时 3.2s)                ˅ │ ← 思考过程折叠
├─────────────────────────────────────────────────────────────┤
│ ⚙️ 已完成 10 个执行步骤 [明细 >]                           ˅ │ ← 步骤折叠聚合器 (核心!)
│   ├── ✔ Step 1: powershell -Command "Get-Process ..."       │
│   ├── ✔ Step 2: view_file memory.go                         │
│   └── ✔ Step 3: git diff --stat                             │
├─────────────────────────────────────────────────────────────┤
│ 我已对工程内的堆栈进行了全面审查，发现以下两处关键泄漏点：       │ ← 纯净正文 Markdown
│ 1. `ws/server.go:128` 未释放连接资源                         │
├─────────────────────────────────────────────────────────────┤
│ 📄 [Implementation Plan]                                   │ ← 工件卡片
│    内存泄漏修复与连接池生命周期重构方案                         │
├─────────────────────────────────────────────────────────────┤
│ 📁 3 files changed (+84 -22)                    [ Review > ]│ ← 代码变更审查卡片
├─────────────────────────────────────────────────────────────┤
│ 3.2s · 1.4k tokens · gemini-3.8-flash        [📋] [👍] [👎] │ ← 底部元数据与反馈
└─────────────────────────────────────────────────────────────┘
```

#### 关键子模块规范

#### (1) 步骤折叠聚合器 (Steps Accordion) —— 绝无刷屏
- **折叠态（默认）**：
  - 仅占据一行高 `32px`，全宽，背景：`rgba(255, 255, 255, 0.03)`，圆角 `8px`。
  - 左侧：齿轮动画图标 `settings` + “`已完成 10 个执行步骤`”。
  - 右侧：“`[明细 >]`” 折叠指示。
- **展开态**：
  - 垂直向下平滑滑出时光轴列表。
  - 每个子步骤为 `24px` 高度，左侧带成功微型对勾（`check_circle` 绿标），右侧等宽字体显示执行的命令概要。
  - 点击任何单项，可就地查看标准输出 (stdout)。

#### (2) 琥珀金行内代码与代码块
- **行内代码**：`background: rgba(242, 201, 76, 0.12)`，字体色：`#f2c94c`，内边距 `2px 6px`，圆角 `4px`。高辨识度，一眼区分常规文本与函数/变量名。
- **多行代码块**：背景色 `#1a1a1c`，微米描边，右上方提供一键复制按钮与语言类型标签。

#### (3) 工件卡片 (Implementation Plan)
- **外形**：`border-radius: 12px`，背景：`#1e2024`，边框：`1px solid rgba(255, 255, 255, 0.1)`。
- **左侧**：蓝色文档图标 `description`。
- **中段**：标题 `Implementation Plan` + 双行截断正文预览（`-webkit-line-clamp: 2`）。
- **点击行为**：全屏模态滑出完整 Markdown 阅读器，支持大纲目录索引。

#### (4) 代码变更审查卡片 (File Diff Card)
- **外形**：高度 `48px`，水平通栏，深灰底色。
- **数据徽章**：绿字 `+1912`，红字 `-1183`，前置文件数 `5 files changed`。
- **右侧触发键**：`[ Review > ]` 胶囊按钮，点击直接无缝唤起全屏 Diff 审查抽屉。

---

### 3.5 任务与终端控制台抽屉 (Terminal Sheet)

在手机上查看终端输出不需要打开完整桌面端，底部控制台抽屉满足长日志排查需求。

```
┌─────────────────────────────────────────────────────────────┐
│                       ─── 拖动手柄 ───                       │
│ ● 终端控制台 (Terminal)                       [ ⏹ 终止任务 ] │
├─────────────────────────────────────────────────────────────┤
│ $ powershell -Command "go test -v ./..."                    │
│ === RUN   TestSessionLifecycle                              │
│ --- PASS: TestSessionLifecycle (0.04s)                      │
│ === RUN   TestQueuedMessageOrder                            │
│ --- PASS: TestQueuedMessageOrder (0.01s)                    │
│ PASS                                                        │
│ ok      cloudwork/daemon/internal/ws    0.082s              │
│                                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

- **呼出方式**：点击顶栏 `terminal` 图标，或点击输入底座上的 `2 tasks running ^` 药丸。
- **覆盖比例**：默认滑出至屏幕高度的 `70%`，支持向上推至 `95%` 全屏，或向下滑动关闭。
- **顶部手柄 (Drag Handle)**：`36 × 4 px`，圆角 `2px`，色值 `rgba(255, 255, 255, 0.3)`。
- **终端视窗**：
  - 字体：`JetBrains Mono`, `12px`，行高 `17px`。
  - 背景：`#0c0d0e`（更深层次的纯黑色）。
  - 支持 ANSI 颜色转义字符（红绿黄蓝）。
  - 右上角常驻红色胶囊 `[ ⏹ 终止任务 ]`，用于一键 Kill 掉卡死或超时的命令行。

---

### 3.6 移动端代码审查全屏抽屉 (Mobile Diff Reviewer)

针对手机端屏幕狭窄的痛点，Antigravity 2.0 摒弃了传统的“左右分栏”，采用**统一单列内联 Diff（Inline Unified Diff）**模式：

```
┌─────────────────────────────────────────────────────────────┐
│ [ ✕ ] 代码审查 (Diff Review)                  5 files · +84 │
├─────────────────────────────────────────────────────────────┤
│ ▾ daemon/internal/ws/server.go                    +42  -12  │ ← 文件折叠栏
├─────────────────────────────────────────────────────────────┤
│ 124   func (s *Server) handleSetWorkspace(...) {            │
│ 125 -     oldPath := s.workspace                            │ (淡红背景)
│ 125 +     oldPath := filepath.Clean(s.workspace)            │ (淡绿背景)
│ 126 +     s.logger.Infof("Switching to: %s", newPath)       │
│ 127       s.workspace = newPath                             │
└─────────────────────────────────────────────────────────────┘
```

- **视觉规范**：
  - 新增行：背景 `rgba(70, 160, 73, 0.15)`，行号前缀 `+`，文字高亮。
  - 删除行：背景 `rgba(235, 87, 87, 0.15)`，行号前缀 `-`，文字带轻微删除线。
  - 单行超长处理：`white-space: pre`，支持水平横向滑动审查，禁止无序强行折行打乱语法结构。

---

## 4. 动效缓动函数与手势时序表

遵循 Google Material 3 运动指南，严禁机械僵硬的线性 (`linear`) 变换。

### 4.1 核心贝塞尔曲线定义
```css
:root {
  /* 减速曲线：用于组件进场、抽屉滑出、卡片展开（先快后慢，自然平稳） */
  --ga-ease-decelerate: cubic-bezier(0.05, 0.7, 0.1, 1.0);
  
  /* 加速曲线：用于组件退出、抽屉滑落、弹窗隐去 */
  --ga-ease-accelerate: cubic-bezier(0.3, 0.0, 0.8, 0.15);
  
  /* 标准曲线：用于位置微调、颜色过渡、尺寸缩放 */
  --ga-ease-standard: cubic-bezier(0.2, 0.0, 0.0, 1.0);
  
  /* 弹性曲线：用于发送键激活、徽章跳动等反馈 */
  --ga-ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
}
```

### 4.2 动效参数映射表

| 动效场景 | 作用目标 | 时长 (Duration) | 缓动曲线 (Easing) | 属性变化 |
| :--- | :--- | :--- | :--- | :--- |
| **底部抽屉滑出** | `.ga-bottom-sheet` | `320ms` | `--ga-ease-decelerate` | `transform: translateY(100% -> 0)` |
| **排队岛挂载弹出**| `.ga-queued-island`| `220ms` | `--ga-ease-spring` | `transform: scale(0.95 -> 1.0), opacity` |
| **步骤折叠展开** | `.steps-accordion` | `240ms` | `--ga-ease-standard` | `max-height: 32px -> 400px` |
| **发送按钮激活** | `.ga-send-btn` | `160ms` | `--ga-ease-spring` | `transform: scale(1.0 -> 1.1 -> 1.0)` |
| **遮罩层淡入淡出**| `.ga-scrim-overlay`| `200ms` | `--ga-ease-standard` | `opacity: 0 -> 1` |

---

## 5. DOM 树结构与 CSS 类名工程规范

为了保证后续前端维护的绝对清晰，全系统采用 **`ga-` 前缀的 BEM 命名空间**：

```
Block:        .ga-[block]
Element:      .ga-[block]__[element]
Modifier:     .ga-[block]--[modifier] 或 .is-[state]
```

### 核心命名空间清单
- `.ga-header`：全局顶栏
- `.ga-canvas`：消息对话主视窗
- `.ga-turn`：单轮问答容器
  - `.ga-turn__user`：用户发言块
  - `.ga-turn__agent`：Agent 统一回复块
  - `.ga-turn__thinking`：思考块
  - `.ga-turn__steps`：步骤折叠器
  - `.ga-turn__markdown`：正文排版区
  - `.ga-turn__diff-card`：变更卡片
  - `.ga-turn__plan-card`：计划工件卡片
  - `.ga-turn__footer`：反馈与数据条
- `.ga-queued-island`：悬浮排队岛
- `.ga-docked-island`：吸附输入底座
  - `.ga-docked-island__task-bar`：顶置运行条
  - `.ga-docked-island__input`：弹性输入区
  - `.ga-docked-island__actions`：底置工具栏
- `.ga-sheet`：抽屉基类
  - `.ga-sheet--terminal`：终端抽屉
  - `.ga-sheet--diff`：代码审查抽屉
  - `.ga-sheet--drawer`：左侧历史抽屉
