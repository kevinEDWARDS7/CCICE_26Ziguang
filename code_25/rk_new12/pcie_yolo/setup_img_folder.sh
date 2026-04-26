#!/bin/bash

# 设置图片保存目录
IMG_FOLDER="/home/linaro/img"

echo "设置图片保存目录: $IMG_FOLDER"

# 创建目录
mkdir -p "$IMG_FOLDER"

# 设置权限
chmod 755 "$IMG_FOLDER"

# 检查结果
if [ -d "$IMG_FOLDER" ]; then
    echo "目录创建成功: $IMG_FOLDER"
    echo "目录权限:"
    ls -ld "$IMG_FOLDER"
    echo "目录内容:"
    ls -la "$IMG_FOLDER"
else
    echo "目录创建失败"
fi

echo "设置完成！"



