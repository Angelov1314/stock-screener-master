# 社交登录配置指南 (Google & Facebook)

## 一、配置 Google 登录

### 1.1 创建 Google Cloud 项目

1. 访问 https://console.cloud.google.com
2. 登录 Google 账号
3. 点击左上角项目选择器 → "New Project"
4. 项目名称填写: `Cozy Farm Game`
5. 点击 "Create"

### 1.2 启用 Google+ API

1. 左侧菜单 → "APIs & Services" → "Library"
2. 搜索 "Google+ API" 或 "Google Identity Toolkit"
3. 点击 "Enable"

### 1.3 创建 OAuth 凭据

1. 左侧菜单 → "APIs & Services" → "Credentials"
2. 点击 "Create Credentials" → "OAuth client ID"
3. 配置同意屏幕:
   - 点击 "Configure Consent Screen"
   - User Type: "External"
   - 填写应用名称: `Cozy Farm`
   - 用户支持邮箱: 你的邮箱
   - 开发者联系信息: 你的邮箱
   - 保存

4. 创建 OAuth Client ID:
   - Application type: "Web application"
   - Name: `Cozy Farm Web Client`
   - **Authorized redirect URIs**:
     ```
     https://aegjluwadbvxlggzkyxw.supabase.co/auth/v1/callback
     ```
   - 点击 "Create"

5. 复制 **Client ID** 和 **Client Secret**

### 1.4 在 Supabase 配置 Google

1. 打开 Supabase Dashboard: https://supabase.com/dashboard
2. 选择项目: `aegjluwadbvxlggzkyxw`
3. 左侧菜单 → "Authentication" → "Providers"
4. 找到 "Google"，点击展开
5. 开启 "Enabled"
6. 填入:
   - Client ID: (从 Google Cloud 复制)
   - Client Secret: (从 Google Cloud 复制)
7. 点击 "Save"

---

## 二、配置 Facebook 登录

### 2.1 创建 Facebook 应用

1. 访问 https://developers.facebook.com
2. 登录 Facebook 账号
3. 点击 "My Apps" → "Create App"
4. 选择 "Consumer" 或 "None"
5. 填写应用名称: `Cozy Farm`
6. 点击 "Create App"

### 2.2 添加 Facebook Login 产品

1. 在应用面板左侧，点击 "Add Product"
2. 找到 "Facebook Login"，点击 "Set Up"

### 2.3 配置 OAuth 设置

1. 左侧菜单 → "Facebook Login" → "Settings"
2. 找到 "Valid OAuth Redirect URIs"
3. 添加:
   ```
   https://aegjluwadbvxlggzkyxw.supabase.co/auth/v1/callback
   ```
4. 保存

### 2.4 获取 App ID 和 Secret

1. 左侧菜单 → "Settings" → "Basic"
2. 复制 **App ID** 和 **App Secret**
3. 如果 App Secret 没显示，点击 "Show"

### 2.5 在 Supabase 配置 Facebook

1. 打开 Supabase Dashboard
2. Authentication → Providers
3. 找到 "Facebook"，点击展开
4. 开启 "Enabled"
5. 填入:
   - Client ID: (Facebook App ID)
   - Secret: (Facebook App Secret)
6. 点击 "Save"

---

## 三、移动端/桌面端 Deep Linking 配置

对于 iOS/Android/桌面应用，需要配置回调处理:

### 3.1 方案 A: 使用本地服务器 (推荐用于桌面)

修改 `supabase_manager.gd`:

```gdscript
func sign_in_with_google():
    # 启动本地 HTTP 服务器接收回调
    var redirect_to = "http://localhost:8080/auth/callback"
    var url = SUPABASE_URL + "/auth/v1/authorize?provider=google&redirect_to=" + redirect_to.uri_encode()
    OS.shell_open(url)
    
    # 启动本地服务器监听回调
    _start_local_server()

func _start_local_server():
    var server = TCP_Server.new()
    server.listen(8080, "127.0.0.1")
    
    # 等待回调...
    # 实际实现需要异步处理
```

### 3.2 方案 B: 使用自定义 URL Scheme (推荐用于移动)

**iOS 配置:**
1. 在 Godot 导出设置中添加 URL Scheme
2. 在 `Info.plist` 添加:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>cozyfarm</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>cozyfarm</string>
        </array>
    </dict>
</array>
```

**Android 配置:**
1. 在 `AndroidManifest.xml` 添加:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="cozyfarm" android:host="auth" />
</intent-filter>
```

**Supabase 配置:**
1. Authentication → URL Configuration
2. 添加 Site URL: `cozyfarm://auth/callback`

---

## 四、测试登录

1. 运行游戏
2. 点击 "用户登录"
3. 点击 "Google" 或 "Facebook" 按钮
4. 浏览器打开登录页面
5. 完成授权
6. 自动跳转回游戏

---

## 五、常见问题

**Q: 点击按钮没有反应？**
A: 检查 Supabase 中 Provider 是否启用，Client ID 是否正确

**Q: 显示 "redirect_uri_mismatch"？**
A: 回调 URL 配置错误，确保 Google/Facebook 后台配置的 URL 和 Supabase 一致

**Q: 移动端浏览器无法返回游戏？**
A: 需要配置 Deep Linking 或本地服务器

**Q: 可以只配一个吗？**
A: 可以，建议至少配 Google，用户群体更广

---

需要我帮你一步步配置吗？或者你配置时遇到问题随时问我。
