# Face Recognition Models

Place face recognition `.tflite` models in this directory.

Current preferred model ID: `buffalo_sc-112x112-v1-aligned`
Fallback model ID: `mobilefacenet-112x112-192-v2-aligned`

## Requirements
- Input: 112x112x3 RGB float tensor, normalized to [-1, 1]
- Output: 1xN float tensor (L2-normalized embedding)

## Integration Notes
- Face embeddings are versioned by model ID in the local database.
- Changing the bundled model ID requires re-extracting embeddings for existing faces.
- Detection results now include landmarks, and the recognizer uses eye/nose alignment when available.
- If `buffalo_sc_recognition.tflite` is present, the app prefers it automatically.

## How to obtain

Option 1: Convert from InsightFace `buffalo_sc`
- For non-commercial research use only. Check the upstream license terms before distribution.
- Preferred on Windows: `py scripts/convert_buffalo_sc_model.py`
- If your default `py` points to Python 3.13 and conversion dependencies fail, prefer `py -3.12 scripts/convert_buffalo_sc_model.py`
- If you can download from GitHub manually, the easiest path is: download `buffalo_sc.zip`, then run `py scripts/convert_buffalo_sc_model.py --zip C:\path\to\buffalo_sc.zip`
- If you already have a local recognition ONNX model, run: `py scripts/convert_buffalo_sc_model.py --onnx C:\path\to\model.onnx`
- If the default GitHub release is slow or blocked, pass a mirror zip URL: `py scripts/convert_buffalo_sc_model.py --download-url https://.../buffalo_sc.zip`
- The helper script writes temporary InsightFace and Matplotlib caches to the system temp directory to avoid Windows profile permission issues.
- The helper script tries `onnx-tf` first and falls back to `onnx2tf` automatically when available.

Option 2: Download from InsightFace
- https://github.com/deepinsight/insightface/tree/master/model_zoo
- Convert the recognition model from the `buffalo_sc` pack to TFLite format

Option 3: Use Python to convert MobileFaceNet fallback
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

Option 4: Search for pre-converted models
- Search: "MobileFaceNet tflite 112x112 192" on GitHub/Kaggle
