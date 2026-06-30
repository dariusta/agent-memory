---
title: >-
    macOS 26 dropped the on-device Vision OCR models — swap to RapidOCR
category: skills
tags: [macos, ocr, vision, computer-vision, rapidocr, domain/tooling, type/howto]
sources: [projects/iphone-control]
summary: >-
    On macOS 26 (Darwin 27) the on-device Vision text-recognition model bundle is missing — TextRecognition.framework logs "Found bundles : { }" and both legacy VNRecognizeTextRequest and modern RecognizeTextRequest fail. It's not an API bug; the model assets aren't provisioned. Swap to RapidOCR (bundled ONNX) instead.
provenance:
  extracted: 0.6
  inferred: 0.35
  ambiguous: 0.05
base_confidence: 0.62
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T02:05:24Z
updated: 2026-06-30T02:05:24Z
---

# macOS 26 dropped the on-device Vision OCR models

If a macOS tool that uses Apple's **Vision** text recognition suddenly returns no text on **macOS 26 (Darwin 27)**, don't chase the API. The on-device OCR **model assets aren't provisioned** on the OS: `TextRecognition.framework` logs **`Found bundles : { }`**, meaning the model bundle the recognizer needs is simply absent. ^[inferred]

The tell that distinguishes this from an API/usage bug:

- It fails for **both** the legacy `VNRecognizeTextRequest` *and* the modern `RecognizeTextRequest` — rewriting to the new API does **not** help, because both load the same missing models. ^[extracted]
- The recognizer doesn't throw a clear "no model" error; it returns empty results while logging the bundle line above. ^[extracted]

## The fix: a self-contained OCR engine

Switch off the system Vision OCR entirely and use an engine that **bundles its own models** so it can't depend on OS-provisioned assets. [[iphone-control]] swapped to **RapidOCR** (`rapidocr_onnxruntime`, ONNXRuntime + PP-OCR models shipped in the wheel, ~0.6s/frame): cache one `RapidOCR()` instance and call it per frame. It sidesteps the broken system models completely and is more portable across machines. ^[extracted]

General principle: when an OS-provided ML capability silently degrades after an OS bump, prefer a dependency that **vendors its own model weights** over one that relies on system-provisioned models — the latter is exactly what breaks across OS upgrades.
