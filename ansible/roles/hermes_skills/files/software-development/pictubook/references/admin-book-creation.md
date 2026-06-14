# Admin Book Creation Pipeline

How to create a publishable book template through the admin API. All endpoints require authentication + admin role. Use a session cookie from a signed-in admin user (`-b /tmp/cookies.txt`).

## 1. Create a Style

```bash
curl -s -b /tmp/cookies.txt -X POST http://localhost:9797/v1/admin/styles \
  -H "Content-Type: application/json" \
  -d '{"name":"Style Name","description":"Detailed description of the illustration aesthetic — this is used in generation prompts."}'
```

Returns the style with an `id`. The `description` field is critical — it feeds into image generation prompts to maintain consistency. Be specific about: brush style, color palette, character features, lighting, line quality, and artistic influences.

Optional: upload a reference image via `POST /v1/admin/styles/{id}/reference-image` (multipart form, field `file`).

## 2. Create a Book Template

```bash
curl -s -b /tmp/cookies.txt -X POST http://localhost:9797/v1/admin/templates \
  -H "Content-Type: application/json" \
  -d '{
    "title":"Book Title",
    "description":"Book description shown to users",
    "characterPrompt":"Prompt used to transform uploaded photo into illustrated character",
    "styleId":"<style-id>"
  }'
```

Required: `title`, `styleId`. Optional: `description`, `characterPrompt`. Status defaults to `draft`.

After creation, set slug/age/categories via direct DB update (the PUT endpoint doesn't handle these fields as of this writing):
```sql
UPDATE book_templates SET slug='my-slug', ageMin=3, ageMax=7, categoriesJson='["cat1","cat2"]' WHERE id='<template-id>';
```

## 3. Add Units (Pages)

```bash
curl -s -b /tmp/cookies.txt -X POST "http://localhost:9797/v1/admin/templates/{id}/units" \
  -H "Content-Type: application/json" \
  -d '{
    "unitNumber": 1,
    "unitType": "cover",
    "title": "Page Title",
    "sceneTitle": "Scene Name",
    "sceneDescription": "What happens on this page",
    "basePrompt": "Base generation instruction",
    "stylePrompt": "Style-specific prompt fragment",
    "compositionPrompt": "Layout and composition instructions",
    "characterPrompt": "Character placement and description",
    "lightingPrompt": "Lighting instructions",
    "storyText": "The story text displayed on this page",
    "textPosition": "caption_below"
  }'
```

Required: `unitNumber` (int, min 1), `unitType`.

### Unit Types
- `cover` — Front cover (8x10, pageSpan 1)
- `back_cover` — Back cover (8x10, pageSpan 1)
- `title_page` — Inside title page (8x10, pageSpan 1)
- `dedication` — Dedication page (8x10, pageSpan 1)
- `single_page` — Single illustrated page (8x10, pageSpan 1)
- `spread` — Two-page spread (16x10, pageSpan 2)

### Prompt Strategy
For image generation, the system compiles modular prompts into a single generation request:
- `basePrompt` — What type of illustration this is (cover, spread, etc.)
- `stylePrompt` — The style reference (usually the style description from step 1)
- `compositionPrompt` — What to draw, layout, character placement
- `characterPrompt` — How the character appears on this page (use `[characterName]` and `[characterDescription]` as placeholders)
- `lightingPrompt` — Lighting and atmosphere

### Text Positions
`caption_below`, `caption_above`, `overlay_center`, `full_page_text`, `none`

## 4. Publish

```bash
curl -s -b /tmp/cookies.txt -X POST "http://localhost:9797/v1/admin/templates/{id}/publish"
```

This sets status to `published`. The book now appears at `GET /v1/templates` for users to select and create projects from. Requires `styleId` to be set.

## Example Book Structure

A typical 12-page children's book:
1. Cover — hero + title
2. Title page — decorative, minimal
3. Spread 1 — story begins
4. Spread 2 — rising action
5. Spread 3 — complication
6. Spread 4 — journey
7. Spread 5 — discovery
8. Spread 6 — climax
9. Spread 7 — resolution
10. Spread 8 — celebration
11. Back cover — summary/blurb

Each spread is 16"×10" (two 8"×10" pages side by side).

## Making a User Admin

```sql
UPDATE user SET role = 'admin' WHERE email = 'user@example.com';
```

The admin middleware checks `user.role === "admin"`. No other roles exist.

## Debugging

List all units for a template:
```bash
curl -s -b /tmp/cookies.txt "http://localhost:9797/v1/admin/templates/{id}/units"
```

Get template with units:
```bash
curl -s -b /tmp/cookies.txt "http://localhost:9797/v1/admin/templates/{id}"
```

## Testing Image Generation

When `GEMINI_API_KEY` is set in `.env.dev`, you can test the full generation pipeline without
going through the user-facing project flow.

### 5a. Create a Test Fixture (Character Illustration)

Upload a photo to generate an illustrated character in the target style:

```bash
# First create a simple test photo if you don't have one
curl -sL -o /tmp/test-photo.png "https://placehold.co/512x512/F5E6D3/4A7C59?text=Test+Photo"

# Create the fixture — this triggers image generation (Gemini call)
curl -s -b /tmp/cookies.txt -X POST \
  "http://localhost:9797/v1/admin/styles/{styleId}/fixtures" \
  -F "name=Test Character" \
  -F "description=A cheerful child with brown hair" \
  -F "characterPrompt=Create a warm whimsical illustrated childrens book character. Soft watercolor style." \
  -F "photo=@/tmp/test-photo.png"
```

This uploads the photo to R2, generates an illustrated version via Gemini,
and stores the result. Returns `illustratedStorageKey` and `illustratedUrl`.

Model used: `gemini-2.5-flash-image` (auto-selected by the pipeline).

### 5b. Test-Generate a Page

Use the fixture to generate a spread for a specific template unit:

```bash
curl -s -b /tmp/cookies.txt -X POST \
  "http://localhost:9797/v1/admin/templates/{templateId}/units/{unitId}/test-generate" \
  -H "Content-Type: application/json" \
  -d '{"fixtureId":"<fixture-id>"}'
```

This compiles the unit's modular prompts (base + style + composition + character + lighting)
into a single generation request. The illustrated fixture character is injected as a
character reference image. Returns `outputStorageKey`, `outputUrl`, `resolvedPrompt`,
and `providerModel`.

The output image is accessible via:
```
http://localhost:9797/v1/r2/{outputStorageKey}
```

Note: the `outputUrl` in the response may reference `localhost:8787` (the API's configured
base URL), but the R2 proxy at `:9797` serves the same paths.
