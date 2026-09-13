# Render deployment notes

هذا المشروع جاهز للنشر على Render كـ **Static Site** للواجهة الأمامية Flutter Web.

## الملفات المستخدمة

- `render.yaml` — Blueprint الخاص بـ Render
- `tool/render_build_web.sh` — سكربت بناء Flutter Web
- `build/web` — مجلد الملفات النهائية التي ينشرها Render

## ما الذي تختاره في Render Dashboard؟

1. افتح Render Dashboard.
2. اختر **New > Blueprint** إذا أردت استعمال `render.yaml` مباشرة.
3. اربط المستودع GitHub الخاص بالمشروع.
4. تأكد أن Render يقرأ `render.yaml` من جذر المشروع.
5. اعتمد النشر.

## ماذا يفعل النشر؟

- يشغّل `bash tool/render_build_web.sh`
- يجهّز Flutter إذا لم يكن موجودًا على بيئة Render
- ينفّذ `flutter pub get`
- يبني نسخة الإنتاج عبر `flutter build web --release --base-href /`
- ينشر الملفات من `build/web`

## لماذا يوجد rewrite؟

Flutter Web يستخدم routing من جهة العميل، لذلك نحتاج إعادة كتابة المسارات إلى `index.html` حتى تعمل الصفحات الداخلية والتحديث المباشر بدون 404.

## إذا ظهر خطأ في البناء

أكثر الأسباب شيوعًا:

- عدم توفر Bash في أمر البناء، وهنا Render يشغّل الأمر داخل بيئة لينكس لذلك `bash` متاح
- تأخر تنزيل Flutter في أول build
- خطأ في إعدادات `.env` الخاصة بالاتصال بالخادم الخلفي

## ملاحظات سريعة

- هذا الإعداد خاص بالواجهة الأمامية فقط.
- إذا أردت نشر الباكند على Render أيضًا، نحتاج Blueprint منفصل أو خدمة web إضافية.
- لو كان عندك دومين مخصص، اربطه من لوحة Render بعد نجاح أول نشر.
