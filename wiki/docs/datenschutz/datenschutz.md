# Datenschutz & DSGVO

Diese Seite fasst die rechtliche Argumentation der App zusammen. Die
**verbindliche** Datenschutzerklärung steht im Code unter
`lib/features/privacy/privacy_policy_text.dart` und wird der Fachkraft
beim Erststart zur Bestätigung vorgelegt.

> Diese Seite ist Erläuterung für Entwickler:innen und
> Datenschutzbeauftragte — sie ersetzt **keine** Rechtsberatung. Im
> Zweifel den DSB des Trägers konsultieren.

## Datenkategorien

Die App verarbeitet zwei verschiedene Kategorien von Daten:

### 1. Lokale Daten (auf dem Gerät, verschlüsselt)

- Personenbezogene Daten leistungsberechtigter Personen
  (Klarnamen, Geburtsdaten, Adressen, Aktenzeichen, Telefonnummern,
  E-Mails, Diagnosen, soziale Anamnese, Therapiehistorie)
- **Sozialdaten** im Sinne von § 67 SGB X
- **Gesundheitsdaten** im Sinne von Art. 9 Abs. 1 DSGVO
- Pseudonymisierungs-Zuordnungstabellen
- Berichts-Drafts und fertige Berichte

### 2. Übermittelte Daten (an den LLM-Provider)

Ausschließlich **pseudonymisierter Text** mit Platzhaltern wie
`[PERSON_001]`, `[DATUM_005]`, `[ADRESSE_002]`. **Keine** Klarnamen,
Geburtsdaten, Adressen, Telefonnummern, E-Mail-Adressen oder
Aktenzeichen verlassen das Gerät.

Die Provider erhalten zusätzlich:
- die HTTP-Standard-Header (User-Agent, IP der Fachkraft)
- die API-Key-Authentifizierung (identifiziert den Träger / die
  Fachkraft beim Provider)
- Token-Verbrauchsmessung

## Rechtsgrundlagen

| Grundlage | Anwendung |
| --- | --- |
| Art. 6 Abs. 1 lit. f DSGVO (berechtigtes Interesse) | Effiziente Berichterstellung durch die Fachkraft |
| Art. 9 Abs. 2 lit. h DSGVO | Verarbeitung zu Zwecken der Gesundheitsversorgung und Pflege |
| SGB IX §§ 117–118 | Gesamtplanverfahren der Eingliederungshilfe |
| SGB X § 67 ff. | Sozialdatenschutz |

Für die Übermittlung an den LLM-Provider wird argumentiert, dass diese
**nicht** unter Art. 6 / 9 DSGVO fällt, weil aus Sicht des Empfängers
keine personenbezogenen Daten vorliegen (siehe nächster Abschnitt).

## Pseudonymisierung versus Anonymisierung

Die DSGVO unterscheidet beide klar:

- **Anonymisierung** (Erwägungsgrund 26) — Daten, die so verändert
  wurden, dass eine Identifizierung **unmöglich** ist. Anonyme Daten
  fallen nicht unter die DSGVO.
- **Pseudonymisierung** (Art. 4 Nr. 5) — Daten, die ohne zusätzliche
  Informationen einer Person nicht mehr zugeordnet werden können.
  Pseudonyme Daten **bleiben** personenbezogene Daten.

Die App argumentiert konkret: aus Sicht des **LLM-Providers** sind die
übermittelten Texte **anonym**, weil:

1. Die Zuordnungstabelle das Gerät niemals verlässt.
2. Der Provider keine "vernünftigerweise einsetzbaren Mittel" hat, die
   Originaldaten zu rekonstruieren (Erwägungsgrund 26 — die
   Verhältnismäßigkeitsprüfung).
3. Direkte Identifikatoren (Namen, Daten, Adressen, Aktenzeichen) sind
   nicht enthalten — die verbleibenden indirekten Identifikatoren
   (Diagnose, ICF-Domäne, regionaler Kontext) ermöglichen ohne externe
   Daten **keine** Re-Identifikation.

**Wichtig:** Aus Sicht des **Verantwortlichen** (= Träger) bleiben die
Daten personenbezogen, weil er die Mittel zur Re-Identifikation hat.
Daher gelten DSGVO und SGB für ihn weiter.

## Auftragsverarbeitung — ja oder nein?

Die App-Architektur argumentiert: **Keine Auftragsverarbeitung** im
Sinne von Art. 28 DSGVO, weil:

1. Der Provider keine personenbezogenen Daten verarbeitet (siehe oben).
2. Die Weisungskette Auftraggeber → Auftragnehmer für anonymisierte
   Daten dogmatisch nicht greift.

**Dennoch wird empfohlen**, ein DPA mit dem Provider abzuschließen, das
EU-Standardvertragsklauseln und Zero-Data-Retention enthält — als
Vorsichtsmaßnahme für den Fall, dass eine Aufsichtsbehörde die
Anonymisierungs-Argumentation anders einschätzt.

### DPA-Status

| Provider | DPA verfügbar | SCCs (EU 2021/914) | Zero Data Retention |
| --- | --- | --- | --- |
| Anthropic | Ja (Standard) | Ja, Modul 2 + 3 | Auf Anfrage / Enterprise |
| OpenAI | Ja (Self-Service) | Ja | Über "API Platform" Opt-in |

## Schrems II — Drittlandtransfer in die USA

EuGH C-311/18 (2020) verlangt für Datentransfers in die USA **zusätzliche
Maßnahmen** ("supplementary measures"), weil das US-Recht (CLOUD Act,
FISA 702) den Schutz vor US-Behörden-Zugriff schwächt.

Die App implementiert konkret:

| Kategorie | Maßnahme |
| --- | --- |
| **Technisch** | Pseudonymisierung aller direkten Identifikatoren, lokale Zuordnungstabelle, TLS 1.3, AES-256-CBC at-rest, OS-Keystore |
| **Vertraglich** | SCCs Modul 2/3 im DPA, Zero-Data-Retention |
| **Organisatorisch** | Pflicht-Bestätigung der Fachkraft, Audit-Log, signierte Datenschutzerklärung |

**Risikobewertung:** Selbst bei einem unbegrenzten Zugriff der
US-Behörden auf die API-Logs des Providers können die übermittelten
Texte **keiner** natürlichen Person zugeordnet werden — ohne die
lokale Zuordnungstabelle sind sie anonym.

## Re-Identifikations-Restrisiko

Trotz aller Schutzmaßnahmen ist ein **Restrisiko** zu benennen:

| Risiko | Wahrscheinlichkeit | Beispiel |
| --- | --- | --- |
| Engine erkennt seltenen Nachnamen ohne Anrede nicht | Mittel | "Frau X war zur Therapie. Müller berichtete später." |
| Engine erkennt fremdsprachigen Vornamen nicht | Niedrig | seltene osteuropäische Schreibweisen ohne Wörterbuch-Eintrag |
| Ungewöhnlich seltene Diagnose + Bezirk + Alter | Niedrig | Re-Identifikation über Statistik möglich |
| Fachkraft übersieht in der Pflicht-Bestätigung einen übersehenen Namen | Mittel | Reflex-Klick |

Die App reduziert das Risiko durch:

1. Lernfunktion (jeder bestätigte Name wird erkannt)
2. Pflicht-Preview mit Hervorhebung
3. Mindest-Lesezeit (5 s) vor freigegebener Bestätigung
4. Zwei-Häkchen-Bestätigung bei Warnungen
5. Transparente Kommunikation in der Datenschutzerklärung (§ 4.3 und § 12)

## Rechte der betroffenen Personen

Auskunft, Berichtigung, Löschung, Einschränkung, Widerspruch,
Datenübertragbarkeit (Art. 15–22 DSGVO) sind **vom Träger** zu
gewährleisten — nicht von der App. Die App stellt die technischen
Werkzeuge:

- Bericht-Löschen über die UI
- Voll-Reset löscht alle Daten inklusive Audit-Log
- Audit-Log-Export als Nachweis

## Pflichten der Fachkraft

Mit der Signatur der Datenschutzerklärung verpflichtet sich die
Fachkraft:

1. **Pseudonymisierten Text vor JEDER API-Übermittlung sorgfältig zu
   prüfen.**
2. **Die Pflicht-Bestätigung gewissenhaft und wahrheitsgemäß abzugeben.**
4. **Den API-Key vertraulich zu behandeln.**
5. **Bei Verdacht auf eine Datenschutzverletzung** unverzüglich den DSB
   und die verantwortliche Stelle zu informieren.

## Audit-Trail

Siehe [Audit-Log](Audit-Log). Wichtig im Kontext Datenschutz:

- **Was wird protokolliert** — Berichts-Generierung, Login-Events,
  Passwort-Wechsel, Signatur-Erstellung, Datenresets.
- **Was wird NICHT protokolliert** — Inhalt der Berichte, Namen, Daten,
  Adressen.
- **Hash-Chain** macht Manipulation erkennbar.
- **Export als JSON** für den DSB.

## Checkliste für die Datenschutz-Folgenabschätzung (DSFA)

Die Verarbeitung besonderer Kategorien personenbezogener Daten
(Art. 9 DSGVO) in Kombination mit automatisierter Entscheidungsfindung
oder umfangreicher Datenverarbeitung kann eine DSFA nach Art. 35 DSGVO
erfordern. Für FEGH-Bericht:

| Frage | Antwort |
| --- | --- |
| Werden besondere Kategorien (Art. 9) verarbeitet? | Ja — Gesundheitsdaten |
| Findet eine systematische Bewertung statt? | Nein — KI erstellt Texte, nicht Entscheidungen |
| Umfangreiche Verarbeitung? | Nur, wenn der Träger viele Klient:innen mit der App betreut |
| Automatisierte Einzelentscheidung mit rechtlicher Wirkung? | Nein |

Eine DSFA wird **empfohlen** vor flächigem Rollout in einem Träger,
auch wenn sie rechtlich nicht zwingend ist.

## Weiterführende Quellen

- DSGVO — Art. 4, 6, 9, 28, 32, 35, Erwägungsgrund 26
- SGB IX §§ 117–123 (Gesamtplanverfahren)
- SGB X §§ 67–85a (Sozialdatenschutz)
- EuGH C-311/18 (Schrems II)
- EDSA-Empfehlungen 01/2020 zu zusätzlichen Maßnahmen
- BfDI: "Datenschutz und KI"-Leitfaden
