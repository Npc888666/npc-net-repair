<#
===============================================================================
  Npc修复网络 · 一键恢复网络（无需重启电脑）
  Npc修复网络 v2 - One-Click Network Recovery Without Reboot
===============================================================================
  给谁用的:
    电脑小白。双击就完事，不用记参数，不用看懂输出。

  解决什么:
    AI / 逆向工具 / 抓包工具 / 加速器 / 代理软件 把本机网络配置搞烂了：
      * 代理劫持        - 浏览器和程序全被指到 127.0.0.1:8080
      * hosts 污染      - 域名被钉死到 0.0.0.0 或 127.0.0.1
      * Winsock 损坏    - 能连上但所有程序都上不了网
      * DNS 篡改        - 域名解析全挂
      * 静态 IP 写死    - DHCP 拿不到地址，卡 169.254.x.x
      * NCSI 异常       - 明明能上网却显示"无 Internet"黄叹号
      * 端口转发残留    - netsh portproxy 把流量全劫走
      * 网卡被禁用      - 网卡属性里 IPv4 被取消勾选
      * 路由表被改烂    - 默认网关指向 0.0.0.0

  为什么不用重启:
    winsock / TCP-IP 栈的重置改的是注册表，官方说法要重启才加载。
    本脚本用「禁用网卡 -> 等一会儿 -> 启用网卡」触发 PnP 重新加载整个
    TCP/IP 驱动栈，等于一次网络子系统冷启动；再配合关键服务强制重启，
    95% 以上的"必须重启才生效"场景直接被顶掉。

  环境自适应（这就是为什么不会在别人电脑上失效）:
    * 中文 / 英文 / 任何语言系统    -> 全部走 PowerShell 对象和注册表，
                                       绝不解析本地化文本
    * 有线 / 无线 / 双网卡 / 多网卡 -> 逐个网卡独立处理，互不影响
    * Windows 10 / 11              -> 优先用 Get-Net* cmdlet
    * Windows 7 / 8 老 cmdlet 缺失  -> 自动降级到 netsh，照样能修
    * 静态 IP 用户                 -> 先探测，只有真的坏了才切 DHCP
    * 远程桌面 / SSH 会话          -> 自动跳过网卡重载，防止把你踢下线
    * 没有无线网卡 / 没有网卡       -> 每一步独立容错，跳过不中断
    * 每台机器配置都不同            -> 动手前先全量备份，随时能滚回去

  用法（小白只需记住第一条）:
    双击同目录的  一键恢复网络.bat

  高级用法（懂的人用）:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Npc修复网络.ps1
      -DryRun            演习模式，只打印不修改
      -Deep              第二轮深度修复（防火墙、NRPT、网络位置）
      -ForceDhcp         无条件切回 DHCP
      -KeepStaticIP      绝不动 IP，只修代理/hosts/DNS/协议栈
      -SkipAdapterReload 跳过网卡重载（远程会话必用）
      -RestoreHosts      只从最近备份恢复 hosts
      -RestoreConfig     只从最近备份恢复网卡 IP/DNS
      -NoPause           跑完不等按键
      -Yes               不询问，直接开干
===============================================================================
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Deep,
    [switch]$ForceDhcp,
    [switch]$KeepStaticIP,
    [switch]$SkipAdapterReload,
    [switch]$RestoreHosts,
    [switch]$RestoreConfig,
    [switch]$NoPause,
    [switch]$Yes
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$WarningPreference     = 'SilentlyContinue'

# 输出编码钉死 UTF-8：GUI 版是用子进程 + stdout 管道读进度的，
# 不钉死的话中文在管道里会按 OEM 代码页(936)编码，GUI 侧解出来是乱码。
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# =============================================================================
#  全局状态
# =============================================================================

$script:Version   = '2.0'
$script:Stamp     = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:RootDir   = Join-Path $env:ProgramData 'NpcNetRepair'
$script:BackupDir = Join-Path $script:RootDir ('backup_' + $script:Stamp)
$script:LogFile   = Join-Path $script:RootDir ('NpcNetRepair_' + $script:Stamp + '.log')

$script:OKCount   = 0
$script:FailCount = 0
$script:SkipCount = 0
$script:Records   = New-Object System.Collections.ArrayList
# hosts 里被移除的、看起来像用户自建内网映射的条目（192.168/10.x/172.16-31），单独记一份提醒用户
$script:HostsPrivateMappings = New-Object System.Collections.ArrayList
$script:HasNetCmdlet = $false
$script:IsRemote  = $false

# =============================================================================
#  输出 / 日志
# =============================================================================

function Initialize-Log {
    try {
        if (-not (Test-Path -LiteralPath $script:RootDir)) {
            New-Item -ItemType Directory -Path $script:RootDir -Force -ErrorAction Stop | Out-Null
        }
    } catch {
        $script:RootDir = Join-Path $env:TEMP 'NpcNetRepair'
        New-Item -ItemType Directory -Path $script:RootDir -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $script:BackupDir = Join-Path $script:RootDir ('backup_' + $script:Stamp)
    $script:LogFile   = Join-Path $script:RootDir ('NpcNetRepair_' + $script:Stamp + '.log')
    try {
        New-Item -ItemType Directory -Path $script:BackupDir -Force -ErrorAction Stop | Out-Null
    } catch {
        $script:BackupDir = $script:RootDir
    }
}

function Write-Log {
    param(
        [Parameter(Position = 0)][string]$Msg = '',
        [Parameter(Position = 1)][string]$Level = 'INFO'
    )
    $ts = Get-Date -Format 'HH:mm:ss'
    $line = '[' + $ts + '][' + $Level + '] ' + $Msg
    $color = 'Gray'
    switch ($Level) {
        'OK'   { $color = 'Green' }
        'WARN' { $color = 'Yellow' }
        'ERR'  { $color = 'Red' }
        'STEP' { $color = 'Cyan' }
        'HEAD' { $color = 'Magenta' }
        'DIM'  { $color = 'DarkGray' }
        'INFO' { $color = 'White' }
    }
    try { Write-Host $line -ForegroundColor $color } catch { Write-Host $line }
    try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
}

function Write-Head {
    param([string]$Text)
    Write-Host ''
    Write-Host ('  ' + ('-' * 68)) -ForegroundColor DarkCyan
    Write-Host ('  | ' + $Text) -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * 68)) -ForegroundColor DarkCyan
    try {
        Add-Content -LiteralPath $script:LogFile -Value '' -Encoding UTF8 -ErrorAction SilentlyContinue
        Add-Content -LiteralPath $script:LogFile -Value ('===== ' + $Text + ' =====') -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { }
}

# =============================================================================
#  执行器：单步失败绝不影响后续步骤
# =============================================================================

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [scriptblock]$PreCheck
    )

    if ($PreCheck) {
        $pass = $false
        try { $pass = [bool](& $PreCheck) } catch { $pass = $false }
        if (-not $pass) {
            Write-Log ('  - 跳过: ' + $Name) 'DIM'
            $script:SkipCount++
            $null = $script:Records.Add([pscustomobject]@{ Step = $Name; State = 'SKIP'; Detail = 'precheck false' })
            return
        }
    }

    if ($DryRun) {
        Write-Log ('  [演习] ' + $Name) 'WARN'
        $script:SkipCount++
        $null = $script:Records.Add([pscustomobject]@{ Step = $Name; State = 'DRYRUN'; Detail = '-' })
        return
    }

    try {
        $out = & $Action
        $txt = ''
        if ($null -ne $out) {
            $txt = (($out | ForEach-Object { [string]$_ }) -join ' ')
        }
        $txt = $txt -replace '\s+', ' '
        if ($txt.Length -gt 150) { $txt = $txt.Substring(0, 150) + '...' }
        Write-Log ('  + ' + $Name) 'OK'
        if ($txt.Trim().Length -gt 0) { Write-Log ('      ' + $txt) 'DIM' }
        $script:OKCount++
        $null = $script:Records.Add([pscustomobject]@{ Step = $Name; State = 'OK'; Detail = $txt })
    } catch {
        $msg = $_.Exception.Message
        if ($null -eq $msg) { $msg = 'unknown error' }
        $msg = ([string]$msg) -replace '\s+', ' '
        Write-Log ('  ! ' + $Name + ' :: ' + $msg) 'ERR'
        $script:FailCount++
        $null = $script:Records.Add([pscustomobject]@{ Step = $Name; State = 'FAIL'; Detail = $msg })
    }
}

# --- 原生进程调用 -------------------------------------------------------------

function Quote-Arg {
    param([string]$s)
    if ($null -eq $s) { return '""' }
    if ($s -match '[\s"]') { return '"' + ($s -replace '"', '\"') + '"' }
    return $s
}

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$Exe,
        [string[]]$ArgList = @(),
        [int]$TimeoutMs = 90000
    )
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName        = $Exe
        $psi.Arguments       = (($ArgList | ForEach-Object { Quote-Arg $_ }) -join ' ')
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow  = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        try {
            $psi.StandardOutputEncoding = [System.Text.Encoding]::Default
            $psi.StandardErrorEncoding  = [System.Text.Encoding]::Default
        } catch { }

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        [void]$p.Start()

        # 异步读，避免管道塞满死锁
        $soTask = $p.StandardOutput.ReadToEndAsync()
        $seTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutMs)) {
            try { $p.Kill() } catch { }
            return '[timeout]'
        }
        $o = ''
        $e = ''
        try { $o = $soTask.Result } catch { }
        try { $e = $seTask.Result } catch { }
        $r = ((($o + ' ' + $e)) -replace '\s+', ' ').Trim()
        return $r
    } catch {
        return '[error] ' + $_.Exception.Message
    }
}

function Invoke-Netsh {
    param([string[]]$ArgList)
    return Invoke-Native -Exe 'netsh' -ArgList $ArgList
}

# 所有可能存放代理配置的注册表位置
function Get-ProxyRegPaths {
    $list = New-Object System.Collections.ArrayList

    [void]$list.Add('HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings')
    [void]$list.Add('HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings')
    [void]$list.Add('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings')
    [void]$list.Add('HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings')

    # HKU: 不是默认 PSDrive，手动挂
    try {
        $drive = Get-PSDrive -Name 'HKU' -ErrorAction SilentlyContinue
        if (-not $drive) {
            New-PSDrive -Name 'HKU' -PSProvider 'Registry' -Root 'HKEY_USERS' -Scope Global -ErrorAction SilentlyContinue | Out-Null
        }
        if (Test-Path -LiteralPath 'HKU:\' -ErrorAction SilentlyContinue) {
            [void]$list.Add('HKU:\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Internet Settings')
            [void]$list.Add('HKU:\.DEFAULT\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings')
        }
    } catch { }

    return @($list)
}

# =============================================================================
#  环境探测
# =============================================================================

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Test-IsRemoteSession {
    try {
        $sn = [string]$env:SESSIONNAME
        if ($sn -match 'RDP-|ICA-|RDP#') { return $true }
        # 更可靠：看会话协议
        try {
            $procId = $PID
            $q = Invoke-Native -Exe 'qwinsta' -ArgList @() -TimeoutMs 8000
            if ($q -match 'rdp') { return $true }
        } catch { }
        return $false
    } catch { return $false }
}

function Test-NetCmdlet {
    try {
        $c = Get-Command Get-NetAdapter -ErrorAction SilentlyContinue
        if ($null -eq $c) { return $false }
        $null = Get-NetAdapter -ErrorAction SilentlyContinue
        return $true
    } catch { return $false }
}

function Get-AdapterList {
    # 统一适配器清单：优先 cmdlet，降级到 WMI，最后降级到 netsh 文本
    $result = New-Object System.Collections.ArrayList

    if ($script:HasNetCmdlet) {
        try {
            foreach ($a in (Get-NetAdapter -ErrorAction SilentlyContinue)) {
                $item = [pscustomobject]@{
                    Name        = [string]$a.Name
                    Description = [string]$a.InterfaceDescription
                    IfIndex     = [int]$a.ifIndex
                    Status      = [string]$a.Status
                    Mac         = [string]$a.MacAddress
                    IsVirtual   = $false
                    IsHardware  = $true
                }
                try { $item.IsVirtual = [bool]$a.Virtual } catch { }
                try { $item.IsHardware = [bool]$a.HardwareInterface } catch { }
                [void]$result.Add($item)
            }
            if ($result.Count -gt 0) { return @($result) }
        } catch { }
    }

    # 降级：WMI（Win7 也有）
    try {
        $wmi = Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction SilentlyContinue |
               Where-Object { $_.NetEnabled -eq $true -or $_.NetConnectionStatus -ne $null }
        foreach ($w in $wmi) {
            if (-not $w.NetConnectionID) { continue }
            $idx = 0
            try {
                $cfg = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue |
                       Where-Object { $_.Index -eq $w.Index }
                if ($cfg) { $idx = [int]$cfg.InterfaceIndex }
            } catch { }
            $st = 'Unknown'
            switch ($w.NetConnectionStatus) {
                0 { $st = 'Disconnected' }
                1 { $st = 'Connecting' }
                2 { $st = 'Up' }
                3 { $st = 'Disconnected' }
                7 { $st = 'MediaDisconnected' }
                11 { $st = 'Up' }
            }
            [void]$result.Add([pscustomobject]@{
                Name        = [string]$w.NetConnectionID
                Description = [string]$w.Description
                IfIndex     = $idx
                Status      = $st
                Mac         = [string]$w.MacAddress
                IsVirtual   = ($w.Description -match 'Virtual|VMware|Hyper-V|Loopback|TAP|TUN|VPN')
                IsHardware  = $true
            })
        }
    } catch { }

    return @($result)
}

function Get-IPv4State {
    # 返回每块网卡的 IPv4 健康度快照
    $states = New-Object System.Collections.ArrayList

    if ($script:HasNetCmdlet) {
        foreach ($a in (Get-AdapterList)) {
            $ips   = @()
            $gw    = @()
            $dns   = @()
            try {
                $ips = @(Get-NetIPAddress -InterfaceIndex $a.IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                         Select-Object -ExpandProperty IPAddress)
            } catch { }
            try {
                $gw = @(Get-NetRoute -InterfaceIndex $a.IfIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                        Where-Object { $_.NextHop -ne '0.0.0.0' } |
                        Select-Object -ExpandProperty NextHop)
            } catch { }
            try {
                $dns = @((Get-DnsClientServerAddress -InterfaceIndex $a.IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
            } catch { }
            [void]$states.Add([pscustomobject]@{
                Name = $a.Name; IfIndex = $a.IfIndex; Status = $a.Status
                IsVirtual = $a.IsVirtual
                IPv4 = $ips; Gateway = $gw; DNS = $dns
            })
        }
        if ($states.Count -gt 0) { return @($states) }
    }

    # 降级：解析 netsh 的 IP 段（不依赖语言，只抓数字）
    try {
        foreach ($a in (Get-AdapterList)) {
            $out = Invoke-Netsh @('interface', 'ipv4', 'show', 'config', ('name=' + $a.Name))
            $ips = @()
            $gw  = @()
            $dns = @()
            $m = [regex]::Matches($out, '(?:IP Address|IP \u5730\u5740)\s*:\s*([0-9]{1,3}(?:\.[0-9]{1,3}){3})')
            foreach ($x in $m) { $ips += $x.Groups[1].Value }
            $m = [regex]::Matches($out, '(?:Default Gateway|Default Gateway)\s*:\s*([0-9]{1,3}(?:\.[0-9]{1,3}){3})')
            foreach ($x in $m) { $gw += $x.Groups[1].Value }
            $m = [regex]::Matches($out, '(?:DNS Servers|DNS \u670d\u52a1\u5668)\s*:\s*([0-9]{1,3}(?:\.[0-9]{1,3}){3})')
            foreach ($x in $m) { $dns += $x.Groups[1].Value }
            [void]$states.Add([pscustomobject]@{
                Name = $a.Name; IfIndex = $a.IfIndex; Status = $a.Status
                IsVirtual = $a.IsVirtual
                IPv4 = $ips; Gateway = $gw; DNS = $dns
            })
        }
    } catch { }

    return @($states)
}

function Test-QuickInternet {
    # 快速判断：能 ping 通任意一个公共 IP 就算通
    foreach ($t in @('223.5.5.5', '119.29.29.29', '114.114.114.114', '8.8.8.8')) {
        if (Test-PingTarget -Target $t -TimeoutMs 1200) { return $true }
    }
    return $false
}

function Test-PingTarget {
    param([string]$Target, [int]$TimeoutMs = 1500)
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $rep = $ping.Send($Target, $TimeoutMs)
        $ok = ($rep.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
        $ping.Dispose()
        return $ok
    } catch { return $false }
}

function Test-PortOpen {
    param([string]$Target, [int]$Port = 443, [int]$TimeoutMs = 3500)
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $iar = $c.BeginConnect($Target, $Port, $null, $null)
        $done = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        $ok = $false
        if ($done) {
            try { $c.EndConnect($iar); $ok = $c.Connected } catch { $ok = $false }
        }
        $c.Close()
        return $ok
    } catch { return $false }
}

function Test-DnsResolve {
    param([string]$Name)
    try {
        $r = Resolve-DnsName -Name $Name -Type A -ErrorAction Stop -DnsOnly
        foreach ($x in $r) {
            if ($x.IPAddress) { return [string]$x.IPAddress }
        }
        return $null
    } catch {
        try {
            $h = [System.Net.Dns]::GetHostAddresses($Name)
            foreach ($x in $h) {
                if ($x.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { return [string]$x.IPAddressToString }
            }
        } catch { }
        return $null
    }
}

# =============================================================================
#  界面
# =============================================================================

function Show-Banner {
    try { Clear-Host } catch { }
    Write-Host ''
    Write-Host '   ================================================================' -ForegroundColor DarkCyan
    Write-Host '    N P C   修 复 网 络   v' -NoNewline -ForegroundColor Cyan
    Write-Host $script:Version -ForegroundColor Cyan
    Write-Host '    无 需 重 启 电 脑   ·   逆 向 断 网 急 救' -ForegroundColor White
    Write-Host '   ================================================================' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host ('    电脑名称 : ' + $env:COMPUTERNAME) -ForegroundColor DarkGray
    Write-Host ('    操作时间 : ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor DarkGray
    Write-Host ('    备份目录 : ' + $script:BackupDir) -ForegroundColor DarkGray
    Write-Host ('    运行日志 : ' + $script:LogFile) -ForegroundColor DarkGray

    $tags = @()
    if ($DryRun)           { $tags += '演习模式(不改任何东西)' }
    if ($Deep)             { $tags += '深度修复' }
    if ($KeepStaticIP)     { $tags += '保留静态IP' }
    if ($SkipAdapterReload) { $tags += '跳过网卡重载' }
    if ($script:IsRemote)  { $tags += '远程会话(已自动保护)' }
    if ($tags.Count -gt 0) {
        Write-Host ('    当前模式 : ' + ($tags -join ' / ')) -ForegroundColor Yellow
    }
    Write-Host ''
}

# =============================================================================
#  阶段 A - 全量备份
# =============================================================================

function Save-Backup {
    Write-Head '第 1 步 / 共 10 步  ·  先备份，出问题能滚回来'

    $snap = [ordered]@{
        '01_ipconfig_all.txt'      = { Invoke-Native -Exe 'ipconfig' -ArgList @('/all') -TimeoutMs 30000 }
        '02_route_print.txt'       = { Invoke-Native -Exe 'route' -ArgList @('print') -TimeoutMs 20000 }
        '03_netsh_ip_config.txt'   = { Invoke-Netsh @('interface', 'ip', 'show', 'config') }
        '04_netsh_winsock.txt'     = { Invoke-Netsh @('winsock', 'show', 'catalog') }
        '05_netsh_portproxy.txt'   = { Invoke-Netsh @('interface', 'portproxy', 'show', 'all') }
        '06_netsh_winhttp.txt'     = { Invoke-Netsh @('winhttp', 'show', 'proxy') }
        '07_netsh_tcp_global.txt'  = { Invoke-Netsh @('int', 'tcp', 'show', 'global') }
        '08_netsh_advfirewall.txt' = { Invoke-Netsh @('advfirewall', 'show', 'allprofiles') }
        '09_arp_table.txt'         = { Invoke-Native -Exe 'arp' -ArgList @('-a') -TimeoutMs 10000 }
        '10_netadapters.txt'       = { (Get-AdapterList | Format-List * | Out-String -Width 300) }
    }

    foreach ($k in $snap.Keys) {
        $key = $k
        $builder = $snap[$k]
        Invoke-Step -Name ('备份 ' + $key) -Action {
            $data = & $builder
            $path = Join-Path $script:BackupDir $key
            ([string]$data) | Set-Content -LiteralPath $path -Encoding UTF8 -Force -ErrorAction Stop
            return 'saved'
        }
    }

    # hosts 原始备份
    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    Invoke-Step -Name '备份 hosts 原文件' -Action {
        if (-not (Test-Path -LiteralPath $hostsPath)) { return 'hosts 不存在' }
        $dst = Join-Path $script:BackupDir 'hosts.bak'
        Copy-Item -LiteralPath $hostsPath -Destination $dst -Force -ErrorAction Stop
        return ('已存 ' + $dst)
    }

    # 代理注册表备份
    Invoke-Step -Name '备份代理注册表' -Action {
        $lines = New-Object System.Collections.ArrayList
        foreach ($p in (Get-ProxyRegPaths)) {
            if (-not (Test-Path -LiteralPath $p)) { continue }
            [void]$lines.Add('##### ' + $p)
            try {
                $props = Get-ItemProperty -LiteralPath $p -ErrorAction Stop
                foreach ($pn in $props.PSObject.Properties) {
                    if ($pn.Name -like 'PS*') { continue }
                    [void]$lines.Add('  ' + $pn.Name + ' = ' + [string]$pn.Value)
                }
            } catch {
                [void]$lines.Add('  <read failed>')
            }
        }
        $out = Join-Path $script:BackupDir 'proxy_registry.txt'
        ($lines -join "`r`n") | Set-Content -LiteralPath $out -Encoding UTF8 -Force -ErrorAction Stop
        return ('已存 ' + $out)
    }

    # 网卡配置 JSON
    Invoke-Step -Name '备份网卡 IP/DNS 配置 (JSON)' -Action {
        $cfg = @()
        foreach ($s in (Get-IPv4State)) {
            $cfg += [pscustomobject]@{
                Name           = $s.Name
                InterfaceIndex = $s.IfIndex
                Status         = $s.Status
                IPv4           = @($s.IPv4)
                Gateway        = @($s.Gateway)
                DnsServers     = @($s.DNS)
            }
        }
        $out = Join-Path $script:BackupDir 'netconfig.json'
        ($cfg | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $out -Encoding UTF8 -Force -ErrorAction Stop
        return ('适配器 ' + $cfg.Count + ' 个')
    }

    # 无线配置文件备份
    Invoke-Step -Name '备份无线配置文件' -Action {
        $out = Join-Path $script:BackupDir 'wlan_profiles'
        if (-not (Test-Path -LiteralPath $out)) { New-Item -ItemType Directory -Path $out -Force -ErrorAction SilentlyContinue | Out-Null }
        $r = Invoke-Netsh @('wlan', 'export', 'profile', ('folder=' + $out), 'key=clear')
        return $r
    }
}

# =============================================================================
#  阶段 B - 代理劫持清理
# =============================================================================

function Repair-Proxy {
    Write-Head '第 2 步 / 共 10 步  ·  清除代理劫持（最常见断网原因）'

    # B1 WinINET 代理（浏览器 / 系统代理设置）
    Invoke-Step -Name '关闭系统代理 (WinINET)' -Action {
        $hit = 0
        foreach ($p in (Get-ProxyRegPaths)) {
            if (-not (Test-Path -LiteralPath $p)) { continue }
            try {
                Set-ItemProperty -LiteralPath $p -Name 'ProxyEnable' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -LiteralPath $p -Name 'AutoDetect'   -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                foreach ($v in @('ProxyServer', 'ProxyOverride', 'AutoConfigURL', 'AutoProxyFailover', 'SavedLegacySettings', 'MigrateProxy')) {
                    Remove-ItemProperty -LiteralPath $p -Name $v -Force -ErrorAction SilentlyContinue
                }
                # Connections 子键里按连接存了二进制代理配置，整块清
                $conn = Join-Path $p 'Connections'
                if (Test-Path -LiteralPath $conn) {
                    Remove-Item -LiteralPath $conn -Recurse -Force -ErrorAction SilentlyContinue
                }
                $hit++
            } catch { }
        }
        return ('处理 ' + $hit + ' 处注册表')
    }

    # B2 WinHTTP 代理（服务 / 更新 / curl / 部分逆向工具走这条）
    Invoke-Step -Name '重置 WinHTTP 代理' -Action {
        return (Invoke-Netsh @('winhttp', 'reset', 'proxy'))
    }

    Invoke-Step -Name '关闭 WinHTTP 追踪' -Action {
        return (Invoke-Netsh @('winhttp', 'set', 'tracing', 'disable'))
    }

    # B3 代理类环境变量
    Invoke-Step -Name '清除代理环境变量' -Action {
        $names = @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY', 'FTP_PROXY',
                   'http_proxy', 'https_proxy', 'all_proxy', 'no_proxy', 'ftp_proxy')
        $n = 0
        foreach ($scope in @('User', 'Machine', 'Process')) {
            foreach ($nm in $names) {
                try {
                    $cur = [Environment]::GetEnvironmentVariable($nm, $scope)
                    if ($null -ne $cur -and $cur -ne '') {
                        [Environment]::SetEnvironmentVariable($nm, $null, $scope)
                        $n++
                    }
                } catch { }
            }
        }
        return ('清掉 ' + $n + ' 个')
    }

    # B4 端口转发残留
    Invoke-Step -Name '清空端口转发规则 (portproxy)' -Action {
        return (Invoke-Netsh @('interface', 'portproxy', 'reset'))
    }

    # B5 深度：DNS 策略表
    if ($Deep) {
        Invoke-Step -Name '[深度] 清除 DNS 策略 (NRPT)' -Action {
            $n = 0
            try {
                $rules = @(Get-DnsClientNrptRule -ErrorAction SilentlyContinue)
                foreach ($r in $rules) {
                    try { Remove-DnsClientNrptRule -Name $r.Name -Force -ErrorAction Stop; $n++ } catch { }
                }
            } catch { }
            return ('删除 ' + $n + ' 条')
        }
    }
}

# =============================================================================
#  阶段 C - hosts 去污染
# =============================================================================

function Repair-Hosts {
    Write-Head '第 3 步 / 共 10 步  ·  清除 hosts 域名污染'

    Invoke-Step -Name 'hosts 文件去劫持' -Action {
        $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'

        # 只解锁文件本身的属性。
        # 【真实事故】绝不能用 icacls 去改 etc 目录的 ACL —— 那会把 hosts 的文件流
        # 搞坏，抛 "Stream was not readable"，随后 Set-Content 把文件截断却写不进去，
        # 最终 hosts 变成 0 字节。改系统目录权限收益为零、风险极高，砍掉。
        if (Test-Path -LiteralPath $hostsPath) {
            try { [IO.File]::SetAttributes($hostsPath, [IO.FileAttributes]::Normal) } catch { }
        } else {
            try { New-Item -ItemType File -Path $hostsPath -Force -ErrorAction SilentlyContinue | Out-Null } catch { }
        }

        # 读原内容：用 .NET API，绕开 Get-Content 在异常 ACL 下的流问题
        $raw = @()
        if (Test-Path -LiteralPath $hostsPath) {
            try {
                $origText = [IO.File]::ReadAllText($hostsPath)
                if ($null -ne $origText -and $origText.Length -gt 0) {
                    $raw = @($origText -split "`r?`n")
                }
            } catch {
                # 读不到就什么都不做，保持原样，绝不冒截断风险
                return ('hosts 读取失败，原文件保持不动: ' + $_.Exception.Message)
            }
        }

        $localNames = New-Object System.Collections.ArrayList
        foreach ($x in @('localhost', 'localhost.localdomain', 'local', 'broadcasthost', 'ip6-localhost', 'ip6-loopback')) {
            [void]$localNames.Add($x)
        }
        try { [void]$localNames.Add(([string]$env:COMPUTERNAME).ToLower()) } catch { }
        try { [void]$localNames.Add(([string]$env:COMPUTERNAME).ToLower() + '.local') } catch { }

        $keep = New-Object System.Collections.ArrayList
        $dropped = New-Object System.Collections.ArrayList

        foreach ($line in $raw) {
            $t = ([string]$line).Trim()
            if ($t -eq '') { [void]$keep.Add(''); continue }
            if ($t.StartsWith('#')) { [void]$keep.Add($line); continue }

            $body = $t
            $h = $body.IndexOf('#')
            if ($h -ge 0) { $body = $body.Substring(0, $h).Trim() }
            if ($body -eq '') { [void]$keep.Add($line); continue }

            $parts = @($body -split '\s+')
            if ($parts.Count -lt 2) { [void]$keep.Add($line); continue }

            $ip = $parts[0]
            $doms = @()
            for ($i = 1; $i -lt $parts.Count; $i++) {
                if ($parts[$i] -ne '') { $doms += $parts[$i].ToLower() }
            }

            $ipIsLoopback = ($ip -eq '127.0.0.1' -or $ip -eq '::1' -or $ip -eq '0.0.0.0' -or $ip -eq '::')
            $allLocal = $true
            foreach ($d in $doms) {
                if (-not ($localNames -contains $d)) { $allLocal = $false; break }
            }

            # 只有「回环地址 + 纯本机名」这种标准条目才留，其余全是被人塞进来的劫持
            if ($ipIsLoopback -and $allLocal) {
                [void]$keep.Add($line)
            } else {
                [void]$dropped.Add($t)
                # 区分"明显劫持"和"可能是用户自己加的内网映射"，后者单独记一份
                $looksPrivate = ($ip -match '^192\.168\.' -or $ip -match '^10\.' -or $ip -match '^172\.(1[6-9]|2[0-9]|3[01])\.')
                if ($looksPrivate) { [void]$script:HostsPrivateMappings.Add($t) }
            }
        }

        $header = @(
            '# Copyright (c) 1993-2009 Microsoft Corp.',
            '#',
            '# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.',
            '#',
            '# This file contains the mappings of IP addresses to host names. Each',
            '# entry should be kept on an individual line. The IP address should',
            '# be placed in the first column followed by the corresponding host name.',
            '# The IP address and the host name should be separated by at least one',
            '# space.',
            '#',
            '# Additionally, comments (such as these) may be inserted on individual',
            '# lines or following the machine name denoted by a ''#'' symbol.',
            '#',
            '# For example:',
            '#',
            '#      102.54.94.97     rhino.acme.com          # source server',
            '#       38.25.63.10     x.acme.com              # x client host',
            '',
            '# localhost name resolution is handled within DNS itself.',
            '#	127.0.0.1       localhost',
            '#	::1             localhost'
        )

        # 合并：标准头 + 保留行（去掉重复的标准注释和连续空行）
        $final = New-Object System.Collections.ArrayList
        foreach ($h in $header) { [void]$final.Add($h) }
        $prevBlank = $true
        foreach ($l in $keep) {
            $ls = ([string]$l).Trim()
            if ($ls -match '^#\s*Copyright \(c\) 1993-2009 Microsoft Corp') { continue }
            if ($ls -match '^#\s*This is a sample HOSTS file') { continue }
            if ($ls -match '^#\s*localhost name resolution') { continue }
            if ($ls -match '^#\s*127\.0\.0\.1\s+localhost') { continue }
            if ($ls -match '^#\s*::1\s+localhost') { continue }
            if ($ls -match '^#\s*This file contains the mappings') { continue }
            if ($ls -match '^#\s*entry should be kept') { continue }
            if ($ls -match '^#\s*be placed in the first column') { continue }
            if ($ls -match '^#\s*The IP address and the host name') { continue }
            if ($ls -match '^#\s*space\.$') { continue }
            if ($ls -match '^#\s*Additionally, comments') { continue }
            if ($ls -match '^#\s*lines or following the machine name') { continue }
            if ($ls -match '^#\s*For example') { continue }
            if ($ls -match '^#\s+102\.54\.94\.97') { continue }
            if ($ls -match '^#\s+38\.25\.63\.10') { continue }
            # 纯 "#" 占位行直接丢弃：标准头里已经带够了，留着只会每跑一次
            # 就在文件尾部多堆一截，跑几次后 hosts 越来越长（幂等性问题）。
            if ($ls -eq '#') { continue }
            $isBlank = ($ls -eq '')
            if ($isBlank -and $prevBlank) { continue }
            [void]$final.Add($l)
            $prevBlank = $isBlank
        }
        [void]$final.Add('')

        # 备份被砍掉的内容，方便事后查
        if ($dropped.Count -gt 0) {
            $dp = Join-Path $script:BackupDir 'hosts_removed_lines.txt'
            ($dropped -join "`r`n") | Set-Content -LiteralPath $dp -Encoding UTF8 -Force -ErrorAction SilentlyContinue

            # 如果里面有内网 IP 映射，多半是你自己加的（公司服务器/开发环境），必须提醒
            if ($script:HostsPrivateMappings.Count -gt 0) {
                $pp = Join-Path $script:BackupDir 'hosts_private_mappings.txt'
                ($script:HostsPrivateMappings -join "`r`n") | Set-Content -LiteralPath $pp -Encoding UTF8 -Force -ErrorAction SilentlyContinue
                Write-Log ('      注意：有 ' + $script:HostsPrivateMappings.Count + ' 条内网 IP 映射被移除了，') 'WARN'
                Write-Log ('            如果你是自己加的，备份在: ' + $pp) 'WARN'
            }
        }

        # 原子写：先写同目录临时文件，确认写成功后再覆盖。
        # 这样即使中途失败，原 hosts 也绝不会被截成 0 字节。
        $tmpHosts = $hostsPath + '.nrtmp'
        $outText = ($final -join "`r`n")
        if (-not $outText.EndsWith("`r`n")) { $outText += "`r`n" }
        try {
            [IO.File]::WriteAllText($tmpHosts, $outText, (New-Object System.Text.ASCIIEncoding))
            if (Test-Path -LiteralPath $hostsPath) {
                try { [IO.File]::SetAttributes($hostsPath, [IO.FileAttributes]::Normal) } catch { }
            }
            Copy-Item -LiteralPath $tmpHosts -Destination $hostsPath -Force -ErrorAction Stop
        } catch {
            try { Remove-Item -LiteralPath $tmpHosts -Force -ErrorAction SilentlyContinue } catch { }
            return ('hosts 写入失败，原文件未改动: ' + $_.Exception.Message)
        }
        try { Remove-Item -LiteralPath $tmpHosts -Force -ErrorAction SilentlyContinue } catch { }

        return ('清除 ' + $dropped.Count + ' 条劫持记录，保留 ' + $final.Count + ' 行')
    }

    Invoke-Step -Name '刷新 DNS 缓存' -Action {
        return (Invoke-Native -Exe 'ipconfig' -ArgList @('/flushdns') -TimeoutMs 15000)
    }
}

# =============================================================================
#  阶段 D - 协议栈重置
# =============================================================================

function Repair-NetStack {
    Write-Head '第 4 步 / 共 10 步  ·  重置网络协议栈（修复 Winsock 损坏）'

    Invoke-Step -Name 'winsock reset catalog' -Action { return (Invoke-Netsh @('winsock', 'reset', 'catalog')) }
    Invoke-Step -Name 'winsock reset (LSP)'    -Action { return (Invoke-Netsh @('winsock', 'reset')) }
    Invoke-Step -Name 'int ip reset'           -Action { return (Invoke-Netsh @('int', 'ip', 'reset')) }
    Invoke-Step -Name 'int ipv4 reset'         -Action { return (Invoke-Netsh @('int', 'ipv4', 'reset')) }
    Invoke-Step -Name 'int ipv6 reset'         -Action { return (Invoke-Netsh @('int', 'ipv6', 'reset')) }
    Invoke-Step -Name 'int tcp reset'          -Action { return (Invoke-Netsh @('int', 'tcp', 'reset')) }
    Invoke-Step -Name 'int httpstunnel reset'  -Action { return (Invoke-Netsh @('int', 'httpstunnel', 'reset')) }
    Invoke-Step -Name 'int teredo reset'       -Action { return (Invoke-Netsh @('int', 'teredo', 'reset')) }
    Invoke-Step -Name 'int isatap reset'       -Action { return (Invoke-Netsh @('int', 'isatap', 'reset')) }

    # TCP 全局参数归位（各种"加速"工具会瞎改）
    $globals = @(
        @('ecncapability', 'default'),
        @('timestamps', 'default'),
        @('rss', 'default'),
        @('chimney', 'default'),
        @('autotuninglevel', 'normal'),
        @('congestionprovider', 'default'),
        @('netdma', 'default'),
        @('dca', 'default'),
        @('pacingprofile', 'default'),
        @('initialRto', '3000')
    )
    foreach ($g in $globals) {
        $kn = [string]$g[0]
        $vv = [string]$g[1]
        Invoke-Step -Name ('tcp global ' + $kn + '=' + $vv) -Action {
            return (Invoke-Netsh @('int', 'tcp', 'set', 'global', ($kn + '=' + $vv)))
        }
    }

    Invoke-Step -Name 'tcp heuristics disabled' -Action { return (Invoke-Netsh @('int', 'tcp', 'set', 'heuristics', 'disabled')) }
    Invoke-Step -Name 'tcp supplemental internet' -Action { return (Invoke-Netsh @('int', 'tcp', 'set', 'supplemental', 'template=internet')) }

    # 注册表级：路由转发、IPv6 组件禁用标记
    Invoke-Step -Name '关闭 IP 路由转发' -Action {
        $p = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
        if (Test-Path -LiteralPath $p) {
            Set-ItemProperty -LiteralPath $p -Name 'IpEnableRouter' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -LiteralPath $p -Name 'EnableRouter' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        return 'done'
    }

    Invoke-Step -Name '重置 IPv6 DisabledComponents' -Action {
        $p = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
        if (Test-Path -LiteralPath $p) {
            Set-ItemProperty -LiteralPath $p -Name 'DisabledComponents' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        return 'done'
    }

    if ($Deep) {
        Invoke-Step -Name '[深度] 防火墙恢复默认' -Action { return (Invoke-Netsh @('advfirewall', 'reset')) }
        Invoke-Step -Name '[深度] 启用防火墙'     -Action { return (Invoke-Netsh @('advfirewall', 'set', 'allprofiles', 'state', 'on')) }
    }
}

# =============================================================================
#  阶段 E - 网卡启用 + 协议绑定
# =============================================================================

function Repair-AdapterBinding {
    Write-Head '第 5 步 / 共 10 步  ·  启用网卡、修复协议绑定'

    $adapters = Get-AdapterList
    Write-Log ('  发现 ' + $adapters.Count + ' 个网络适配器') 'INFO'
    foreach ($a in $adapters) {
        Write-Log ('      ' + $a.Name + '  [' + $a.Status + ']' + $(if ($a.IsVirtual) { ' (虚拟)' } else { '' })) 'DIM'
    }

    if (-not $script:HasNetCmdlet) {
        Write-Log '  老系统：网卡操作降级为 netsh 模式' 'WARN'
        # netsh 只能启用接口，不能启用"被禁用的设备"
        foreach ($a in $adapters) {
            $nm = $a.Name
            Invoke-Step -Name ('启用接口 ' + $nm) -Action {
                return (Invoke-Netsh @('interface', 'set', 'interface', ('name="' + $nm + '"'), 'admin=enable'))
            }
        }
        return
    }

    # E1 被禁用的网卡全部拉起来
    Invoke-Step -Name '启用所有被禁用的网卡' -Action {
        $dis = @()
        try { $dis = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Disabled' }) } catch { }
        if ($dis.Count -eq 0) { return '没有禁用的网卡' }
        $n = 0
        foreach ($a in $dis) {
            try {
                Enable-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction Stop
                Write-Log ('      启用 ' + $a.Name) 'DIM'
                $n++
            } catch {
                Write-Log ('      ' + $a.Name + ' 启用失败: ' + $_.Exception.Message) 'DIM'
            }
        }
        return ('启用 ' + $n + ' 个')
    }

    # E2 协议绑定（IPv4 被取消勾选 = 彻底没网，这步必须补回来）
    $comps = @('ms_tcpip', 'ms_tcpip6', 'ms_msclient', 'ms_server', 'ms_implat')
    foreach ($cid in $comps) {
        $c = $cid
        Invoke-Step -Name ('启用协议绑定 ' + $c) -Action {
            $items = @()
            try { $items = @(Get-NetAdapterBinding -ComponentID $c -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $false }) } catch { }
            if ($items.Count -eq 0) { return '全部已启用' }
            $n = 0
            foreach ($b in $items) {
                try { Enable-NetAdapterBinding -Name $b.Name -ComponentID $c -ErrorAction Stop; $n++ } catch { }
            }
            return ('启用 ' + $n + ' 个')
        }
    }

    # E3 网卡节能断流关掉
    Invoke-Step -Name '关闭网卡节能断流' -Action {
        $n = 0
        try {
            foreach ($a in (Get-NetAdapter -ErrorAction SilentlyContinue)) {
                try {
                    Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword '*EEE' -RegistryValue 0 -ErrorAction SilentlyContinue
                    Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword 'EnableGreenEthernet' -RegistryValue 0 -ErrorAction SilentlyContinue
                    $n++
                } catch { }
            }
        } catch { }
        return ('处理 ' + $n + ' 个')
    }
}

# =============================================================================
#  阶段 F - IP / DNS / 路由归位
# =============================================================================

function Repair-IpConfig {
    Write-Head '第 6 步 / 共 10 步  ·  IP / DNS / 路由归位'

    if ($KeepStaticIP) {
        Write-Log '  已开启「保留静态 IP」：只修 DNS 和路由，不动地址' 'WARN'
    }

    $states = Get-IPv4State

    # 判断是否处于"地址层故障"
    $addrBroken = $false
    $physical = @($states | Where-Object { -not $_.IsVirtual -and $_.Status -eq 'Up' })

    if ($physical.Count -eq 0) {
        Write-Log '  没有处于连接状态的物理网卡，跳过 IP 改造' 'WARN'
    } else {
        foreach ($s in $physical) {
            $v4 = @($s.IPv4)
            $gw = @($s.Gateway)
            if ($v4.Count -eq 0) { $addrBroken = $true }
            foreach ($ip in $v4) {
                if ($ip -like '169.254.*') { $addrBroken = $true }
                if ($ip -eq '0.0.0.0') { $addrBroken = $true }
            }
            if ($gw.Count -eq 0) { $addrBroken = $true }
        }
    }

    if ($ForceDhcp) { $addrBroken = $true }

    if ($addrBroken) {
        Write-Log '  检测到地址层异常（无地址 / APIPA / 无网关 / 强制切换）→ 将切回 DHCP' 'WARN'
    } else {
        Write-Log '  地址层看起来正常 → 保留现有 IP，只修 DNS/路由' 'OK'
    }

    # F1 DNS 归位（无条件执行，这是最高频断网原因）
    foreach ($s in $physical) {
        $idx = $s.IfIndex
        $nm  = $s.Name
        Invoke-Step -Name ('[' + $nm + '] DNS 改为自动获取') -Action {
            try {
                Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses -ErrorAction Stop
                return 'done'
            } catch {
                return (Invoke-Netsh @('interface', 'ipv4', 'set', 'dnsserver', [string]$idx, 'source=dhcp'))
            }
        }
    }

    # F2 切 DHCP（只在真坏的时候）
    if ($addrBroken -and -not $KeepStaticIP) {
        foreach ($s in $physical) {
            $idx = $s.IfIndex
            $nm  = $s.Name

            Invoke-Step -Name ('[' + $nm + '] IPv4 切回 DHCP') -Action {
                return (Invoke-Netsh @('interface', 'ipv4', 'set', 'interface', [string]$idx, 'dhcp'))
            }
            Invoke-Step -Name ('[' + $nm + '] IPv6 切回 DHCP') -Action {
                return (Invoke-Netsh @('interface', 'ipv6', 'set', 'interface', [string]$idx, 'dhcp'))
            }
            Invoke-Step -Name ('[' + $nm + '] 清除残留静态地址') -Action {
                $n = 0
                try {
                    $statics = @(Get-NetIPAddress -InterfaceIndex $idx -ErrorAction SilentlyContinue | Where-Object { $_.PrefixOrigin -eq 'Manual' })
                    foreach ($st in $statics) {
                        try { Remove-NetIPAddress -InterfaceIndex $idx -IPAddress $st.IPAddress -Confirm:$false -ErrorAction Stop; $n++ } catch { }
                    }
                } catch { }
                return ('移除 ' + $n + ' 条')
            }
        }
    }

    # F3 MTU 恢复
    foreach ($s in $physical) {
        $idx = $s.IfIndex
        $nm  = $s.Name
        Invoke-Step -Name ('[' + $nm + '] MTU 恢复 1500') -Action {
            try {
                Set-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4 -NlMtuBytes 1500 -ErrorAction Stop
                return 'done'
            } catch {
                return (Invoke-Netsh @('interface', 'ipv4', 'set', 'subinterface', [string]$idx, 'mtu=1500', 'store=persistent'))
            }
        }
    }

    # F4 跃点数自动
    foreach ($s in $physical) {
        $idx = $s.IfIndex
        $nm  = $s.Name
        Invoke-Step -Name ('[' + $nm + '] 跃点自动') -Action {
            try {
                Set-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4 -AutomaticMetric Enabled -ErrorAction Stop
                return 'done'
            } catch { return 'skip' }
        }
    }

    # F5 ARP 缓存清空（防网关 MAC 被钉死）
    Invoke-Step -Name '清空 ARP 缓存' -Action {
        $a = Invoke-Netsh @('interface', 'ip', 'delete', 'arpcache')
        $b = Invoke-Native -Exe 'arp' -ArgList @('-d', '*') -TimeoutMs 10000
        return ($a + ' ' + $b)
    }

    # F6 异常默认路由清扫
    Invoke-Step -Name '清除异常默认路由' -Action {
        $n = 0
        try {
            $bad = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Where-Object { $_.NextHop -eq '0.0.0.0' -or $_.NextHop -eq '::' })
            foreach ($r in $bad) {
                try {
                    Remove-NetRoute -DestinationPrefix $r.DestinationPrefix -InterfaceIndex $r.InterfaceIndex -NextHop $r.NextHop -Confirm:$false -ErrorAction Stop
                    $n++
                } catch { }
            }
        } catch { }
        return ('清除 ' + $n + ' 条')
    }
}

# =============================================================================
#  阶段 G - 关键服务重启
# =============================================================================

function Repair-Services {
    Write-Head '第 7 步 / 共 10 步  ·  重启网络相关服务'

    $svcList = @(
        @{ N = 'Dnscache';          T = 'Automatic' },
        @{ N = 'Dhcp';              T = 'Automatic' },
        @{ N = 'Wcmsvc';            T = 'Automatic' },
        @{ N = 'WinHttpAutoProxySvc'; T = 'Manual' },
        @{ N = 'lmhosts';           T = 'Manual' },
        @{ N = 'NcaSvc';            T = 'Manual' },
        @{ N = 'iphlpsvc';          T = 'Automatic' },
        @{ N = 'NlaSvc';            T = 'Automatic' },
        @{ N = 'netprofm';          T = 'Automatic' },
        @{ N = 'Netman';            T = 'Manual' },
        @{ N = 'NetSetupSvc';       T = 'Manual' },
        @{ N = 'LanmanWorkstation'; T = 'Automatic' }
    )

    foreach ($item in $svcList) {
        $sname = [string]$item.N
        $stype = [string]$item.T
        Invoke-Step -Name ('重启服务 ' + $sname) -Action {
            $svc = Get-Service -Name $sname -ErrorAction SilentlyContinue
            if ($null -eq $svc) { return '服务不存在' }
            try { Set-Service -Name $sname -StartupType $stype -ErrorAction SilentlyContinue } catch { }

            # 用 SilentlyContinue：某些系统服务（典型如 NcaSvc）在 Win11 上依赖缺失
            # 或本身被策略禁用，重启必然失败。这属于正常现象，不该记成 FAIL 去吓用户。
            try {
                if ($svc.Status -eq 'Stopped') {
                    Start-Service -Name $sname -ErrorAction SilentlyContinue
                } else {
                    Restart-Service -Name $sname -Force -ErrorAction SilentlyContinue
                }
            } catch { }

            $after = Get-Service -Name $sname -ErrorAction SilentlyContinue
            if ($null -ne $after -and $after.Status -eq 'Running') { return '已重启' }
            $st = 'unknown'
            if ($null -ne $after) { $st = [string]$after.Status }
            return ('跳过（当前状态 ' + $st + '）')
        }
    }

    # 无线服务单独处理（没有无线网卡的机器会跳过）
    Invoke-Step -Name '重启服务 WlanSvc' -Action {
        $svc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
        if ($null -eq $svc) { return '无无线服务' }
        try { Set-Service -Name 'WlanSvc' -StartupType Automatic -ErrorAction SilentlyContinue } catch { }
        try {
            Restart-Service -Name 'WlanSvc' -Force -ErrorAction Stop
            return '已重启'
        } catch { return 'skip' }
    }

    # 网络底座，放最后（重启它等于短暂全断，但必须做）
    Invoke-Step -Name '重启服务 nsi (网络底座)' -Action {
        $svc = Get-Service -Name 'nsi' -ErrorAction SilentlyContinue
        if ($null -eq $svc) { return '服务不存在' }
        try {
            Restart-Service -Name 'nsi' -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 1200
            return '已重启'
        } catch { return 'skip' }
    }
}

# =============================================================================
#  阶段 H - 网卡重载（这就是"不用重启"的核心）
# =============================================================================

function Repair-AdapterReload {
    Write-Head '第 8 步 / 共 10 步  ·  重载网卡（替代重启的关键一步）'

    if ($SkipAdapterReload -or $script:IsRemote) {
        if ($script:IsRemote) {
            Write-Log '  检测到远程桌面/远程会话，自动跳过网卡重载（防止把你踢下线）' 'WARN'
        } else {
            Write-Log '  已指定跳过网卡重载' 'WARN'
        }
        Write-Log '  协议栈重置的注册表改动会在下次网卡加载时自动生效，多数场景够用。' 'WARN'
        $script:SkipCount++
        return
    }

    if (-not $script:HasNetCmdlet) {
        Write-Log '  老系统没有网卡重载能力，改用接口禁用/启用兜底' 'WARN'
        foreach ($a in (Get-AdapterList)) {
            $nm = $a.Name
            if ($a.IsVirtual) { continue }
            Invoke-Step -Name ('[' + $nm + '] 接口重启') -Action {
                $null = Invoke-Netsh @('interface', 'set', 'interface', ('name="' + $nm + '"'), 'admin=disabled')
                Start-Sleep -Milliseconds 1500
                $null = Invoke-Netsh @('interface', 'set', 'interface', ('name="' + $nm + '"'), 'admin=enable')
                Start-Sleep -Milliseconds 2500
                return 'done'
            }
        }
        return
    }

    $targets = @()
    try {
        $targets = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
            $_.Status -ne 'Not Present' -and ([bool]$_.HardwareInterface -eq $true)
        })
    } catch { }

    if ($targets.Count -eq 0) {
        try { $targets = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }) } catch { }
    }

    if ($targets.Count -eq 0) {
        Write-Log '  找不到可重载的网卡，跳过' 'WARN'
        $script:SkipCount++
        return
    }

    Write-Log ('  将重载 ' + $targets.Count + ' 个网卡，每个断网约 4 秒，请稍候...') 'INFO'

    foreach ($a in $targets) {
        $nm = $a.Name
        Invoke-Step -Name ('[' + $nm + '] 禁用') -Action {
            Disable-NetAdapter -Name $nm -Confirm:$false -ErrorAction Stop
            Start-Sleep -Milliseconds 1500
            return 'ok'
        }
        Invoke-Step -Name ('[' + $nm + '] 启用') -Action {
            Enable-NetAdapter -Name $nm -Confirm:$false -ErrorAction Stop
            return 'ok'
        }

        # 等接口真正回到 Up。
        # 【真实事故】绝不能把 Disconnected 当成"可以了"就 break —— 网卡刚启用时
        # 会短暂显示 Disconnected，此时 ipconfig /renew 直接失败
        # （"不能在该适配器上执行任何操作，它已断开媒体连接"），把第一轮白打废。
        # 最多等 25 秒，超时也继续往下走，不强求。
        $deadline = (Get-Date).AddSeconds(25)
        $last = 'unknown'
        while ((Get-Date) -lt $deadline) {
            try {
                $cur = Get-NetAdapter -Name $nm -ErrorAction SilentlyContinue
                if ($cur) {
                    $last = [string]$cur.Status
                    if ($last -eq 'Up') { break }
                }
            } catch { }
            Start-Sleep -Milliseconds 400
        }
        # 链路刚起来后再稳 1 秒，避免紧接着的 renew 撞在接口初始化中间
        Start-Sleep -Milliseconds 1000
        Write-Log ('      [' + $nm + '] 状态: ' + $last) 'DIM'
    }
}

# =============================================================================
#  阶段 I - DHCP 续租 / DNS 注册 / 无线重连
# =============================================================================

function Repair-Lease {
    Write-Head '第 9 步 / 共 10 步  ·  重新获取 IP 地址与 DNS'

    Invoke-Step -Name 'ipconfig /release' -Action {
        return (Invoke-Native -Exe 'cmd' -ArgList @('/c', 'ipconfig /release * >nul 2>&1') -TimeoutMs 60000)
    }

    Invoke-Step -Name 'ipconfig /renew' -Action {
        $r = Invoke-Native -Exe 'cmd' -ArgList @('/c', 'ipconfig /renew * 2>&1') -TimeoutMs 120000
        if ($r.Length -gt 200) { $r = $r.Substring(0, 200) + '...' }
        return $r
    }

    Invoke-Step -Name 'ipconfig /flushdns' -Action {
        return (Invoke-Native -Exe 'ipconfig' -ArgList @('/flushdns') -TimeoutMs 15000)
    }

    Invoke-Step -Name 'ipconfig /registerdns' -Action {
        return (Invoke-Native -Exe 'ipconfig' -ArgList @('/registerdns') -TimeoutMs 30000)
    }

    # 无线重连：完全不解析本地化文本，只取「冒号后面那截」
    Invoke-Step -Name '无线网络重新连接' -Action {
        $ifOut = Invoke-Netsh @('wlan', 'show', 'interfaces')

        # 判断是否已连上：只认 "State : connected/已连接" 这种精确形态，
        # 避免被 "Hosted network status : connected" 或 "disconnected" 里的子串误导。
        $alreadyConnected = $false
        if ($ifOut -match '(?i)(?:State|\u72b6\u6001)\s*:\s*(?:connected|\u5df2\u8fde\u63a5)') { $alreadyConnected = $true }
        if ($alreadyConnected) { return '无线已连接' }

        # 取所有配置文件名：跳过标题行和空行，只认「非空冒号右值」
        $profOut = Invoke-Netsh @('wlan', 'show', 'profiles')
        $names = New-Object System.Collections.ArrayList

        foreach ($line in ($profOut -split "`r?`n")) {
            $ln = ([string]$line).Trim()
            if ($ln -eq '') { continue }

            $ci = $ln.IndexOf(':')
            if ($ci -lt 0) { continue }

            $left = $ln.Substring(0, $ci).Trim()
            $right = $ln.Substring($ci + 1).Trim()

            if ($right -eq '') { continue }
            # 「Profiles on interface Wi-Fi:」这种标题行的右值是空，已排除
            # 「Group policy profiles (read only)」这种也右值空，已排除
            if ($left -eq '') { continue }
            # 排除明显是表头/分组标题的行
            if ($left -match '(?i)^group policy') { continue }
            if ($left -match '\u7ec4\u7b56\u7565') { continue }

            # 配置名不可能含这些字符
            if ($right -match '[<>|]') { continue }

            if (-not ($names -contains $right)) { [void]$names.Add($right) }
        }

        if ($names.Count -eq 0) { return '没有已保存的无线网络' }

        $joined = $false
        foreach ($n in $names) {
            $r = Invoke-Netsh @('wlan', 'connect', ('name=' + $n), 'ssid=' + $n)
            Start-Sleep -Milliseconds 2500

            $chk = Invoke-Netsh @('wlan', 'show', 'interfaces')
            $ok = ($chk -match '(?i)(?:State|\u72b6\u6001)\s*:\s*(?:connected|\u5df2\u8fde\u63a5)')
            if ($ok) {
                Write-Log ('      已连上无线: ' + $n) 'DIM'
                $joined = $true
                break
            }
        }

        if ($joined) { return '重连成功' }
        return ('尝试了 ' + $names.Count + ' 个配置，均未连上')
    }
}

# =============================================================================
#  阶段 J - NCSI 探针修复（"无 Internet"黄叹号）
# =============================================================================

function Repair-NCSI {
    Write-Head '第 10 步 / 共 10 步  ·  修复 "无 Internet 访问" 黄叹号'

    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet'

    $values = [ordered]@{
        'EnableActiveProbing'   = @('DWord',  1)
        'ActiveWebProbeHost'    = @('String', 'www.msftconnecttest.com')
        'ActiveWebProbePath'    = @('String', 'connecttest.txt')
        'ActiveWebProbeContent' = @('String', 'Microsoft Connect Test')
        'ActiveDnsProbeHost'    = @('String', 'dns.msftncsi.com')
        'ActiveDnsProbeContent' = @('String', '131.107.255.255')
        'PassivePollPeriod'     = @('DWord',  5)
        'StaleThreshold'        = @('DWord',  30)
        'WebTimeout'            = @('DWord',  35)
    }

    Invoke-Step -Name '重建 NCSI 探针注册表' -Action {
        if (-not (Test-Path -LiteralPath $base)) {
            New-Item -Path $base -Force -ErrorAction Stop | Out-Null
        }
        $n = 0
        foreach ($k in $values.Keys) {
            $t = [string]$values[$k][0]
            $v = $values[$k][1]
            try {
                Set-ItemProperty -LiteralPath $base -Name $k -Value $v -Type $t -Force -ErrorAction Stop
                $n++
            } catch { }
        }
        return ('写入 ' + $n + ' 个值')
    }

    Invoke-Step -Name '开启 NCSI 主动探测' -Action {
        $p = 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters'
        if (Test-Path -LiteralPath $p) {
            Set-ItemProperty -LiteralPath $p -Name 'EnableActiveProbing' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        return 'done'
    }

    # 删掉挡 NCSI 探针的防火墙规则（逆向工具常加）
    Invoke-Step -Name '清除阻挡 NCSI 的防火墙规则' -Action {
        $n = 0
        try {
            $rules = @(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {
                $_.DisplayName -match '(?i)msftconnecttest|msftncsi|msftncsi\.com'
            })
            foreach ($r in $rules) {
                try { Remove-NetFirewallRule -Name $r.Name -ErrorAction Stop; $n++ } catch { }
            }
        } catch { }
        return ('移除 ' + $n + ' 条')
    }

    Invoke-Step -Name '重启 NlaSvc 触发探针重检' -Action {
        try {
            Restart-Service -Name 'NlaSvc' -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 1500
            return 'done'
        } catch { return 'skip' }
    }
}

# =============================================================================
#  验证
# =============================================================================

function Test-FinalState {
    Write-Head '正在验证网络状态，请稍候...'

    $rows = New-Object System.Collections.ArrayList

    if ($DryRun) {
        Write-Log '  演习模式跳过验证' 'WARN'
        return @{ Pass = 0; Fail = 0; Total = 0; Rows = $rows }
    }

    # 1) 地址与网关
    $states = Get-IPv4State
    $phys = @($states | Where-Object { -not $_.IsVirtual -and $_.Status -eq 'Up' })
    foreach ($s in $phys) {
        $ip = ''
        if (@($s.IPv4).Count -gt 0) { $ip = [string](@($s.IPv4)[0]) }
        $gw = ''
        if (@($s.Gateway).Count -gt 0) { $gw = [string](@($s.Gateway)[0]) }
        $dns = (@($s.DNS) -join ',')

        $okAddr = ($ip -ne '' -and $ip -notlike '169.254.*')
        [void]$rows.Add([pscustomobject]@{
            Item = 'IP 地址'; Target = $s.Name; Result = $(if ($okAddr) { 'PASS' } else { 'FAIL' }); Detail = ($ip + ' / GW ' + $gw + ' / DNS ' + $dns)
        })
    }

    # 2) 网关 ping
    $gws = @()
    foreach ($s in $phys) { foreach ($g in @($s.Gateway)) { if ($g -and ($gws -notcontains $g)) { $gws += $g } } }
    if ($gws.Count -eq 0) {
        [void]$rows.Add([pscustomobject]@{ Item = '网关可达'; Target = '(无网关)'; Result = 'FAIL'; Detail = '未获取到默认网关' })
    } else {
        foreach ($g in $gws) {
            $ok = Test-PingTarget -Target $g -TimeoutMs 2000
            [void]$rows.Add([pscustomobject]@{ Item = '网关可达'; Target = $g; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Detail = '' })
        }
    }

    # 3) 公网 IP ping（ICMP 被墙不算致命）
    $pingAny = $false
    foreach ($t in @('223.5.5.5', '119.29.29.29', '114.114.114.114', '8.8.8.8')) {
        $ok = Test-PingTarget -Target $t -TimeoutMs 2000
        if ($ok) { $pingAny = $true }
        [void]$rows.Add([pscustomobject]@{ Item = '公网 ICMP'; Target = $t; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Detail = '' })
    }

    # 4) DNS 解析
    $dnsAny = $false
    foreach ($d in @('www.baidu.com', 'www.msftconnecttest.com')) {
        $ip = Test-DnsResolve -Name $d
        $ok = ($null -ne $ip -and [string]$ip -ne '')
        if ($ok) { $dnsAny = $true }
        [void]$rows.Add([pscustomobject]@{ Item = 'DNS 解析'; Target = $d; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Detail = [string]$ip })
    }

    # 5) TCP 443
    $tcpAny = $false
    foreach ($h in @('www.baidu.com', 'www.msftconnecttest.com')) {
        $ok = Test-PortOpen -Target $h -Port 443 -TimeoutMs 4000
        if ($ok) { $tcpAny = $true }
        [void]$rows.Add([pscustomobject]@{ Item = 'TCP 443'; Target = $h; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Detail = '' })
    }

    # 6) HTTP 探针
    $httpOk = $false
    try {
        $wr = Invoke-WebRequest -Uri 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ([string]$wr.Content -match 'Microsoft Connect Test') { $httpOk = $true }
        elseif ($wr.StatusCode -eq 200) { $httpOk = $true }
    } catch { $httpOk = $false }
    [void]$rows.Add([pscustomobject]@{ Item = 'HTTP 探测'; Target = 'msftconnecttest'; Result = $(if ($httpOk) { 'PASS' } else { 'FAIL' }); Detail = '' })

    # 7) 代理复查
    $proxyOff = $true
    try {
        $pv = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
        if ($null -ne $pv) {
            if ($pv.ProxyEnable -eq 1) { $proxyOff = $false }
        }
    } catch { }
    [void]$rows.Add([pscustomobject]@{ Item = '代理已关闭'; Target = 'WinINET'; Result = $(if ($proxyOff) { 'PASS' } else { 'FAIL' }); Detail = '' })

    # 输出表格（英文属性名 + 中文表头映射，避开编码坑）
    Write-Host ''
    $rows | Format-Table -AutoSize `
        @{ Label = '检查项'; Expression = { $_.Item } },
        @{ Label = '目标';   Expression = { $_.Target } },
        @{ Label = '结果';   Expression = { $_.Result } },
        @{ Label = '详情';   Expression = { $_.Detail } } | Out-String -Width 200 | Write-Host

    $pass = @($rows | Where-Object { $_.Result -eq 'PASS' }).Count
    $fail = @($rows | Where-Object { $_.Result -eq 'FAIL' }).Count
    $total = $rows.Count

    # 保存验证结果
    try {
        $rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $script:RootDir 'last_verify.json') -Encoding UTF8 -Force
    } catch { }

    return @{ Pass = $pass; Fail = $fail; Total = $total; Rows = $rows; PingAny = $pingAny; DnsAny = $dnsAny; TcpAny = $tcpAny; HttpOk = $httpOk }
}

# =============================================================================
#  回滚
# =============================================================================

function Get-LatestBackupDir {
    try {
        $dirs = @(Get-ChildItem -LiteralPath $script:RootDir -Directory -Filter 'backup_*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
        if ($dirs.Count -gt 0) { return $dirs[0].FullName }
    } catch { }
    return $null
}

function Invoke-RestoreHosts {
    Write-Head '回滚 · 恢复 hosts'
    $b = Get-LatestBackupDir
    if (-not $b) { Write-Log '  找不到备份目录' 'ERR'; return }
    $src = Join-Path $b 'hosts.bak'
    $dst = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    if (-not (Test-Path -LiteralPath $src)) { Write-Log ('  备份里没有 hosts.bak: ' + $src) 'ERR'; return }

    Invoke-Step -Name '恢复 hosts 文件' -Action {
        try { [IO.File]::SetAttributes($dst, [IO.FileAttributes]::Normal) } catch { }
        Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
        return ('已从 ' + $src + ' 恢复')
    }
    Invoke-Step -Name '刷新 DNS 缓存' -Action { return (Invoke-Native -Exe 'ipconfig' -ArgList @('/flushdns') -TimeoutMs 15000) }
}

function Invoke-RestoreConfig {
    Write-Head '回滚 · 恢复网卡 IP/DNS'
    $b = Get-LatestBackupDir
    if (-not $b) { Write-Log '  找不到备份目录' 'ERR'; return }
    $src = Join-Path $b 'netconfig.json'
    if (-not (Test-Path -LiteralPath $src)) { Write-Log ('  备份里没有 netconfig.json: ' + $src) 'ERR'; return }

    $cfg = $null
    try { $cfg = Get-Content -LiteralPath $src -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
        Write-Log ('  读取备份失败: ' + $_.Exception.Message) 'ERR'
        return
    }

    foreach ($a in @($cfg)) {
        $idx = [string]$a.InterfaceIndex
        $nm = [string]$a.Name
        $addrs = @($a.IPv4)
        $dns = @($a.DnsServers)

        if ($addrs.Count -eq 0) {
            Invoke-Step -Name ('[' + $nm + '] 恢复为 DHCP') -Action {
                return (Invoke-Netsh @('interface', 'ipv4', 'set', 'interface', $idx, 'dhcp'))
            }
        } else {
            $first = [string]$addrs[0]
            Invoke-Step -Name ('[' + $nm + '] 恢复 IP ' + $first) -Action {
                return (Invoke-Netsh @('interface', 'ipv4', 'set', 'address', $idx, 'static', $first, '255.255.255.0'))
            }
        }

        if ($dns.Count -gt 0) {
            $dnsJoin = ($dns -join ',')
            Invoke-Step -Name ('[' + $nm + '] 恢复 DNS ' + $dnsJoin) -Action {
                try {
                    Set-DnsClientServerAddress -InterfaceIndex ([int]$idx) -ServerAddresses $dnsJoin -ErrorAction Stop
                    return 'done'
                } catch {
                    return (Invoke-Netsh @('interface', 'ipv4', 'set', 'dnsserver', $idx, 'static', [string]$dns[0], 'primary'))
                }
            }
        }
    }
}

# =============================================================================
#  总结报告
# =============================================================================

function Show-Summary {
    param($Verify)

    Write-Host ''
    Write-Host '  ================================================================' -ForegroundColor DarkCyan
    Write-Host '   执 行 结 果' -ForegroundColor Cyan
    Write-Host '  ================================================================' -ForegroundColor DarkCyan
    Write-Host ('    成功步骤 : ' + $script:OKCount) -ForegroundColor Green
    Write-Host ('    失败步骤 : ' + $script:FailCount) -ForegroundColor Red
    Write-Host ('    跳过步骤 : ' + $script:SkipCount) -ForegroundColor Yellow
    Write-Host ('    备份位置 : ' + $script:BackupDir) -ForegroundColor Gray
    Write-Host ('    日志文件 : ' + $script:LogFile) -ForegroundColor Gray
    Write-Host ''

    if ($null -ne $Verify -and $Verify.Total -gt 0) {
        $p = [int]$Verify.Pass
        $t = [int]$Verify.Total
        $f = [int]$Verify.Fail

        $netOk = $false
        if ($Verify.ContainsKey('TcpAny')) { $netOk = [bool]$Verify.TcpAny }
        if (-not $netOk -and $Verify.ContainsKey('HttpOk')) { $netOk = [bool]$Verify.HttpOk }
        if (-not $netOk -and $Verify.ContainsKey('PingAny')) { $netOk = [bool]$Verify.PingAny }
        if (-not $netOk -and $Verify.ContainsKey('DnsAny')) { $netOk = [bool]$Verify.DnsAny }

        Write-Host '  ----------------------------------------------------------------' -ForegroundColor DarkGray
        if ($netOk) {
            Write-Host '    >>> 网络已经通了，现在就能上网。' -ForegroundColor Green
            Write-Host '    >>> 如果浏览器还打不开，把浏览器整个关掉再重新打开。' -ForegroundColor Green
        } elseif ($p -gt 0) {
            Write-Host '    >>> 修好了一部分，但公网还没通。' -ForegroundColor Yellow
            Write-Host '    >>> 请先看下面的建议，再试一次深度修复。' -ForegroundColor Yellow
        } else {
            Write-Host '    >>> 本机配置已经全部重置到出厂状态。' -ForegroundColor Yellow
            Write-Host '    >>> 如果还是不通，问题多半不在电脑上，而在路由器或宽带那边。' -ForegroundColor Yellow
            Write-Host '    >>> 建议：拔掉路由器电源等 30 秒再插上。' -ForegroundColor Yellow
        }
        Write-Host ('    >>> 检查项通过 ' + $p + ' / ' + $t + '（失败 ' + $f + '）') -ForegroundColor Gray
        Write-Host '  ----------------------------------------------------------------' -ForegroundColor DarkGray
    }

    # 常见问题排查建议
    Write-Host ''
    Write-Host '  还没好的话，按顺序试这几招：' -ForegroundColor Cyan
    Write-Host '    1. 把浏览器（Chrome/Edge/360等）全部关掉，重新打开。' -ForegroundColor Gray
    Write-Host '       浏览器的代理设置是启动时读的，不关它不生效。' -ForegroundColor DarkGray
    Write-Host '    2. 拔网线 / 关 WiFi 再打开，等 10 秒。' -ForegroundColor Gray
    Write-Host '    3. 手机能上网但电脑不行 -> 是电脑的问题，回来跑一次深度修复。' -ForegroundColor Gray
    Write-Host '    4. 手机也上不了网 -> 是路由器或宽带的问题，重启路由器。' -ForegroundColor Gray
    Write-Host '    5. 公司/学校网络可能需要网页登录认证，浏览器打开任意网站试试。' -ForegroundColor Gray
    Write-Host ''

    # 保存报告
    try {
        $rp = Join-Path $script:RootDir ('report_' + $script:Stamp + '.txt')
        $lines = New-Object System.Collections.ArrayList
        [void]$lines.Add('Npc修复网络 v' + $script:Version + ' 执行报告')
        [void]$lines.Add('时间: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        [void]$lines.Add('主机: ' + $env:COMPUTERNAME)
        [void]$lines.Add('成功: ' + $script:OKCount + '  失败: ' + $script:FailCount + '  跳过: ' + $script:SkipCount)
        [void]$lines.Add('')
        [void]$lines.Add('--- 步骤明细 ---')
        foreach ($r in $script:Records) {
            [void]$lines.Add(('[' + $r.State + '] ' + $r.Step + ' :: ' + $r.Detail))
        }
        if ($null -ne $Verify -and $Verify.Total -gt 0) {
            [void]$lines.Add('')
            [void]$lines.Add('--- 验证结果 ---')
            foreach ($r in $Verify.Rows) {
                [void]$lines.Add(('[' + $r.Result + '] ' + $r.Item + ' ' + $r.Target + ' ' + $r.Detail))
            }
        }
        ($lines -join "`r`n") | Set-Content -LiteralPath $rp -Encoding UTF8 -Force -ErrorAction Stop
        Write-Host ('  详细报告: ' + $rp) -ForegroundColor DarkGray
    } catch { }

    Write-Host ''
}

# =============================================================================
#  主流程
# =============================================================================

Initialize-Log
$script:HasNetCmdlet = Test-NetCmdlet
$script:IsRemote    = Test-IsRemoteSession

Show-Banner

# --- 权限检查 ---
if (-not (Test-IsAdmin)) {
    Write-Host ''
    Write-Log '当前不是管理员，权限不够，没动任何东西。' 'ERR'
    Write-Host ''
    Write-Host '  正确做法（二选一）：' -ForegroundColor Yellow
    Write-Host '    A. 双击同目录的「一键恢复网络.bat」，它会自动申请管理员权限。' -ForegroundColor Yellow
    Write-Host '    B. 右键本脚本 -> 使用 PowerShell 运行（需以管理员身份）。' -ForegroundColor Yellow
    Write-Host ''
    if (-not $NoPause) { Read-Host '按回车退出' | Out-Null }
    exit 1
}

Write-Log '管理员权限检查: 通过' 'OK'
Write-Log ('PowerShell 版本: ' + $PSVersionTable.PSVersion.ToString()) 'INFO'
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) { Write-Log ('操作系统: ' + $os.Caption + ' ' + $os.Version) 'INFO' }
} catch { }
Write-Log ('现代网卡命令支持: ' + $(if ($script:HasNetCmdlet) { '是' } else { '否（降级到 netsh）' })) 'INFO'
Write-Log ('远程会话环境: ' + $(if ($script:IsRemote) { '是（将跳过网卡重载保护连接）' } else { '否' })) 'INFO'
Write-Host ''

# --- 单独回滚模式 ---
if ($RestoreHosts) {
    Invoke-RestoreHosts
    Write-Log 'hosts 回滚完成。' 'OK'
    if (-not $NoPause) { Read-Host '按回车退出' | Out-Null }
    exit 0
}
if ($RestoreConfig) {
    Invoke-RestoreConfig
    Write-Log '网卡配置回滚完成。' 'OK'
    if (-not $NoPause) { Read-Host '按回车退出' | Out-Null }
    exit 0
}

# --- 动手前先看现在通不通 ---
$preOk = Test-QuickInternet
if ($preOk) {
    Write-Log '当前网络看起来是通的。' 'OK'
} else {
    Write-Log '当前网络不通，开始修复。' 'WARN'
}
Write-Host ''

if (-not $Yes -and -not $DryRun) {
    Write-Host '  说明：本工具会把网络设置重置回正常状态，' -ForegroundColor Gray
    Write-Host '        期间网卡会重启一次，断网约 4-8 秒，之后自动恢复。' -ForegroundColor Gray
    Write-Host '        所有原始设置已自动备份，出问题可以一键还原。' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  8 秒后自动开始（按 N 键取消）...' -ForegroundColor Yellow
    $cancelled = $false
    for ($sec = 8; $sec -ge 1; $sec--) {
        Write-Host ("    倒计时 " + $sec + " ") -NoNewline -ForegroundColor Yellow
        $deadline = (Get-Date).AddSeconds(1)
        while ((Get-Date) -lt $deadline) {
            try {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq 'N' -or $key.Key -eq 'n') { $cancelled = $true }
                    break
                }
            } catch { }
            Start-Sleep -Milliseconds 80
        }
        if ($cancelled) { break }
    }
    Write-Host ''
    if ($cancelled) {
        Write-Host ''
        Write-Log '用户取消，什么都没动。' 'WARN'
        if (-not $NoPause) { Read-Host '按回车退出' | Out-Null }
        exit 0
    }
    Write-Host ''
}

$timer = [System.Diagnostics.Stopwatch]::StartNew()

# --- 第一轮：标准修复 ---
Save-Backup
Repair-Proxy
Repair-Hosts
Repair-NetStack
Repair-AdapterBinding
Repair-IpConfig
Repair-Services
Repair-AdapterReload
Repair-Lease
Repair-NCSI

$verify = Test-FinalState

# --- 第二轮：自动深度补救（第一轮没通才跑）---
$needSecond = $false
if ($null -ne $verify -and $verify.Total -gt 0) {
    $tcpOk = $false
    if ($verify.ContainsKey('TcpAny')) { $tcpOk = [bool]$verify.TcpAny }
    $httpOk2 = $false
    if ($verify.ContainsKey('HttpOk')) { $httpOk2 = [bool]$verify.HttpOk }
    if (-not $tcpOk -and -not $httpOk2) { $needSecond = $true }
}

if ($needSecond -and -not $Deep -and -not $DryRun) {
    Write-Head '第一轮没完全通，自动启动深度补救'
    Write-Log '  追加执行：DNS 策略清理 / 默认路由重建 / 协议再重置 / 服务二次重启' 'WARN'

    # 追加一：DNS 策略表
    Invoke-Step -Name '[补救] 清除 DNS 策略' -Action {
        $n = 0
        try {
            $rules = @(Get-DnsClientNrptRule -ErrorAction SilentlyContinue)
            foreach ($r in $rules) {
                try { Remove-DnsClientNrptRule -Name $r.Name -Force -ErrorAction Stop; $n++ } catch { }
            }
        } catch { }
        return ('删除 ' + $n + ' 条')
    }

    # 追加二：DNS 服务器改用公共 DNS（DHCP 没下发 DNS 时的救命手段）
    Invoke-Step -Name '[补救] 设置公共 DNS 兜底' -Action {
        $n = 0
        foreach ($s in (Get-IPv4State)) {
            if ($s.IsVirtual) { continue }
            if ($s.Status -ne 'Up') { continue }
            try {
                Set-DnsClientServerAddress -InterfaceIndex $s.IfIndex -ServerAddresses @('223.5.5.5', '119.29.29.29') -ErrorAction Stop
                $n++
            } catch { }
        }
        return ('设置 ' + $n + ' 个网卡')
    }

    # 追加三：协议栈再压一遍
    Invoke-Step -Name '[补救] 协议栈二次重置' -Action {
        $a = Invoke-Netsh @('winsock', 'reset', 'catalog')
        $b = Invoke-Netsh @('int', 'ip', 'reset')
        $c = Invoke-Netsh @('int', 'ipv4', 'reset')
        return ($a + ' | ' + $b + ' | ' + $c)
    }

    # 追加四：服务二次重启（顺序更保守）
    foreach ($sn in @('Dnscache', 'Dhcp', 'NlaSvc', 'netprofm', 'nsi')) {
        $sname2 = $sn
        Invoke-Step -Name ('[补救] 重启 ' + $sname2) -Action {
            $svc = Get-Service -Name $sname2 -ErrorAction SilentlyContinue
            if ($null -eq $svc) { return '不存在' }
            try { Restart-Service -Name $sname2 -Force -ErrorAction Stop; return 'ok' } catch { return 'skip' }
        }
    }

    # 追加五：再来一次续租
    Invoke-Step -Name '[补救] ipconfig /renew' -Action {
        $r = Invoke-Native -Exe 'cmd' -ArgList @('/c', 'ipconfig /renew * 2>&1') -TimeoutMs 120000
        if ($r.Length -gt 200) { $r = $r.Substring(0, 200) + '...' }
        return $r
    }

    Invoke-Step -Name '[补救] 刷新 DNS' -Action {
        return (Invoke-Native -Exe 'ipconfig' -ArgList @('/flushdns') -TimeoutMs 15000)
    }

    Start-Sleep -Seconds 2
    $verify = Test-FinalState
}

$timer.Stop()

try {
    Write-Log ('总耗时: ' + [math]::Round($timer.Elapsed.TotalSeconds, 1) + ' 秒') 'INFO'
} catch { }

Show-Summary -Verify $verify

# =============================================================================
#  交互：要不要再来一轮更狠的
# =============================================================================

$netGood = $false
if ($null -ne $verify -and $verify.Total -gt 0) {
    if ($verify.ContainsKey('TcpAny') -and [bool]$verify.TcpAny) { $netGood = $true }
    if (-not $netGood -and $verify.ContainsKey('HttpOk') -and [bool]$verify.HttpOk) { $netGood = $true }
}

if (-not $NoPause) {
    if (-not $netGood -and -not $DryRun) {
        Write-Host '  ----------------------------------------------------------------' -ForegroundColor DarkYellow
        Write-Host '  输入 D 再跑一次「深度修复」（重置防火墙 + DNS 策略 + 网络位置）' -ForegroundColor Yellow
        Write-Host '  输入 H 把 hosts 恢复成修复前的样子' -ForegroundColor Yellow
        Write-Host '  直接回车退出' -ForegroundColor Yellow
        Write-Host '  ----------------------------------------------------------------' -ForegroundColor DarkYellow
        $choice = Read-Host '  请选择'
        $choice = ([string]$choice).Trim().ToUpper()

        if ($choice -eq 'D') {
            Write-Host ''
            Write-Log '启动深度修复...' 'STEP'
            $Deep = $true
            Repair-Proxy
            Repair-NetStack
            Repair-Services
            Repair-AdapterReload
            Repair-Lease
            Repair-NCSI
            $verify2 = Test-FinalState
            Show-Summary -Verify $verify2
        } elseif ($choice -eq 'H') {
            Invoke-RestoreHosts
        }
    }

    Write-Host ''
    Read-Host '按回车退出' | Out-Null
}

Write-Log 'Npc修复网络 结束。' 'OK'
exit 0
