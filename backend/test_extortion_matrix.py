# -*- coding: utf-8 -*-
"""مصفوفة اختبار كشف الابتزاز — رسائل واقعية من المستخدم.

تشغيل: cd backend && ../.venv/Scripts/python.exe test_extortion_matrix.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from app.services.classifier import KeywordClassifier, _KEYWORDS_PATH  # noqa: E402

# (النص، الفئة المتوقعة، ابتزاز مؤكد؟، أدنى ثقة)
MATRIX = [
    # === الفئة 1: ابتزاز صريح — extortion • 0.95+ ===
    ("عندي صورك الخاصة، ادفع 500 دولار وإلا سأنشرها على الفيسبوك", "extortion", True, 0.90),
    ("معي فيديوهاتك مع فتاة، حول 1000 ريال على هذا الحساب أو سأرسلها لأهلك", "extortion", True, 0.90),
    ("أنا عندي محادثاتك ومقاطعك، تدفع أو بفضحك في كل مكان", "extortion", True, 0.90),
    ("هذه آخر فرصة: ادفع المبلغ المطلوب خلال 24 ساعة أو سأنشر كل شي", "extortion", True, 0.90),
    # === الفئة 2: تهديد — threat • 0.85+ ===
    ("أعرف وين تسكن، وراح أجيك أنت وعائلتك إذا ما ساعدتني", "threat", True, 0.85),
    ("انتبه لنفسك، أنا مستعد لك وأعرف مكان عملك", "threat", True, 0.80),
    ("راح أخبر كل الناس عنك وافضحك في كل مكان إذا ما سويت اللي أبغاه", "threat", True, 0.85),
    # === الفئة 3: مشبوه — suspicious • 0.65+ ===
    ("مرحبا، ممكن ترسل لي صورة لك؟ أبي أتعرف عليك أكثر", "suspicious", False, 0.60),
    ("مرحبا، أنا من الدعم الفني. أرسل لي رمز التحقق اللي وصلك للتأكد من حسابك", "suspicious", False, 0.60),
    ("تم إيقاف حسابك مؤقتاً. أرسل كود التحقق لاستعادة الوصول", "suspicious", False, 0.60),
    # === الفئة 4: إزعاج — spam ===
    ("عرض خاص! خصم 50% على جميع المنتجات. اشترك الآن", "spam", False, 0.60),
    ("توصيل سريع لجميع المناطق، اتصل الآن: 777123456", "spam", False, 0.55),
    # === الفئة 5: عادي — normal ===
    ("مرحبا كيف حالك اليوم؟ إن شاء الله بخير", "normal", False, 0.90),
    ("شكراً على مساعدتك أمس، جزاك الله خير", "normal", False, 0.90),
    ("موعدنا بكرة الساعة 5 في المقهى، تيجي؟", "normal", False, 0.90),
    ("طلبك تم شحنه، سيصلك خلال 3 أيام عمل", "normal", False, 0.90),
    ("تذكير: موعدك مع الدكتور غداً الساعة 10 صباحاً", "normal", False, 0.90),
    # === حالات الحافة ===
    ("أنا لا أحب المشاكل، فقط أبغى حقي. عندي أشياء لك، إذا ما تفاهمنا ممكن تنتشر", "extortion", True, 0.75),
    ("ههههه إذا ما ساعدتني راح أنشر صورك، أمزح أمزح", "extortion", True, 0.70),
    ("I have your photos, pay me or I will send them to your family", "extortion", True, 0.85),
    ("معي صورك يالغالي، دبر لك مبلغ ولا أخبر الناس عنك", "extortion", True, 0.85),
    ("عندي كلام مهم لك، اتصل بي", "normal", False, 0.0),
]


def main() -> int:
    c = KeywordClassifier()
    c.load(_KEYWORDS_PATH)

    passed = 0
    failures = []
    print(f"{'#':>2} {'فعلي':<24} {'متوقع':<24} الحالة")
    print("-" * 96)
    for i, (text, want_cat, want_ext, min_conf) in enumerate(MATRIX, 1):
        r = c.classify(text)
        got_cat = r["category"]
        got_ext = r["is_extortion"]
        got_conf = r["confidence"]

        cat_ok = got_cat == want_cat
        ext_ok = got_ext == want_ext
        conf_ok = got_conf >= min_conf
        ok = cat_ok and ext_ok and conf_ok

        mark = "PASS" if ok else "FAIL"
        if ok:
            passed += 1
        else:
            failures.append((i, text, want_cat, want_ext, min_conf, got_cat, got_ext, got_conf, r.get("keywords", [])))
        print(f"{i:>2} {got_cat}/{got_ext}/{got_conf:.2f} "
              f"{want_cat}/{want_ext}/{min_conf} {mark} | {text[:48]}")

    print("-" * 96)
    print(f"النتيجة: {passed}/{len(MATRIX)}")
    if failures:
        print("\n=== التفاصيل ===")
        for i, text, wc, we, mc, gc, ge, gconf, kw in failures:
            print(f"#{i} متوقع={wc}/{we}/>{mc} فعلي={gc}/{ge}/{gconf:.2f} kw={kw[:5]}")
            print(f"    {text}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
