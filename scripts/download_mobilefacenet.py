"""
下载并转换 MobileFaceNet 模型为 TFLite 格式
输入: 112x112x3 RGB, 归一化到 [-1, 1]
输出: 1x192 float (L2-normalized embedding)

使用方法:
  pip install onnx onnxruntime numpy
  pip install tf2onnx tensorflow
  python scripts/download_mobilefacenet.py
"""

import os
import sys
import urllib.request
import tempfile

MODEL_DIR = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'assets', 'models')
OUTPUT_PATH = os.path.join(MODEL_DIR, 'mobilefacenet.tflite')

# InsightFace MobileFaceNet ONNX 模型 (来自 ONNX Model Zoo / InsightFace)
ONNX_URLS = [
    # buffalo_l model pack 中的 w600k_r50.onnx 太大，用 buffalo_sc 的 MobileFaceNet
    "https://github.com/niceDev0908/mobile-face-net/raw/main/MobileFaceNet.tflite",
    "https://github.com/anthropics/MobileFaceNet/raw/main/mobilefacenet.tflite",
]


def try_direct_download():
    """尝试直接下载预转换的 tflite 文件"""
    for url in ONNX_URLS:
        print(f"尝试下载: {url}")
        try:
            urllib.request.urlretrieve(url, OUTPUT_PATH)
            size = os.path.getsize(OUTPUT_PATH)
            if size > 100000:  # 有效的 tflite 至少 100KB
                print(f"下载成功! 文件大小: {size / 1024 / 1024:.1f} MB")
                print(f"保存到: {os.path.abspath(OUTPUT_PATH)}")
                return True
            else:
                os.remove(OUTPUT_PATH)
                print(f"文件太小 ({size} bytes), 可能不是有效模型")
        except Exception as e:
            print(f"下载失败: {e}")
    return False


def convert_from_onnx():
    """从 ONNX 模型转换为 TFLite"""
    try:
        import onnx
        import numpy as np
    except ImportError:
        print("需要安装依赖: pip install onnx numpy")
        return False

    onnx_url = "https://huggingface.co/deepinsight/insightface-mobilefacenet/resolve/main/mobilefacenet.onnx"
    onnx_path = os.path.join(tempfile.gettempdir(), "mobilefacenet.onnx")

    print(f"下载 ONNX 模型...")
    try:
        urllib.request.urlretrieve(onnx_url, onnx_path)
    except Exception as e:
        print(f"ONNX 下载失败: {e}")
        return False

    print("转换 ONNX → TFLite...")
    try:
        import subprocess
        # 使用 tf2onnx 的反向: onnx → saved_model → tflite
        saved_model_dir = os.path.join(tempfile.gettempdir(), "mobilefacenet_saved_model")

        # 方法1: 用 onnx-tf
        try:
            from onnx_tf.backend import prepare
            model = onnx.load(onnx_path)
            tf_rep = prepare(model)
            tf_rep.export_graph(saved_model_dir)
        except ImportError:
            print("需要安装 onnx-tf: pip install onnx-tf")
            return False

        import tensorflow as tf
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
        tflite_model = converter.convert()

        os.makedirs(MODEL_DIR, exist_ok=True)
        with open(OUTPUT_PATH, 'wb') as f:
            f.write(tflite_model)

        print(f"转换成功! 文件大小: {len(tflite_model) / 1024 / 1024:.1f} MB")
        print(f"保存到: {os.path.abspath(OUTPUT_PATH)}")
        return True

    except Exception as e:
        print(f"转换失败: {e}")
        return False


def main():
    os.makedirs(MODEL_DIR, exist_ok=True)

    if os.path.exists(OUTPUT_PATH):
        size = os.path.getsize(OUTPUT_PATH)
        print(f"模型已存在: {os.path.abspath(OUTPUT_PATH)} ({size / 1024 / 1024:.1f} MB)")
        return

    print("=" * 50)
    print("MobileFaceNet TFLite 模型下载工具")
    print("=" * 50)

    # 方法1: 尝试直接下载
    print("\n[方法1] 尝试直接下载预转换模型...")
    if try_direct_download():
        return

    # 方法2: 从 ONNX 转换
    print("\n[方法2] 尝试从 ONNX 模型转换...")
    if convert_from_onnx():
        return

    # 都失败了，给出手动指引
    print("\n" + "=" * 50)
    print("自动下载失败，请手动获取模型:")
    print("=" * 50)
    print("""
方法 A: 从 GitHub 搜索
  搜索 "MobileFaceNet tflite 112x112 192"
  下载 .tflite 文件放入:
  {}

方法 B: 从 InsightFace 转换
  1. pip install insightface onnx onnx-tf tensorflow
  2. 下载 MobileFaceNet ONNX 模型
  3. 运行转换脚本 (见 README.md)

方法 C: 从 Kaggle 下载
  搜索 "mobilefacenet tflite" 下载

要求:
  - 输入: 112x112x3 RGB float, 归一化到 [-1, 1]
  - 输出: 1x192 float (L2-normalized embedding)
  - 文件大小约 5MB
""".format(os.path.abspath(MODEL_DIR)))


if __name__ == '__main__':
    main()
