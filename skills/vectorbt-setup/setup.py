#!/usr/bin/env python3
"""
vectorbt 回测环境设置脚本
专注于美股交易，使用 yfinance 获取数据（无需 API key）
"""

import subprocess
import sys

def install_package(package):
    """安装 Python 包"""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        print(f"✅ {package} 安装成功")
    except subprocess.CalledProcessError as e:
        print(f"❌ {package} 安装失败: {e}")
        return False
    return True

def check_package(package_name, import_name=None):
    """检查包是否已安装"""
    if import_name is None:
        import_name = package_name
    try:
        __import__(import_name)
        print(f"✅ {package_name} 已安装")
        return True
    except ImportError:
        print(f"⚠️  {package_name} 未安装，正在安装...")
        return install_package(package_name)

def main():
    print("=" * 50)
    print("vectorbt 回测环境设置")
    print("=" * 50)
    print()
    
    # 检查必要的包
    packages = [
        ("vectorbt", "vectorbt"),
        ("yfinance", "yfinance"),
        ("pandas", "pandas"),
        ("numpy", "numpy"),
        ("matplotlib", "matplotlib"),
    ]
    
    all_installed = True
    for package_name, import_name in packages:
        if not check_package(package_name, import_name):
            all_installed = False
    
    print()
    print("=" * 50)
    
    if all_installed:
        print("✅ 环境设置完成！")
        print()
        print("现在可以运行回测:")
        print("  python /Users/jerry/.openclaw/workspace/skills/vectorbt-backtest/backtest.py --symbol TSLA")
    else:
        print("❌ 部分包安装失败，请检查错误信息")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
