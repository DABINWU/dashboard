# Core functions are separate so configuration can be tested without changing Windows tasks.
Set-StrictMode -Version Latest

function Get-KioskBrowserCandidates {
    $locations = @(
        @{ Name = 'Chrome'; Root = $env:ProgramFiles; Relative = 'Google\Chrome\Application\chrome.exe' },
        @{ Name = 'Chrome'; Root = ${env:ProgramFiles(x86)}; Relative = 'Google\Chrome\Application\chrome.exe' },
        @{ Name = 'Chrome'; Root = $env:LOCALAPPDATA; Relative = 'Google\Chrome\Application\chrome.exe' },
        @{ Name = 'Edge'; Root = ${env:ProgramFiles(x86)}; Relative = 'Microsoft\Edge\Application\msedge.exe' },
        @{ Name = 'Edge'; Root = $env:ProgramFiles; Relative = 'Microsoft\Edge\Application\msedge.exe' },
        @{ Name = 'Edge'; Root = $env:LOCALAPPDATA; Relative = 'Microsoft\Edge\Application\msedge.exe' }
    )
    $seen = @{}
    foreach ($location in $locations) {
        if (-not $location.Root) { continue }
        $candidate = Join-Path $location.Root $location.Relative
        if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and -not $seen.ContainsKey($location.Name)) {
            $seen[$location.Name] = $true
            [pscustomobject]@{ Name = $location.Name; Path = $candidate }
        }
    }
}

function New-KioskPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HtmlPath,
        [Parameter(Mandatory)][ValidateSet('Chrome', 'Edge')][string]$BrowserName,
        [Parameter(Mandatory)][string]$BrowserPath,
        [ValidateRange(0, 3600)][int]$DelaySeconds = 30,
        [string]$DataRoot = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'DashboardPlayer'),
        [string]$UserSid = ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
    )
    $htmlItem = Get-Item -LiteralPath $HtmlPath -ErrorAction Stop
    if ($htmlItem.PSIsContainer -or $htmlItem.Extension -notin @('.html', '.htm')) {
        throw '请选择存在的 .html 或 .htm 文件。'
    }
    $browserItem = Get-Item -LiteralPath $BrowserPath -ErrorAction Stop
    $expectedName = if ($BrowserName -eq 'Chrome') { 'chrome.exe' } else { 'msedge.exe' }
    if ($browserItem.PSIsContainer -or $browserItem.Name -ine $expectedName) {
        throw "请选择 $BrowserName 的 $expectedName 程序。"
    }
    if ($DataRoot.Contains('"') -or -not [IO.Path]::IsPathRooted($DataRoot)) {
        throw '浏览器数据目录必须是有效的绝对路径。'
    }
    $fullHtmlPath = $htmlItem.FullName
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($fullHtmlPath.ToUpperInvariant() + '|' + $UserSid)
        $installId = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '').Substring(0, 12).ToLowerInvariant()
    } finally { $hasher.Dispose() }
    $installDirectory = Join-Path ([IO.Path]::GetFullPath($DataRoot)) ('installations\' + $installId)
    $profilePath = Join-Path $installDirectory ('profile-' + $BrowserName.ToLowerInvariant())
    $htmlUrl = ([Uri]$fullHtmlPath).AbsoluteUri
    $arguments = '--kiosk "{0}" --no-first-run --user-data-dir="{1}"' -f $htmlUrl, $profilePath
    if ($BrowserName -eq 'Edge') { $arguments += ' --edge-kiosk-type=fullscreen' }
    [pscustomobject]@{
        Version = 1
        InstallId = $installId
        HtmlPath = $fullHtmlPath
        HtmlUrl = $htmlUrl
        BrowserName = $BrowserName
        BrowserPath = $browserItem.FullName
        WorkingDirectory = $htmlItem.DirectoryName
        InstallDirectory = $installDirectory
        ProfilePath = $profilePath
        Arguments = $arguments
        DelaySeconds = $DelaySeconds
        UserSid = $UserSid
        TaskName = 'DashboardPlayer-' + $installId
        TaskDescription = 'DashboardPlayer.ManagedTask.v1|' + $installId
        ShortcutName = '看板全屏播放-' + $installId + '.lnk'
    }
}

function New-KioskTaskXml {
    param([Parameter(Mandatory)]$Plan)
    $exe = [Security.SecurityElement]::Escape($Plan.BrowserPath)
    $arguments = [Security.SecurityElement]::Escape($Plan.Arguments)
    $workingDirectory = [Security.SecurityElement]::Escape($Plan.WorkingDirectory)
    $sid = [Security.SecurityElement]::Escape($Plan.UserSid)
    $description = [Security.SecurityElement]::Escape($Plan.TaskDescription)
    @"
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>$description</Description></RegistrationInfo>
  <Triggers><LogonTrigger><Enabled>true</Enabled><UserId>$sid</UserId><Delay>PT$($Plan.DelaySeconds)S</Delay></LogonTrigger></Triggers>
  <Principals><Principal id="PlayerUser"><UserId>$sid</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
  </Settings>
  <Actions Context="PlayerUser"><Exec><Command>$exe</Command><Arguments>$arguments</Arguments><WorkingDirectory>$workingDirectory</WorkingDirectory></Exec></Actions>
</Task>
"@
}

function Export-KioskFiles {
    param([Parameter(Mandatory)]$Plan)
    [void][IO.Directory]::CreateDirectory($Plan.InstallDirectory)
    $xmlPath = Join-Path $Plan.InstallDirectory 'task.xml'
    $configPath = Join-Path $Plan.InstallDirectory 'config.json'
    $shortcutPath = Join-Path $Plan.InstallDirectory $Plan.ShortcutName
    $utf8 = New-Object Text.UTF8Encoding($true)
    [IO.File]::WriteAllText($xmlPath, (New-KioskTaskXml $Plan), $utf8)
    [IO.File]::WriteAllText($configPath, ($Plan | ConvertTo-Json -Depth 4), $utf8)
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $Plan.BrowserPath
    $shortcut.Arguments = $Plan.Arguments
    $shortcut.WorkingDirectory = $Plan.WorkingDirectory
    $shortcut.IconLocation = $Plan.BrowserPath + ',0'
    $shortcut.Description = 'DashboardPlayer fullscreen kiosk'
    $shortcut.Save()
    $saved = $shell.CreateShortcut($shortcutPath)
    if ($saved.TargetPath -ine $Plan.BrowserPath -or $saved.Arguments -cne $Plan.Arguments -or $saved.WorkingDirectory -ine $Plan.WorkingDirectory) {
        throw '快捷方式参数回读校验失败，请检查目录写入权限。'
    }
    [pscustomobject]@{ ShortcutPath = $shortcutPath; XmlPath = $xmlPath; ConfigPath = $configPath }
}

function Get-KioskTaskFolder {
    $service = New-Object -ComObject Schedule.Service
    $service.Connect()
    $service.GetFolder('\')
}

function Get-KioskExistingTask {
    param([Parameter(Mandatory)]$Folder, [Parameter(Mandatory)]$Plan)
    try { $task = $Folder.GetTask($Plan.TaskName) }
    catch {
        $code = $_.Exception.GetBaseException().HResult
        if ($code -eq -2147024894 -or $code -eq -2147024893) { return $null }
        throw
    }
    if ($null -ne $task) {
        [xml]$xml = $task.Xml
        $namespaces = New-Object Xml.XmlNamespaceManager($xml.NameTable)
        $namespaces.AddNamespace('t', 'http://schemas.microsoft.com/windows/2004/02/mit/task')
        $description = $xml.SelectSingleNode('/t:Task/t:RegistrationInfo/t:Description', $namespaces)
        if ($null -eq $description -or $description.InnerText -cne $Plan.TaskDescription) {
            throw "同名任务 $($Plan.TaskName) 不属于本工具，已停止操作以避免覆盖。"
        }
    }
    $task
}

function Register-KioskAutostart {
    param([Parameter(Mandatory)]$Plan, $Folder = $null)
    if ($null -eq $Folder) { $Folder = Get-KioskTaskFolder }
    [void](Get-KioskExistingTask -Folder $Folder -Plan $Plan)
    # TASK_CREATE_OR_UPDATE = 6, TASK_LOGON_INTERACTIVE_TOKEN = 3; no password needed.
    $registered = $Folder.RegisterTask($Plan.TaskName, (New-KioskTaskXml $Plan), 6, $Plan.UserSid, $null, 3, $null)
    [xml]$saved = $registered.Xml
    if ([string]$saved.Task.Actions.Exec.Command -ine $Plan.BrowserPath -or
        [string]$saved.Task.Actions.Exec.Arguments -cne $Plan.Arguments -or
        [string]$saved.Task.Actions.Exec.WorkingDirectory -ine $Plan.WorkingDirectory -or
        [string]$saved.Task.Principals.Principal.LogonType -ne 'InteractiveToken' -or
        [string]$saved.Task.Principals.Principal.UserId -ine $Plan.UserSid -or
        [string]$saved.Task.Triggers.LogonTrigger.UserId -ine $Plan.UserSid -or
        [Xml.XmlConvert]::ToTimeSpan([string]$saved.Task.Triggers.LogonTrigger.Delay).TotalSeconds -ne $Plan.DelaySeconds) {
        throw '任务已提交，但保存后的参数校验失败。请在任务计划程序中检查此任务。'
    }
    [pscustomobject]@{ TaskName = $Plan.TaskName; Verified = $true }
}

function Disable-KioskAutostart {
    param([Parameter(Mandatory)]$Plan, $Folder = $null)
    if ($null -eq $Folder) { $Folder = Get-KioskTaskFolder }
    $task = Get-KioskExistingTask -Folder $Folder -Plan $Plan
    if ($null -eq $task) { return $false }
    $task.Enabled = $false
    if ($task.Enabled) { throw '任务未能停用，请检查任务计划程序中的权限。' }
    $true
}

function Start-KioskPlayer {
    param([Parameter(Mandatory)]$Plan)
    # This is the visible application the user explicitly chooses to open.
    Start-Process -FilePath $Plan.BrowserPath -ArgumentList $Plan.Arguments -WorkingDirectory $Plan.WorkingDirectory
}
