# AVEA FASHION

تطبيق متجر إلكتروني للملابس النسائية مبني بـ Flutter مع دعم Firebase (Auth/Firestore/Storage) + كاش محلي (SQLite) لتحسين الأداء.

ميزات النسخة الحالية:
- واجهة متجر عربية حديثة (RTL) مع بطاقات منتجات ديناميكية.
- مصادقة Firebase + مزامنة بيانات (المفضلة/الطلبات/الإشعارات/المكافآت).
- لوحة إدارة لإدارة المنتجات والعروض.
- تخزين محلي (SQLite) لتحسين الاستجابة والعمل المرن.

المتطلبات:
- Flutter SDK مثبت
- حساب Firebase وProject مهيأ

خطوات الإعداد السريع:
1. افتح مجلد المشروع في الطرفية.
2. (Firebase) لربط التطبيق بـ Firebase:
	 - أنشئ Firebase Project من Firebase Console.
	 - أضف تطبيق Android:
		 - اجعل `applicationId` مطابقًا لما في `android/app/build.gradle.kts` (حاليًا: `com.aveafashion.app`).
		 - نزّل ملف `google-services.json` وضعه هنا:
			 - `android/app/google-services.json`
	 - (اختياري) أضف تطبيق iOS ونزّل `GoogleService-Info.plist` وضعه هنا:
		 - `ios/Runner/GoogleService-Info.plist`
		 - لو فعّلت Google Sign-In على iOS: انسخ قيمة `REVERSED_CLIENT_ID` من `GoogleService-Info.plist` وضعها داخل
			 `ios/Runner/Info.plist` تحت `CFBundleURLTypes` بدل `com.googleusercontent.apps.CHANGE_ME`.
	 - ملاحظة: ملفات Firebase مضافة في `.gitignore` داخل هذا المشروع. إذا تريدها تُرفع مع Git احذفها من `.gitignore`.
3. انشر قواعد Firestore (مهم):

```bash
firebase deploy --only firestore:rules
```

4. شغّل محلياً:

```bash
flutter pub get
flutter run
```

ملاحظة Firebase:
- تم إضافة `firebase_core` وتهيئة `Firebase.initializeApp()` في `lib/main.dart`.
- تم تفعيل `Firebase App Check` في `lib/main.dart` و`lib/main_admin.dart`:
	- وضع التطوير: Debug Provider.
	- وضع الإنتاج: Play Integrity (Android) وApp Attest/DeviceCheck (iOS).
- في حال لم تضف ملفات Firebase أعلاه، سيستمر التطبيق بالعمل لكن Firebase قد لا يتهيأ (وسيظهر Log في وضع Debug).

تصميمات ومقترحات الواجهة:
- وضعت نماذج تصميمية بصيغة SVG في مجلد `design/` (Home, Product Detail, Checkout) وملف شعار في `assets/logo.svg`.

ملاحظات:
- النسخة الحالية لا تتضمن طرق دفع. يمكن إضافة Stripe/PayPal لاحقًا.
- أنصح بإنشاء حساب admin منفصل أو تفعيل Firebase Auth لحماية لوحة الإدارة.

إن احتجت أجهز CI/CD أو لوحة إدارة web منفصلة، أقدر أضيفها.

## تطبيق الإدارة المنفصل (Admin App)

تم تجهيز نسخة إدارة مستقلة على مستوى الـ entrypoint:

- ملف التشغيل: `lib/main_admin.dart`
- شاشة البداية: `AdminLoginScreen`
- الواجهة: `AdminAppShell` + مركز التحكم الشامل

### التشغيل من VS Code (Launch Profiles)

تمت إضافة ملف:

- `.vscode/launch.json`

ويحتوي بروفايلين:

- `AVEA FASHION (Customer)` لتشغيل تطبيق العميل
- `AVEA FASHION Admin (Standalone Entry)` لتشغيل تطبيق الإدارة مباشرة

### التشغيل من الطرفية

- تطبيق العميل:
	- `flutter run --flavor customer -t lib/main.dart`
- تطبيق الإدارة:
	- `flutter run --flavor admin -t lib/main_admin.dart`

### التثبيت كتطبيقين منفصلين على Android

- العميل: `applicationId = com.aveafashion.app`
- لوحة التحكم: `applicationId = com.aveafashion.app.admin`

هذا يعني أن الهاتف سيتعامل معهما كتطبيقين مستقلين (أيقونتان منفصلتان وإعدادات منفصلة).

> ملاحظة مهمة: لأن الإدارة تعتمد Firebase/Firestore للصلاحيات والإشعارات، تأكد من تفعيل Firestore API وإعداد قواعد الصلاحيات وحسابات الأدمن.

## النشر على Render

هذا المشروع يحتوي على إعداد جاهز لـ Render كـ **Static Site** لتشغيل Flutter Web:

- ملف الإعداد: `render.yaml`
- سكربت البناء: `tool/render_build_web.sh`
- مجلد النشر: `build/web`

### ما الذي يفعله Render؟

1. يسحب المشروع من GitHub.
2. يشغّل سكربت البناء.
3. يجهّز Flutter إذا لم يكن موجودًا.
4. يبني نسخة الويب.
5. ينشر الملفات الثابتة من `build/web`.

### ملاحظات مهمة

- أضف التطبيق في Render كـ **Static Site**.
- لوحة Flutter web تعتمد على إعادة كتابة المسارات إلى `index.html` حتى تعمل الصفحات الداخلية.
- إذا أردت ربطه بالخادم الخلفي، تأكد أن `LOCAL_CATALOG_BASE_URL` في `.env` يشير إلى رابط الإنتاج الصحيح.