# 手动对齐教程

## 1. 查看当前情况

在 Godot 编辑器中：
1. 打开 `scenes/world/farm.tscn`
2. 点击顶部菜单 **"视图" → "显示栅格"**
3. 确保 **Background** 节点位置是 `(0, 0)`

## 2. 添加调试标记

在 `farm_controller.gd` 的 `_ready()` 函数末尾添加：

```gdscript
func _ready():
	# ... 原有代码 ...
	
	# ===== 调试：显示土地边界 =====
	_show_debug_outlines()

func _show_debug_outlines():
	for plot_id in _plot_rects.keys():
		var rect = _plot_rects[plot_id]
		
		# 创建彩色边框
		var outline = ColorRect.new()
		outline.name = "DEBUG_" + plot_id
		outline.position = rect.position
		outline.size = rect.size
		outline.color = Color(1, 0, 0, 0.3)  # 红色半透明
		
		# 添加边框
		var border = ReferenceRect.new()
		border.position = rect.position
		border.size = rect.size
		border.editor_only = false
		
		add_child(outline)
		add_child(border)
		
		print("[DEBUG] %s: pos=%s size=%s" % [plot_id, rect.position, rect.size])
```

## 3. 调整偏移量

如果土地和背景对不上，修改这些值：

**在 `farm.tscn` 中：**
```
[node name="Background" type="Sprite2D"]
position = Vector2(X偏移, Y偏移)  # 从这里调整
```

**在 `farm_controller.gd` 中：**
```gdscript
# 在 PLOT_DEFINITIONS 的每个土地定义中添加偏移：
{"id": "plot_01", "x": 100, "y": 200, "w": 128, "h": 170, "offset_x": 0, "offset_y": 0}
```

然后在 `_scale_x` 函数中加入全局偏移：
```gdscript
const GLOBAL_OFFSET_X = 0  # 调整这个值
const GLOBAL_OFFSET_Y = 0  # 调整这个值

func _scale_x(ref_x: float) -> float:
	return ref_x * TOTAL_SCALE_X + GLOBAL_OFFSET_X

func _scale_y(ref_y: float) -> float:
	return ref_y * TOTAL_SCALE_Y + GLOBAL_OFFSET_Y
```

## 4. 运行时微调

添加这个脚本到农场场景，可以实时调整：

```gdscript
# 添加到 farm_controller.gd
var _debug_offset_x = 0
var _debug_offset_y = 0

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP: _debug_offset_y -= 10
			KEY_DOWN: _debug_offset_y += 10
			KEY_LEFT: _debug_offset_x -= 10
			KEY_RIGHT: _debug_offset_x += 10
			KEY_ENTER: print("当前偏移: (%d, %d)" % [_debug_offset_x, _debug_offset_y])
			
		# 重新生成土地
		if event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			_rebuild_plots()

func _rebuild_plots():
	# 清除旧的土地
	for child in plots_container.get_children():
		child.queue_free()
	_plot_rects.clear()
	
	# 重建
	_build_custom_plots()
```

## 5. 手动记录坐标

如果以上都不行，最直接的方法：

1. 在 Photoshop/GIMP 打开 `farm_background.png`
2. 用标尺工具测量每块土地的像素坐标 (x, y, w, h)
3. 直接替换 `PLOT_DEFINITIONS` 中的值
4. 测量时要注意图片是 1536×2752 像素
5. 游戏内是 4x 缩放，所以坐标要乘以 4

## 6. 验证对齐

运行游戏后，观察：
- 红色半透明方块应该覆盖在土地位置上
- 如果不重合，记录差值
- 调整 `GLOBAL_OFFSET_X/Y` 直到对齐

## 快速修复代码

如果完全对不上，试试这个粗暴方法：

```gdscript
# 在 _create_custom_plot 函数开头添加：
var manual_offsets = {
	"plot_01": Vector2(100, 50),
	"plot_02": Vector2(120, 60),
	# ... 为每个土地添加偏移
}

var offset = manual_offsets.get(plot_id, Vector2.ZERO)
plot.position += offset
```
