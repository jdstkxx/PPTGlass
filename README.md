# PPT沙漏 pptglass

一个极简的 PPT / WPS 放映计时器：屏幕右上角一条纯黑时间条，双击即开始计时并启动放映，放映结束自动复位。

![icon](ppttimer_icon.ico)

## 功能

- **自动计时**：检测到 PowerPoint / WPS 进入放映，自动开始倒计时；退出放映自动停止复位
- **双击联动**：双击时间条 = 开始计时 + 启动当前打开的演示文稿放映（PowerPoint / WPS 均支持）
- **预铃提醒**：剩余 N 分钟时数字变橙、弹出提示并播放声音（0–30 分钟可配）
- **超时提示**：到点后红色闪烁 + 超时正计时 + 自定义提示语 + 声音
- **手动控制**：F12 开始 / Ctrl+F12 停止 / Win+ESC 退出（快捷键可在 ini 修改），也可双击或右键菜单操作
- **悬停交互**：时间条默认鼠标穿透，不遮挡放映；鼠标悬停时浮出 ⚙ 设置 / ℹ 关于 / ✕ 退出
- **设置**：限时 1–99 分钟、预铃、音量、声音文件、超时提示语、自动隐藏、开机自启（均持久化）
- **半透明**：时间条 84% 不透明度（ini 可调），尽量少遮挡演示内容

## 实现原理

程序本体是 [AutoHotkey 1.1](https://www.autohotkey.com/) 脚本（Ahk2Exe 编译为单文件 exe）：

1. **放映检测**：250ms 轮询——PowerPoint 放映窗口类 `screenClass`，以及 WPS 演示进程（wpp.exe/wps.exe）中"可见 + 置顶 + 全屏"的窗口（双策略，兼容新版 WPS）
2. **倒计时渲染**：GDI+ 绘制纯黑圆角位图 → `STM_SETIMAGE` 送入图片控件呈现；数字使用 [DSEG7](https://github.com/keshikan/DSEG) 七段数码管字体（私有字体集合加载，免安装）
3. **放映联动**：COM（`ComObjActive`）挂接已运行的 PowerPoint / WPS 实例，`SlideShowSettings.Run()` 启动放映
4. **交互**：时间条默认 `WS_EX_TRANSPARENT` 鼠标穿透；悬停时移除穿透并浮出按钮（⚙ ℹ ✕）；拖动靠 `WM_NCLBUTTONDOWN` 原生移动

## 开发工具

| 工具 | 用途 |
|---|---|
| [AutoHotkey 1.1.37](https://www.autohotkey.com/) | 脚本运行时 |
| [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe) | 编译为单文件 exe |
| [DSEG7 Classic](https://github.com/keshikan/DSEG) | 七段数码管字体（SIL OFL 1.1） |
| GDI+ / Win32 API | 卡片绘制、放映窗口检测 |

## 使用

- **单文件版**：从 [Releases](https://github.com/jdstkxx/PPTGlass/releases) 下载 `PPTGlass-v1.0.0.zip`（），运行即可——字体与提示音已内嵌，首次运行自动解包到临时目录
- **源码运行**：需要 AutoHotkey 1.1；`src/pptglass.ahk` 同目录放置 `fonts/DSEG7.ttf` 与 `sounds/*.wav`（ini 可改路径）
- 打开你的 PPT / WPS 演示文稿，**双击屏幕右上角的时间条**——计时开始，放映同时启动
- 讲完按 ESC 退出放映，计时自动结束

所有配置保存在 `ppttimer_new.ini`（脚本目录），可直接编辑（含放映窗口类名、进程名、快捷键、透明度）。

## 作者

**jdstkxx** · [github.com/jdstkxx](https://github.com/jdstkxx)

灵感与功能清单参考陈家琪老师的《PPT播放提示钟》（2003）。

## 许可证

[MIT License](LICENSE)
