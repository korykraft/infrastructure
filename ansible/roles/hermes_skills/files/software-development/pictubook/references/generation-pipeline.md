# Generation Pipeline — Architecture Reference

## Data Flow (book page generation)

```
User clicks "Generate Book"
  → Queue message sent (jobId, bookProjectId, projectUnitId, projectCharacterId?)
  → bookWorker.ts picks up message

bookWorker.ts: processJob()
  1. Load project → template → templateUnit → character → customFields
  2. Build reference candidates:
     a. Style refs from generation_reference_assets (ownerType="style") or legacy bookStyles.referenceImageKey
     b. Character ref from projectCharacters.referenceAssetId → generatedAssets.storageKey
     c. Template refs from generation_reference_assets (ownerType="template")
     d. TemplateUnit refs from generation_reference_assets (ownerType="template_unit")
  3. Assemble input via generationInputAssembler.ts:
     a. compilePrompt() — modular blocks or legacy promptTemplate
     b. Sort candidates: style(0) → character(1) → template(2) → template_unit(3) → page(4)
     c. Deduplicate by storageKey
     d. Enforce 14-ref cap; overflow → warnings
  4. If GEMINI_STUB="true" → return 1x1 PNG placeholder
  5. If referenceInputs.length > 0:
     a. Upload each ref to Gemini File API via geminiFiles.ts (cached in DB, re-uploads on expiry/404)
     b. Call callGeminiEditWithFileRefs() — file_data parts, not inline base64
     c. System instruction from negativePrompt if present
  6. Else (no refs):
     a. Call callGeminiImageGenerate() — Imagen 4 text-to-image with aspectRatio + negativePrompt
  7. Store result in R2: pages/{bookProjectId}/{projectUnitId}/{uuid}.{ext}
  8. Create generatedAsset row, update projectUnit.finalAssetId + status
  9. If all units settled → update bookProject.status to "ready"
```

## Gemini File API Caching (geminiFiles.ts)

- R2 is SOURCE OF TRUTH (durable). Gemini File API is EPHEMERAL (files expire).
- `ensureFileApiUpload(apiKey, db, bucket, storageKey, mimeType)`:
  1. Check DB cache (gemini_file_cache table) for non-expired URI for this storageKey
  2. If cached and valid → return cached URI
  3. If expired/missing → download from R2, upload to Gemini File API, cache URI in DB
  4. On Gemini 404 for a cached URI → re-upload (transparent recovery)
- Cache table: `gemini_file_cache` (migration 0030) — maps r2Key → geminiFileUri + mimeType + expiresAt

## Prompt Assembly (promptCompiler.ts)

Fixed order when modular blocks are populated:
```
stylePrompt      → "[style block]"
compositionPrompt → "[composition block]"  
characterPrompt  → "[character block]"
basePrompt       → "[base block]"
lightingPrompt   → "[lighting block]"
```
Blocks joined with `\n\n`. Whitespace-only/null/undefined blocks skipped.
If no modular blocks are populated → falls back to legacy `promptTemplate`.

Placeholder substitution: `{{variable}}` (preferred) and `[variable]` (legacy). Both syntaxes are replaced globally.

## Reference Candidate Resolution

Priority order for style references (first non-empty wins):
1. Template's assigned style → generation_reference_assets (ownerType="style")
2. Template's assigned style → bookStyles.referenceImageKey (legacy fallback)
3. Admin default style → generation_reference_assets (legacy chain)
4. Admin settings → character_style_reference_key (very legacy)
5. No style → fall back to Imagen 4 (text-only)

## Key Env Vars

- `GEMINI_API_KEY` — required for generation (unless GEMINI_STUB="true")
- `GEMINI_STUB` — "true" returns 1x1 PNG placeholder (dev/testing)
- `R2_PUBLIC_URL` — if set, asset URLs use direct R2; otherwise proxy via `/v1/r2/{key}`
- `DEV_MODE` — "true" logs OTPs to console, skips email sending

## Generation Audit Trail

Every generationJob stores:
- `prompt` — compiled prompt text
- `rawRequestJson` — audit metadata (prompt char count, reference counts, buckets, overflow warnings)
- `providerModel` — which model ran ("gemini-2.5-flash-image", "imagen-4.0-generate-001", or "stub")
- `outputAssetId` — link to generatedAsset
- `errorMessage` — if failed

Never stores: raw image bytes, API keys, or unredacted request payloads.

## Plans Status (as of June 2026)

- **admin-gemini-style-template-workbench** (11 tasks): ALL COMPLETE — Styles required, multi-reference images, File API cache, Books/Pages terminology, shared assembler
- **admin-page-text-overlay** (7 tasks): ALL COMPLETE — One overlay per page, normalized coords, whitelisted fonts, shared PageOverlayRenderer, admin + user review rendering
