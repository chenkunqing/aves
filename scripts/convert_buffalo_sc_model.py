"""
Convert the recognition model from InsightFace `buffalo_sc` to TFLite.

Output:
  android/app/src/main/assets/models/buffalo_sc_recognition.tflite

Examples:
  py scripts/convert_buffalo_sc_model.py
  py scripts/convert_buffalo_sc_model.py --zip C:\\path\\to\\buffalo_sc.zip
  py scripts/convert_buffalo_sc_model.py --onnx C:\\path\\to\\w600k_r50.onnx

Dependencies:
  pip install onnx onnxruntime onnx-tf tensorflow
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MODEL_PACK = "buffalo_sc"
MODEL_DIR = os.path.join(REPO_ROOT, "android", "app", "src", "main", "assets", "models")
OUTPUT_PATH = os.path.join(MODEL_DIR, "buffalo_sc_recognition.tflite")
CACHE_ROOT = os.path.join(tempfile.gettempdir(), "aves_face_model_cache")
INSIGHTFACE_HOME = os.path.join(CACHE_ROOT, "insightface")
MPLCONFIGDIR = os.path.join(CACHE_ROOT, "matplotlib")
MODEL_ZIP_NAME = f"{MODEL_PACK}.zip"
DEFAULT_MODEL_ZIP_URL = f"https://github.com/deepinsight/insightface/releases/download/v0.7/{MODEL_ZIP_NAME}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert InsightFace buffalo_sc recognition model to TFLite")
    parser.add_argument("--zip", help="Path to a local buffalo_sc zip package")
    parser.add_argument("--onnx", help="Path to a local 112x112 recognition ONNX model")
    parser.add_argument("--download-url", help="Override the model pack zip URL when GitHub releases are slow or blocked")
    parser.add_argument("--force", action="store_true", help="Overwrite the generated TFLite file if it already exists")
    return parser.parse_args()


def configure_environment() -> None:
    os.makedirs(MODEL_DIR, exist_ok=True)
    os.makedirs(INSIGHTFACE_HOME, exist_ok=True)
    os.makedirs(MPLCONFIGDIR, exist_ok=True)
    os.environ.setdefault("INSIGHTFACE_HOME", INSIGHTFACE_HOME)
    os.environ.setdefault("MPLCONFIGDIR", MPLCONFIGDIR)


def find_recognition_onnx(model_dir: str) -> str:
    import onnxruntime as ort

    candidates: list[tuple[str, int]] = []
    for root, _, filenames in os.walk(model_dir):
        for filename in filenames:
            if not filename.endswith(".onnx"):
                continue
            path = os.path.join(root, filename)
            session = ort.InferenceSession(path)
            input_info = session.get_inputs()[0]
            output_info = session.get_outputs()[0]
            input_shape = input_info.shape
            output_shape = output_info.shape
            if len(input_shape) != 4 or len(output_shape) != 2:
                continue
            if input_shape[-1] != 112 or input_shape[-2] != 112:
                continue
            if not isinstance(output_shape[1], int):
                continue
            candidates.append((path, output_shape[1]))

    if not candidates:
        raise FileNotFoundError(f"No 112x112 recognition ONNX model found in {model_dir}")

    candidates.sort(key=lambda item: item[1], reverse=True)
    return candidates[0][0]


def download_file(url: str, target_path: str) -> None:
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request) as response, open(target_path, "wb") as file:
        shutil.copyfileobj(response, file)


def ensure_model_pack(zip_path_override: str | None, download_url: str | None) -> str:
    model_dir = os.path.join(os.environ["INSIGHTFACE_HOME"], "models", MODEL_PACK)
    if os.path.isdir(model_dir):
        try:
            find_recognition_onnx(model_dir)
            return model_dir
        except FileNotFoundError:
            shutil.rmtree(model_dir, ignore_errors=True)

    zip_dir = os.path.join(os.environ["INSIGHTFACE_HOME"], "models")
    zip_path = os.path.abspath(zip_path_override) if zip_path_override else os.path.join(zip_dir, MODEL_ZIP_NAME)
    model_zip_url = download_url or DEFAULT_MODEL_ZIP_URL

    if zip_path_override:
        if not os.path.isfile(zip_path):
            raise FileNotFoundError(f"Model zip not found: {zip_path}")
    elif not os.path.isfile(zip_path):
        print(f"Step 1/3: download InsightFace model pack `{MODEL_PACK}`...")
        print(f"Downloading to: {zip_path}")
        print(f"Source: {model_zip_url}")
        try:
            download_file(model_zip_url, zip_path)
        except Exception as exc:
            print(f"Download failed: {exc}")
            print("Tips:")
            print("  1. retry with --download-url using an alternate mirror")
            print("  2. or pass --onnx with a local recognition model path")
            raise

    with zipfile.ZipFile(zip_path, "r") as archive:
        archive.extractall(model_dir)
    return model_dir


def resolve_onnx_path(zip_path: str | None, cli_path: str | None, download_url: str | None) -> str:
    if cli_path:
        onnx_path = os.path.abspath(cli_path)
        if not os.path.isfile(onnx_path):
            raise FileNotFoundError(f"ONNX model not found: {onnx_path}")
        return onnx_path

    model_dir = ensure_model_pack(zip_path, download_url)
    return find_recognition_onnx(model_dir)


def convert_with_onnx_tf(onnx_path: str) -> bytes:
    import onnx

    if not hasattr(onnx, "mapping") and hasattr(onnx, "_mapping"):
        onnx.mapping = onnx._mapping

    from onnx_tf.backend import prepare
    import tensorflow as tf

    saved_model_dir = os.path.join(CACHE_ROOT, "buffalo_sc_saved_model")
    shutil.rmtree(saved_model_dir, ignore_errors=True)

    model = onnx.load(onnx_path)
    tf_rep = prepare(model)
    tf_rep.export_graph(saved_model_dir)

    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
    return converter.convert()


def convert_with_onnx2tf(onnx_path: str) -> bytes:
    from onnx2tf.onnx2tf import convert

    saved_model_dir = os.path.join(CACHE_ROOT, "buffalo_sc_saved_model")
    shutil.rmtree(saved_model_dir, ignore_errors=True)

    convert(
        input_onnx_file_path=onnx_path,
        output_folder_path=saved_model_dir,
        non_verbose=True,
    )

    tflite_candidates = []
    for root, _, filenames in os.walk(saved_model_dir):
        for filename in filenames:
            if filename.endswith(".tflite"):
                tflite_candidates.append(os.path.join(root, filename))

    if not tflite_candidates:
        raise FileNotFoundError(f"No TFLite output found in {saved_model_dir}")

    tflite_candidates.sort(key=os.path.getsize, reverse=True)
    with open(tflite_candidates[0], "rb") as file:
        return file.read()


def convert_onnx_to_tflite(onnx_path: str) -> tuple[bytes, str]:
    print(f"Using ONNX: {onnx_path}")
    print("Step 2/3: convert ONNX to TFLite...")

    errors: list[str] = []
    for backend_name, backend in (
        ("onnx-tf", convert_with_onnx_tf),
        ("onnx2tf", convert_with_onnx2tf),
    ):
        try:
            return backend(onnx_path), backend_name
        except Exception as exc:
            errors.append(f"{backend_name}: {exc}")

    print("No available conversion backend succeeded.")
    for error in errors:
        print(f"  - {error}")
    print("Install one of these stacks first:")
    print("  1. py -m pip install onnx onnxruntime onnx-tf tensorflow")
    print("  2. or py -m pip install tensorflow onnx onnxruntime onnx2tf")
    sys.exit(1)


def main() -> None:
    args = parse_args()
    configure_environment()

    if os.path.exists(OUTPUT_PATH) and not args.force:
        print(f"Model already exists: {os.path.abspath(OUTPUT_PATH)}")
        return

    onnx_path = resolve_onnx_path(args.zip, args.onnx, args.download_url)
    tflite_model, backend_name = convert_onnx_to_tflite(onnx_path)

    with open(OUTPUT_PATH, "wb") as file:
        file.write(tflite_model)

    print(f"Done: {os.path.abspath(OUTPUT_PATH)}")
    print(f"Size: {len(tflite_model) / 1024 / 1024:.1f} MB")
    print(f"Backend: {backend_name}")


if __name__ == "__main__":
    main()
