---
name: pictubook
description: "PictuBook app dev conventions, admin workflows, and book creation pipeline."
version: 1.0.0
created_by: agent
---

# PictuBook Development

Trigger: any task involving the PictuBook monorepo (pictubook-app) — development, debugging, admin book creation, staging QA, or onboarding.

## Dev Conventions (DO NOT SKIP)

### Ports
- **Kory's own dev:** web on 5173, API on 8787
- **Hermes dev:** web on 6173, API on 9797 — never use Kory's ports or they collide

When starting the web dev server: `pnpm --filter @pictubook/web run dev --port 6173 --host 0.0.0.0`
When starting the API: `pnpm exec wrangler dev --persist-to ../../.wrangler/state --port 9797` (run from `apps/api/` — the package.json script hardcodes `--port 8787` so you can't use `pnpm run dev --port`)

### CSRF trustedOrigins
SvelteKit `config.kit.csrf.checkOrigin` is **deprecated**. Use `csrf.trustedOrigins` — an array of **strings** (NOT regex). Kory accesses the app from his Mac via `http://ubuntu:5173`, so `"ubuntu"` must be in the list:
```js
csrf: {
  trustedOrigins: ["localhost", "ubuntu", "pictubook.com", "k2v.org"],
}
```

### Git
- Repo: `github.com/korykraft/pictubook-app`
- Branch off `origin/dev`, PR against `dev` — never `main`
- Git identity (repo-level): `user.name=Hermes`, `user.email=hermes@pictubook.com`
- Use `gh` CLI for PRs; token stored persistently

### Setup
- `setup.sh` — bash equivalent of `setup.fish`, runs full onboarding (prereqs, env, deps, sync, migrate, test, start). Creates `~/.pictubook-secrets` template if missing.
- `pnpm sync-env` merges `.env.dev` + `~/.pictubook-secrets` (secrets override) → `apps/api/.dev.vars` + `apps/web/.env.local`
- `pnpm db:migrate` applies Drizzle migrations to local D1

### .env.dev
`DEV_MODE=true` means email OTPs are logged to console instead of sent. To find an OTP during dev, query the `verification` table directly:
```
pnpm exec wrangler d1 execute pictubook-db --local --persist-to ../../.wr...tate --command "SELECT * FROM verification WHERE identifier LIKE 'email-otp:%' ORDER BY createdAt DESC LIMIT 1;"
```

**API keys are NOT in `.env.dev`.** They live in `~/.pictubook-secrets` outside the repo, referenced by the `ENV_SECRETS_PATH` pointer in `.env.dev`. `sync-env` merges them at sync time. `.env.dev` is safe to read during debugging — only non-sensitive config lives there.

### Auth
Better Auth with email/password + OTP verification. Endpoints at `/v1/api/auth/*`. Custom OTP verification at `POST /v1/verify-email-otp` with `{email, otp}`. Session cookie: `cloud.session_token`.

## Generation Pipeline (Gemini)

The AI pipeline uses the Gemini API directly (NOT n8n — n8n workflows in the repo are legacy/inactive). Future plan: multi-backend selector for admins, but for now everything goes through Gemini.

### Two models
- **Gemini 2.5 Flash Image** (`gemini-2.5-flash-image`) — primary model. Used when one or more reference images are available. Accepts image inputs + text prompt, returns an image. Supports the Gemini File API for ephemeral reference caching.
- **Imagen 4** (`imagen-4.0-generate-001`) — fallback. Pure text-to-image. Used only when no reference images exist (no style refs, no character illustration).

### Key source files (know these before touching generation code)
| File | Role |
|------|------|
| `apps/api/src/lib/gemini.ts` | Low-level Gemini/Imagen API calls (`callGeminiImageEdit`, `callGeminiEditWithFileRefs`, `callGeminiImageGenerate`) |
| `apps/api/src/lib/geminiFiles.ts` | Gemini File API upload/cache layer — ephemeral per-job cache for reused references |
| `apps/api/src/lib/promptCompiler.ts` | Compiles modular prompt blocks (style→composition→character→base→lighting) + placeholder substitution (`{{var}}` and `[var]`) |
| `apps/api/src/lib/generationInputAssembler.ts` | Sorts, deduplicates, and enforces the 14-reference limit on reference candidates |
| `apps/api/src/queue/bookWorker.ts` | Queue worker — loads refs from R2, uploads to File API, calls Gemini, stores result in R2 |
| `apps/api/src/lib/character-generation.ts` | Character illustration generation (lab + runtime) |

### Prompt flow
1. Template unit defines modular blocks: `stylePrompt`, `compositionPrompt`, `characterPrompt`, `basePrompt`, `lightingPrompt`
2. `promptCompiler.ts` joins non-empty blocks with `\n\n` in fixed order
3. Placeholders `{{characterName}}`, `{{characterDescription}}`, `[customField]` are substituted
4. `generationInputAssembler.ts` assembles ordered reference candidates (style → character → template → unit)
5. `bookWorker.ts` uploads refs to Gemini File API, sends prompt + refs, stores output in R2

### Reference ordering contract
1. Style refs (by `sortOrder`)
2. Generated character refs  
3. Template refs (by `sortOrder`)
4. Template unit refs (by `sortOrder`)
5. Deduplicated by `storageKey`, capped at 14 (Gemini limit), overflow logged as warnings

### Text overlay system (COMPLETE)
All 7 tasks of the admin-page-text-overlay plan are done. Pages support one overlay text box via `layoutJson.textOverlay` with normalized coordinates, whitelisted fonts (Nunito, Playfair Display, Fraunces, Patrick Hand), font size 12–72, hex colors, left/center/right alignment. Rendered via shared `PageOverlayRenderer` component used by both admin preview and user book review.

### Admin workbench (COMPLETE)
All 11 tasks of the admin-gemini-style-template-workbench plan are done. Styles are required for Templates, multi-reference images are supported, Gemini File API is used as ephemeral per-job cache. Admin-facing terminology says Books/Pages; internal API/schema keeps Templates/Template Units.

### Docs to consult
- `docs/admin/09-generation-concepts.md` — authoritative reference on the generation pipeline, model selection, part ordering, temperature, safety filters, R2 storage.
- `docs/admin/06-character-lab.md` — character generation iteration workflow.
- `docs/admin/07-scene-lab.md` — scene generation iteration workflow.

## User Book Creation Flow

This is the primary customer flow. The app is still being built out — this is the target path, not all steps may be fully wired yet.

1. **Landing → Create Book** — user clicks "Create Book" CTA
2. **Upload Photo + Name Character** — user uploads a portrait photo of the child, enters the character's name and description
3. **Pick a Book** — user chooses from published templates (each with a Style already assigned)
4. **Character Reveal / Preview** — system generates the character illustration in the template's style using Gemini; user sees the illustrated character and confirms
5. **Payment** — Stripe checkout (price from admin settings `book_price_cents`)
6. **Generate All Pages** — queue worker generates every page/spread in the book using the character ref + style refs
7. **Review Book** — user previews each page with text overlays rendered over generated images; can approve or regenerate individual pages
8. **Enter Shipping Address + Order** — Lulu print API integration for physical book fulfillment

### Key routes in the user flow
| Route | Step |
|-------|------|
| `/create` | Upload photo, name character (steps 1-2) |
| `/create` (next screen) | Pick a book template (step 3) |
| `/create` (next screen) | Character preview/reveal (step 4) |
| `/checkout/[bookId]` | Payment (step 5) |
| `/draft/[id]` | Generation progress / review (steps 6-7) |
| `/books/[id]/print` | Shipping + order (step 8) |

### Character generation endpoints used by the flow
- `POST /v1/characters` — create a saved character (name + description)
- `POST /v1/characters/:id/photo` — upload reference photo
- `GET /v1/characters` — list user's saved characters with their illustrations (includes `illustrationUrl` from R2)
- `POST /v1/projects` — create a book project from a template
- `POST /v1/projects/:id/generate` — trigger generation for all pending units

See `references/admin-book-creation.md` for the full pipeline: create Style → create Template → add Units (pages) → publish. Also covers testing image generation via fixtures and test-generate.

## Reference Files

- `references/admin-book-creation.md` — Step-by-step admin book creation via API, with endpoint schemas, example payloads, and image generation testing (fixture → test-generate).
- `references/generation-pipeline.md` — Dense architectural reference: key file paths, data flow, prompt assembly order, reference candidate resolution, and Gemini File API caching pattern.
