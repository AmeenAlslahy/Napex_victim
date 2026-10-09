"""مصنّف كشف الابتزاز على الخادم — نفس خوارزمية تطبيق الجهاز
(تطبيع عربي + أوزان كلمات + منحنى ثقة 1 - e^(-S/k))
يُستخدم لتحليل النصوص على الخادم وتوحيد القواعد عبر /config/keywords"""
import json
import math
import re
from pathlib import Path

_KEYWORDS_PATH = Path(__file__).parent / "keywords_ar.json"

_DIACRITICS = re.compile("[\u064b-\u065f\u0670]")
_TATWEEL = "\u0640"
_ARABIC_DIGITS = re.compile("[\u0660-\u0669]")
_PERSIAN_DIGITS = re.compile("[\u06f0-\u06f9]")

_RISK_THRESHOLDS = ((0.95, "critical"), (0.85, "high"), (0.60, "medium"), (0.30, "low"))


def normalize_arabic(text: str) -> str:
    if not text:
        return ""
    text = _DIACRITICS.sub("", text)
    text = text.replace(_TATWEEL, "")
    for src, dst in (
        ("\u0623", "\u0627"),
        ("\u0625", "\u0627"),
        ("\u0622", "\u0627"),
        ("\u0671", "\u0627"),
        ("\u0649", "\u064a"),
        ("\u0629", "\u0647"),
        ("\u0624", "\u0648"),
        ("\u0626", "\u064a"),
    ):
        text = text.replace(src, dst)
    text = _ARABIC_DIGITS.sub(lambda m: chr(ord(m.group()) - 0x0660 + 0x30), text)
    text = _PERSIAN_DIGITS.sub(lambda m: chr(ord(m.group()) - 0x06F0 + 0x30), text)
    return " ".join(text.split()).lower()


def risk_from_score(score: float) -> str:
    for threshold, level in _RISK_THRESHOLDS:
        if score >= threshold:
            return level
    return "none"


class KeywordClassifier:
    def __init__(self, path: Path = _KEYWORDS_PATH) -> None:
        self._categories: dict[str, list[tuple[str, float]]] = {}
        self._recommendations: dict[str, list[str]] = {}
        self._k = 6.0
        self._overrides: dict[str, float] = {}  # من Feedback Loop
        self.load(path)

    def load(self, path: Path) -> None:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        self._k = float(data.get("k_factor", 6.0))
        self._categories.clear()
        self._recommendations.clear()

        for name, category in (data.get("categories") or {}).items():
            rules: list[tuple[str, float]] = []
            default_weight = float(category.get("default_weight", 1.0))
            for rule in category.get("keywords", []):
                if isinstance(rule, dict):
                    rules.append(
                        (normalize_arabic(rule["phrase"]), float(rule.get("weight", 1.0)))
                    )
                elif isinstance(rule, str):
                    rules.append((normalize_arabic(rule), default_weight))
            self._categories[name] = [r for r in rules if r[0]]

        for key, value in (data.get("recommendations") or {}).items():
            self._recommendations[key] = list(value)

    def apply_overrides(self, overrides: dict[str, float]) -> None:
        """تطبيق معاملات تعديل الأوزان من تغذية الضحايا الراجعة"""
        self._overrides = {
            normalize_arabic(keyword): float(factor)
            for keyword, factor in (overrides or {}).items()
        }

    def classify(self, text: str) -> dict:
        normalized = normalize_arabic(text or "")
        if not normalized:
            return self._result("normal", 0.95, "none", False, {}, [], [])

        scores: dict[str, float] = {}
        matched: list[str] = []
        for name, rules in self._categories.items():
            score = 0.0
            for phrase, weight in rules:
                # الوزن الفعلي = الوزن الأساسي × معامل التغذية الراجعة
                effective = weight * self._overrides.get(phrase, 1.0)
                if phrase in normalized:
                    score += effective
                    matched.append(phrase)
            if score > 0:
                scores[name] = score

        if not scores:
            return self._result("normal", 0.95, "none", False, {}, [], [])

        best_name, best_score = max(scores.items(), key=lambda kv: kv[1])
        confidence = 1 - math.exp(-best_score / self._k)
        is_extortion = best_name == "extortion" or (
            best_name == "threat" and confidence >= 0.85
        )

        return self._result(
            best_name,
            round(confidence, 4),
            risk_from_score(confidence),
            is_extortion,
            {name: round(1 - math.exp(-s / self._k), 4) for name, s in scores.items()},
            matched[:10],
            matched[:5],
        )

    @staticmethod
    def _result(
        category: str,
        confidence: float,
        risk_level: str,
        is_extortion: bool,
        probabilities: dict,
        keywords: list,
        threat_phrases: list,
    ) -> dict:
        return {
            "category": category,
            "confidence": confidence,
            "risk_level": risk_level,
            "is_extortion": is_extortion,
            "probabilities": probabilities,
            "keywords": keywords,
            "threat_phrases": threat_phrases,
            "recommendations": [],
            "analysis_engine": "keyword-v1",
        }


classifier = KeywordClassifier()
