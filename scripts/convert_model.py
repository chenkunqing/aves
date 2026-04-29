"""
从 InsightFace 下载 MobileFaceNet ONNX 模型并转换为 TFLite
运行: python scripts/convert_model.py
"""
import os
import sys
import numpy as np

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'assets', 'models')
OUTPUT_PATH = os.path.join(OUTPUT_DIR, 'mobilefacenet.tflite')


def main():
    if os.path.exists(OUTPUT_PATH):
        print(f"模型已存在: {os.path.abspath(OUTPUT_PATH)}")
        return

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("步骤 1/3: 下载 InsightFace 模型...")
    try:
        from insightface.app import FaceAnalysis
        app = FaceAnalysis(name='buffalo_sc', providers=['CPUExecutionProvider'])
        app.prepare(ctx_id=-1)

        rec_model = None
        for model in app.models.values():
            if hasattr(model, 'input_size') and hasattr(model, 'output_shape'):
                input_size = getattr(model, 'input_size', None)
                if input_size and input_size[0] == 112:
                    rec_model = model
                    break

        if rec_model is None:
            for model in app.models.values():
                model_name = type(model).__name__.lower()
                if 'rec' in model_name or 'arcface' in model_name:
                    rec_model = model
                    break

        if rec_model is None:
            print("未找到人脸识别模型，尝试列出所有模型:")
            for name, model in app.models.items():
                print(f"  {name}: {type(model).__name__}")
            sys.exit(1)

        print(f"  找到模型: {type(rec_model).__name__}")
        onnx_session = rec_model.session
        input_info = onnx_session.get_inputs()[0]
        output_info = onnx_session.get_outputs()[0]
        print(f"  输入: {input_info.name} {input_info.shape}")
        print(f"  输出: {output_info.name} {output_info.shape}")

    except Exception as e:
        print(f"InsightFace 加载失败: {e}")
        print("请尝试: pip install insightface onnxruntime")
        sys.exit(1)

    print("\n步骤 2/3: ONNX → TFLite 转换...")
    try:
        import onnxruntime as ort
        import tensorflow as tf

        # 获取 ONNX 模型路径
        model_path = onnx_session._model_path if hasattr(onnx_session, '_model_path') else None

        # 从 ONNX session 中提取模型信息
        input_shape = input_info.shape  # e.g. [1, 3, 112, 112]
        output_shape = output_info.shape  # e.g. [1, 512] or [1, 192]

        embedding_dim = output_shape[1] if len(output_shape) > 1 else 512
        print(f"  嵌入维度: {embedding_dim}")

        # 使用 tf2onnx 的反向转换
        # 更好的方式: 用 onnxruntime 做推理的 wrapper
        # 直接创建一个 TFLite 模型做同样的事

        # 找到 ONNX 文件路径
        import insightface
        home = os.path.expanduser('~')
        model_dir = os.path.join(home, '.insightface', 'models', 'buffalo_sc')

        onnx_file = None
        for f in os.listdir(model_dir):
            if f.endswith('.onnx') and 'w600k' in f.lower():
                onnx_file = os.path.join(model_dir, f)
                break
        if onnx_file is None:
            for f in os.listdir(model_dir):
                if f.endswith('.onnx'):
                    # 检查是否是识别模型 (非检测模型)
                    sess = ort.InferenceSession(os.path.join(model_dir, f))
                    inp = sess.get_inputs()[0]
                    out = sess.get_outputs()[0]
                    if len(inp.shape) == 4 and inp.shape[2] == 112:
                        onnx_file = os.path.join(model_dir, f)
                        print(f"  使用 ONNX 文件: {f} (input={inp.shape}, output={out.shape})")
                        embedding_dim = out.shape[1]
                        break

        if onnx_file is None:
            print("  未找到 ONNX 文件，列出目录内容:")
            for f in os.listdir(model_dir):
                print(f"    {f}")
            sys.exit(1)

        print(f"  ONNX 文件: {onnx_file}")

        # 使用 tf2onnx 转换 (ONNX → TF SavedModel → TFLite)
        import subprocess
        import tempfile

        saved_model_dir = os.path.join(tempfile.gettempdir(), 'mobilefacenet_tf')

        print("  转换 ONNX → TF SavedModel...")
        subprocess.run([
            sys.executable, '-m', 'tf2onnx.convert',
            '--onnx', onnx_file,
            '--output', os.path.join(tempfile.gettempdir(), 'temp.onnx'),
        ], capture_output=True, text=True)

        # 直接用 onnx + tf 方式
        try:
            import onnx
            from onnx_tf.backend import prepare

            model = onnx.load(onnx_file)
            tf_rep = prepare(model)
            tf_rep.export_graph(saved_model_dir)
            print("  SavedModel 导出成功")
        except ImportError:
            # 替代方案: 手动构建 tf.function wrapper
            print("  onnx-tf 未安装，使用替代方案...")

            # 创建 concrete function wrapper
            sess = ort.InferenceSession(onnx_file)
            inp = sess.get_inputs()[0]

            @tf.function(input_signature=[tf.TensorSpec(shape=[1, 3, 112, 112], dtype=tf.float32)])
            def model_fn(x):
                # 转置 NCHW → NHWC (如果需要)
                x_nhwc = tf.transpose(x, [0, 2, 3, 1])
                return x_nhwc  # placeholder

            # 这种方法不行，我们需要 onnx-tf
            print("  请安装 onnx-tf: pip install onnx-tf")
            print("  然后重新运行此脚本")
            sys.exit(1)

        print("  转换 SavedModel → TFLite...")
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float32]
        tflite_model = converter.convert()

        with open(OUTPUT_PATH, 'wb') as f:
            f.write(tflite_model)

        print(f"\n步骤 3/3: 完成!")
        print(f"  文件: {os.path.abspath(OUTPUT_PATH)}")
        print(f"  大小: {len(tflite_model) / 1024 / 1024:.1f} MB")
        print(f"  嵌入维度: {embedding_dim}")

        if embedding_dim != 192:
            print(f"\n⚠ 注意: 输出维度是 {embedding_dim}，而非 192。")
            print("  需要修改 FaceClustering.embeddingDimension 和 FaceRecognitionHandler.EMBEDDING_SIZE")

    except Exception as e:
        print(f"转换失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
