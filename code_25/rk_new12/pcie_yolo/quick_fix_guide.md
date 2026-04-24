# YOLO检测框位置问题快速修复指南

## 问题现象
检测框集中在屏幕最左侧，显示大量误检目标

## 可能原因
1. **坐标转换错误**：letterbox参数计算错误
2. **图像格式不匹配**：RGB16转RGB888时的尺寸问题
3. **模型输入尺寸错误**：模型期望尺寸与实际输入不符

## 快速修复步骤

### 步骤1：添加调试信息
在 `mainwindow.cpp` 的 `dada_recv_to_dis()` 函数中添加调试输出：

```cpp
// 在检测前添加
qDebug() << "原始图像尺寸:" << My_Image.width() << "x" << My_Image.height();
qDebug() << "RGB888图像尺寸:" << rgb888.width() << "x" << rgb888.height();

// 在检测后添加
for (size_t i = 0; i < detections.size(); i++) {
    qDebug() << "目标" << i << ": 位置=(" << detections[i].rect.x 
             << "," << detections[i].rect.y << "," 
             << detections[i].rect.width << "," << detections[i].rect.height << ")";
}
```

### 步骤2：检查letterbox参数
在 `yolov11_detector.cpp` 的 `post_process()` 函数中添加：

```cpp
printf("letterbox参数: scale=%.3f, x_pad=%d, y_pad=%d\n", 
       letter_box->scale, letter_box->x_pad, letter_box->y_pad);
```

### 步骤3：验证模型输入尺寸
检查模型期望的输入尺寸是否与代码中的设置一致：

```cpp
printf("模型输入尺寸: %dx%d\n", app_ctx->model_width, app_ctx->model_height);
```

### 步骤4：临时禁用检测验证
暂时设置 `detection_enabled = false` 来确认问题确实出在YOLO检测上

## 常见修复方案

### 方案1：修复坐标转换
如果letterbox参数异常，可能需要重新计算：

```cpp
// 确保letterbox参数正确
if (letter_box->x_pad < 0 || letter_box->x_pad > model_in_w/2) {
    printf("警告：x_pad参数异常: %d\n", letter_box->x_pad);
}
```

### 方案2：调整置信度阈值
提高置信度阈值减少误检：

```cpp
const float box_conf_threshold = 0.5; // 从0.25提高到0.5
```

### 方案3：检查图像预处理
确保图像预处理正确：

```cpp
// 验证图像数据
if (frame.data == nullptr) {
    printf("错误：图像数据为空\n");
    return -1;
}
```

## 调试输出示例
运行后查看控制台输出，正常情况下应该看到：
- 图像尺寸正确
- letterbox参数合理
- 检测框坐标在图像范围内

如果看到异常值，说明对应环节有问题。

