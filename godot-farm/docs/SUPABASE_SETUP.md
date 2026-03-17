# Supabase Database Setup Guide

## 1. 创建 Supabase 项目

1. 访问 https://supabase.com
2. 注册/登录账号
3. 点击 "New Project"
4. 填写项目名称和密码
5. 选择区域（建议选 Asia Pacific - Singapore）
6. 等待项目创建完成

## 2. 获取 API 密钥

项目创建后，进入:
- Settings → API
- 复制以下信息：
  - **Project URL**: `https://xxxxx.supabase.co`
  - **anon public** API Key (用于客户端)

## 3. 创建数据库表

在 SQL Editor 中执行以下 SQL：

```sql
-- 用户数据表
CREATE TABLE user_data (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    gold INTEGER DEFAULT 300,
    level INTEGER DEFAULT 1,
    xp INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 背包物品表
CREATE TABLE inventory (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL,  -- 如: "cow", "wheat", "tomato"
    quantity INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, item_id)
);

-- 农场作物表
CREATE TABLE farm_crops (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    crop_id TEXT NOT NULL,
    plot_x INTEGER NOT NULL,
    plot_y INTEGER NOT NULL,
    growth_stage INTEGER DEFAULT 0,
    planted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, plot_x, plot_y)
);

-- 动物数据表
CREATE TABLE farm_animals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    animal_type TEXT NOT NULL,  -- 如: "cow", "pig", "sheep"
    position_x FLOAT,
    position_y FLOAT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 启用 RLS (Row Level Security)
ALTER TABLE user_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE farm_crops ENABLE ROW LEVEL SECURITY;
ALTER TABLE farm_animals ENABLE ROW LEVEL SECURITY;

-- 创建策略：用户只能访问自己的数据
CREATE POLICY "Users can only access their own data" ON user_data
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access their own inventory" ON inventory
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access their own crops" ON farm_crops
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access their own animals" ON farm_animals
    FOR ALL USING (auth.uid() = user_id);
```

## 4. 配置 Godot 项目

编辑 `scripts/core/supabase_manager.gd`：

```gdscript
const SUPABASE_URL := "https://你的项目ID.supabase.co"
const SUPABASE_KEY := "你的anon-key"
```

## 5. 在场景中添加 SupabaseManager

1. 在 Main 场景中添加 Node
2. 命名为 `SupabaseManager`
3. 附加脚本 `scripts/core/supabase_manager.gd`

## 6. 使用示例

```gdscript
# 登录
$SupabaseManager.login("user@example.com", "password123")

# 监听登录成功信号
$SupabaseManager.login_success.connect(_on_login_success)

func _on_login_success(user_id: String):
    # 加载用户数据
    $SupabaseManager.load_user_data(user_id)

# 保存数据
var data = {
    "username": "农场主",
    "gold": 500,
    "level": 2,
    "xp": 150
}
$SupabaseManager.save_user_data(user_id, data)
```

## 免费额度

- 500MB 数据库空间
- 2GB 带宽/月
- 无限用户（前 50,000 MAU）
- 足够小型游戏使用

## 下一步

1. 注册 Supabase 账号
2. 创建项目并复制 API URL 和 Key
3. 运行 SQL 创建表
4. 配置 Godot 中的 API 密钥
5. 测试登录和保存功能

需要我帮你继续集成到现有的登录系统中吗？
