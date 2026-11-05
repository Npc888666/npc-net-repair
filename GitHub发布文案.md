# GitHub 发布文案（复制粘贴版）

> 配套文件：`README.md`（已写好）、`LICENSE`（MIT）、`.gitignore`、`GitHub上传指南-新手版.md`
> 下面每一块都可以直接复制到 GitHub 对应输入框。

---

## 一、项目名称候选

| # | 名称 | 仓库名（slug） | 说明 | 推荐度 |
| --- | --- | --- | --- | --- |
| 1 | **Npc 网络急救** | `npc-net-repair` | 品牌 + 动作，四个字好记；“急救”天然带“一键、马上好”的感觉，AI 场景放在副标题里讲 | ★★★★★ |
| 2 | **AI 断网急救包** | `ai-net-firstaid` | 最直白，搜“AI 断网”的人一眼命中；缺点是显得只修 AI 相关的问题 | ★★★★☆ |
| 3 | **一键网络回魂** | `net-revive` | “回魂”很抓人，强调不用重启就能复活；英文名 NetRevive 也好念 | ★★★★☆ |
| 4 | **断网救星 NetFixOne** | `netfix-one` | 中英双名，`One` 直接点出“一键”；偏通用，辨识度一般 | ★★★☆☆ |
| 5 | **网络复活甲** | `net-revive-armor` | 游戏化表达，年轻用户记得住；正式感弱一些 | ★★★☆☆ |

**最终建议**

- 仓库名：`npc-net-repair`（全小写 + 连字符，网址干净，GitHub 搜索友好）
- README 大标题：`Npc 网络急救`
- 英文副标题（放在 README 第一行下方或 About 里）：`Npc Net Rescue — one-click Windows network repair, no reboot`

> 仓库名一旦定下就尽量别改：改了旧链接会 404（GitHub 会做 301 跳转，但别人收藏的 Release 链接可能失效）。

---

## 二、一句话简介（About，≤100 字符）

**主推（约 60 字，直接粘贴）：**

```text
AI 工具 / 代理 / 抓包软件把 Windows 网络配置搞坏后，一键修复代理、hosts、DNS、Winsock，30–90 秒生效，无需重启。
```

**备选 A（更短，偏品牌）：**

```text
一键修复被 AI 工具弄坏的 Windows 网络：代理、hosts、DNS、Winsock 全修，无需重启。
```

**备选 B（更技术，偏搜索）：**

```text
Windows 网络一键修复：代理劫持、hosts 污染、DNS 篡改、Winsock 损坏、静态 IP 写死，10 阶段修复免重启。
```

---

## 三、仓库描述（GitHub Description，可长一些，≤350 字符）

```text
Npc 网络急救：AI 工具、代理、抓包、加速器把 Windows 网络配置搞坏（代理劫持、hosts 污染、DNS 篡改、Winsock 损坏、静态 IP 写死、NCSI 异常）后，一键修复，30–90 秒生效，无需重启。单文件 exe，修复前全量备份，可一键回滚，支持中英文系统。MIT License。
```

---

## 四、Topics 标签（建议 18 个，直接逐个粘贴）

```text
windows
powershell
network
network-repair
dns
proxy
hosts
winsock
tcpip
one-click
no-reboot
ai-tools
wpf
troubleshooting
netfix
dhcp
ipv4
china
```

> GitHub 的 Topics 规则：全小写、用连字符、最多 20 个。前 6 个最重要，会显示在仓库顶部。
> 想再加可考虑：`system-tools`、`network-tools`、`windows-11`、`cli`。

---

## 五、首次提交信息（commit message）

```text
feat: Npc 网络急救 v2.0 首次发布
```

后续提交建议用这套前缀，看起来专业：

| 前缀 | 用途 | 例子 |
| --- | --- | --- |
| `feat:` | 新功能 | `feat: 增加无线网卡自动重连` |
| `fix:` | 修 bug | `fix: 修复 hosts 原子写入失败的问题` |
| `docs:` | 改文档 | `docs: 补充 Windows 7 兼容说明` |
| `refactor:` | 重构 | `refactor: 拆分代理清理逻辑` |
| `chore:` | 杂项 | `chore: 更新 .gitignore` |

---

## 六、Release 文案（v2.0.0，直接粘贴）

**Release title：**

```text
v2.0.0 · 首个公开版本
```

**Describe this release：**

```markdown
## Npc 网络急救 v2.0.0

一键修复被 AI 工具 / 代理 / 抓包软件改坏的网络配置，**无需重启**。

### 下载

- `Npc修复网络.exe` —— 单文件版，双击即用（推荐）
- `Npc修复网络.bat` + `Npc修复网络-GUI.ps1` + `Npc修复网络.ps1` —— 脚本版，三个文件放同一目录运行

### 能修什么

- 代理劫持（WinINET / WinHTTP / 环境变量 / portproxy 端口转发）
- hosts 污染
- Winsock / TCP/IP 协议栈损坏
- DNS 被篡改 / NRPT 策略残留
- 静态 IP 被写死、DHCP 拿不到地址（卡 169.254.x.x）
- 网卡被禁用、IPv4 协议绑定被取消
- 路由表异常、默认网关指向 0.0.0.0
- NCSI 异常导致的“无 Internet”黄色感叹号

### 特点

- 10 阶段自动修复 + 第二轮深度补救
- 修复前全量备份，支持一键回滚
- 静态 IP 保护、远程会话保护
- 中英文系统自动切换
- 纯本地运行，不收集任何数据

### 使用说明

1. 双击 `Npc修复网络.exe`
2. UAC 弹窗点“是”
3. 点“开始修复”，等 30–90 秒
4. 中途断网 4–8 秒属正常（网卡在重启）

### 系统要求

- Windows 10 / 11（Windows 7 / 8 需 PowerShell 5.1 + .NET Framework 4.6+）
- 管理员权限

### 协议

MIT License
```

---

## 七、README 首屏优化建议（可选）

README 前 160 个字符会出现在搜索引擎和社交分享卡片里，现在已经包含：
`连上 WiFi 却上不了网？AI 工具、代理、抓包软件把网络配置搞坏了？` + `无需重启`。

如果想再强化，可以在第一段后加一行关键词（不影响阅读）：

```markdown
> 关键词：网络修复 / 断网急救 / 代理劫持 / hosts 清理 / DNS 修复 / Winsock 重置 / 免重启 / Windows 网络工具
```

---

## 八、社交预览图（可选，但很加分）

GitHub 仓库 → **Settings** → **Social preview** → 上传一张 1280×640 的图。

内容建议：

- 左侧：深色背景 + 青色圆环（和程序界面同色系）
- 大字：`Npc 网络急救`
- 副标题：`一键修复 AI 弄坏的网络 · 无需重启`
- 右下角：`Windows 10 / 11 · MIT`

用系统自带的“画图”或 Canva 都能做，5 分钟搞定。

---

## 九、发布后可以做的事

1. 在 README 顶部加 Release 下载徽章：

```markdown
[![Download](https://img.shields.io/badge/download-latest%20release-22D3EE)](https://github.com/你的用户名/npc-net-repair/releases/latest)
```

2. 提一个 Issue 模板（`.github/ISSUE_TEMPLATE/bug_report.md`），让反馈的人附上 `report_*.txt`。
3. 在仓库 **Insights → Traffic** 看访问量，判断哪些关键词带来了流量。
4. 如果被安全软件误报，在 README 的 FAQ 里加一条说明（源码公开、可自行审计）。
