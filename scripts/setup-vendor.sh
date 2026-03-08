#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENDOR_DIR="$PROJECT_ROOT/vendor"
TMP_DIR="$PROJECT_ROOT/.vendor-build-tmp"

echo "=== SessionTimer vendor setup ==="
echo "Project root: $PROJECT_ROOT"
echo "Vendor dir:   $VENDOR_DIR"
echo ""

mkdir -p "$VENDOR_DIR"

# ── 1. Build sherpa-onnx from source ──────────────────────────────────────────
if [ -d "$VENDOR_DIR/sherpa-onnx.xcframework" ] && [ -d "$VENDOR_DIR/ios-onnxruntime" ]; then
    echo "[1/5] sherpa-onnx.xcframework already exists — skipping build"
else
    echo "[1/5] Building sherpa-onnx from source (this takes 10-20 minutes)..."
    mkdir -p "$TMP_DIR"

    if [ ! -d "$TMP_DIR/sherpa-onnx" ]; then
        git clone --depth 1 https://github.com/k2-fsa/sherpa-onnx.git "$TMP_DIR/sherpa-onnx"
    fi

    pushd "$TMP_DIR/sherpa-onnx" > /dev/null
    bash ./build-ios.sh
    popd > /dev/null

    cp -R "$TMP_DIR/sherpa-onnx/build-ios/sherpa-onnx.xcframework" "$VENDOR_DIR/"
    cp -R "$TMP_DIR/sherpa-onnx/build-ios/ios-onnxruntime" "$VENDOR_DIR/"

    echo "    → sherpa-onnx.xcframework and ios-onnxruntime copied to vendor/"
fi

# ── 2. Download matcha model files from ModelScope ────────────────────────────
MATCHA_DIR="$VENDOR_DIR/matcha-icefall-zh-en"
mkdir -p "$MATCHA_DIR"

if [ -f "$MATCHA_DIR/model-steps-6.onnx" ] && [ -f "$MATCHA_DIR/vocos-16khz-univ.onnx" ]; then
    echo "[2/5] ModelScope model files already exist — skipping"
else
    echo "[2/5] Downloading model files from ModelScope..."
    mkdir -p "$TMP_DIR"

    if [ ! -d "$TMP_DIR/matcha_tts_modelscope" ]; then
        git clone https://www.modelscope.cn/dengcunqin/matcha_tts_zh_en_20251010.git "$TMP_DIR/matcha_tts_modelscope"
    fi

    for f in model-steps-2.onnx model-steps-3.onnx model-steps-4.onnx model-steps-5.onnx model-steps-6.onnx vocos-16khz-univ.onnx vocab_tts.txt; do
        if [ -f "$TMP_DIR/matcha_tts_modelscope/$f" ]; then
            cp "$TMP_DIR/matcha_tts_modelscope/$f" "$MATCHA_DIR/"
        fi
    done

    echo "    → Model files copied to $MATCHA_DIR/"
fi

# ── 3. Download auxiliary files from HuggingFace ─────────────────────────────
if [ -f "$MATCHA_DIR/tokens.txt" ] && [ -f "$MATCHA_DIR/lexicon.txt" ] && [ -d "$MATCHA_DIR/espeak-ng-data" ]; then
    echo "[3/5] HuggingFace auxiliary files already exist — skipping"
else
    echo "[3/5] Downloading auxiliary files from HuggingFace (requires git-lfs)..."
    mkdir -p "$TMP_DIR"

    if [ ! -d "$TMP_DIR/matcha_icefall_hf" ]; then
        git clone https://huggingface.co/csukuangfj/matcha-icefall-zh-en "$TMP_DIR/matcha_icefall_hf"
    fi

    for f in tokens.txt lexicon.txt date-zh.fst number-zh.fst phone-zh.fst; do
        if [ -f "$TMP_DIR/matcha_icefall_hf/$f" ]; then
            cp "$TMP_DIR/matcha_icefall_hf/$f" "$MATCHA_DIR/"
        fi
    done

    if [ -d "$TMP_DIR/matcha_icefall_hf/espeak-ng-data" ]; then
        cp -R "$TMP_DIR/matcha_icefall_hf/espeak-ng-data" "$MATCHA_DIR/"
    fi

    echo "    → Auxiliary files copied to $MATCHA_DIR/"
fi

# ── 4. Download jieba dict from cppjieba ─────────────────────────────────────
if [ -d "$MATCHA_DIR/dict" ]; then
    echo "[4/5] cppjieba dict already exists — skipping"
else
    echo "[4/5] Downloading jieba dict from cppjieba..."
    mkdir -p "$TMP_DIR"

    if [ ! -d "$TMP_DIR/cppjieba" ]; then
        git clone --depth 1 https://github.com/yanyiwu/cppjieba.git "$TMP_DIR/cppjieba"
    fi

    cp -R "$TMP_DIR/cppjieba/dict" "$MATCHA_DIR/"
    echo "    → dict/ copied to $MATCHA_DIR/"
fi

# ── 5. Clean up temporary build directory ────────────────────────────────────
echo "[5/5] Cleaning up temporary files..."
rm -rf "$TMP_DIR"

echo ""
echo "=== Vendor setup complete ==="
echo ""
echo "Contents of $VENDOR_DIR:"
ls -la "$VENDOR_DIR"
echo ""
echo "Contents of $MATCHA_DIR:"
ls -la "$MATCHA_DIR"
