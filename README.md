# منظومة زوار المستشفى (HVMS)

تطبيق Flutter بواجهة عربية من اليمين إلى اليسار لإدارة دخول النظام وطلبات حسابات العاملين، مع وظائف تسجيل الزوار والتقارير.

## وظائف التطبيق الحالية
- تسجيل الدخول عبر Firebase Authentication (البريد الإلكتروني وكلمة المرور).
- إرسال طلب حساب جديد لدور ضابط أمن أو مشرف.
- منع الدخول ما لم يوجد مستند مستخدم فعّال في Firestore.
- شاشة مسؤول لمراجعة طلبات الحسابات، بعد نشر Cloud Functions.
- إدخال بيانات الزيارات وإنشاء تقرير PDF ومشاركته يدويًا من الهاتف.

## إعداد Firebase
1. أنشئ مشروع Firebase واربط تطبيق Android باستخدام package name الموجود في إعداد Firebase.
2. ضع ملف `google-services.json` في `android/app/google-services.json`.
3. فعّل Email/Password من Authentication.
4. انشر قواعد Firestore من الملف `firestore.rules`.
5. أنشئ حساب المسؤول في Authentication، ثم أنشئ يدويًا مستند `users/{UID}` له من Firebase Console بالحقول:
   - `role`: `admin`
   - `status`: `active`
   - `displayName`: اسم المسؤول
   - `email`: بريده الإلكتروني
6. انشر Cloud Functions الموجودة في مجلد `functions` باستخدام Firebase CLI، مع اختيار مشروع Firebase الصحيح. الدالتان `listAccountRequests` و`decideAccountRequest` تتحققان من صلاحية المسؤول على الخادم قبل عرض الطلبات أو اعتمادها.
7. بعد نشر الدوال، حدّث اعتماديات Flutter عبر `flutter pub get`.

## نشر Cloud Functions
من بيئة تطوير فيها Node.js 20 وFirebase CLI:
```bash
firebase login
firebase use --add
cd functions
npm install
cd ..
firebase deploy --only functions
```

اختر مشروع Firebase الصحيح عند إعداد `firebase use --add`. قد يتطلب نشر Cloud Functions تفعيل خطة الفوترة Blaze في مشروع Firebase. لا تنشر من مشروع غير صحيح ولا تشارك مفاتيح حساب الخدمة أو كلمات المرور.

## قواعد الأمان
- لا يستطيع تطبيق العميل إنشاء أو تعديل مستندات `users` أو قراءة قائمة طلبات الحسابات مباشرة.
- الدوال الخلفية تستخدم Firebase Admin SDK وتتحقق من وجود `users/{uid}` بدور `admin` وحالة `active`.
- الموافقة تنشئ ملف مستخدم بالدور المسموح به فقط: `security_officer` أو `supervisor`.
- الرفض يعلّم الطلب كمرفوض ويحذف حساب المصادقة الخاص بمقدم الطلب حتى يتمكن من إعادة الطلب لاحقًا.
- لا تعتبر إخفاء عناصر الواجهة وسيلة حماية؛ التحقق الأساسي يجري على الخادم.

## الخصوصية
تحتاج سجلات الزوار إلى تصميم وربط Firestore منفصلين قبل تخزينها سحابيًا. لا تُعامل واجهات الإحصاءات أو البحث الحالية على أنها متصلة ببيانات فعلية ما لم يُنفّذ ربطها صراحةً.

## البناء
- ملف GitHub Actions الخاص ببناء APK يعمل يدويًا فقط عبر `workflow_dispatch`.
- لا تُشغّل عملية بناء أو Workflow إلا بعد موافقة المستخدم الصريحة.
