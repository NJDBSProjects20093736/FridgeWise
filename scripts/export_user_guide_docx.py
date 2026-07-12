"""Export FridgeWise web app user guide to Word (.docx)."""

from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "deploy" / "FridgeWise_Web_App_User_Guide.docx"
OUTPUT_V3 = ROOT / "deploy" / "FridgeWise_Web_App_User_Guide_v3.docx"
MARKDOWN = ROOT / "deploy" / "FridgeWise_Web_App_User_Guide.md"


def set_styles(doc: Document) -> None:
    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(11)
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Calibri")
    for level in range(1, 4):
        h = doc.styles[f"Heading {level}"]
        h.font.name = "Calibri"
        h.font.color.rgb = RGBColor(0x2E, 0x7D, 0x32)


def add_bullets(doc: Document, items: list[str]) -> None:
    for item in items:
        doc.add_paragraph(item, style="List Bullet")


def add_numbered(doc: Document, items: list[str]) -> None:
    for item in items:
        doc.add_paragraph(item, style="List Number")


def add_table(doc: Document, headers: list[str], rows: list[list[str]]) -> None:
    width = max(len(r) for r in rows) if rows else len(headers)
    rows = [r + [""] * (width - len(r)) for r in rows]
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = "Table Grid"
    for i, h in enumerate(headers):
        cell = table.rows[0].cells[i]
        cell.text = h
        for p in cell.paragraphs:
            for run in p.runs:
                run.bold = True
    for r_idx, row in enumerate(rows):
        for c_idx, val in enumerate(row):
            table.rows[r_idx + 1].cells[c_idx].text = val


def code_block(doc: Document, text: str) -> None:
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.font.name = "Consolas"
    run.font.size = Pt(10)


def build() -> None:
    doc = Document()
    set_styles(doc)
    section = doc.sections[0]
    for margin in (section.top_margin, section.bottom_margin, section.left_margin, section.right_margin):
        pass
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)

    title = doc.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = title.add_run("FridgeWise AI — Web App User Guide")
    r.bold = True
    r.font.size = Pt(20)
    sub = doc.add_paragraph()
    sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    sub.add_run("Product prototype — Flutter web + FastAPI (v3 — polished UI)").italic = True
    doc.add_paragraph()
    doc.add_paragraph(
        "FridgeWise AI is a smart fridge and recipe assistant that helps reduce food waste by "
        "tracking ingredients, expiry dates, dietary requirements, and delivering personalised "
        "AI recipe recommendations."
    )

    doc.add_heading("1. Start the servers", level=1)
    doc.add_heading("Terminal 1 — API backend", level=2)
    code_block(
        doc,
        'cd "D:\\DBS - Sem 2\\RC\\Fridge-Wise"\n'
        "python scripts/run_api.py",
    )
    doc.add_paragraph("Wait for: Uvicorn running on http://0.0.0.0:8000")
    doc.add_paragraph("Health check: http://localhost:8000/health")

    doc.add_heading("Terminal 2 — Web app", level=2)
    code_block(
        doc,
        'cd "D:\\DBS - Sem 2\\RC\\Fridge-Wise\\app"\n'
        "flutter pub get\n"
        "flutter run -d web-server --web-port=8080 --web-hostname=127.0.0.1 "
        "--dart-define=API_BASE_URL=http://localhost:8000",
    )
    add_table(
        doc,
        ["Service", "URL"],
        [
            ["Web app", "http://127.0.0.1:8080"],
            ["API docs", "http://localhost:8000/docs"],
            ["API health", "http://localhost:8000/health"],
        ],
    )
    doc.add_paragraph(
        "Windows tip: use 127.0.0.1 instead of localhost for the web app on port 8080."
    )

    doc.add_heading("Docker (optional — Linux server)", level=2)
    doc.add_paragraph(
        "See docker/README.md or deploy/SERVER_DEPLOY.md for the full Docker stack (nginx + API + web)."
    )

    doc.add_heading("2. App shell & navigation", level=1)
    doc.add_paragraph(
        "Modern product layout: FridgeWise AI header, API status dot (green = connected, red = offline), "
        "Profile icon in top bar. Bottom nav on mobile; navigation rail + centred content on desktop."
    )
    add_table(
        doc,
        ["Tab / button", "Purpose"],
        [
            ["Recipes", "AI hybrid recommendations, hero card, mood chips, toggles"],
            ["Fridge", "Two-column desktop: list left, add form right; stats & filters"],
            ["Substitute", "Unfamiliar ingredient similarity (cold-start)"],
            ["Profile (top bar)", "Edit diet, allergies, cuisines anytime"],
        ],
    )

    doc.add_heading("3. First-time setup (Onboarding)", level=1)
    doc.add_paragraph(
        "Centred profile card (max ~720px) with logo and subtitle: "
        "“Personalise your recommendations before we search your fridge.”"
    )
    doc.add_paragraph("Sections A–E in cards:")
    add_bullets(
        doc,
        [
            "A. Dietary requirement: radio cards — none, vegetarian, vegan, halal (hard safety filter)",
            "B. Allergies: chips — milk, eggs, peanuts, gluten, soy, fish (hard safety filter)",
            "C. Nutrition preferences: low sugar, low fat, gluten free, high protein",
            "D. Cuisine preferences: Italian, Asian, Indian, Mexican, Mediterranean, Sri Lankan, Any",
            "E. Openness to new cuisines: slider 0.0–1.0",
        ],
    )
    doc.add_paragraph(
        "Button: “Save profile and continue” with loading state. Error banner if API fails. "
        "Profile saved via PUT /users/5060/profile and locally as fallback."
    )

    doc.add_heading("4. Fridge inventory", level=1)
    doc.add_paragraph(
        "Desktop: two-column layout — item list on left, Add ingredient form on right (always visible). "
        "Mobile: scrollable list with add form below."
    )
    doc.add_paragraph("Summary cards: Total items, Expiring soon, Barcode products. Filter chips: All, Expiring soon, Barcode items, Safe ingredients.")
    add_table(
        doc,
        ["Field", "Description"],
        [
            ["Ingredient name", "e.g. tomato, eggs, parsley"],
            ["Quantity / unit", "Optional, e.g. 2 pcs"],
            ["Days to expiry", "Slider 1–30 days"],
            ["Barcode", "Manual entry for web demo (e.g. 6111246721261)"],
        ],
    )
    doc.add_paragraph("Urgency colours on item cards:")
    add_bullets(
        doc,
        [
            "Red stripe: 0–2 days to expiry",
            "Amber stripe: 3–5 days",
            "Green stripe: 6+ days",
        ],
    )
    doc.add_paragraph("Barcode nutrition panel: product name, brand, Nutri-Score, metric tiles (calories, sugar, protein, fat, salt), allergen chips, “Add product to fridge”.")
    doc.add_paragraph("Edit (pencil) or delete (bin) with confirmation. Changes refresh AI recommendations.")

    doc.add_heading("5. AI Recommendations", level=1)
    doc.add_paragraph("Main demo screen with hero card, context badge (e.g. Winter · Comfort), model badge, mood chips, toggles, search card.")
    add_bullets(
        doc,
        [
            "Green banner: AI model (Hybrid / Content / Collaborative) and context badge (e.g. Winter · Sunday)",
            "Mood chips: Comfort, Healthy, Quick, Adventurous, Celebration — reloads ranking",
            "Use expiry priority: ON boosts recipes using items expiring soon",
            "Use context boost: ON applies season/weekday re-ranking",
            "Search bar: filter AI list or search full recipe catalogue",
            "Tune menu (top right): switch AI model",
        ],
    )
    doc.add_paragraph("Each recipe card shows:")
    add_bullets(
        doc,
        [
            "Circular match % badge and AI score",
            "Safe shield badge (passes diet/allergy filters)",
            "Tags: expiring (orange), high match, quick, nutrition, missing count",
            "Prep time and short reason line",
        ],
    )
    doc.add_paragraph(
        "If no safe recipes match your filters, you will see: “No safe recipes found — try relaxing filters or add fridge items.”"
    )

    doc.add_heading("6. Recipe detail", level=1)
    doc.add_paragraph("Tap any recipe card to open full detail:")
    add_numbered(
        doc,
        [
            "Recommendation summary (match %, AI score, prep time, nutrition)",
            "Full ingredients list",
            "Missing ingredients from your fridge",
            "Method / cooking steps (numbered)",
            "Why FridgeWise recommended this (explainable AI bullets)",
            "Allergy & dietary safety notes",
            "Nutrition notes",
            "Possible ingredient substitutions",
        ],
    )

    doc.add_paragraph("Desktop: two-column — summary/ingredients left, steps/why recommended right. Mobile: stacked.")

    doc.add_heading("7. Ingredient substitutes (Substitute tab)", level=1)
    doc.add_paragraph(
        "Title: Ingredient substitutes. Search card with quick chips (miso, tempeh, kimchi, etc.). "
        "Results show ingredient, explanation, confidence. API: GET /ingredients/{name}/similar."
    )

    doc.add_heading("8. Edit profile later", level=1)
    doc.add_paragraph(
        "Tap the Profile icon in the top app bar. Save changes — recommendations reload. Snackbar confirms save."
    )

    doc.add_heading("9. Product principles", level=1)
    add_table(
        doc,
        ["Type", "Examples", "Behaviour"],
        [
            ["Hard filters (safety)", "Allergies, vegetarian/vegan/halal", "Unsafe recipes excluded"],
            ["Soft signals (ranking)", "Expiry, nutrition, mood, cuisine, context", "Re-rank safe recipes"],
        ],
    )

    doc.add_heading("10. Full demo script (presentation)", level=1)
    add_numbered(
        doc,
        [
            "Open app — confirm green API dot in header",
            "Set profile: vegetarian, milk allergy, low sugar, Asian + Sri Lankan cuisines",
            "Fridge tab — two-column layout, stat cards, add form on right",
            "Barcode 6111246721261 → add product to fridge",
            "View AI recommendations — hero card, match % rings, Safe badge",
            "Toggle expiry OFF — show ranking change",
            "Select Comfort then Healthy mood — show reload",
            "Open recipe — show ingredients, steps, why recommended",
            "Substitute tab — search miso",
            "Profile icon in top bar — edit and save",
        ],
    )

    doc.add_heading("11. Demo checklist", level=1)
    for item in [
        "API health OK — green dot in header",
        "Onboarding centred card with sections A–E",
        "Fridge two-column: add form on right (desktop)",
        "Fridge shows urgency colours",
        "Barcode lookup returns nutrition panel",
        "AI recommendations: hero card, match % rings",
        "Recipe detail: green why-recommended card",
        "Mood / expiry toggles change results",
        "Substitute search works for miso",
        "Profile editable via top bar icon",
    ]:
        p = doc.add_paragraph()
        p.add_run("☐ ").font.name = "Segoe UI Symbol"
        p.add_run(item)

    doc.add_heading("12. Troubleshooting", level=1)
    add_table(
        doc,
        ["Problem", "Fix"],
        [
            ["API not reachable", "Run python scripts/run_api.py; click Retry"],
            ["localhost:8080 fails", "Use http://127.0.0.1:8080 instead"],
            ["No cooking steps", "Restart API after code updates; hard refresh browser"],
            ["Empty recommendations", "Wait 30s for models to load; add fridge items"],
            ["No safe recipes", "Relax nutrition filters or add more ingredients"],
            ["Port in use", "Stop old processes on 8000/8080 and restart"],
            ["Old UI after update", "Hard refresh (Ctrl+Shift+R) or restart Flutter web server"],
            ["Add form not visible", "Desktop: form is on the right; mobile: scroll down"],
        ],
    )

    doc.add_heading("13. Known limitations", level=1)
    add_bullets(
        doc,
        [
            "Demo user ID 5060 only — no login yet",
            "Web barcode = manual entry (no camera)",
            "Fridge may reset on API restart (in-memory store)",
            "Profile also cached locally via SharedPreferences",
        ],
    )

    doc.add_heading("14. Screenshots for report (Appendix E)", level=1)
    add_numbered(
        doc,
        [
            "Onboarding — centred profile card, sections A–E",
            "App shell — header with API green dot, nav rail",
            "AI recommendations — hero card, mood chips, match % rings",
            "Recipe detail — green why-recommended card, numbered steps",
            "Fridge — two-column layout, add form right, urgency stripes",
            "Barcode panel — nutrition metric tiles, allergen chips",
            "Substitute — miso quick chip and result card",
        ],
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    saved: list[Path] = []
    for path in (OUTPUT_V3, OUTPUT, ROOT / "deploy" / "FridgeWise_Web_App_User_Guide_v2.docx"):
        try:
            doc.save(path)
            saved.append(path)
            print(f"Saved: {path}")
        except PermissionError:
            print(f"Skipped (file open?): {path}")
    if not saved:
        raise PermissionError("Could not save user guide — close open Word files and retry.")


if __name__ == "__main__":
    build()
