#!/bin/bash

# 测试图片保存路径
SAVE_PATH="/home/linaro/img"

echo "检查保存路径: $SAVE_PATH"

# 检查目录是否存在
if [ -d "$SAVE_PATH" ]; then
    echo "目录已存在: $SAVE_PATH"
    ls -la "$SAVE_PATH"
else
    echo "目录不存在，尝试创建..."
    mkdir -p "$SAVE_PATH"
    if [ $? -eq 0 ]; then
        echo "目录创建成功: $SAVE_PATH"
        ls -la "$SAVE_PATH"
    else
        echo "目录创建失败，请检查权限"
    fi
fi

# 检查权限
echo "检查目录权限:"
ls -ld "$SAVE_PATH" 2>/dev/null || echo "无法访问目录"

# 测试写入权限
echo "测试写入权限..."
touch "$SAVE_PATH/test_write.tmp" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "写入权限正常"
    rm -f "$SAVE_PATH/test_write.tmp"
else
    echo "写入权限不足"
fi



