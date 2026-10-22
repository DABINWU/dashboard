$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'kiosk-core.ps1')

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Assert-Throws([scriptblock]$Action, [string]$Message) {
    $didThrow = $false
    try { & $Action | Out-Null } catch { $didThrow = $true }
    Assert-True $didThrow $Message
}

# All real filesystem writes remain in this ignored directory; no task is registered.
$testRoot = Join-Path $PSScriptRoot '.kiosk-test-output'
$assetDirectory = Join-Path $testRoot 'assets 中文 & # %'
$browserDirectory = Join-Path $testRoot 'browser 中文 & space'
[void][IO.Directory]::CreateDirectory($assetDirectory)
[void][IO.Directory]::CreateDirectory($browserDirectory)
$htmlPath = Join-Path $assetDirectory 'display #1 %.html'
$otherHtmlPath = Join-Path $assetDirectory 'other.html'
$chromePath = Join-Path $browserDirectory 'chrome.exe'
$edgePath = Join-Path $browserDirectory 'msedge.exe'
$badHtmlPath = Join-Path $assetDirectory 'invalid.txt'
foreach ($path in @($htmlPath, $otherHtmlPath, $badHtmlPath)) { [IO.File]::WriteAllText($path, '<html><body>Test</body></html>') }
foreach ($path in @($chromePath, $edgePath)) { [IO.File]::WriteAllText($path, 'Test placeholder - never executed') }
$dataRoot = Join-Path $testRoot 'data 中文 & space'
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$chrome = New-KioskPlan -HtmlPath $htmlPath -BrowserName Chrome -BrowserPath $chromePath -DataRoot $dataRoot
$edge = New-KioskPlan -HtmlPath $htmlPath -BrowserName Edge -BrowserPath $edgePath -DataRoot $dataRoot -DelaySeconds 0
Assert-True ($chrome.HtmlUrl.Contains('%23') -and $chrome.HtmlUrl.Contains('%25') -and $chrome.HtmlUrl.Contains('%20')) 'Reserved URL characters are escaped'
Assert-True (([Uri]$chrome.HtmlUrl).LocalPath -eq $chrome.HtmlPath) 'HTML URL round trips exactly'
Assert-True ($chrome.Arguments.Contains('--kiosk "') -and -not $chrome.Arguments.Contains('--edge-kiosk-type')) 'Chrome parameters'
Assert-True ($edge.Arguments.Contains('--edge-kiosk-type=fullscreen')) 'Edge parameters'
Assert-True ($chrome.TaskName -eq $edge.TaskName -and $chrome.ProfilePath -ne $edge.ProfilePath) 'One stable task per HTML with separate browser profiles'
Assert-True ($chrome.WorkingDirectory -eq $assetDirectory) 'Relative HTML resources retain the source working directory'
$other = New-KioskPlan -HtmlPath $otherHtmlPath -BrowserName Chrome -BrowserPath $chromePath -DataRoot $dataRoot
$otherUser = New-KioskPlan -HtmlPath $htmlPath -BrowserName Chrome -BrowserPath $chromePath -DataRoot $dataRoot -UserSid 'S-1-5-21-123-456-789-1001'
Assert-True ($other.TaskName -ne $chrome.TaskName -and $otherUser.TaskName -ne $chrome.TaskName) 'Different files and users have different tasks'
Assert-Throws { New-KioskPlan -HtmlPath $badHtmlPath -BrowserName Chrome -BrowserPath $chromePath } 'Non-HTML input rejected'
Assert-Throws { New-KioskPlan -HtmlPath $htmlPath -BrowserName Chrome -BrowserPath $edgePath } 'Wrong browser executable rejected'
Assert-Throws { New-KioskPlan -HtmlPath $htmlPath -BrowserName Chrome -BrowserPath $chromePath -DelaySeconds -1 } 'Invalid delay rejected'

[xml]$taskXml = New-KioskTaskXml $chrome
Assert-True ([string]$taskXml.Task.Actions.Exec.Command -ceq $chromePath) 'XML escapes executable paths'
Assert-True ([string]$taskXml.Task.Actions.Exec.Arguments -ceq $chrome.Arguments) 'XML preserves complete arguments'
Assert-True ([string]$taskXml.Task.Principals.Principal.LogonType -eq 'InteractiveToken') 'Visible interactive user session'
Assert-True ([string]$taskXml.Task.Principals.Principal.RunLevel -eq 'LeastPrivilege') 'No administrative run level'
Assert-True ([string]$taskXml.Task.Triggers.LogonTrigger.Delay -eq 'PT30S') '30-second logon delay'
Assert-True ([string]$taskXml.Task.Settings.ExecutionTimeLimit -eq 'PT0S') 'No automatic task runtime cutoff'
Assert-True ([string]$taskXml.Task.Settings.MultipleInstancesPolicy -eq 'IgnoreNew') 'Duplicate instance guard'
Assert-True ([string]$taskXml.Task.Settings.DisallowStartIfOnBatteries -eq 'false') 'Battery power allowed'
[xml]$zeroDelay = New-KioskTaskXml $edge
Assert-True ([string]$zeroDelay.Task.Triggers.LogonTrigger.Delay -eq 'PT0S') 'Zero-second delay supported'

# Validate against the Windows scheduler XML parser in memory, without registering.
$service = New-Object -ComObject Schedule.Service
$service.Connect()
$definition = $service.NewTask(0)
$definition.XmlText = New-KioskTaskXml $chrome
Assert-True ($definition.Actions.Item(1).Arguments -ceq $chrome.Arguments) 'Native scheduler parser accepts XML and preserves arguments'

$files = Export-KioskFiles -Plan $chrome
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($files.ShortcutPath)
Assert-True ($link.TargetPath -ieq $chromePath -and $link.Arguments -ceq $chrome.Arguments -and $link.WorkingDirectory -ieq $assetDirectory) 'Real shortcut COM save/read preserves paths and parameters'
$savedPlan = Get-Content -LiteralPath $files.ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True ($savedPlan.Arguments -ceq $chrome.Arguments) 'JSON configuration round trip'
[xml]$exportedXml = Get-Content -LiteralPath $files.XmlPath -Raw -Encoding UTF8
Assert-True ([string]$exportedXml.Task.Actions.Exec.Arguments -ceq $chrome.Arguments) 'Exported XML round trip'

# Substitute only Task Scheduler. Do not create, modify or stop real Windows tasks.
$folder = [pscustomobject]@{ Store = @{}; Registrations = 0; DropArguments = $false }
$folder | Add-Member ScriptMethod GetTask {
    param($Name)
    if ($this.Store.ContainsKey($Name)) { return $this.Store[$Name] }
    return $null
}
$folder | Add-Member ScriptMethod RegisterTask {
    param($Name, $Xml, $Flags, $User, $Password, $LogonType, $SecurityDescriptor)
    if ($Flags -ne 6 -or $LogonType -ne 3 -or $null -ne $Password) { throw 'Incorrect task registration flags' }
    [xml]$parsed = $Xml
    if ([string]$parsed.Task.Principals.Principal.UserId -ne $User) { throw 'Incorrect task user' }
    if ($this.DropArguments) { $parsed.Task.Actions.Exec.Arguments = '' }
    $this.Registrations++
    $registered = [pscustomobject]@{ Xml = $parsed.OuterXml; Enabled = $true }
    $this.Store[$Name] = $registered
    return $registered
}
$result = Register-KioskAutostart -Plan $chrome -Folder $folder
Assert-True $result.Verified 'Registered XML is read back and verified'
[void](Register-KioskAutostart -Plan $edge -Folder $folder)
Assert-True ($folder.Store.Count -eq 1 -and $folder.Registrations -eq 2) 'Repeat setup updates instead of duplicating tasks'
Assert-True (Disable-KioskAutostart -Plan $chrome -Folder $folder) 'Own task can be disabled after changing browser'
Assert-True (-not $folder.Store[$chrome.TaskName].Enabled) 'Disable actually changes task enabled state'
Assert-True (-not (Disable-KioskAutostart -Plan $other -Folder $folder)) 'Missing task is a harmless no-op'

[xml]$foreign = New-KioskTaskXml $chrome
$foreign.Task.RegistrationInfo.Description = 'Not managed by this tool'
$folder.Store[$chrome.TaskName] = [pscustomobject]@{ Xml = $foreign.OuterXml; Enabled = $true }
$before = $folder.Registrations
Assert-Throws { Register-KioskAutostart -Plan $chrome -Folder $folder } 'Foreign same-name task is not overwritten'
Assert-Throws { Disable-KioskAutostart -Plan $chrome -Folder $folder } 'Foreign task is not disabled'
Assert-True ($folder.Registrations -eq $before -and $folder.Store[$chrome.TaskName].Enabled) 'Ownership guard has no side effects'
$descriptionNode = $foreign.GetElementsByTagName('Description').Item(0)
[void]$descriptionNode.ParentNode.RemoveChild($descriptionNode)
$folder.Store[$chrome.TaskName].Xml = $foreign.OuterXml
Assert-Throws { Register-KioskAutostart -Plan $chrome -Folder $folder } 'Unmarked task is not overwritten'
[void]$folder.Store.Remove($chrome.TaskName)
$folder.DropArguments = $true
Assert-Throws { Register-KioskAutostart -Plan $chrome -Folder $folder } 'Dropped task arguments cannot report success'

Write-Output 'PASS: plan validation, special-character URLs, Chrome/Edge, native scheduler XML validation, real shortcut round-trip, task registration/update/disable mocks, ownership guard and parameter-loss detection.'
Write-Output ('Reviewable test artifacts: ' + $testRoot)
