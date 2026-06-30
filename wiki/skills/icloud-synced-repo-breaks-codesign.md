---
title: >-
    iCloud-Drive-synced repo breaks Xcode codesign (FinderInfo detritus on .appex)
category: skills
tags: [ios, xcode, codesign, icloud, derived-data, app-extension, build, type/howto]
sources: [projects/kori]
summary: >-
    Building an Xcode project inside an iCloud-Drive-synced folder (~/Documents, ~/Desktop) makes codesign fail on app-extension bundles ("resource fork, Finder information... not allowed") because iCloud stamps com.apple.FinderInfo xattrs on freshly-built .appex. Stripping doesn't help — point derivedDataPath outside iCloud.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.66
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T04:22:30Z
updated: 2026-06-30T04:22:30Z
---

# iCloud-Drive-synced repo breaks Xcode codesign

If your repo lives under an **iCloud-Drive-synced** directory (`~/Documents` and `~/Desktop` are synced by default when iCloud Drive is on), an Xcode build that produces **app-extension bundles** (`.appex` — widgets, Live Activities, share extensions) can fail at the signing step with:

```
<Extension>.appex: resource fork, Finder information, or similar detritus not allowed
Command CodeSign failed with a nonzero exit code
```

## Why

iCloud's fileprovider stamps **every newly-created directory** inside the synced tree with extended attributes — `com.apple.FinderInfo` and `com.apple.fileprovider.fpfs#P`. `codesign` refuses to sign a bundle that carries that "detritus." Because the build *writes* the `.appex` into the synced tree and iCloud **re-stamps it mid-build**, pre-stripping the xattrs (`xattr -c`, `dot_clean`) does **not** work — the freshly-built bundle is re-tagged before codesign runs. ^[extracted]

A sibling **`Libtool … React-Fabric failed`** with only "no symbols" warnings often appears alongside it; that's just collateral from Xcode aborting the parallel build when codesign dies. Fixing codesign fixes both — don't chase the Libtool error separately. ^[inferred]

## Fix — build to a derivedDataPath outside iCloud

Point `-derivedDataPath` (or the Xcode "Derived Data" location) at a path **not** under any iCloud-synced folder — the canonical Xcode location works:

```
xcodebuild … -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/<Name>" …
```

`~/Library` is never iCloud-synced, so the built `.appex` is created clean and stays clean. ^[extracted]

### Gotcha after switching derivedDataPath: React Native codegen

For RN/Expo projects, moving the derivedDataPath **invalidates the generated codegen sources** and the next build dies with:

```
error: Build input file cannot be found: ios/build/generated/ios/<lib>/<lib>-generated.mm
```

(rnsvg, safeareacontext, etc.) Regenerate them before rebuilding by re-running `pod install` (`cd ios && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install`), which recreates `ios/build/generated`. ^[extracted]

## Related

- [[kori-ios-build-run]] — full device-build path where this was hit (Kori lives in `~/Documents/Stratton/kori`).
- [[ios26-scene-lifecycle-launch-crash]] — the other iOS-build wall from the same session.
