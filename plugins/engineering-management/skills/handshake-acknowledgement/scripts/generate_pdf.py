"""
Somnio HandShake - Step 3 Acknowledgement PDF Generator

Fonts used:
  - Content: Nunito 11pt (fallback: Liberation Sans if Nunito not installed)
  - Footer:  Plus Jakarta Sans 9pt (fallback: Liberation Sans)

To install proper fonts, place TTF files in assets/fonts/:
  - Nunito-Regular.ttf, Nunito-Bold.ttf, Nunito-Italic.ttf, Nunito-BoldItalic.ttf
  - PlusJakartaSans-Regular.ttf

Download from: https://fonts.google.com/specimen/Nunito
               https://fonts.google.com/specimen/Plus+Jakarta+Sans

Content JSON structure:
{
  "nivel_actual": "Senior Medium",
  "siguiente_nivel": "Senior Advance",
  "primera_instancia": true,
  "rendimiento_actual": [
    "Bullet point 1",
    {"text": "Bullet with sub-items", "sub": ["Sub item 1", "Sub item 2"]}
  ],
  "comparacion_anterior": [
    {"objetivo": "Description of previous objective", "status": "Logrado"},
    {"objetivo": "Another objective", "status": "Logrado, pero hay que seguir trabajando"}
  ],
  "oportunidad_mejora": ["Improvement area 1"],
  "continuar_trabajando": {
    "Conocimientos Técnicos": ["Item 1"]
  },
  "comentarios_dev": ["Optional comment"]
}
"""

import argparse
import json
import os
import sys
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm, cm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# ─── PATHS ─────────────────────────────────────────────────────────────────────
SKILL_DIR  = Path(__file__).parent.parent
LOGO_PATH  = SKILL_DIR / "assets" / "somnio_logo.png"
BG_PATH    = SKILL_DIR / "assets" / "somnio_bg.jpg"
FONTS_DIR  = SKILL_DIR / "assets" / "fonts"

# ─── FONT REGISTRATION ─────────────────────────────────────────────────────────
def register_fonts():
    """Register Nunito + Plus Jakarta Sans if available, else fall back to Liberation Sans."""
    nunito_map = {
        "Nunito":           "Nunito-Regular.ttf",
        "Nunito-Bold":      "Nunito-Bold.ttf",
        "Nunito-Italic":    "Nunito-Italic.ttf",
        "Nunito-BoldItalic":"Nunito-BoldItalic.ttf",
    }
    jakarta_map = {
        "PlusJakarta":      "PlusJakartaSans-Regular.ttf",
    }
    liberation = {
        "Nunito":            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "Nunito-Bold":       "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "Nunito-Italic":     "/usr/share/fonts/truetype/liberation/LiberationSans-Italic.ttf",
        "Nunito-BoldItalic": "/usr/share/fonts/truetype/liberation/LiberationSans-BoldItalic.ttf",
        "PlusJakarta":       "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    }

    for alias, fname in {**nunito_map, **jakarta_map}.items():
        path = FONTS_DIR / fname
        if path.exists():
            pdfmetrics.registerFont(TTFont(alias, str(path)))
            print(f"  ✓ Loaded font: {alias} from {fname}")
        else:
            fallback = liberation.get(alias)
            if fallback and Path(fallback).exists():
                pdfmetrics.registerFont(TTFont(alias, fallback))
                print(f"  ~ Fallback font: {alias} → Liberation Sans")
            else:
                print(f"  ✗ Font missing: {alias}")

    # Register font family for automatic bold/italic switching
    from reportlab.pdfbase.pdfmetrics import registerFontFamily
    registerFontFamily(
        "Nunito",
        normal="Nunito",
        bold="Nunito-Bold",
        italic="Nunito-Italic",
        boldItalic="Nunito-BoldItalic",
    )

# ─── BRAND COLORS ──────────────────────────────────────────────────────────────
SOMNIO_DARK_BLUE = colors.HexColor("#1a1a6e")
TEXT_DARK        = colors.HexColor("#1a1a1a")
TABLE_BORDER     = colors.HexColor("#d0d0d0")
SEP_COLOR        = colors.HexColor("#cccccc")

PAGE_W, PAGE_H = A4
MARGIN_LEFT   = 2.0 * cm
MARGIN_RIGHT  = 2.0 * cm
MARGIN_TOP    = 3.2 * cm
MARGIN_BOTTOM = 2.2 * cm
FOOTER_H      = 1.5 * cm

# ─── PAGE CANVAS (bg + logo + footer) ─────────────────────────────────────────
def make_on_page():
    def on_page(cnv, doc):
        cnv.saveState()
        w, h = A4

        # Background
        if BG_PATH.exists():
            cnv.drawImage(str(BG_PATH), 0, 0, width=w, height=h,
                          preserveAspectRatio=False, mask="auto")

        # Logo top-right header
        if LOGO_PATH.exists():
            logo_w = 4.8 * cm
            logo_h = 2.0 * cm
            logo_y = h - 0.4 * cm - logo_h
            cnv.drawImage(str(LOGO_PATH),
                          w - MARGIN_RIGHT - logo_w, logo_y,
                          width=logo_w, height=logo_h,
                          preserveAspectRatio=True, mask="auto")

        # Separator under header
        sep_y = h - MARGIN_TOP + 0.3 * cm
        cnv.setStrokeColor(SEP_COLOR)
        cnv.setLineWidth(0.5)
        cnv.line(MARGIN_LEFT, sep_y, w - MARGIN_RIGHT, sep_y)

        # Footer text — transparent bg, white text over background's blue bar
        cnv.setFillColor(colors.white)
        cnv.setFont("PlusJakarta", 9)
        cnv.drawCentredString(w / 2, 6 * mm, "Confidential document · hello@somniosoftware.com")

        cnv.restoreState()
    return on_page

# ─── STYLES ───────────────────────────────────────────────────────────────────
CONTENT_FONT      = "Nunito"
CONTENT_FONT_B    = "Nunito-Bold"
CONTENT_FONT_I    = "Nunito-Italic"
CONTENT_FONT_BI   = "Nunito-BoldItalic"
CONTENT_SIZE      = 11
FOOTER_FONT       = "PlusJakarta"
FOOTER_SIZE       = 9

def get_styles():
    base = dict(fontName=CONTENT_FONT, fontSize=CONTENT_SIZE,
                textColor=TEXT_DARK, leading=16)
    return {
        "title": ParagraphStyle("title",
            fontName=CONTENT_FONT_B, fontSize=20,
            textColor=TEXT_DARK, alignment=TA_CENTER,
            spaceAfter=10),
        "subtitle": ParagraphStyle("subtitle",
            fontName=CONTENT_FONT_B, fontSize=13,
            textColor=TEXT_DARK, alignment=TA_CENTER,
            spaceBefore=6, spaceAfter=28),
        "section_h2": ParagraphStyle("section_h2",
            fontName=CONTENT_FONT_B, fontSize=CONTENT_SIZE,
            textColor=TEXT_DARK, spaceBefore=14, spaceAfter=5),
        "section_h3": ParagraphStyle("section_h3",
            fontName=CONTENT_FONT_B, fontSize=CONTENT_SIZE,
            textColor=TEXT_DARK, spaceBefore=10, spaceAfter=4,
            leftIndent=10),
        "underline_label": ParagraphStyle("underline_label",
            fontName=CONTENT_FONT, fontSize=CONTENT_SIZE,
            textColor=TEXT_DARK, leading=16,
            spaceBefore=6, spaceAfter=3),
        "normal": ParagraphStyle("normal", **base),
        "bullet": ParagraphStyle("bullet",
            fontName=CONTENT_FONT, fontSize=CONTENT_SIZE,
            textColor=TEXT_DARK, leading=16,
            leftIndent=16, bulletIndent=4, spaceAfter=2),
        "sub_bullet": ParagraphStyle("sub_bullet",
            fontName=CONTENT_FONT, fontSize=CONTENT_SIZE,
            textColor=TEXT_DARK, leading=15,
            leftIndent=32, bulletIndent=20, spaceAfter=2),
        "status_logrado": ParagraphStyle("status_logrado",
            fontName=CONTENT_FONT_I, fontSize=CONTENT_SIZE - 1,
            textColor=colors.HexColor("#2a7a2a"),
            leftIndent=32, bulletIndent=20, spaceAfter=2),
        "status_progreso": ParagraphStyle("status_progreso",
            fontName=CONTENT_FONT_I, fontSize=CONTENT_SIZE - 1,
            textColor=colors.HexColor("#b05a00"),
            leftIndent=32, bulletIndent=20, spaceAfter=2),
        "table_cell": ParagraphStyle("table_cell",
            fontName=CONTENT_FONT_I, fontSize=CONTENT_SIZE,
            textColor=TEXT_DARK),
    }

def bull(text, S, level=0, bullet="●"):
    style = S["bullet"] if level == 0 else S["sub_bullet"]
    return Paragraph(f"{bullet}&nbsp;&nbsp;{text}", style)

def subbull(text, S):
    return bull(text, S, level=1, bullet="○")

# ─── STORY BUILDER ────────────────────────────────────────────────────────────
def build_story(data, meta, S):
    story = []

    # Title
    story.append(Spacer(1, 0.4 * cm))
    story.append(Paragraph("HandShake", S["title"]))
    story.append(Paragraph("Step 3 - Acknowledgement", S["subtitle"]))

    # Info table
    col_w = [(PAGE_W - MARGIN_LEFT - MARGIN_RIGHT) * f for f in (0.28, 0.72)]
    rows = [
        ("Somnier",          meta["somnier"]),
        ("Líder",            meta["lider"]),
        ("Fecha",            meta["fecha"]),
        ("Rol del Somnier",  meta["rol"]),
    ]
    tbl_data = [
        [Paragraph(f"<i>{r}</i>", S["table_cell"]),
         Paragraph(f"<i>{v}</i>", S["table_cell"])]
        for r, v in rows
    ]
    tbl = Table(tbl_data, colWidths=col_w)
    tbl.setStyle(TableStyle([
        ("BOX",        (0,0),(-1,-1), 0.5, TABLE_BORDER),
        ("INNERGRID",  (0,0),(-1,-1), 0.5, TABLE_BORDER),
        ("BACKGROUND", (0,0),(-1,-1), colors.white),
        ("TOPPADDING",    (0,0),(-1,-1), 7),
        ("BOTTOMPADDING", (0,0),(-1,-1), 7),
        ("LEFTPADDING",   (0,0),(-1,-1), 10),
        ("RIGHTPADDING",  (0,0),(-1,-1), 10),
        ("VALIGN",     (0,0),(-1,-1), "MIDDLE"),
    ]))
    story.append(tbl)
    story.append(Spacer(1, 0.55 * cm))

    # Puntos abordados
    story.append(Paragraph("<b>Puntos abordados:</b>", S["section_h2"]))
    puntos = [
        "Primer instancia de evaluación del año"
            if data.get("primera_instancia", True)
            else "Segunda instancia de evaluación del año",
        "Evolución en último tiempo con feedback Cliente/AM/TL.",
        "Evaluación self assessment",
        "Comparar feedback con instancia anterior",
        "Siguientes pasos",
    ]
    for p in puntos:
        story.append(bull(p, S))
    story.append(Spacer(1, 0.45 * cm))

    # Resumen del encuentro
    story.append(Paragraph("<b>Resumen del encuentro:</b>", S["section_h2"]))

    story.append(Paragraph("<u>Seniority:</u>", S["underline_label"]))
    story.append(Paragraph(
        f'Nivel actual es <b>{data["nivel_actual"]}</b>.', S["normal"]))
    story.append(Spacer(1, 0.3 * cm))

    story.append(Paragraph("<u>Rendimiento actual:</u>", S["underline_label"]))
    for item in data.get("rendimiento_actual", []):
        if isinstance(item, str):
            story.append(bull(item, S))
        else:
            story.append(bull(item["text"], S))
            for sub in item.get("sub", []):
                story.append(subbull(sub, S))
    story.append(Spacer(1, 0.3 * cm))

    comparacion = data.get("comparacion_anterior", [])
    if comparacion:
        story.append(Paragraph("<u>Comparación reunión anterior:</u>", S["underline_label"]))
        for item in comparacion:
            story.append(bull(item["objetivo"], S))
            status = item.get("status", "")
            if status:
                is_ok = "Logrado" in status and "seguir" not in status.lower()
                st = S["status_logrado"] if is_ok else S["status_progreso"]
                story.append(subbull(status, S))  # use normal sub then override style
                story[-1] = Paragraph(f"○&nbsp;&nbsp;{status}", st)
        story.append(Spacer(1, 0.3 * cm))

    # Objetivos acordados
    story.append(Paragraph("<b>Objetivos acordados:</b>", S["section_h2"]))
    story.append(Paragraph(
        f'El siguiente nivel sería <b>{data["siguiente_nivel"]}</b>.', S["normal"]))
    story.append(Paragraph("Para esto se pide:", S["normal"]))
    story.append(Spacer(1, 0.2 * cm))

    oportunidades = data.get("oportunidad_mejora", [])
    if oportunidades:
        story.append(Paragraph("<b>Oportunidad de mejora:</b>", S["section_h3"]))
        for item in oportunidades:
            if isinstance(item, str):
                story.append(bull(item, S))
            else:
                story.append(bull(item["text"], S))
                for sub in item.get("sub", []):
                    story.append(subbull(sub, S))
        story.append(Spacer(1, 0.25 * cm))

    continuar = data.get("continuar_trabajando", {})
    if continuar:
        story.append(Paragraph("<b>Continuar trabajando en:</b>", S["section_h3"]))
        story.append(Spacer(1, 0.15 * cm))
        for category, items in continuar.items():
            story.append(Paragraph(f"<b>{category}</b>", S["section_h3"]))
            for item in items:
                if isinstance(item, str):
                    story.append(bull(item, S))
                else:
                    story.append(bull(item["text"], S))
                    for sub in item.get("sub", []):
                        story.append(subbull(sub, S))
        story.append(Spacer(1, 0.25 * cm))

    comentarios = data.get("comentarios_dev", [])
    if comentarios:
        story.append(Paragraph(
            "<b>Aclaración o comentarios generales de la persona <i>(opcional)</i>:</b>",
            S["section_h2"]))
        for c in comentarios:
            story.append(bull(c, S))

    return story

# ─── MAIN ─────────────────────────────────────────────────────────────────────
def generate(meta, data, output_path):
    register_fonts()
    S = get_styles()
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        leftMargin=MARGIN_LEFT,
        rightMargin=MARGIN_RIGHT,
        topMargin=MARGIN_TOP,
        bottomMargin=MARGIN_BOTTOM + FOOTER_H + 0.3 * cm,
    )
    story = build_story(data, meta, S)
    on_page = make_on_page()
    doc.build(story, onFirstPage=on_page, onLaterPages=on_page)
    print(f"✅ PDF generated: {output_path}")

MONTHS = ["Jan","Feb","Mar","Apr","May","Jun",
          "Jul","Aug","Sep","Oct","Nov","Dec"]

def validate_fecha(fecha: str) -> str:
    """
    Ensures date format matches 'Dec 19, 2025'.
    Accepts common variants and normalises them.
    Raises ValueError if unparseable.
    """
    import re
    from datetime import datetime

    fecha = fecha.strip()

    # Already correct format: "Dec 19, 2025"
    if re.match(r'^[A-Z][a-z]{2}\s+\d{1,2},\s+\d{4}$', fecha):
        # Normalise spacing and remove leading zero from day
        parts = re.split(r'[\s,]+', fecha)
        month, day, year = parts[0], str(int(parts[1])), parts[2]
        return f"{month} {day}, {year}"

    # Try to parse other common formats
    for fmt in ("%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%B %d, %Y",
                "%b %d, %Y", "%d %B %Y", "%d %b %Y"):
        try:
            dt = datetime.strptime(fecha, fmt)
            return f"{MONTHS[dt.month-1]} {dt.day}, {dt.year}"
        except ValueError:
            continue

    raise ValueError(
        f"Cannot parse date '{fecha}'. "
        f"Please use format: Dec 19, 2025"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--somnier", required=True)
    parser.add_argument("--lider",   required=True)
    parser.add_argument("--fecha",   required=True)
    parser.add_argument("--rol",     required=True)
    parser.add_argument("--output",  required=True)
    parser.add_argument("--content", required=True)
    args = parser.parse_args()

    # Validate and normalise required fields
    if not args.somnier.strip():
        raise ValueError("--somnier cannot be empty")
    if not args.lider.strip():
        raise ValueError("--lider cannot be empty")
    if not args.rol.strip():
        raise ValueError("--rol cannot be empty")

    fecha_normalised = validate_fecha(args.fecha)
    print(f"  Date: {args.fecha!r} → {fecha_normalised!r}")

    with open(args.content, "r", encoding="utf-8") as f:
        data = json.load(f)

    meta = dict(
        somnier=args.somnier.strip(),
        lider=args.lider.strip(),
        fecha=fecha_normalised,
        rol=args.rol.strip(),
    )
    generate(meta, data, args.output)

if __name__ == "__main__":
    main()
