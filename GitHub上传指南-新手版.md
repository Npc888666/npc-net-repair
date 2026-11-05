# GitHub 上传指南（纯新手版）

> 目标：把 `C:\Users\Administrator\Desktop\Npc修复网络-针对Ai弄坏网络的\` 这个文件夹，变成一个能被人访问的 GitHub 仓库。
> 全程大约 20 分钟，照着复制粘贴就行。命令都在 **PowerShell** 里执行。

---

## 0. 先搞懂三个词（30 秒）

| 词 | 意思 | 类比 |
| --- | --- | --- |
| 仓库（Repository） | GitHub 上的一个项目文件夹 | 一个网盘文件夹 |
| commit（提交） | 给当前代码拍一张“存档照” | 游戏存档 |
| push（推送） | 把本地存档上传到 GitHub | 上传到网盘 |

流程就是：**本地建仓库 → 存档 → 在网页建空仓库 → 把两者连起来 → 推上去。**

---

## 1. 准备工作（只做一次）

### 1.1 注册 GitHub 账号

1. 打开 https://github.com
2. 点右上角 **Sign up**
3. 填邮箱 → 密码 → 用户名（用户名会出现在仓库网址里，建议用英文，例如 `npc-lab`）
4. 邮箱收验证码，验证完成

### 1.2 安装 Git

**方法 A：一条命令（推荐，Win10/11 自带 winget）**

在开始菜单搜索 `PowerShell`，右键 → **以管理员身份运行**，粘贴：

```powershell
winget install --id Git.Git -e --source winget
```

**方法 B：手动下载**

打开 https://git-scm.com/download/win ，下载 64-bit 安装包，双击，一路点 **Next**（默认选项就行），最后 Install。

### 1.3 验证装好了

**关掉刚才的 PowerShell，重新开一个**（让环境变量生效），执行：

```powershell
git --version
```

看到类似 `git version 2.47.1.windows.1` 就成功了。

---

## 2. 配置身份（只做一次）

Git 需要知道“这次提交是谁干的”。把邮箱换成你注册 GitHub 用的邮箱：

```powershell
git config --global user.name "你的GitHub用户名"
git config --global user.email "你的邮箱@example.com"
```

检查：

```powershell
git config --global --list
```

> 这两行只是写进本机配置文件，不会公开，也不会发给别人。

---

## 3. 本地建仓库并提交

### 3.1 进入项目文件夹

```powershell
cd "C:\Users\Administrator\Desktop\Npc修复网络-针对Ai弄坏网络的"
```

确认位置对不对：

```powershell
Get-Location
Get-ChildItem
```

应该能看到 `README.md`、`LICENSE`、`.gitignore`、`Npc修复网络.exe` 等文件。

> 注意：路径里有中文，**必须带引号**。PowerShell 里按 Tab 可以自动补全路径。

### 3.2 初始化仓库

```powershell
git init
```

正常输出：`Initialized empty Git repository in C:/Users/Administrator/Desktop/Npc修复网络-针对Ai弄坏网络的/.git/`

### 3.3 把所有文件加入暂存区

```powershell
git add .
```

### 3.4 提交前先看一眼：到底会传哪些文件（重要）

```powershell
git status
```

你应该看到这些文件是绿色的（已暂存）：

```text
README.md
LICENSE
.gitignore
Npc修复网络.exe
Npc修复网络.bat
Npc修复网络-GUI.ps1
Npc修复网络.ps1
使用说明.txt
GitHub发布文案.md
GitHub上传指南-新手版.md
```

**如果看到日志、备份文件夹、`report_*.txt`、`last_verify.json` 之类的，先停下来**，把它们删掉或加进 `.gitignore`（本项目已经配好，一般不会出现）。

### 3.5 提交

```powershell
git commit -m "feat: Npc 网络急救 v2.0 首次发布"
```

正常输出会显示 `10 files changed, ...`。

### 3.6 如果报错 "detected dubious ownership"

管理员账户偶尔会触发，执行下面这行（把路径换成你的）：

```powershell
git config --global --add safe.directory "C:/Users/Administrator/Desktop/Npc修复网络-针对Ai弄坏网络的"
```

然后重新 `git add .` 和 `git commit`。

---

## 4. 在 GitHub 网页上创建远程仓库

1. 登录 GitHub，点右上角 **+** → **New repository**
2. 填写：

| 字段 | 填什么 |
| --- | --- |
| Repository name | `npc-net-repair`（英文小写 + 连字符，网址好看） |
| Description | 见下方“一句话简介”，可先留空，建完再填 |
| Public / Private | 选 **Public**（公开才能被搜到） |
| Add a README file | **不要勾** |
| Add .gitignore | **不要勾**（我们已经有了） |
| Choose a license | **不要选**（我们已经有了 LICENSE 文件） |

3. 点 **Create repository**

> 为什么不勾 README / .gitignore / LICENSE？
> 因为本地已经有了。网页上再生成一份，推送时会冲突，新手处理起来很麻烦。

创建成功后，页面会显示一段“quick setup”命令，**先别急着照抄**，用下面第 5 步的命令。

---

## 5. 关联远程仓库并推送

把下面命令里的 `你的用户名` 换成你的 GitHub 用户名（不是邮箱）：

```powershell
git remote add origin https://github.com/你的用户名/npc-net-repair.git
git branch -M main
git push -u origin main
```

### 第一次 push 会发生什么

1. 弹出 **Git Credential Manager** 窗口
2. 选 **Sign in with your browser**（用浏览器登录）
3. 浏览器打开 GitHub 授权页 → 点 **Authorize**
4. 回到 PowerShell，看到类似输出就成功了：

```text
Enumerating objects: 8, done.
Writing objects: 100% (8/8), 250.12 KiB | 1.2 MiB/s, done.
To https://github.com/你的用户名/npc-net-repair.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
```

5. 刷新 GitHub 页面，文件应该都在了。

### 如果没弹登录窗口，或者提示密码错误

GitHub 早就不允许用账号密码推送了。两个办法：

**办法 A：用浏览器登录（推荐）**

```powershell
git config --global credential.helper manager
git push -u origin main
```

**办法 B：用 Personal Access Token（PAT）**

1. 点头像 → **Settings** → 左侧最下面 **Developer settings**
2. **Personal access tokens** → **Tokens (classic)** → **Generate new token (classic)**
3. Note 随便写（如 `npc-net-repair`），Expiration 选 90 days
4. 勾选 **repo** 这一整项
5. 点 **Generate token**，复制那串 `ghp_xxxxx`
6. 回到 PowerShell 再 `git push`，弹出的密码框里**粘贴 token**（不是账号密码）

> Token 只显示一次，别截图、别写进 README、别发给别人。

---

## 6. 填 About 和 Topics（让别人搜得到）

进入仓库首页：

1. 右侧 **About** 旁边有个 **齿轮图标** ⚙，点它
2. **Description** 粘贴：

```text
AI 工具 / 代理 / 抓包软件把 Windows 网络配置搞坏后，一键修复代理、hosts、DNS、Winsock，30–90 秒生效，无需重启电脑。
```

3. **Website** 留空
4. **Topics** 里一个一个粘贴（每粘一个按一次回车）：

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

5. 点 **Save changes**

---

## 7. 把 exe 发布成 Release（推荐做）

仓库里直接放 exe 也能下载，但用 Releases 更规范：版本清楚、下载按钮明显、以后更新不影响源码历史。

1. 进入仓库 → 右侧 **Releases** → **Create a new release**（或直接访问 `https://github.com/你的用户名/npc-net-repair/releases/new`）
2. **Choose a tag** → 输入 `v2.0.0` → 点 **Create new tag on publish**
3. **Release title** 填：`v2.0.0 · 首个公开版本`
4. **Describe this release** 粘贴：

```markdown
## Npc 网络急救 v2.0.0

一键修复被 AI 工具 / 代理 / 抓包软件改坏的网络配置，**无需重启**。

### 下载

- `Npc修复网络.exe` —— 单文件版，双击即用（推荐）
- `Npc修复网络.bat` + `Npc修复网络-GUI.ps1` + `Npc修复网络.ps1` —— 脚本版，放在同一目录运行

### 能修什么

- 代理劫持（WinINET / WinHTTP / 环境变量 / portproxy）
- hosts 污染
- Winsock / TCP/IP 协议栈损坏
- DNS 被篡改 / NRPT 策略残留
- 静态 IP 被写死、DHCP 拿不到地址
- 网卡被禁用、IPv4 绑定被取消
- 路由表异常、默认网关指向 0.0.0.0
- NCSI 异常导致的“无 Internet”黄色感叹号

### 说明

- 需要管理员权限
- 修复过程约 30–90 秒，中途断网 4–8 秒属正常
- 修复前自动全量备份到 `C:\ProgramData\NpcNetRepair\`
- 支持中英文系统自动切换
- MIT License
```

5. **Attach binaries**：把 `Npc修复网络.exe` 拖进去
6. 点 **Publish release**

可选：想要下载量统计，就把 Release 里 exe 的下载链接放到 README 顶部。

---

## 8. 上传前检查清单（照着打勾）

- [ ] `git status` 里没有日志、备份目录、`report_*.txt`、`last_verify.json`
- [ ] 没有任何账号、密码、Token、内网 IP、公司域名写进代码或截图
- [ ] `C:\ProgramData\NpcNetRepair\` 里的东西**一个都没**拖进项目文件夹
- [ ] exe 是最新版本（exe 内嵌了引擎，改了 `.ps1` 必须重新打包，否则 exe 里还是旧逻辑）
- [ ] 单个文件不超过 100 MB（本项目 exe 约 240 KB，没问题）
- [ ] 网页上 README 能正常显示（中文不乱码、表格能渲染）
- [ ] LICENSE 被 GitHub 识别（仓库首页右侧显示 “MIT license”）
- [ ] About 简介和 Topics 已填

---

## 9. 以后改了代码，怎么更新

```powershell
cd "C:\Users\Administrator\Desktop\Npc修复网络-针对Ai弄坏网络的"
git status
git add -A
git commit -m "fix: 修复 xxx 问题"
git push
```

如果同时更新了 exe：

1. 重新打包 exe
2. `git add Npc修复网络.exe` → `commit` → `push`
3. 或者新建一个 Release（`v2.0.1`）把新 exe 传上去

---

## 10. 常见报错速查

| 报错 | 原因 | 解决 |
| --- | --- | --- |
| `fatal: not a git repository` | 当前目录不对 | `cd` 到项目文件夹再执行 |
| `Author identity unknown` | 没配用户名邮箱 | 回到第 2 步 |
| `remote origin already exists` | 之前加过 remote | `git remote set-url origin https://github.com/用户名/仓库名.git` |
| `failed to push some refs` / `non-fast-forward` | 网页仓库里有本地没有的提交（比如建仓库时勾了 README） | `git pull --rebase origin main` 再 `git push`；实在搞不定就删掉网页仓库重建，别勾 README |
| `Authentication failed` | 用了账号密码 | 用第 5 步的浏览器登录或 PAT |
| `Support for password authentication was removed` | 同上 | 同上 |
| `OpenSSL SSL_read: Connection was reset` | 网络抖动 / 代理干扰 | 关掉系统代理再试，或 `git config --global http.proxy ""` |
| `LF will be replaced by CRLF` | Windows 换行符提示 | 无害，忽略；想彻底消掉：`git config --global core.autocrlf true` |
| `detected dubious ownership` | 文件夹属主与当前用户不一致 | `git config --global --add safe.directory "路径"` |
| 中文显示成乱码 | 终端编码不是 UTF-8 | 先执行 `chcp 65001`，再执行 git 命令 |
| 网页上没看到新文件 | 看错分支 / 缓存 | 确认在 `main` 分支，Ctrl+F5 强刷 |
| `filename too long` | 路径过长 | `git config --global core.longpaths true` |

---

## 11. 不想敲命令？用 GitHub Desktop（备选）

1. 下载 https://desktop.github.com/ 并安装，登录 GitHub 账号
2. **File → Add local repository** → 选项目文件夹
3. 如果提示 “not a git repository”，点 **create a repository**，名字填 `npc-net-repair`
4. 左下角填提交信息 → **Commit to main**
5. 顶部 **Publish repository** → 取消勾选 “Keep this code private” → **Publish**

效果和命令行完全一样，只是把命令变成了按钮。

---

## 12. 做完之后，你的仓库长这样

```text
https://github.com/你的用户名/npc-net-repair
├─ README.md               ← 首页展示的说明书
├─ LICENSE                 ← MIT
├─ .gitignore
├─ Npc修复网络.exe
├─ Npc修复网络.bat
├─ Npc修复网络-GUI.ps1
├─ Npc修复网络.ps1
├─ 使用说明.txt
├─ GitHub发布文案.md
├─ GitHub上传指南-新手版.md
└─ Releases → v2.0.0 → Npc修复网络.exe
```

把网址发给朋友，他打开就能看到介绍、直接下载。
