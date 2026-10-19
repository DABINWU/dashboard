# 大屏看板轮播播放器

一个无需安装依赖、无需构建的单文件网页播放器。通过多个 `iframe` 展示已有网页，按设定时间循环切换，适合在车间看板、库存大屏、信息展示屏等场景使用。

播放器本身没有后端，也不提供看板业务数据。展示内容来自配置的网站，运行电脑需要能够访问这些网站。

## 快速开始

1. 下载项目，将 `dashboard-player.html` 放到固定目录，例如 `C:\project\dashboard`。
2. 用支持 UTF-8 的文本编辑器修改 HTML 中的 `const pages`，填写实际看板地址和播放时长。
3. 双击 HTML 可以预览；需要无人操作全屏展示时，按下文创建 Chrome 或 Edge 的 Kiosk 快捷方式。
4. 先验证每个页面能正常展示，再配置开机自启。

当前源码配置了 **5 个网页，每页 5 秒**，包含内网地址和第三方网站测试地址。请在部署前替换为自己的页面；这些地址不保证在其他电脑上可访问，也不保证允许 iframe 嵌入。

## 文件说明

| 文件或目录 | 作用 | 是否提交 GitHub |
| --- | --- | --- |
| `dashboard-player.html` | 播放器页面，包含样式、轮播配置和逻辑 | 是，公开前检查其中的真实地址 |
| `README.md` | 使用、部署和故障排查说明 | 是 |
| `.gitignore` | 排除本机浏览器数据和快捷方式 | 是 |
| `Dashboard-Kiosk.lnk` | 本机生成的 Edge 启动快捷方式，包含绝对路径 | 否，换电脑后应重新创建 |
| `.chrome-kiosk/` | Chrome 专用用户数据目录，运行后生成 | 否 |
| `.edge-kiosk/` | Edge 专用用户数据目录，运行后生成 | 否 |

## 配置轮播页面

打开 `dashboard-player.html`，找到 `const pages = [...]`，按下面的格式修改。示例中的 `.test` 地址只是占位符，需要替换：

```js
const pages = [
  {
    name: "生产看板",
    url: "http://dashboard.example.test/production/",
    duration: 30000
  },
  {
    name: "库存看板",
    url: "http://dashboard.example.test/inventory/",
    duration: 60000
  }
];
```

| 字段 | 说明 |
| --- | --- |
| `name` | 页面名称，用于 iframe 标题和右下角状态显示 |
| `url` | 完整网页地址，通常以 `http://` 或 `https://` 开头 |
| `duration` | 当前页的展示时间，单位为毫秒 |

常用时长：`5000` 为 5 秒，`10000` 为 10 秒，`30000` 为 30 秒，`60000` 为 1 分钟，`120000` 为 2 分钟。

- 数组顺序就是播放顺序，最后一页之后返回第一页。
- 使用正整数配置 `duration`；当前代码在未填写或设为 `0` 时按 30 秒处理，`0` 不能用来停止轮播。
- 只有一个页面时不会自动切换；页面数组为空时，状态文字显示“没有配置展示页面”。
- 每个页面应使用准确、易区分的名称，避免沿用测试配置中的重复名称。
- 修改配置后需要重新加载播放器外层页面。右侧的刷新按钮只刷新当前内嵌网页，不会重新读取 HTML 配置。

## Windows 全屏启动

### 自动轮播与自动全屏

页面打开后会立即开始轮播，普通浏览器窗口中即使显示全屏提示层，后台也在计时切换。

双击 HTML、创建一个指向 HTML 的快捷方式，都会通过默认浏览器打开页面，不能保证自动全屏。普通网页调用 `requestFullscreen()` 通常需要用户点击或按键触发；本项目通过点击提示层或按 `F` 请求网页全屏。参见 [Fullscreen API 说明](https://developer.mozilla.org/en-US/docs/Web/API/Element/requestFullscreen)。

无人操作的大屏应由浏览器的 Kiosk 启动参数进入全屏。快捷方式的“目标”必须指向 **浏览器的 `.exe` 文件**，并附带参数。

以下命令用于 Windows 快捷方式的“目标”栏，也可以在 CMD 中执行。如果在 PowerShell 中执行，需要在最前面加 `& `。

### Chrome 快捷方式

在 Windows 中新建快捷方式，将下面完整的一行粘贴到“目标”：

```text
"C:\Program Files\Google\Chrome\Application\chrome.exe" --kiosk "file:///C:/project/dashboard/dashboard-player.html" --no-first-run --user-data-dir="C:\project\dashboard\.chrome-kiosk"
```

“起始位置”填写：

```text
C:\project\dashboard
```

Chrome 使用 `--kiosk`，无需添加 Edge 专用的 `--edge-kiosk-type=fullscreen`。Kiosk 开关可在 [Chromium 源码](https://github.com/chromium/chromium/blob/main/chrome/common/chrome_switches.h)中查阅。

如果找不到 `chrome.exe`，请在 Chrome 快捷方式的属性中确认安装路径；部分电脑安装在 `C:\Program Files (x86)` 或当前用户的应用目录中。

### Edge 快捷方式

“目标”填写：

```text
"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --kiosk "file:///C:/project/dashboard/dashboard-player.html" --edge-kiosk-type=fullscreen --no-first-run --user-data-dir="C:\project\dashboard\.edge-kiosk"
```

“起始位置”填写：

```text
C:\project\dashboard
```

部分电脑的 Edge 安装在 `C:\Program Files\Microsoft\Edge\Application\msedge.exe`，请以实际路径为准。Edge 的全屏 Kiosk 参数见[微软官方说明](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-configure-kiosk-mode#use-kiosk-mode-features)。

### 参数与路径注意事项

| 参数 | 作用 |
| --- | --- |
| `--kiosk "file:///..."` | 以 Kiosk 模式打开播放器地址 |
| `--edge-kiosk-type=fullscreen` | Edge 的全屏展示模式，Chrome 不需要此项 |
| `--no-first-run` | 跳过浏览器首次运行引导；不能保证跳过企业策略或系统提示 |
| `--user-data-dir="..."` | 指定播放器专用浏览器数据目录，减少与日常浏览器共用实例的干扰 |

- 示例假设项目放在 `C:\project\dashboard`。换位置时，同时修改网页 URL、用户数据目录和“起始位置”。
- 浏览器路径和用户数据目录使用 Windows 路径；`file:///` 后的网页路径使用 `/`。含空格的路径要保留英文双引号。
- 数据目录需要对当前 Windows 用户可写。Chrome 和 Edge 应使用各自的目录，不要让两个浏览器共用一个目录。
- 专用目录会保存浏览器运行数据，可能包含 Cookie、缓存和登录信息。它不是项目源码，不应上传。
- 修改启动参数后，先用 `Alt + F4` 关闭之前启动的播放器窗口，再测试新快捷方式。已有同目录的浏览器实例可能影响新参数的应用。
- `Alt + F4` 用于关闭播放器窗口。Kiosk 下不要依赖 `Esc` 或 `F11` 退出；Edge Kiosk 会限制 `F11`，见[微软支持功能说明](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-configure-kiosk-mode#kiosk-mode-supported-features)。

`--user-data-dir` 的背景和用法见 [Chromium 用户数据目录文档](https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md)。

## 开机自启

这里的“开机自启”指 **Windows 用户登录后启动**，项目不会配置 Windows 自动登录。

1. 先手动运行 Kiosk 快捷方式，确认无地址栏、内容全屏且不需要点击提示层。
2. 按 `Win + R`，输入 `shell:startup` 并回车。
3. 将验证通过的浏览器 Kiosk 快捷方式复制到这个目录，移除旧的看板启动项，避免同时打开多个播放器。
4. 重启并登录 Windows，确认每个页面都能加载、轮播和保持全屏。

启动目录中应放入指向浏览器并带参数的快捷方式。指向 `dashboard-player.html` 的普通快捷方式不具备 Kiosk 参数。

如果登录时网络、显示器或看板服务尚未就绪，可改用 Windows 任务计划程序，在用户登录后延迟 15～30 秒启动，并选择“只在用户登录时运行”。延迟仅是部署建议，本项目未内置网络就绪检测或启动重试；请避免与启动目录重复配置。

播放电脑还需要按实际使用需求设置睡眠、息屏和屏幕保护程序。播放器本身不会阻止 Windows 休眠，也不负责浏览器崩溃后的自动重启。

## 播放控制

鼠标移到屏幕右侧约 120 像素范围可显示控制栏。控制栏与状态信息默认隐藏，触发后约 4 秒隐藏。

| 操作 | 功能 |
| --- | --- |
| `→` 或 `↓` | 下一页 |
| `←` 或 `↑` | 上一页 |
| 空格 | 暂停或继续轮播 |
| `F` | 请求或退出网页 Fullscreen API 全屏 |
| `R` | 刷新当前内嵌网页 |
| 右侧按钮 | 上一页、暂停/继续、下一页、刷新当前页、网页全屏切换 |
| `Alt + F4` | 关闭浏览器窗口 |

这些页面快捷键监听在播放器外层文档上。鼠标点击内嵌网页后，键盘焦点可能进入 iframe，外层快捷键可能无法响应，此时使用右侧按钮操作。

`F` 和全屏按钮控制的是网页 Fullscreen API，无法保证退出浏览器本身的 Kiosk 全屏。暂停只停止自动切换，不会暂停内嵌网页的视频、动画、数据请求或定时刷新。暂停期间仍可手动翻页；恢复后从当前页重新计满该页时长，不保留剩余时间。

## 实现细节与限制

### 预加载与切换

- 启动时创建全部 iframe，并立即加载所有配置页面，首屏显示第一页。
- 切换时改变页面的可见性，不重新加载网页；样式配置了 0.8 秒的透明度过渡，实际效果取决于页面和浏览器渲染。
- 计时从显示页面开始，不等待 iframe 加载完成。网络较慢时，5 秒可能不足以完成首次加载，应延长时长。
- 隐藏 iframe 仍可能继续运行脚本、连接、音频或视频；没有按可见性暂停、统一静音或视频自动播放策略配置。
- 页面越多，浏览器内存和网络开销通常越大；后台页面也可能被浏览器节流。请用实际看板数量进行长时间运行验证。
- 当前没有加载失败提示、自动跳过坏页、断网恢复检测或崩溃守护。无法展示的页面仍会占用配置的轮播时间。

### 定时刷新

当前代码每隔 **10 分钟**执行一次 `refreshCurrentPage()`，重新赋值当前 iframe 的地址。

这个动作只重新加载执行时正在展示的页面，不会同时刷新所有页面，也不保证绕过浏览器缓存。间隔与轮播周期重合时，同一页可能反复被刷新，其他页则长期不被刷新。暂停轮播期间，该定时器仍会运行。

需要调整刷新间隔时，在源码末尾修改 `10 * 60 * 1000`。如果看板已经自行更新数据，可以按业务需要调整这一行为。

### 全屏提示检测

为处理浏览器在页面加载后才进入 Kiosk 的情况，当前实现：

- 启动后前 1.5 秒暂时隐藏提示层，给浏览器留出启动时间。
- 页面初始化、`resize`、`pageshow` 和 `fullscreenchange` 时重新判断。
- 每隔 1 秒再次检查，以兼容延迟进入全屏的情况。
- 优先检查 `document.fullscreenElement`；浏览器 Kiosk / F11 全屏则通过屏幕与窗口内容区域的宽高差判断，两项都小于 15 个 CSS 像素时隐藏提示层。

尺寸检测属于推断，页面无法直接读取浏览器是否带有 `--kiosk` 参数。非 100% 网页缩放、多显示器和特殊窗口布局可能影响判断，建议先将播放器缩放恢复为 100% 后验证。Windows 显示缩放不等于网页缩放，不必一开始就修改系统缩放。

该检测逻辑已做过模拟验证，包含延迟进入 Kiosk、退出全屏、定时复查和 Fullscreen API 事件；不同电脑的真实开机流程仍需现场验证。

### iframe、登录与部署限制

- 目标网站可以通过 `X-Frame-Options` 或 CSP `frame-ancestors` 限制嵌入。被拒绝时应由目标网站维护方调整允许来源，或改用该网站提供的嵌入页面；修改本播放器的 URL 或增加 `allow="fullscreen"` 不能绕过限制。参见 [X-Frame-Options](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/X-Frame-Options) 和 [frame-ancestors](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/frame-ancestors)。
- 跨域 iframe 的键盘事件和页面内部状态不能按普通同页内容处理。当前播放器不读取内嵌网页的业务 DOM，也无法据此判断业务数据是否正常。
- 登录状态取决于目标站点、浏览器 Cookie 设置和运行模式。Chrome 专用目录与日常 Chrome 登录状态分开；Edge Kiosk 使用 InPrivate 会话，不要假定登录状态重启后会保留，见[微软模式说明](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-configure-kiosk-mode#overview)。
- 如果以 HTTPS 托管播放器，再嵌入 HTTP 内网看板，浏览器可能因混合内容而阻止加载。部署时要同时验证协议、证书、嵌入策略和网络访问条件。
- GitHub 托管源码不会让外网用户获得内网看板访问权限；本项目也没有提供代理、认证或内网穿透服务。

## 常见问题

| 现象 | 排查方法 |
| --- | --- |
| 双击后还显示“点击进入全屏展示” | 检查快捷方式“目标”是否从浏览器 `.exe` 开始且包含 `--kiosk`，不要点击 HTML 或旧的 HTML 快捷方式；确认加载的是修改后的 HTML |
| 启动参数正确，但仍有提示层 | 先关闭旧播放器再启动；确认不是普通最大化窗口，恢复网页缩放为 100%；区分浏览器实际没有全屏和尺寸检测误判 |
| 仍能看到任务栏 | 可能没有进入全屏，也可能有其他窗口、系统提示或任务栏覆盖；单凭截图不能确定，需要结合窗口状态检查 |
| 单独打开网站正常，轮播中空白或提示拒绝连接 | 检查看板电脑的网络、目标站点嵌入策略、协议和登录状态；浏览器控制台可查看具体错误 |
| 开机后空白，过一会儿手动打开正常 | 检查网络和看板服务启动时间，可使用任务计划程序延迟启动；当前没有启动失败重试机制 |
| 修改 `pages` 后没有变化 | 重新加载外层播放器或退出后重开；当前页刷新按钮不会更新播放器配置 |
| 按键没有反应 | 焦点可能在 iframe 中，改用屏幕右侧控制栏 |
| 某页经常刷新，其他页一直不刷新 | 每 10 分钟只刷新当时显示的一页，需要按需求修改刷新策略 |
| 浏览器提示用户数据目录被占用 | 关闭使用同一专用目录的播放器后再启动；不要在浏览器运行时删除配置目录 |

## 上传 GitHub

本项目的 `.gitignore` 已排除 `.chrome-kiosk/`、`.edge-kiosk/` 和 `*.lnk`。浏览器目录可能很大，并包含本机运行和登录数据；快捷方式包含本机绝对路径，其他电脑应按 README 重新创建。

**当前 HTML 仍包含真实内网 IP、端口、路径以及第三方测试网址。** 公开仓库前，请按公开范围检查并替换为示例地址；需要保留现场配置时，可先在仓库之外备份一份。本次文档整理没有替换实际运行地址。

还应检查地址中是否带有账号、密码、Token 或其他访问凭据，不要把凭据写入源码。`.gitignore` 只影响 Git 文件跟踪，不会过滤 HTML 内容，也不会阻止在 GitHub 网页端手动上传敏感文件。

首次使用 Git 时，可以按顺序执行以下命令，先明确选择要提交的文件：

```bash
git init
git add README.md .gitignore dashboard-player.html
git diff --cached
git commit -m "Add dashboard player and usage documentation"
git branch -M main
```

在 GitHub 创建一个空仓库后，再将下面的占位用户名和仓库名换成自己的信息：

```bash
git remote add origin https://github.com/YOUR_NAME/YOUR_REPOSITORY.git
git push -u origin main
```

如果已经有 Git 仓库或远程地址，不要重复初始化或添加 `origin`，按现有仓库配置提交即可。提交前查看 `git status`，确认没有浏览器目录、快捷方式或个人数据。如果这些文件以前已提交，新增 `.gitignore` 不会自动取消跟踪，也不会清除已有历史。

项目目前没有附带开源许可证文件。需要允许他人使用、修改和分发时，请由维护者选择合适的许可证并添加 `LICENSE`。
