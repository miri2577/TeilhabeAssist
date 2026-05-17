"""
Erweitert die offizielle Berliner Informationsbericht-Vorlage so, dass
die "Teilhabeziel"-Seite zehnmal vorhanden ist (Slots _a bis _j).

Strategie:
1. Original-PDF öffnen
2. Seite 3 (Index 2, enthält die `_a`-Felder) in ein Zwischen-PDF schreiben
3. Aus dem Zwischen-PDF neunmal zurück-importieren (mit `copy_foreign`)
4. Pro Kopie alle Field-Namen `_a` → `_b`, `_c`, …, `_j` umbenennen
5. AcroForm-/Fields-Array um die neuen Field-Refs ergänzen
6. Speichern

Aufruf:
    python tools/expand_template.py \\
        assets/templates/informationsbericht_101.pdf \\
        assets/templates/informationsbericht_101_extended.pdf
"""

from __future__ import annotations

import sys
import io
from pathlib import Path

import pikepdf
from pikepdf import Pdf, Name, Array


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    src = Path(sys.argv[1]).resolve()
    dst = Path(sys.argv[2]).resolve()

    print(f"Lese  {src}")
    pdf = Pdf.open(src)

    # Ein Zwischen-PDF nur mit der Quell-Seite (Index 2 = Page 3)
    intermediate = Pdf.new()
    intermediate.pages.append(pdf.pages[2])
    buf = io.BytesIO()
    intermediate.save(buf)
    intermediate.close()
    buf.seek(0)

    target_suffixes = list("bcdefghij")

    root = pdf.Root
    acroform = root.get(Name.AcroForm)
    if acroform is None:
        print("Kein AcroForm — Abbruch")
        sys.exit(2)
    fields_array = acroform[Name.Fields]
    if not isinstance(fields_array, Array):
        fields_array = fields_array.get_object()

    new_field_count_total = 0
    insert_after_idx = 2  # nach der originalen Page 3

    for suffix in target_suffixes:
        # Frisch aus dem Zwischen-PDF laden — die `pages.append`-API
        # macht intern ein Deep-Copy mit Refs-Resolve UND registriert die
        # Form-Felder bereits automatisch in /AcroForm/Fields. Wir dürfen
        # sie also NICHT nochmal manuell hinzufügen.
        buf.seek(0)
        src_doc = Pdf.open(buf)
        pdf.pages.append(src_doc.pages[0])
        src_doc.close()

        # Die zuletzt angehängte Seite zur richtigen Position verschieben
        last_idx = len(pdf.pages) - 1
        target_idx = insert_after_idx + 1
        if last_idx != target_idx:
            page_obj = pdf.pages[last_idx]
            del pdf.pages[last_idx]
            pdf.pages.insert(target_idx, page_obj)
        insert_after_idx = target_idx

        # Nur die Field-Namen umbenennen (von `_a` auf `_b`/`_c`/…).
        # Hinzufügen ins AcroForm-Array übernimmt pikepdf bereits.
        new_page = pdf.pages[insert_after_idx]
        annots = new_page.get(Name.Annots, [])
        renamed_count = 0
        for annot in annots:
            ao = annot.get_object() if hasattr(annot, "get_object") else annot
            if Name.T not in ao:
                continue
            original = str(ao[Name.T])
            if not original.endswith("_a"):
                continue
            renamed = original[:-2] + "_" + suffix
            ao[Name.T] = renamed
            renamed_count += 1
            new_field_count_total += 1

        print(f"  Slot _{suffix}: {renamed_count} Felder umbenannt")

    print(f"Gesamt: {new_field_count_total} neue Felder")
    print(f"Schreibe {dst}")
    pdf.save(dst)
    print("OK")


if __name__ == "__main__":
    main()
