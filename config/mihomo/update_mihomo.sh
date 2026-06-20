#!/bin/bash

# 自动获取脚本实际所在目录（解析软链接）
SUB_URL=""
SCRIPT_DIR=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
SECRET="123456"

# 确保 config 目录存在
mkdir -p "$SCRIPT_DIR/config"

CONFIG_FILE="$SCRIPT_DIR/config/config.yaml"
BACKUP_FILE="$SCRIPT_DIR/config/config.yaml.bak"
DIFF_FILE="$SCRIPT_DIR/config/config.diff"

# 检查 colordiff
check_colordiff() {
    if ! command -v colordiff &> /dev/null; then
        echo "⚠️  colordiff 未安装"
        if command -v apt-get &> /dev/null; then
            echo "正在安装 colordiff (需要 sudo 权限)..."
            sudo apt-get update -qq && sudo apt-get install -y colordiff
            if [ $? -eq 0 ]; then
                echo "✅ colordiff 安装成功"
                return 0
            fi
        fi
        echo "❌ 将使用普通 diff (建议安装: sudo apt-get install colordiff)"
        return 1
    fi
    return 0
}

# 如果存在旧配置文件，备份它
if [ -f "$CONFIG_FILE" ]; then
    echo "📦 备份当前配置文件..."
    cp "$CONFIG_FILE" "$BACKUP_FILE"
fi

# 下载配置文件
echo "📥 正在下载配置文件..."
if curl -L --progress-bar -o "$CONFIG_FILE" "$SUB_URL"; then
    echo "✅ 配置文件下载成功"
    
    # 如果存在备份文件，显示差异
    if [ -f "$BACKUP_FILE" ]; then
        echo ""
        echo "=========================================="
        echo "📊 配置文件变更对比 (旧 → 新)"
        echo "=========================================="
        
        if check_colordiff; then
            diff -u "$BACKUP_FILE" "$CONFIG_FILE" | colordiff
        else
            diff -u "$BACKUP_FILE" "$CONFIG_FILE"
        fi
        
        diff -u "$BACKUP_FILE" "$CONFIG_FILE" > "$DIFF_FILE"
        
        echo "=========================================="
        
        ADDED=$(diff -u "$BACKUP_FILE" "$CONFIG_FILE" | grep -E "^\+" | grep -v "^\+\+\+" | wc -l)
        REMOVED=$(diff -u "$BACKUP_FILE" "$CONFIG_FILE" | grep -E "^-" | grep -v "^---" | wc -l)
        echo "📈 统计: 新增 $ADDED 行, 删除 $REMOVED 行"
        echo "💾 差异详情已保存到: $DIFF_FILE"
        echo ""
        
        # 回车默认 y，输入 n 才取消
        read -p "❓ 是否继续应用新配置? (Y/n): " -n 1 -r
        echo ""
        
        # 只有输入 n/N 才取消，其他情况（包括回车、y/Y 等）都继续
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "❌ 已取消更新，恢复旧配置..."
            mv "$BACKUP_FILE" "$CONFIG_FILE"
            exit 0
        else
            echo "✅ 继续应用新配置..."
        fi
    else
        echo "📝 首次下载，无旧配置可对比"
    fi
    
    # 更新配置文件，允许局域网连接
    # sed -i -e 's/allow-lan: false/allow-lan: true/g' -e 's/127.0.0.1:9090/0.0.0.0:9090/g' -e 's/port: 7890/port: 7892/g' "$CONFIG_FILE"
    
    # # 修正：添加 secret（先检查是否已存在）
    # if ! grep -q "^secret:" "$CONFIG_FILE"; then
    #     echo "secret: \"$SECRET\"" >> "$CONFIG_FILE"
    #     echo "🔐 已添加 secret 配置"
    # else
    #     # 如果已存在，替换它
    #     sed -i "s/^secret:.*/secret: \"$SECRET\"/" "$CONFIG_FILE"
    #     echo "🔐 已更新 secret 配置"
    # fi
    
    # echo "mixed-port: 7890" >>"$CONFIG_FILE"
    
    echo "✅ 配置文件已成功下载并更新。"
    
    # 检查是否存在名为 'mihomo' 的容器
    if [ $(docker ps -q -f name=mihomo) ]; then
        echo "🔄 正在停止 mihomo 容器..."
        docker stop mihomo
        echo "🔄 正在启动 mihomo 容器..."
        docker start mihomo
        echo "✅ mihomo Docker 容器已成功重启。"
    else
        echo "⚠️  未找到 mihomo 容器。"
    fi
else
    echo "❌ 配置文件下载失败。"
    exit 1
fi