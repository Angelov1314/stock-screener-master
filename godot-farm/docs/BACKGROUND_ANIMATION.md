# 背景微动方案 - Background Animation Techniques

## 概述
为农场游戏营造"ASMR治愈风"和"生命感"，推荐以下三种方案组合使用。

---

## 方案 A：Parallax 视差背景

### 适用对象
山、云、远景树、远景建筑

### 层级拆分建议
将背景图拆分为以下图层：
1. **天空** - 最底层
2. **远山层 1** - 远处的山脉
3. **远山层 2** - 中距离的山
4. **远树层** - 远景树林
5. **前景木框** - 前景装饰

### Godot 实现
使用 `ParallaxBackground` + `ParallaxLayer` 节点

```gdscript
# 各层 motion_scale 设置示例
天空:     motion_scale = Vector2(0, 0)      # 几乎不动
远山1:    motion_scale = Vector2(0.05, 0)   # 极慢
远山2:    motion_scale = Vector2(0.1, 0)    # 慢速
远树:     motion_scale = Vector2(0.15, 0)   # 中等
前景木框: motion_scale = Vector2(0.02, 0)   # 轻微或不动
```

### 效果
- 玩家拖动画面或镜头轻微移动时，产生立体空间感
- 远景慢、近景快，营造深度错觉

---

## 方案 B：Idle 漂浮 / 呼吸感

### 适用对象
- 云朵左右缓慢飘动
- 太阳/月亮轻微上下浮动（2~4 px）
- 前景树冠轻微左右晃动
- UI 按钮极轻微呼吸缩放

### Godot 实现（Tween）

```gdscript
# 云朵左右飘动
var tween = create_tween().set_loops()
tween.tween_property(cloud, "position:x", start_x + 20, 8.0)
tween.tween_property(cloud, "position:x", start_x - 20, 8.0)

# 太阳上下浮动
var sun_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
sun_tween.tween_property(sun, "position:y", base_y - 3, 2.0)
sun_tween.tween_property(sun, "position:y", base_y + 3, 2.0)

# UI 按钮呼吸效果
var btn_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
btn_tween.tween_property(button, "scale", Vector2(1.02, 1.02), 1.5)
btn_tween.tween_property(button, "scale", Vector2(0.98, 0.98), 1.5)

# 树冠轻微摆动
var tree_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
tree_tween.tween_property(tree, "rotation_degrees", 1.5, 3.0)
tree_tween.tween_property(tree, "rotation_degrees", -1.5, 3.0)
```

### 参数范围
- **position**: 原位上下/左右 2~3 px
- **rotation**: -1.5° 到 1.5° 间来回
- **scale**: 0.98 ~ 1.02 间循环
- **duration**: 2~8 秒，缓慢舒适

### 优点
- 不需要额外帧图
- 代码实现，性能开销小
- 营造"活着的世界"感觉

---

## 方案 C：Shader 微风效果

### 适用对象
- 草地
- 树叶
- 小麦/向日葵等作物
- 任何需要"风吹动"效果的植物

### 实现原理
使用顶点着色器（Vertex Shader）对植物顶部顶点进行正弦波偏移，模拟风吹摆动。

```glsl
// 简化的微风 shader 伪代码
uniform float time;
uniform float sway_amount : hint_range(0.0, 0.1) = 0.02;
uniform float sway_speed : hint_range(0.0, 5.0) = 1.0;

void vertex() {
    // 根据 UV.y 判断是顶部还是底部（底部不动）
    float sway = UV.y * sway_amount * sin(time * sway_speed + VERTEX.x);
    VERTEX.x += sway;
}
```

### Godot Shader 代码示例

```gdscript
shader_type canvas_item;

uniform float sway_speed : hint_range(0.0, 5.0) = 1.0;
uniform float sway_amount : hint_range(0.0, 0.1) = 0.02;
uniform float mask_softness : hint_range(0.0, 1.0) = 0.1;

void vertex() {
    // 基础摇摆
    float sway = sin(TIME * sway_speed + VERTEX.x * 0.01) * sway_amount;
    
    // 根据 UV.y 应用（底部 UV.y=0 不动，顶部 UV.y=1 全动）
    VERTEX.x += sway * UV.y;
}

void fragment() {
    // 可以在这里添加额外的颜色变化
    COLOR = texture(TEXTURE, UV);
}
```

### 优点
- 不需要每株植物做多帧动画
- 一套 shader 可以复用到很多对象
- 非常有"ASMR农场"的治愈感
- GPU 计算，性能高效

### 使用建议
- 为不同植物类型创建变体（草、小麦、树叶参数不同）
- `sway_amount`: 草 0.02，小麦 0.03，树叶 0.015
- `sway_speed`: 统一 0.8~1.2 之间，保持和谐

---

## 组合使用建议

### 推荐配置
| 层级 | 技术方案 | 运动类型 |
|------|---------|---------|
| 天空 | Parallax | 几乎静止 |
| 远山 | Parallax | 极慢移动 |
| 云 | Idle Tween | 左右飘动 |
| 太阳/月亮 | Idle Tween | 上下浮动 |
| 前景树 | Parallax + Idle | 轻微摆动 |
| 草地/作物 | Shader | 微风吹动 |
| UI 按钮 | Idle Tween | 呼吸缩放 |
| 角色/NPC | Idle Tween | 待机动画 |

### 注意事项
1. **保持克制** - 所有动作都应该非常 subtle，不能干扰游戏
2. **统一时序** - 尽量让摇摆周期有整数倍关系，看起来和谐
3. **可关闭** - 提供设置选项让玩家可以关闭动画（考虑性能/眩晕）
4. **性能优先** - 优先使用 Shader 和 Tween，避免每帧复杂计算

---

## 参考参数速查

```gdscript
# 云飘动
tween_duration: 8.0~12.0 秒
distance: 10~20 px

# 太阳/月亮浮动
tween_duration: 4.0~6.0 秒（正弦波）
distance: 2~4 px

# UI 呼吸
tween_duration: 2.0~3.0 秒
scale_range: 0.98~1.02

# 树叶/树冠摆动
tween_duration: 3.0~5.0 秒
rotation_range: -1.5°~1.5°

# Shader 微风
sway_speed: 0.8~1.2
sway_amount: 0.015~0.03
```

---

*文档创建日期: 2026-03-07*
*适用于: Cozy Farm - ASMR Farm Simulation Game*
