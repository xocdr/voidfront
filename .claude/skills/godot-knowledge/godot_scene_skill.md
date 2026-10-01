# Godot UI 与场景开发指南

## 1. 概述

TSCN（文本场景）是 Godot 引擎的核心文件格式，用于构建游戏的 UI 和场景。

## 2. 场景基础

### 2.1 场景结构

TSCN 文件包含以下主要部分：

1. **文件描述符**: 定义场景基本信息
2. **外部资源**: 引用其他文件的资源
3. **内部资源**: 在当前文件中定义的资源
4. **节点**: 构成场景树的核心元素
5. **连接**: 节点间的信号连接

### 2.2 基本场景模板

```tscn
[gd_scene load_steps=2 format=3 uid="uid://example"]

[ext_resource type="Script" path="res://ui/main_menu.gd" id=1]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
offset_right = 1280.0
offset_bottom = 720.0
script = ExtResource(1)
```

## 3. UI 节点系统

### 3.1 核心 UI 节点

| 节点类型 | 用途 | 特性 |
|---------|------|------|
| Control | UI 根节点 | 提供布局和变换功能 |
| Label | 文本显示 | 支持富文本、自动换行 |
| Button | 交互按钮 | 支持多种状态和样式 |
| TextureRect | 图片显示 | 支持各种纹理格式 |
| LineEdit | 单行输入 | 支持输入验证和提示 |
| RichTextLabel | 富文本显示 | 支持 HTML 标签 |
| ProgressBar | 进度显示 | 支持水平/垂直方向 |
| Slider | 值调节 | 支持范围限制和步长 |

### 3.2 布局系统

#### 锚点预设

```tscn
[node name="Button" type="Button"]
anchors_preset = 15  # Full Rect
anchors_preset = 12  # Center
anchors_preset = 0   # Top Left
```

#### 容器布局

```tscn
[node name="VBoxContainer" type="VBoxContainer"]
layout_mode = 3
anchors_preset = 15
offset_right = 400.0
offset_bottom = 300.0
vertical_alignment = 1
spacing = 20

[node name="Button1" type="Button" parent="VBoxContainer"]
text = "按钮1"
size_flags_horizontal = 3
```

### 3.3 UI 样式

```tscn
[sub_resource type="Theme" id=1]

[sub_resource type="StyleBoxFlat" id=2]
bg_color = Color(0.2, 0.6, 0.8, 1.0)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_left = 8
corner_radius_bottom_right = 8

[node name="Button" type="Button"]
theme_override_styles/normal = SubResource(2)
```

## 4. 场景开发最佳实践

### 4.1 项目组织

```
project/
├── scenes/
│   ├── ui/
│   │   ├── main_menu.tscn
│   │   └── hud.tscn
│   └── levels/
│       └── level1.tscn
├── scripts/
└── resources/
```

### 4.2 实例化场景

```tscn
[ext_resource type="PackedScene" path="res://scenes/ui/button.tscn" id=1]

[node name="ButtonContainer" type="VBoxContainer"]

[node name="CustomButton" parent="ButtonContainer" instance=ExtResource(1)]
text = "自定义按钮"
```

## 5. UI 交互与信号

### 5.1 信号连接

```tscn
[node name="Button" type="Button"]
text = "点击我"

[connection signal="pressed" from="Button" to="." method="_on_button_pressed"]
```

### 5.2 常用 UI 信号

| 节点类型 | 常用信号 |
|---------|----------|
| Button | pressed, toggled |
| LineEdit | text_changed, text_submitted |
| Slider | value_changed |
| CheckBox | toggled |

## 6. 完整示例：主菜单

```tscn
[gd_scene load_steps=4 format=3 uid="uid://main_menu"]

[ext_resource type="Script" path="res://scripts/main_menu.gd" id=1]

[sub_resource type="StyleBoxFlat" id=2]
bg_color = Color(0.1, 0.4, 0.7, 1.0)
corner_radius = 12

[sub_resource type="StyleBoxFlat" id=3]
bg_color = Color(0.15, 0.5, 0.8, 1.0)
corner_radius = 12

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
offset_right = 1280.0
offset_bottom = 720.0
script = ExtResource(1)

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.05, 0.05, 0.1, 1.0)

[node name="MenuContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
offset_left = 540.0
offset_top = 350.0
offset_right = 740.0
offset_bottom = 550.0
spacing = 20

[node name="StartButton" type="Button" parent="MenuContainer"]
text = "开始游戏"
theme_override_styles/normal = SubResource(2)
theme_override_styles/hover = SubResource(3)

[node name="SettingsButton" type="Button" parent="MenuContainer"]
text = "设置"
theme_override_styles/normal = Sub[node name="QuitResource(2)

Button" type="Button" parent="MenuContainer"]
text = "退出"
theme_override_styles/normal = SubResource(2)

[connection signal="pressed" from="MenuContainer/StartButton" to=".." method="_on_start_pressed"]
[connection signal="pressed" from="MenuContainer/QuitButton" to=".." method="_on_quit_pressed"]
```

## 7. 性能优化

### 7.1 UI 性能优化

- 减少节点数量，避免过深嵌套
- 使用 VisibilityNotifier2D 控制 UI 显示
- 避免在 _process() 中频繁更新 UI
- 使用纹理图集减少 Draw Call

### 7.2 场景性能优化

- 使用实例化减少内存占用
- 合理使用资源加载策略
- 使用 set_process(false) 禁用不需要的节点更新

## 8. 参考资料

- [Godot 官方文档](https://docs.godotengine.org/)
- [UI 节点文档](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)
- [场景系统](https://docs.godotengine.org/en/stable/tutorials/scripting Scenes.html)
