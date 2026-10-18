# PiCODE

**A local-first PDF reading companion that turns how you read into grounded study notes — powered by Gemma 4 running on your own machine.**

You read a PDF. With your permission, PiCODE notices a few explicit reading signals — text you select (most important), passages you scroll back up to re-read, pages you return to, time on each page; mouse movement is not tracked — and sends a compact, size-limited summary of them, together with relevant PDF excerpts, to a **local Gemma 4** model. The model returns structured notes; PiCODE checks every page reference and quote against the real PDF text before showing anything.

Built for Hacktoberfest Elazığ 2026. This project is not affiliated with or endorsed by Hacktoberfest or its organizers.

> **Renamed from FocusNote.** Existing local data (notes, sessions, consent, saved theme) is moved to the new `picode` storage automatically on first start, and the old `FOCUSNOTE_*` environment variables and `backend/focusnote.config.json` are still read as fallbacks.

> 📸 _Screenshot placeholder:_ `docs/screenshot-desktop.png` (reader + AI notes panel) and `docs/screenshot-session.png` (Session tab). Contributions welcome — see [good first issues](CONTRIBUTING.md#good-first-issues).

---

## What it does

| | |
|---|---|
| **PDF reader** | PDF.js rendering, continuous pages with lazy rendering, page navigation (buttons, page box, ← →), zoom, text selection, full-text search, light/dark theme, drag-and-drop. |
| **Reading signals** | Consent-gated, pausable tracker with **no mouse-movement tracking at all**. **`CRITICAL_IMPORTANCE`:** text you select (click + drag) — the only mouse interaction used — sent with its whole paragraph. **`HIGH_RELEVANCE`:** re-reading — scrolling down a page, then back up over the same lines and staying there ≥ 1 s. Weaker: returns to a page, reading time. **Ignored as noise:** anything under 1 second, fast scrolling, and time after 3 minutes without scrolling or selecting. |
| **One study note** | One card in the document's language: **highlight bullets first** (🔴 what you selected → 🔵 what you re-read → key points), then a **collapsible "Summary" accordion** (smooth open/close): a 2–3 sentence overview, then one **H4 sub-heading per read page** with short paragraphs (≤ 2 sentences) and key-point bullets. Pages with a selection or re-read get the most detail; lightly read pages a sentence; unread pages are left out. Sources & reading notes and self-test questions are further accordions, closed by default. |
| **Interface** | Soft warm-neutral palette (no pure white/black, AA contrast), a clearly separated notes panel, the **PiCODE** wordmark at top right, and the model status as a dot on the sidebar's **Model** button. Light and dark themes. |
| **Grounding** | Model output is validated against a JSON schema, quotes are matched against the extracted PDF text, wrong page numbers are corrected or dropped, fabricated quotes are removed, and behavioural notes that cite a signal that never happened are rejected. |
| **Your notes** | Save / edit / delete notes; AI-generated, AI-edited-by-you and your own notes are labeled differently. Export as Markdown or JSON, or copy. |
| **Privacy** | Everything stays in your browser (IndexedDB) and on your machine. Visible tracking indicator, pause, clear session, delete per-document or all data, and a preview of exactly what will be sent to the model. |
| **Demo mode** | Works without any model: a clearly labeled, simulated analysis and example events for the bundled sample PDF. |

## Quick start

Requirements: **Python 3.10+** and, for real AI analysis, **[Ollama](https://ollama.com)** with a Gemma 4 model. No Node.js, no build step, no cloud account.

**Windows — one click:** double-click **`RUN.bat`**. It checks for and, if needed, installs everything (Python 3.12 and Ollama via `winget`, the `.venv` with the Python packages, the `gemma4:12b` model, about 8 GB), starts the Ollama server and PiCODE, and opens http://127.0.0.1:8000. If the model can't be installed, the site still opens and demo mode works. If PiCODE is already running it just opens the browser; if port 8000 is taken by another program it picks the next free port; when double-clicked, the window always stays open with a message instead of closing silently. The file is ASCII-only on purpose (no codepage issues) — don't re-save it as "UTF-8 with BOM". Options: `RUN.bat --no-start` (setup only); set `PICODE_MODEL`, `PICODE_PORT` or `PICODE_NO_BROWSER=1` before running.

**Windows (PowerShell, manual)**

```powershell
py -m venv .venv
.\.venv\Scripts\python -m pip install -r backend\requirements.txt
.\.venv\Scripts\python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000
```

**macOS / Linux**

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r backend/requirements.txt
.venv/bin/python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000
```

Open **http://127.0.0.1:8000** and click **Try the sample document**.

### Set up Gemma 4 (local)

PiCODE was developed and verified against **Ollama 0.40.5** with the model tag **`gemma4:12b`** (Ollama reports family `gemma4`, 11.9B parameters, GGUF `Q4_K_M`, ~8 GB on disk).

```bash
ollama pull gemma4:12b
ollama serve          # skip if the Ollama app is already running
ollama list           # confirm the tag you have
```

Then in PiCODE open **Model** (left sidebar; the small dot on it shows the live connection status — green ready, amber not Gemma 4 / unverified, red offline) → keep `http://127.0.0.1:11434` and `gemma4:12b` → **Test connection**. The dialog shows whether the runtime is reachable, whether the model is installed, and whether its family is really Gemma 4 (read from Ollama's model metadata — never assumed).

If you use a different Gemma 4 tag, enter exactly what `ollama list` shows. PiCODE does not invent model identifiers; if the configured model is not Gemma 4, every result is labeled with the model's real name.

**Hardware.** Needs are set by the model, not PiCODE. On the development laptop (7.7 GB RAM, RTX 5050 4 GB) `gemma4:12b` took ~80 s to load the first time, then generated ~11 tokens/s; a full session analysis took **~90 s**. The UI streams progress and allows cancelling. If your machine struggles, try a smaller Gemma 4 variant if your runtime offers one, or use demo mode.

**Other runtimes.** Any OpenAI-compatible local server (llama.cpp `llama-server`, LM Studio, vLLM) works: choose *OpenAI-compatible server* in the Model dialog and enter its base URL (without `/v1`) and model id. These APIs expose no model-family metadata, so PiCODE can only check the model *name* and labels the result accordingly.

### Configuration

Environment variables (read at startup; the pre-rename `FOCUSNOTE_*` names are accepted as fallbacks) — values saved from the Model dialog go to `backend/picode.config.json` (git-ignored) and take precedence:

| Variable | Default | Purpose |
|---|---|---|
| `PICODE_RUNTIME` | `ollama` | `ollama` or `openai` (OpenAI-compatible) |
| `PICODE_MODEL_BASE_URL` | `http://127.0.0.1:11434` | Model runtime URL |
| `PICODE_MODEL` | `gemma4:12b` | Model identifier |
| `PICODE_TIMEOUT` | `300` | Max seconds to wait between streamed chunks |
| `PICODE_NUM_CTX` | `8192` | Ollama context window (keep fixed: changing it reloads the model) |
| `PICODE_API_KEY` | _(empty)_ | Bearer token for a runtime that needs one. Stays in the backend; never sent to the browser. |

## The demo flow

1. **Open** the sample (or your own PDF) and **allow reading signals** in the consent dialog.
2. Read a few pages, **select** a passage, go **back** to an earlier page.
3. Open the **Session** tab: selected passages (critical), re-read passages (high), time per page, revisits, what was ignored as noise, and the raw coarse events — exactly what was recorded.
4. Click **Create study note**. Gemma 4 streams one continuous note with provenance (`Gemma 4 · gemma4:12b`), a "N/M quotes verified" badge, and a depth label per section (*Ayrıntılı / Standart / Kısa*, with the time you spent there).
5. Click a page badge or quote → the reader jumps to the page and highlights the supporting passage.
6. **Save note** stores the whole note as one editable Markdown note; **Copy** or **export** Markdown/JSON from the **Saved** tab.

No model? Click **Demo** in the sidebar: same flow with a pre-written, clearly labeled *Simulated* analysis.

## Privacy

- **PDFs never leave your computer.** They're read from disk into the browser; the PDF file itself is not stored.
- **Tracking needs consent** (asked on first use), shows a permanent indicator in the toolbar, and can be paused, resumed or withdrawn at any time.
- **Only inside the viewer, and only three things:** text selection inside the PDF (`selectionchange`), the viewer's scroll position (speed and direction), and page changes / tab visibility. **No** `pointermove`, `mousemove`, hover, wheel or position listeners exist (a browser test asserts this). **Never:** mouse movement, keystrokes, clipboard, screen, other tabs or apps.
- **Stored locally** in IndexedDB (`picode`): aggregated session data, notes, the latest analysis, settings.
- **Sent only when you click Create study note/Regenerate**, and only to the backend on `127.0.0.1`, which forwards to the configured model endpoint. Payload: ≤ 8 excerpts (≤ 12,000 chars), selected passages with their paragraphs, re-read passages, per-page statistics, and saved notes only if you tick the box. Use *Preview what will be sent* to see the exact JSON.
- **Remote endpoints** are possible but deliberate: the UI warns when configuring one and asks for confirmation before every analysis; the backend refuses to send without that confirmation.
- **No analytics, no third parties, no CDN.** All assets are served locally; a Content-Security-Policy restricts the page to its own origin.
- **Interpretation limits.** A revisit or a pause is a weak signal, not a statement about your understanding. Prompts forbid psychological claims, notes carry `low`/`medium` evidence labels, and wording like "you were confused" is flagged.

## Architecture

```
Browser (vanilla JS, ES modules)                         Python backend (FastAPI)          Local runtime
┌──────────────────────────────────────────────┐      ┌──────────────────────────┐      ┌──────────────┐
│ pdf-reader.js      PDF.js render/text/search │      │ app.py                   │      │ Ollama       │
│ reading-tracker.js consent-gated signals ──┐ │      │  serves the frontend     │      │  gemma4:12b  │
│ event-aggregator.js aggregates (pure)  ◄───┘ │      │  /api/status  /api/config│      │ (or OpenAI-  │
│ context-builder.js ranked, size-capped ctx ──┼─────►│  /api/analyze (NDJSON) ──┼─────►│  compatible) │
│ model-client.js    same-origin fetch only    │◄─────┼─ validate · repair once  │◄─────┤              │
│ schema-validator.js schema + grounding check │      │ prompts.py  model_adapter│      └──────────────┘
│ notes-panel.js / session-panel.js  UI        │      └──────────────────────────┘
│ local-storage.js   IndexedDB                 │      schema/analysis.schema.json — shared by both sides
└──────────────────────────────────────────────┘
```

**Why a backend?** PDF.js ES modules need to be served over HTTP; the model endpoint and any API key stay out of the browser; the backend enforces context limits and the remote-consent rule, and blocks cross-site requests to the local API (Host/Origin checks against DNS rebinding and CSRF). It's a few hundred lines with three dependencies (`fastapi`, `uvicorn`, `httpx`). The frontend never talks to the model directly, so the vendor API can change without touching the UI (`backend/model_adapter.py`).

### Analysis pipeline

1. PDF text is extracted locally (PDF.js), visible pages first rendering-wise, text in the background.
2. **Telemetry** (`reading-tracker.js` → `event-aggregator.js`):
   - **Selection → `CRITICAL_IMPORTANCE`.** On `selectionchange` inside a page's text layer, the selected text is stored with its page and the whole paragraph around it (paragraphs are found from the text lines' vertical gaps).
   - **Re-read → `HIGH_RELEVANCE`.** Scrolling down, then back up by ≥ 50 px (and ≥ 4 % of a page, ≤ 1.5 screens) and staying ≥ 1 s records the lines that passed the reading line (35 % of the viewport) again. Going straight back down within 1 s is discarded. App-driven jumps (page buttons, search, zoom) are ignored.
   - **Noise filter.** Reading time is the *real elapsed time* (sampled every 0.5 s). A stay under 1 s on a page is never written to state (only a counter of ignored passes is kept). Seconds of fast scrolling (> 1 screen per second) and time after 3 minutes without any scrolling or selecting are not counted.
3. `context-builder.js` gives each page an **attention score**: 120 per selection + 60 per re-read + 20 per return + 1 per second. Any selection or re-read makes a page `deep`; otherwise `deep` = ≥ 55 % of the maximum and ≥ 45, `brief` < 15, `standard` in between. **When reading data exists, pages read for less than 1 s are left out** and listed under the note; with tracking off the whole document is covered evenly. The prompt lists `criticalPassages` (selection + paragraph) first, then `highRelevancePassages`, then the excerpts (centred on those passages), then weaker observations. Deep pages get up to 2,400 characters, standard 1,300, brief 500 — max 8 excerpts, 12,000 characters in total.
4. The backend renders a compact prompt, calls the model with the task's JSON schema as structured output, streams progress, validates, and makes **one** repair request if the JSON is invalid. **Depth guarantee:** if a section on a page marked `deep` (selected / re-read / most read) comes back under 90 words, it makes **one** follow-up request that rewrites only those sections as 3–4 short paragraphs (120–180 words) from the same excerpts; if that fails, the original note is kept. (The UI still shows every paragraph short — long ones are split at sentence boundaries.)
5. The browser validates again, grounds quotes/pages against the PDF text, drops unsupported items (reported in the UI), and renders.

### Event record (stored, coarse)

```json
{ "pageNumber": 3, "eventType": "text_selection", "timestamp": "2026-10-17T12:00:00.000Z",
  "selectedText": "Example passage", "selectionCount": 2, "importance": "CRITICAL_IMPORTANCE" }
```

`eventType` ∈ `page_visit` (`dwellTimeSeconds` ≥ 1, `revisitCount`), `page_revisit` (`revisitCount`, `secondsSinceLastVisit`), `text_selection` (`selectedText`, `selectionCount`, `importance: CRITICAL_IMPORTANCE`), `text_reread` (`revisitCount`, `relevance: HIGH_RELEVANCE`, `region: {band, yStart, yEnd}` normalized to page height). Validated by `validateEvent()` in `js/event-aggregator.js`.

### Model output

Defined once in [`schema/analysis.schema.json`](schema/analysis.schema.json) (version 3) as a single object:

```
studyNote {
  title,
  highlights[ { text, page, importance: CRITICAL_IMPORTANCE|HIGH_RELEVANCE|KEY_POINT, evidence } ],
  overview,
  sections[ { heading, page, depth: deep|standard|brief, content, keyPoints[], evidence,
              readerNote, signal: none|selection|reread|revisit|dwell } ],   // page order
  reviewLater[ { page, reason, signal } ],
  questions[ { question, answer, page, evidence } ]
}
```

Grounding rules applied in the browser: sections on non-existent pages are dropped; a quote found on another page corrects the page; quotes not found are marked *unverified*; a `readerNote` is removed unless its signal was actually recorded on that page; depth is replaced by the measured depth. A highlight keeps `CRITICAL_IMPORTANCE` only if a selection was recorded on its page and `HIGH_RELEVANCE` only if a re-read was; otherwise it is downgraded. Any selection the model left out is added as a `CRITICAL_IMPORTANCE` bullet, so selections always appear at the top. The note's fixed headings follow the document's language, detected from its text.

## Project layout

```
index.html                 app shell (semantic HTML, dialogs)
styles/main.css            all styles (light/dark, responsive)
js/                        ES modules — see Architecture
schema/                    shared output schema
backend/                   FastAPI app, prompts, model adapters, tests
samples/                   sample PDF + the script that generates it
tests/                     browser test page (open /tests/)
vendor/pdfjs/              PDF.js 4.10.38 (Apache-2.0), served locally
```

## Testing

```powershell
# Backend: prompt/schema validation, repair-once logic, limits, remote consent, origin checks (no model needed)
.\.venv\Scripts\python -m unittest discover -s backend/tests -t .
```

Browser tests (aggregation, page references, excerpt limits, response validation and grounding, IndexedDB storage, export): start the server and open **http://127.0.0.1:8000/tests/**. All 21 should pass.

Manual acceptance checks used during development: sample render + navigation, selection → correct page, revisit counting, consent/pause/resume/clear, real `gemma4:12b` analysis (validated, all quotes verified), click-to-source highlighting, note persistence after reload, Markdown/JSON export, corrupted and empty PDFs, model offline / wrong model id, demo mode, mobile drawer layout, and that the page makes no requests outside its own origin.

## Known limitations

- **Scanned PDFs** without a text layer can be read but not searched or analyzed (no OCR).
- **Reading time is approximate**: since the mouse is not tracked, PiCODE can't tell whether you are still at the screen; it stops counting after 3 minutes without scrolling or selecting. Background tabs pause counting.
- **Re-reading** is inferred from scrolling only: scrolling back up by keyboard or scroll bar counts too, and a re-read is located by a fixed "reading line" at 35 % of the viewport, which is an approximation of where you are looking.
- **Paragraph expansion** for selections relies on line spacing in the PDF; unusual layouts (multi-column pages, tables) can produce a paragraph that is too short or too long — the selected text itself is always kept.
- **Highlighting** marks whole text-layer spans, so highlights can be a bit wider than the exact quote.
- **Large PDFs**: text extraction is capped at 2,000 pages; analysis context is always capped, so very long documents are summarized from samples.
- **Speed** depends entirely on your hardware and model size; CPU-only inference of a 12B model can take several minutes.
- **One analysis is kept per document** (the latest); earlier runs are overwritten.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, conventions and a list of good first issues.

## Credits & licenses

- [PDF.js](https://mozilla.github.io/pdf.js/) 4.10.38 — Apache License 2.0 (`vendor/pdfjs/LICENSE`).
- Sample document *Kalıcı Öğrenme* (Turkish) — written for this project, CC0.
- Gemma is a family of open models by Google; use of Gemma models is subject to their license terms.
- No license has been chosen for PiCODE's own code yet — the repository owner should add a `LICENSE` file before accepting contributions.
