# Godot TSCN 格式参考

## 文件结构

TSCN（Text Scene）是 Godot 的文本场景格式，包含以下部分：

1. **文件描述符**: `[gd_scene load_steps=N format=3 uid="uid://..."]`
2. **外部资源**: `[ext_resource type="..." path="..." id=N]`
3. **内部资源**: `[sub_resource type="..." id=N]`
4. **节点**: `[node name="..." type="..."]`
5. **连接**: `[connection signal="..." from="..." to="..." method="..."]`

## 基本格式

```tscn
[gd_scene load_steps=2 format=3 uid="uid://example"]

[ext_resource type="Script" path="res://script.gd" id=1]

[node name="Main" type="Node"]
script = ExtResource(1)
```

## 节点属性

```tscn
[node name="Sprite2D" type="Sprite2D"]
position = Vector2(100, 100)
scale = Vector2(2, 2)
modulate = Color(1, 1, 1, 1)
z_index = 0
z_as_relative = true
```

## 布局属性

```tscn
[node name="Control" type="Control"]
layout_mode = 3
anchors_preset = 15
offset_right = 1280.0
offset_bottom = 720.0
```

### 常用 anchors_preset 值

| 值 | 名称 | 描述 |
|----|------|------|
| 0 | Top Left | 左上角 |
| 1 | Top Right | 右上角 |
| 2 | Bottom Left | 左下角 |
| 3 | Bottom Right | 右下角 |
| 5 | Left | 左侧 |
| 6 | Right | 右侧 |
| 7 | Top | 顶部 |
| 8 | Bottom | 底部 |
| 10 | Center | 居中 |
| 12 | Center Right | 右中 |
| 15 | Full Rect | 全屏 |

## 资源类型

### 子资源

```tscn
[sub_resource type="StyleBoxFlat" id=1]
bg_color = Color(0.2, 0.6, 0.8, 1.0)
corner_radius_top_left = 8

[sub_resource type="Animation" id=2]
length = 1.0

[node name="Button" type="Button"]
theme_override_styles/normal = SubResource(1)
```

### 外部资源引用

```tscn
[ext_resource type="Texture2D" path="res://assets/image.png" id=1]
[ext_resource type="PackedScene" path="res://scene.tscn" id=2]
[ext_resource type="Script" path="res://script.gd" id=3]

[node name="Sprite" type="Sprite2D"]
texture = ExtResource(1)

[node name="Instance" parent="." instance=ExtResource(2)]

[node name="Node" type="Node"]
script = ExtResource(3)
```

## 信号连接

```tscn
[connection signal="pressed" from="Button" to="." method="_on_button_pressed"]
[connection signal="value_changed" from="Slider" to="." method="_on_slider_changed"]
```

## 常用节点类型

### 2D 节点

| 节点 | 描述 |
|------|------|
| Node2D | 2D 节点基类 |
| Sprite2D | 2D 精灵图 |
| AnimatedSprite2D | 动画精灵 |
| Label2D | 2D 文本 |
| Control | UI 控件基类 |
| Node3D | 3D 节点基类 |

### UI 节点

| 节点 | 描述 |
|------|------|
| Control | UI 根节点 |
| Label | 文本显示 |
| Button | 按钮 |
| TextureRect | 纹理显示 |
| LineEdit | 单行输入 |
| RichTextLabel | 富文本 |
| ProgressBar | 进度条 |
| Slider | 滑块 |
| CheckBox | 复选框 |
| VBoxContainer | 垂直容器 |
| HBoxContainer | 水平容器 |

## 场景实例化

```tscn
[ext_resource type="PackedScene" path="res://prefabs/enemy.tscn" id=1]

[node name="Main" type="Node"]

[node name="Enemy1" parent="Main" instance=ExtResource(1)]
position = Vector2(100, 200)

[node name="Enemy2" parent="Main" instance=ExtResource(1)]
position = Vector2(300, 200)
```
