# 26 — Asset Provenance & License Policy

**Status: LOCKED process**

## 1. Goal
Every shipped visual, audio, font, code dependency, and external dataset must have a known origin and permitted use.

## 2. Asset manifest
Maintain a machine-readable or Markdown/CSV manifest with at least:
- asset ID/path;
- asset category;
- creator/source;
- generation method;
- license/terms;
- modification status;
- attribution requirement;
- approval status;
- notes/evidence reference.

## 3. AI-generated assets
For AI-assisted assets, record:
- tool/model/service used;
- date/batch identifier where practical;
- prompt/brief reference;
- manual modifications;
- final production file path.

Do not treat an AI output as production-ready until it passes the Art Bible integration checks.

## 4. Web assets
Do not download arbitrary images/audio from search results into the game because they are convenient.

Only use third-party assets with explicit compatible licensing/permission, and preserve attribution/license evidence.

## 5. Fonts
Ship only fonts with clear redistribution rights. Do not package proprietary/local system font files into the repository without permission.

## 6. Code dependencies/addons
For each addon/library:
- pin version/commit where practical;
- record license;
- confirm compatibility with target platforms/Godot 4.7;
- avoid dependency for trivial functionality that can be safely implemented internally.

## 7. Placeholders
Prototype placeholders must be clearly marked. Release build scripts/checklists should detect or list unapproved placeholders.

## 8. Final audit
Before RC:
- every production asset appears in manifest;
- attribution text generated if required;
- no unknown-source files;
- no accidental reference images shipped;
- no debug/test assets in production bundle unless intended.
