"""عينات ابتزاز واقعية (لهجة دارجة) — تمنع تراجع كشف المحرك.

أي رسالة هنا يجب أن تُكشف ابتزازاً مؤكداً بثقة ≥ 0.85.
الرسائل العادية يجب ألا تُطلق إنذاراً كاذباً.
"""
from pathlib import Path

from app.services.classifier import KeywordClassifier

KEYWORDS_PATH = Path(__file__).parents[1] / "services" / "keywords_ar.json"

EXTORTION_SAMPLES = [
    "اذا ما ترسل لي 500 الف بنشر صورك واسمع بك",
    "اذا ما تنفذ اللي طلبته منه اعرف ان فضيحتك بتكون بين كل الناس",
    "معك مهله يومين والا ما تلوم الا نفسك",
    "اسمعي يابنت اذا ما ترسلي صورك وانت عارية كل شي بيوصل لعند اهلك ولعند الناس",
    # الجولة الثانية — إخفاقات فعلية أُصلحت (حماية من التراجع)
    "أعرف وين تسكن، وراح أجيك أنت وعائلتك إذا ما ساعدتني",
    "انتبه لنفسك، أنا مستعد لك وأعرف مكان عملك",
    "راح أخبر كل الناس عنك وافضحك في كل مكان إذا ما سويت اللي أبغاه",
    "أنا لا أحب المشاكل، فقط أبغى حقي. عندي أشياء لك، إذا ما تفاهمنا ممكن تنتشر",
    "ههههه إذا ما ساعدتني راح أنشر صورك، أمزح أمزح",
]

INNOCENT_SAMPLES = [
    "وين وصلت يا اخي اتصل بي لما تفضى",
    "عندي عرض خاص على الاشتراك خصم 50 بالمئة",
    "صباح الخير كيف حالك اليوم",
    # مشبوه/إزعاج — يجب ألا يُعتبر ابتزازاً
    "مرحبا، ممكن ترسل لي صورة لك؟ أبي أتعرف عليك أكثر",
    "توصيل سريع لجميع المناطق، اتصل الآن: 777123456",
]


def test_real_world_extortion_samples_are_detected():
    classifier = KeywordClassifier()
    classifier.load(KEYWORDS_PATH)

    for text in EXTORTION_SAMPLES:
        result = classifier.classify(text)
        assert result["is_extortion"], (
            f'لم تُكشف: "{text}" → {result["category"]} '
            f'({result["confidence"]:.2f})'
        )
        assert result["confidence"] >= 0.85, (
            f'ثقة منخفضة: "{text}" → {result["confidence"]:.2f}'
        )


def test_innocent_messages_no_false_alarm():
    classifier = KeywordClassifier()
    classifier.load(KEYWORDS_PATH)

    for text in INNOCENT_SAMPLES:
        result = classifier.classify(text)
        assert not result["is_extortion"], (
            f'إنذار كاذب: "{text}" → {result["category"]} '
            f'({result["confidence"]:.2f})'
        )
