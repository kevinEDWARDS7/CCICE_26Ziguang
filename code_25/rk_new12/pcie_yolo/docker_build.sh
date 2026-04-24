#!/bin/bash

# Docker交叉编译脚本
# 使用Docker进行ZYNQ视频接收程序的交叉编译

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查Docker是否安装
check_docker() {
    print_step "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        echo "安装命令:"
        echo "sudo apt update"
        echo "sudo apt install docker.io"
        echo "sudo systemctl start docker"
        echo "sudo usermod -aG docker $USER"
        echo "请重新登录后重试"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker服务未运行或无权限访问"
        echo "请确保Docker服务正在运行，并且当前用户有Docker权限"
        echo "运行: sudo systemctl start docker"
        echo "添加用户到docker组: sudo usermod -aG docker $USER"
        exit 1
    fi
    
    print_info "Docker环境检查通过"
}

# 构建Docker镜像
build_docker_image() {
    print_step "构建Docker交叉编译镜像..."
    
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile不存在"
        exit 1
    fi
    
    print_info "开始构建Docker镜像 (这可能需要几分钟)..."
    docker build -t zynq-cross-compile .
    
    if [ $? -eq 0 ]; then
        print_info "Docker镜像构建成功"
    else
        print_error "Docker镜像构建失败"
        exit 1
    fi
}

# 运行Docker编译
run_docker_compile() {
    print_step "运行Docker交叉编译..."
    
    # 清理之前的编译结果
    if [ -d "deploy-docker" ]; then
        rm -rf deploy-docker
    fi
    
    print_info "在Docker容器中编译项目..."
    docker run --rm -v $(pwd):/workspace zynq-cross-compile
    
    if [ $? -eq 0 ]; then
        print_info "Docker编译完成"
        
        if [ -d "deploy-docker" ]; then
            print_info "部署包已创建: deploy-docker/"
            print_info "部署包内容:"
            ls -la deploy-docker/
            
            # 显示可执行文件信息
            if [ -f "deploy-docker/ZYNQ_video_show" ]; then
                print_info "可执行文件信息:"
                file deploy-docker/ZYNQ_video_show
                ls -lh deploy-docker/ZYNQ_video_show
            fi
        else
            print_warning "未找到部署包，请检查编译日志"
        fi
    else
        print_error "Docker编译失败"
        exit 1
    fi
}

# 创建部署说明
create_deployment_guide() {
    print_step "创建部署说明..."
    
    cat > deploy-docker/README.md << 'EOF'
# ZYNQ视频接收程序部署包

## 文件说明
- ZYNQ_video_show: 主程序可执行文件 (ARM64架构)
- 3rdparty/: 第三方库目录
  - opencv/: OpenCV图像处理库
  - librga/: RGA硬件加速库
  - rknpu2/: RKNN NPU库
- models/: AI模型文件目录
- README.md: 本说明文件

## 系统要求
- ARM64架构 (aarch64) 的Linux设备
- 支持RKNN NPU的设备 (如瑞芯微RK系列芯片)
- 至少512MB可用内存
- 支持OpenGL的显示环境

## 部署步骤

### 1. 复制文件到目标设备
```bash
# 将整个deploy-docker目录复制到目标设备
scp -r deploy-docker/ user@target-device:/opt/
```

### 2. 在目标设备上设置权限
```bash
cd /opt/deploy-docker
chmod +x ZYNQ_video_show
chmod +x 3rdparty/*/Linux/aarch64/*.so
```

### 3. 设置环境变量
```bash
export LD_LIBRARY_PATH=/opt/deploy-docker/3rdparty/opencv/opencv-linux-aarch64/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/opt/deploy-docker/3rdparty/librga/Linux/aarch64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/opt/deploy-docker/3rdparty/rknpu2/Linux/aarch64:$LD_LIBRARY_PATH
```

### 4. 运行程序
```bash
cd /opt/deploy-docker
./ZYNQ_video_show
```

## 故障排除

### 1. 库文件找不到
如果出现 "libxxx.so not found" 错误，请检查：
- LD_LIBRARY_PATH环境变量是否正确设置
- 库文件是否存在且有执行权限
- 目标设备架构是否匹配 (aarch64)

### 2. Qt相关错误
如果出现Qt相关错误，请确保：
- 目标设备已安装Qt5运行时库
- 显示环境支持 (DISPLAY环境变量)
- 图形驱动正常工作

### 3. RKNN相关错误
如果出现RKNN相关错误，请确保：
- 目标设备支持RKNN NPU
- RKNN驱动已正确安装
- 模型文件路径正确

## 功能说明
- PCIe数据接收和显示
- UDP网络通信
- YOLOv11目标检测
- 实时视频流处理
- 硬件加速图像处理

## 联系方式
如有问题，请联系开发团队。
EOF

    print_info "部署说明已创建: deploy-docker/README.md"
}

# 清理Docker镜像 (可选)
cleanup_docker() {
    read -p "是否清理Docker镜像以节省空间? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "清理Docker镜像..."
        docker rmi zynq-cross-compile
        print_info "Docker镜像已清理"
    fi
}

# 主函数
main() {
    print_info "开始Docker交叉编译 ZYNQ视频接收程序..."
    
    check_docker
    build_docker_image
    run_docker_compile
    create_deployment_guide
    
    print_info "Docker交叉编译完成！"
    print_info "部署包位置: deploy-docker/"
    print_info "可以将deploy-docker目录复制到目标设备运行"
    
    cleanup_docker
}

# 运行主函数
main "$@"
