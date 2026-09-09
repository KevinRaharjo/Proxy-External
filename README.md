# External Noelx / OGIOS

هذا هو المشروع الكامل المرسل في أرشيف MediaFire، وليس نموذجًا جديدًا. يحتوي على مشروع Xcode الأصلي، الشاشات، الخدمات، الأصول، ملفات الـpatch، ووحدات العمل الداخلية.

## البنية

- `ExternalNoelx/views`: واجهات التطبيق ونظام التصميم.
- `ExternalNoelx/helpers`: الخدمات الداخلية مثل إدارة الملفات، المشاريع، التنظيف، التخزين، الأرشفة، وإدارة التفعيل.
- `ExternalNoelx/Assets.xcassets`: الأيقونات والصور والخلفيات.
- `ExternalNoelx/Patches`: حزم patch المضمنة في التطبيق.
- `ExternalNoelx/exploit` و`ExternalNoelx/kexploit`: ملفات الدعم الأصلية للمشروع كما وردت في المصدر.
- `ExternalNoelx.xcodeproj`: مشروع Xcode الكامل.
- `build_unsigned.sh`: بناء IPA غير موقّع على macOS.

## التفعيل

تم استبدال التحقق الشبكي بمدير تفعيل محلي داخل `helpers/LicenseManager.swift`. لا يحتاج التطبيق إلى API server لتفعيل الترخيص، والمفتاح المقبول هو:

```text
OGIOS
```

يحفظ التفعيل في Keychain على الجهاز، ويمكن إزالة التفعيل من داخل التطبيق عبر `deactivate()`.

## البناء

يتطلب البناء جهاز macOS مع Xcode. يمكن تشغيل:

```bash
./build_unsigned.sh
```

ثم استخدام GitHub Actions من خلال Workflow البناء الموجود في `.github/workflows/build.yml`.
