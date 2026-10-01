# Godot命令行参考

## 一般选项

| 命令 | 描述 |
|------|------|
| -h, --help, /? | 显示命令行选项列表。 |
| --version | 显示版本字符串。 |
| -v, --verbose | 使用详细的标准输出模式。 |
| --quiet | 安静模式，silences stdout消息。错误仍然显示。 |

## 运行选项

| 命令 | 描述 |
|------|------|
| -e, --editor | 启动编辑器而不是运行场景（必须启用工具）。 |
| -p, --project-manager | 启动项目管理器，即使自动检测到项目（必须启用工具）。 |
| -q, --quit | 在第一次迭代后退出。 |
| -l <locale>, --language <locale> | 使用特定的区域设置（<locale>是两个字母的代码）。 |
| --path <directory> | 项目路径（<directory>必须包含'project.godot'文件）。 |
| -u, --upwards | 向上扫描文件夹查找'project.godot'文件。 |
| --main-pack <file> | 要加载的包（.pck）文件的路径。 |
| --render-thread <mode> | 渲染线程模式（'unsafe'，'safe'，'separate'）。 |
| --remote-fs <address> | 远程文件系统（<host/IP>[:<port>]地址）。 |
| --audio-driver <driver> | 音频驱动程序。首先使用--help显示可用驱动程序列表。 |
| --video-driver <driver> | 视频驱动程序。首先使用--help显示可用驱动程序列表。 |

## 显示选项

| 命令 | 描述 |
|------|------|
| -f, --fullscreen | 请求全屏模式。 |
| -m, --maximized | 请求最大化窗口。 |
| -w, --windowed | 请求窗口模式。 |
| -t, --always-on-top | 请求始终在顶部的窗口。 |
| --resolution <W>x<H> | 请求窗口分辨率。 |
| --position <X>,<Y> | 请求窗口位置。 |
| --low-dpi | 强制低DPI模式（仅macOS和Windows）。 |
| --no-window | 运行时使用不可见窗口。与--script一起使用很有用。 |

## 调试选项

| 命令 | 描述 |
|------|------|
| -d, --debug | 调试（本地标准输出调试器）。 |
| -b, --breakpoints | 断点列表，格式为source::line逗号分隔对，无空格（使用%%20代替）。 |
| --profiling | 在脚本调试器中启用分析。 |
| --remote-debug <address> | 远程调试（<host/IP>:<port>地址）。 |
| --debug-collisions | 运行场景时显示碰撞形状。 |
| --debug-navigation | 运行场景时显示导航多边形。 |
| --frame-delay <ms> | 模拟高CPU负载（每帧延迟<ms>毫秒）。 |
| --time-scale <scale> | 强制时间缩放（值越高越快，1.0是正常速度）。 |
| --disable-render-loop | 禁用渲染循环，使渲染仅在从脚本显式调用时发生。 |
| --disable-crash-handler | 在平台代码支持时禁用崩溃处理程序。 |
| --fixed-fps <fps> | 强制固定的每秒帧数。此设置禁用实时同步。 |
| --print-fps | 将每秒帧数打印到标准输出。 |

## 独立工具

| 命令 | 描述 |
|------|------|
| -s <script>, --script <script> | 运行脚本。 |
| --check-only | 仅解析错误并退出（与--script一起使用）。 |
| --export <target> | 使用给定的导出目标导出项目。如果路径以.pck或.zip结尾，则仅导出主包（必须启用工具）。 |
| --export-debug <target> | 类似于--export，但使用调试模板（必须启用工具）。 |
| --doctool <path> | 将引擎API参考以XML格式转储到给定的<path>，如果找到现有文件则合并（必须启用工具）。 |
| --no-docbase | 禁止转储基本类型（与--doctool一起使用，必须启用工具）。 |
| --build-solutions | 构建脚本解决方案（例如，对于C#项目，必须启用工具）。 |
| --gdnative-generate-json-api | 为GDNative绑定生成Godot API的JSON转储（必须启用工具）。 |
| --test <test> | 运行单元测试。首先使用--help显示测试列表。（必须启用工具）。 |
| --export-pack <preset> <path> | 类似于--export，但仅导出给定预设的游戏包。<path>扩展名确定它是PCK还是ZIP格式。（必须启用工具）。 |
