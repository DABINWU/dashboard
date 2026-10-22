param([switch]$SmokeTest, [string]$PreviewPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

try {
    . (Join-Path $PSScriptRoot 'kiosk-core.ps1')

    $form = New-Object Windows.Forms.Form
    $form.Text = '看板全屏播放 · 一键配置'
    $form.ClientSize = New-Object Drawing.Size(780, 670)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9)
    $form.BackColor = [Drawing.Color]::FromArgb(247, 249, 252)
    $form.AutoScaleMode = 'Dpi'

    function Add-Label([string]$Text, [int]$X, [int]$Y, [int]$Width = 710) {
        $label = New-Object Windows.Forms.Label
        $label.Text = $Text
        $label.SetBounds($X, $Y, $Width, 24)
        $form.Controls.Add($label)
        $label
    }
    function Add-TextBox([int]$X, [int]$Y, [int]$Width) {
        $box = New-Object Windows.Forms.TextBox
        $box.SetBounds($X, $Y, $Width, 28)
        $form.Controls.Add($box)
        $box
    }
    function Add-Button([string]$Text, [int]$X, [int]$Y, [int]$Width = 94) {
        $button = New-Object Windows.Forms.Button
        $button.Text = $Text
        $button.SetBounds($X, $Y, $Width, 32)
        $form.Controls.Add($button)
        $button
    }
    $heading = Add-Label '选择 HTML，一键配置全屏与登录启动' 24 20
    $heading.Font = New-Object Drawing.Font('Microsoft YaHei UI', 15, [Drawing.FontStyle]::Bold)
    $heading.Height = 36
    $hint = Add-Label '文件仅在本机使用，不会上传。请先把 HTML 和依赖资源放在固定目录。' 24 64
    $hint.ForeColor = [Drawing.Color]::FromArgb(85, 100, 120)

    [void](Add-Label '播放器 HTML' 24 108 110)
    $htmlBox = Add-TextBox 140 104 506
    $htmlBrowse = Add-Button '选择文件…' 656 102
    $defaultHtml = Join-Path $PSScriptRoot 'dashboard-player.html'
    if (Test-Path -LiteralPath $defaultHtml -PathType Leaf) { $htmlBox.Text = $defaultHtml }

    [void](Add-Label '浏览器' 24 157 110)
    $browserCombo = New-Object Windows.Forms.ComboBox
    $browserCombo.SetBounds(140, 153, 130, 28)
    $browserCombo.DropDownStyle = 'DropDownList'
    [void]$browserCombo.Items.AddRange(@('Chrome', 'Edge'))
    $form.Controls.Add($browserCombo)
    $browserBox = Add-TextBox 282 153 364
    $browserBrowse = Add-Button '选择程序…' 656 151

    [void](Add-Label '登录后延迟' 24 206 110)
    $delayBox = New-Object Windows.Forms.NumericUpDown
    $delayBox.SetBounds(140, 202, 80, 28)
    $delayBox.Minimum = 0
    $delayBox.Maximum = 3600
    $delayBox.Value = 30
    $form.Controls.Add($delayBox)
    [void](Add-Label '秒（需要 Windows 用户先登录）' 230 206 390)

    $autostartCheck = New-Object Windows.Forms.CheckBox
    $autostartCheck.Text = '创建 / 更新登录自启任务'
    $autostartCheck.SetBounds(24, 252, 235, 28)
    $autostartCheck.Checked = $true
    $form.Controls.Add($autostartCheck)
    $desktopCheck = New-Object Windows.Forms.CheckBox
    $desktopCheck.Text = '同时创建桌面快捷方式'
    $desktopCheck.SetBounds(280, 252, 220, 28)
    $desktopCheck.Checked = $true
    $form.Controls.Add($desktopCheck)
    $launchCheck = New-Object Windows.Forms.CheckBox
    $launchCheck.Text = '完成后立即全屏播放'
    $launchCheck.SetBounds(525, 252, 225, 28)
    $launchCheck.Checked = $true
    $form.Controls.Add($launchCheck)

    $previewButton = Add-Button '预览配置' 24 299 110
    $installButton = Add-Button '一键生成并应用' 148 299 180
    $installButton.BackColor = [Drawing.Color]::FromArgb(35, 105, 220)
    $installButton.ForeColor = [Drawing.Color]::White
    $installButton.FlatStyle = 'Flat'
    $disableButton = Add-Button '取消此看板自启' 342 299 156
    $openButton = Add-Button '打开配置目录' 512 299 140

    $output = New-Object Windows.Forms.TextBox
    $output.SetBounds(24, 350, 726, 252)
    $output.Multiline = $true
    $output.ReadOnly = $true
    $output.ScrollBars = 'Both'
    $output.WordWrap = $false
    $output.BackColor = [Drawing.Color]::White
    $output.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9)
    $output.Text = @'
先选择 HTML 和浏览器，点击“预览配置”核对。
点击“一键生成并应用”后，才会写入快捷方式和计划任务。
再次选择同一 HTML 会更新原有任务；移动 HTML 后需要重新配置。
取消勾选自启不会停用已存在的任务；停用请点击“取消此看板自启”。
'@
    $form.Controls.Add($output)
    $footer = Add-Label '退出全屏：Alt + F4  ·  本工具不配置 Windows 自动登录，也不修改 HTML 内容。' 24 620
    $footer.ForeColor = [Drawing.Color]::FromArgb(85, 100, 120)

    $candidates = @(Get-KioskBrowserCandidates)
    function Update-BrowserPath {
        $name = [string]$browserCombo.SelectedItem
        $found = @($candidates | Where-Object { $_.Name -eq $name })
        $browserBox.Text = if ($found.Count -gt 0) { $found[0].Path } else { '' }
    }
    function Read-CurrentPlan {
        if ([string]::IsNullOrWhiteSpace($htmlBox.Text)) { throw '请先选择播放器 HTML 文件。' }
        if ([string]::IsNullOrWhiteSpace($browserBox.Text)) { throw '未自动找到浏览器，请选择对应的 chrome.exe 或 msedge.exe。' }
        New-KioskPlan -HtmlPath $htmlBox.Text.Trim() -BrowserName ([string]$browserCombo.SelectedItem) -BrowserPath $browserBox.Text.Trim() -DelaySeconds ([int]$delayBox.Value)
    }
    function Show-Plan($Plan) {
        $output.Text = @"
HTML：$($Plan.HtmlPath)
程序：$($Plan.BrowserPath)
参数：$($Plan.Arguments)
工作目录：$($Plan.WorkingDirectory)
配置目录：$($Plan.InstallDirectory)
任务名称：$($Plan.TaskName)
登录用户：$([Security.Principal.WindowsIdentity]::GetCurrent().Name)
登录后延迟：$($Plan.DelaySeconds) 秒
"@.Replace("`n", "`r`n")
    }
    function Append-Log([string]$Message) {
        $output.AppendText("`r`n" + $Message)
        $output.SelectionStart = $output.TextLength
        $output.ScrollToCaret()
    }
    function Show-Failure($Failure) {
        Append-Log ('失败：' + $Failure.Exception.Message)
        Append-Log '未报告配置成功。上方已完成的步骤可能仍保留，请按日志检查；企业策略限制时请联系管理员。'
        [void][Windows.Forms.MessageBox]::Show($form, $Failure.Exception.Message, '配置未完成', 'OK', 'Error')
    }
    $browserCombo.Add_SelectedIndexChanged({ Update-BrowserPath })
    $browserCombo.SelectedIndex = if (@($candidates | Where-Object Name -eq 'Chrome').Count -gt 0 -or $candidates.Count -eq 0) { 0 } else { 1 }
    $htmlBrowse.Add_Click({
        $dialog = New-Object Windows.Forms.OpenFileDialog
        try {
            $dialog.Title = '选择播放器 HTML'
            $dialog.Filter = 'HTML 文件 (*.html;*.htm)|*.html;*.htm'
            if ($dialog.ShowDialog($form) -eq 'OK') { $htmlBox.Text = $dialog.FileName }
        } finally { $dialog.Dispose() }
    })
    $browserBrowse.Add_Click({
        $dialog = New-Object Windows.Forms.OpenFileDialog
        try {
            $dialog.Title = '选择浏览器可执行文件'
            $dialog.Filter = '浏览器程序 (*.exe)|*.exe'
            if ($dialog.ShowDialog($form) -eq 'OK') { $browserBox.Text = $dialog.FileName }
        } finally { $dialog.Dispose() }
    })
    $previewButton.Add_Click({
        try { Show-Plan (Read-CurrentPlan) } catch { Show-Failure $_ }
    })
    $installButton.Add_Click({
        $installButton.Enabled = $false
        $form.UseWaitCursor = $true
        try {
            $plan = Read-CurrentPlan
            Show-Plan $plan
            # Check ownership before writing or updating any registered task.
            $folder = $null
            if ($autostartCheck.Checked) {
                $folder = Get-KioskTaskFolder
                [void](Get-KioskExistingTask -Folder $folder -Plan $plan)
            }
            $files = Export-KioskFiles -Plan $plan
            Append-Log ('已生成并核对快捷方式：' + $files.ShortcutPath)
            if ($autostartCheck.Checked) {
                [void](Register-KioskAutostart -Plan $plan -Folder $folder)
                Append-Log ('已创建 / 更新并核对自启任务：' + $plan.TaskName)
            } else {
                Append-Log '本次未修改自启任务。'
            }
            if ($desktopCheck.Checked) {
                $desktopPath = Join-Path ([Environment]::GetFolderPath('Desktop')) $plan.ShortcutName
                if (Test-Path -LiteralPath $desktopPath) {
                    $shell = New-Object -ComObject WScript.Shell
                    $existing = $shell.CreateShortcut($desktopPath)
                    if ($existing.Description -ne 'DashboardPlayer fullscreen kiosk') { throw '桌面同名快捷方式不属于本工具，未覆盖。配置目录内的快捷方式已保留。' }
                }
                Copy-Item -LiteralPath $files.ShortcutPath -Destination $desktopPath -Force
                Append-Log ('已创建桌面快捷方式：' + $desktopPath)
            }
            Append-Log '配置完成。旧的手工任务或启动目录快捷方式请自行停用，避免重复启动。'
            if ($launchCheck.Checked) {
                Start-KioskPlayer -Plan $plan
                Append-Log '已请求启动浏览器，请核对实际显示效果。'
            }
        } catch { Show-Failure $_ }
        finally { $installButton.Enabled = $true; $form.UseWaitCursor = $false }
    })
    $disableButton.Add_Click({
        try {
            $plan = Read-CurrentPlan
            Show-Plan $plan
            if (Disable-KioskAutostart -Plan $plan) { Append-Log '此看板的自启任务已停用。保留快捷方式、HTML 和浏览器数据，不关闭已运行的窗口。' }
            else { Append-Log '未找到本工具为此 HTML 创建的任务。手工创建的旧任务不受此按钮影响。' }
        } catch { Show-Failure $_ }
    })
    $openButton.Add_Click({
        try {
            $plan = Read-CurrentPlan
            if (-not (Test-Path -LiteralPath $plan.InstallDirectory -PathType Container)) { throw '配置目录尚不存在，请先生成配置。' }
            Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $plan.InstallDirectory + '"')
        } catch { Show-Failure $_ }
    })
    if ($SmokeTest) {
        $plan = Read-CurrentPlan
        Show-Plan $plan
        if ($PreviewPath) {
            $form.ShowInTaskbar = $false
            $form.StartPosition = 'Manual'
            $form.Location = New-Object Drawing.Point(-30000, -30000)
            $form.Show()
            [Windows.Forms.Application]::DoEvents()
            $bitmap = New-Object Drawing.Bitmap($form.Width, $form.Height)
            try {
                $form.PerformLayout()
                $form.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
                $bitmap.Save([IO.Path]::GetFullPath($PreviewPath), [Drawing.Imaging.ImageFormat]::Png)
            } finally { $bitmap.Dispose(); $form.Hide() }
        }
        Write-Output ('GUI smoke test passed. Controls: ' + $form.Controls.Count + '; Browser: ' + $plan.BrowserName)
        $form.Dispose()
    } else {
        [void]$form.ShowDialog()
        $form.Dispose()
    }
} catch {
    if ($SmokeTest) { throw }
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message, '无法打开配置工具', 'OK', 'Error')
    exit 1
}
