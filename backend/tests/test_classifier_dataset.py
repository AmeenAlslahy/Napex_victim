"""اختبار شامل لمصنّف الابتزاز — يقرأ CSV ويقيس الدقة.

التشغيل: cd backend && ../.venv/Scripts/python.exe -m pytest tests/test_classifier_dataset.py -v -s
"""
import csv
from pathlib import Path

import pytest

from app.services.classifier import KeywordClassifier, _KEYWORDS_PATH

DATASET = Path(__file__).parent / "datasets" / "extortion_test_set.csv"


def load_dataset():
    rows = []
    with DATASET.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append((row["text"], row["expected_label"]))
    return rows


@pytest.fixture(scope="module")
def classifier():
    c = KeywordClassifier()
    c.load(_KEYWORDS_PATH)
    return c


@pytest.fixture(scope="module")
def dataset():
    return load_dataset()


def test_dataset_exists():
    assert DATASET.exists(), f"Dataset not found: {DATASET}"


def test_overall_accuracy(classifier, dataset):
    """الدقة الإجمالية — الهدف ≥ 90%"""
    correct = sum(
        1 for text, expected in dataset
        if classifier.classify(text)["category"] == expected
    )
    accuracy = correct / len(dataset)
    print(f"\n📊 الدقة الإجمالية: {correct}/{len(dataset)} = {accuracy:.1%}")
    assert accuracy >= 0.90, f"الدقة {accuracy:.1%} أقل من 90%"


def test_extortion_recall(classifier, dataset):
    """معدل استدعاء الابتزاز — الهدف ≥ 95% (extortion + threat = ابتزاز مؤكد)"""
    cases = [(t, e) for t, e in dataset if e in ("extortion", "threat")]
    correct = sum(
        1 for t, e in cases
        if classifier.classify(t)["is_extortion"]
    )
    recall = correct / len(cases)
    print(f"\n🎯 استدعاء الابتزاز: {correct}/{len(cases)} = {recall:.1%}")
    assert recall >= 0.95, f"الاستدعاء {recall:.1%} أقل من 95%"


def test_false_positive_rate(classifier, dataset):
    """معدل الإيجابيات الكاذبة على العادي — الهدف ≤ 5%"""
    normal_cases = [(t, e) for t, e in dataset if e == "normal"]
    false_positives = sum(
        1 for t, _ in normal_cases
        if classifier.classify(t)["is_extortion"]
    )
    fp_rate = false_positives / len(normal_cases)
    print(f"\n❌ إيجابيات كاذبة: {false_positives}/{len(normal_cases)} = {fp_rate:.1%}")
    assert fp_rate <= 0.05, f"FP rate {fp_rate:.1%} أعلى من 5%"


def test_suspicious_not_extortion(classifier, dataset):
    """المشبوه يجب ألا يُعتبر ابتزازاً مؤكداً"""
    suspicious_cases = [(t, e) for t, e in dataset if e == "suspicious"]
    wrong = [
        t for t, _ in suspicious_cases
        if classifier.classify(t)["is_extortion"]
    ]
    assert not wrong, f"مشبوه صُنّف ابتزازاً: {wrong}"


def test_performance(classifier):
    """زمن التحليل < 50ms للرسالة"""
    import time
    start = time.perf_counter()
    for _ in range(100):
        classifier.classify("عندي صورك، ادفع 5000 ريال وإلا أنشرها")
    elapsed_ms = (time.perf_counter() - start) * 1000 / 100
    print(f"\n⚡ متوسط زمن التحليل: {elapsed_ms:.1f}ms")
    assert elapsed_ms < 50
