-- Farm Game Database Schema
-- Run this in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 用户数据表
CREATE TABLE IF NOT EXISTS user_data (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    gold INTEGER DEFAULT 300,
    level INTEGER DEFAULT 1,
    xp INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 背包物品表
CREATE TABLE IF NOT EXISTS inventory (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL,
    quantity INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, item_id)
);

-- 农场作物表
CREATE TABLE IF NOT EXISTS farm_crops (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    crop_id TEXT NOT NULL,
    plot_x INTEGER NOT NULL,
    plot_y INTEGER NOT NULL,
    growth_stage INTEGER DEFAULT 0,
    planted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    growth_time FLOAT DEFAULT 120.0,
    water_count INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, plot_x, plot_y)
);

-- Migration: add settings column to user_data
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_data' AND column_name='settings') THEN
        ALTER TABLE user_data ADD COLUMN settings JSONB DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- Migration: add columns if table already exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='farm_crops' AND column_name='growth_time') THEN
        ALTER TABLE farm_crops ADD COLUMN growth_time FLOAT DEFAULT 120.0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='farm_crops' AND column_name='water_count') THEN
        ALTER TABLE farm_crops ADD COLUMN water_count INTEGER DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='farm_crops' AND column_name='updated_at') THEN
        ALTER TABLE farm_crops ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- 动物数据表 (placed animal instances with positions)
CREATE TABLE IF NOT EXISTS farm_animals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    animal_type TEXT NOT NULL,
    position_x FLOAT DEFAULT 0,
    position_y FLOAT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 启用 RLS (Row Level Security)
ALTER TABLE user_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE farm_crops ENABLE ROW LEVEL SECURITY;
ALTER TABLE farm_animals ENABLE ROW LEVEL SECURITY;

-- 删除旧策略（如果存在）
DROP POLICY IF EXISTS "Users can only access their own data" ON user_data;
DROP POLICY IF EXISTS "Users can only access their own inventory" ON inventory;
DROP POLICY IF EXISTS "Users can only access their own crops" ON farm_crops;
DROP POLICY IF EXISTS "Users can only access their own animals" ON farm_animals;

-- 创建策略：用户只能访问自己的数据 (允许所有操作包括 INSERT/UPDATE/DELETE)
CREATE POLICY "Users can only access their own data" ON user_data
    FOR ALL 
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only access their own inventory" ON inventory
    FOR ALL 
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only access their own crops" ON farm_crops
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only access their own animals" ON farm_animals
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 创建索引提高查询性能
CREATE INDEX IF NOT EXISTS idx_user_data_user_id ON user_data(user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_user_id ON inventory(user_id);
CREATE INDEX IF NOT EXISTS idx_farm_crops_user_id ON farm_crops(user_id);
CREATE INDEX IF NOT EXISTS idx_farm_animals_user_id ON farm_animals(user_id);

-- 创建触发器函数：新用户注册时自动创建 user_data
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_data (user_id, username, gold, level, xp)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', '农场主'),
    300,
    1,
    0
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- Friends & Community (first pass)
-- =============================================

-- 用户搜索：添加 display_name 和 trigram 索引支持模糊搜索
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_data' AND column_name='display_name') THEN
        ALTER TABLE user_data ADD COLUMN display_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_data' AND column_name='avatar_url') THEN
        ALTER TABLE user_data ADD COLUMN avatar_url TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_data' AND column_name='bio') THEN
        ALTER TABLE user_data ADD COLUMN bio TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_data' AND column_name='last_online_at') THEN
        ALTER TABLE user_data ADD COLUMN last_online_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Backfill display_name from username where null
UPDATE user_data SET display_name = username WHERE display_name IS NULL;

-- Trigram index for fuzzy search on display_name
CREATE INDEX IF NOT EXISTS idx_user_data_display_name_trgm ON user_data USING gin (display_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_user_data_username_trgm ON user_data USING gin (username gin_trgm_ops);

-- 好友请求表
CREATE TABLE IF NOT EXISTS friend_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    from_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(from_user_id, to_user_id)
);

ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can see their own friend requests" ON friend_requests;
CREATE POLICY "Users can see their own friend requests" ON friend_requests
    FOR ALL
    USING (auth.uid() = from_user_id OR auth.uid() = to_user_id)
    WITH CHECK (auth.uid() = from_user_id);

CREATE INDEX IF NOT EXISTS idx_friend_requests_to ON friend_requests(to_user_id, status);
CREATE INDEX IF NOT EXISTS idx_friend_requests_from ON friend_requests(from_user_id, status);

-- 好友关系表 (双向，每对好友存两行便于查询)
CREATE TABLE IF NOT EXISTS friends (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, friend_id)
);

ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can see their own friends" ON friends;
CREATE POLICY "Users can see their own friends" ON friends
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_friends_user ON friends(user_id);

-- 社区帖子
CREATE TABLE IF NOT EXISTS community_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone authed can read posts" ON community_posts;
CREATE POLICY "Anyone authed can read posts" ON community_posts
    FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authors can insert posts" ON community_posts;
CREATE POLICY "Authors can insert posts" ON community_posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);
DROP POLICY IF EXISTS "Authors can update own posts" ON community_posts;
CREATE POLICY "Authors can update own posts" ON community_posts
    FOR UPDATE USING (auth.uid() = author_id);
DROP POLICY IF EXISTS "Authors can delete own posts" ON community_posts;
CREATE POLICY "Authors can delete own posts" ON community_posts
    FOR DELETE USING (auth.uid() = author_id);

CREATE INDEX IF NOT EXISTS idx_community_posts_author ON community_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_community_posts_created ON community_posts(created_at DESC);

-- 社区点赞
CREATE TABLE IF NOT EXISTS community_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

ALTER TABLE community_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authed users can manage likes" ON community_likes;
CREATE POLICY "Authed users can manage likes" ON community_likes
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_community_likes_post ON community_likes(post_id);

-- 社区评论
CREATE TABLE IF NOT EXISTS community_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, author_id, created_at)
);

ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authed users can read comments" ON community_comments;
CREATE POLICY "Authed users can read comments" ON community_comments
    FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authors can insert comments" ON community_comments;
CREATE POLICY "Authors can insert comments" ON community_comments
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE INDEX IF NOT EXISTS idx_community_comments_post ON community_comments(post_id, created_at);

-- RPC: search users (exact + fuzzy)
CREATE OR REPLACE FUNCTION search_users(query_text TEXT, max_results INT DEFAULT 20)
RETURNS TABLE(user_id UUID, username TEXT, display_name TEXT, avatar_url TEXT, level INT, similarity FLOAT)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
    SELECT
        ud.user_id,
        ud.username,
        ud.display_name,
        ud.avatar_url,
        ud.level,
        GREATEST(
            similarity(ud.username, query_text),
            similarity(COALESCE(ud.display_name, ''), query_text)
        ) AS similarity
    FROM user_data ud
    WHERE ud.username = query_text                          -- exact match first
       OR ud.username % query_text                          -- trigram fuzzy
       OR COALESCE(ud.display_name, '') % query_text
    ORDER BY
        (ud.username = query_text) DESC,                    -- exact on top
        similarity DESC
    LIMIT max_results;
$$;

-- RPC: accept friend request (creates bidirectional rows + updates status)
CREATE OR REPLACE FUNCTION accept_friend_request(request_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    req RECORD;
BEGIN
    SELECT * INTO req FROM friend_requests WHERE id = request_id AND to_user_id = auth.uid() AND status = 'pending';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request not found or not yours';
    END IF;

    UPDATE friend_requests SET status = 'accepted', updated_at = NOW() WHERE id = request_id;

    INSERT INTO friends (user_id, friend_id) VALUES (req.from_user_id, req.to_user_id) ON CONFLICT DO NOTHING;
    INSERT INTO friends (user_id, friend_id) VALUES (req.to_user_id, req.from_user_id) ON CONFLICT DO NOTHING;
END;
$$;

-- Allow public read of user_data profiles for search (read-only)
DROP POLICY IF EXISTS "Authed users can read profiles" ON user_data;
CREATE POLICY "Authed users can read profiles" ON user_data
    FOR SELECT USING (auth.role() = 'authenticated');

-- 成功消息
SELECT 'Database tables and triggers created successfully!' as status;
