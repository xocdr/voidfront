#!/usr/bin/env -S godot -s
extends SceneTree

func _init():
	print("Godot脚本执行示例")
	print("===================")
	print("当前时间:", OS.get_datetime())
	print("系统名称:", OS.get_name())
	print("Godot版本:", Engine.get_version_info())
	print("脚本执行成功！")
	quit()
