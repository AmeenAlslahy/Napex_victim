"""تدريب نموذج كشف الابتزاز العربي وتحويله إلى TFLite

الاستخدام:
    pip install tensorflow pandas scikit-learn
    python train_extortion_classifier.py --data dataset.csv --out tflite/

البيانات (dataset.csv): عمودان بدون ترويسة أو بترويسة text,label
    "عندي صورك سأنشرها إذا ما ادفعت",extortion
    "صباح الخير كيف حالك",normal

النموذج: Embedding + BiLSTM صغير — خفيف بما يكفي للهاتف (< 2MB)
المخرجات:
    tflite/extortion_classifier.tflite   — النموذج
    tflite/tokenizer.json                — معجم الرقمنة (يُحمّل في التطبيق)
    tflite/labels.json                   — الفئات بالترتيب
    تقرير تقييم في نهاية التشغيل
"""
import argparse
import json
import math
import re
from pathlib import Path

import numpy as np
import pandas as pd

import tensorflow as tf
from sklearn.model_selection import train_test_split

# ============ التطبيع العربي — نفس منطق التطبيق والخادم ============
_DIACRITICS = re.compile("[\u064b-\u065f\u0670]")
_ARABIC_DIGITS = re.compile("[\u0660-\u0669]")

_NORMALIZE_MAP = {
    "\u0623": "\u0627", "\u0625": "\u0627", "\u0622": "\u0627",
    "\u0671": "\u0627", "\u0649": "\u064a", "\u0629": "\u0647",
    "\u0624": "\u0648", "\u0626": "\u064a",
}


def normalize_arabic(text: str) -> str:
    text = _DIACRITICS.sub("", str(text))
    text = text.replace("\u0640", "")
    for src, dst in _NORMALIZE_MAP.items():
        text = text.replace(src, dst)
    text = _ARABIC_DIGITS.sub(lambda m: chr(ord(m.group()) - 0x0660 + 0x30), text)
    return " ".join(text.split()).lower()


LABELS = ["normal", "spam", "suspicious", "threat", "extortion"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True, help="مسار CSV (text,label)")
    parser.add_argument("--out", default="tflite", help="مجلد المخرجات")
    parser.add_argument("--epochs", type=int, default=12)
    parser.add_argument("--max-len", type=int, default=64)
    parser.add_argument("--vocab-size", type=int, default=8000)
    args = parser.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    # ============ 1. تحميل البيانات ============
    frame = pd.read_csv(args.data)
    column_names = list(frame.columns)
    text_column = "text" if "text" in column_names else column_names[0]
    label_column = "label" if "label" in column_names else column_names[1]

    texts = frame[text_column].map(normalize_arabic).tolist()
    labels = frame[label_column].str.strip().str.lower().tolist()

    unknown = set(labels) - set(LABELS)
    if unknown:
        raise SystemExit(f"فئات غير معروفة: {unknown} — المسموح: {LABELS}")

    # ============ 2. الرقمنة ============
    vectorizer = tf.keras.layers.TextVectorization(
        max_tokens=args.vocab_size,
        output_mode="int",
        output_sequence_length=args.max_len,
    )
    vectorizer.adapt(texts)

    x = vectorizer(np.array(texts))
    y = np.array([LABELS.index(label) for label in labels])

    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=0.2, random_state=42, stratify=y
    )

    # ============ 3. النموذج ============
    model = tf.keras.Sequential(
        [
            tf.keras.layers.Input(shape=(args.max_len,), dtype="int64"),
            tf.keras.layers.Embedding(args.vocab_size, 64),
            tf.keras.layers.Bidirectional(tf.keras.layers.LSTM(48, return_sequences=False)),
            tf.keras.layers.Dropout(0.3),
            tf.keras.layers.Dense(32, activation="relu"),
            tf.keras.layers.Dense(len(LABELS), activation="softmax"),
        ]
    )
    model.compile(
        optimizer="adam",
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.summary()

    model.fit(
        x_train,
        y_train,
        validation_split=0.1,
        epochs=args.epochs,
        batch_size=32,
        callbacks=[tf.keras.callbacks.EarlyStopping(patience=3, restore_best_weights=True)],
    )

    # ============ 4. التقييم ============
    loss, accuracy = model.evaluate(x_test, y_test, verbose=0)
    print(f"\nالدقة على بيانات الاختبار: {accuracy:.3f} (خسارة {loss:.3f})")

    # ============ 5. التحويل إلى TFLite ============
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    model_path = out_dir / "extortion_classifier.tflite"
    model_path.write_bytes(tflite_model)
    (out_dir / "tokenizer.json").write_text(
        json.dumps(
            {
                "vocab": vectorizer.get_vocabulary(),
                "max_len": args.max_len,
                "lower_and_strip": False,
                "note": "طبّق نفس التطبيع العربي قبل الرقمنة",
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    (out_dir / "labels.json").write_text(
        json.dumps(LABELS, ensure_ascii=False), encoding="utf-8"
    )

    size_kb = len(tflite_model) / 1024
    print(f"✓ النموذج: {model_path} ({size_kb:.0f} KB)")
    print("✓ المعجم والفئات جاهزان — انقل الملفات الثلاثة إلى assets/ml_models/")
    print("\nدمج النموذج في التطبيق: اتبع ml/README.md قسم (الدمج في Flutter)")


if __name__ == "__main__":
    main()
