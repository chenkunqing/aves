# MobileFaceNet Model

Place `mobilefacenet.tflite` in this directory.

## Requirements
- Input: 112x112x3 RGB float tensor, normalized to [-1, 1]
- Output: 1x192 float tensor (L2-normalized embedding)

## How to obtain

Option 1: Download from InsightFace
- https://github.com/deepinsight/insightface/tree/master/model_zoo
- Convert ArcFace-MobileFaceNet to TFLite format

Option 2: Use Python to convert
```python
pip install tensorflow onnx onnx-tf
# Download MobileFaceNet ONNX model, then:
import onnx
from onnx_tf.backend import prepare
import tensorflow as tf

model = onnx.load("mobilefacenet.onnx")
tf_rep = prepare(model)
tf_rep.export_graph("mobilefacenet_saved_model")

converter = tf.lite.TFLiteConverter.from_saved_model("mobilefacenet_saved_model")
tflite_model = converter.convert()
with open("mobilefacenet.tflite", "wb") as f:
    f.write(tflite_model)
```

Option 3: Search for pre-converted models
- Search: "MobileFaceNet tflite 112x112 192" on GitHub/Kaggle
