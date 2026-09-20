# External Nixx — Universal Build (iOS 17–27)

Satu IPA. Tiga engine. Auto-select saat runtime.

## Engine matrix

| iOS version | Engine | Catatan |
|---|---|---|
| **17.0 – 17.7.x** | `kexploit_opa334` | Kernel R/W + sandbox escape |
| **18.0 – 18.7.x** | `kexploit_opa334` | Kernel R/W + sandbox escape |
| **26.0 – 26.6.2** | `kexploit_opa334` → `BadKernel` fallback | Auto-fallback kalau opa334 gagal |
| **27.0 db1–db4** | `BadKernel` | bad_query + IOSurface K/R/W |

## Device support

BadKernel **verified di A13** (iPhone 11 series, SE 2nd gen, iPad 9).
SoC lain **belum diverifikasi**.

## Build lokal

```bash
git clone https://github.com/YOUR_USER/ExternalNoelx.git
cd ExternalNoelx
./build_universal.sh
