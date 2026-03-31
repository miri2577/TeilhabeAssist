const kPrivacyPolicyText = '''
DATENSCHUTZERKLÄRUNG UND NUTZUNGSVEREINBARUNG
TeilhabeAssist – KI-gestützte Berichterstellung
Version 1.0 | Stand: März 2026

═══════════════════════════════════════════════════

1. VERANTWORTLICHER

Verantwortlich für die Datenverarbeitung im Sinne der DSGVO ist der jeweilige Leistungserbringer (Träger), der diese Software einsetzt. Die Software wird bereitgestellt von Mirko Richter.

2. ZWECK DER DATENVERARBEITUNG

TeilhabeAssist unterstützt Fachkräfte der Eingliederungshilfe bei der Erstellung von Informationsberichten (Berlin, Version 1.01) und Behandlungs- und Rehabilitationsplänen (BRP, 4. Berliner Fassung). Die App nutzt KI-Sprachmodelle (Large Language Models) zur Textgenerierung.

3. VERARBEITETE DATENKATEGORIEN

3.1 Lokal auf dem Gerät verarbeitete Daten:
• Personenbezogene Daten der leistungsberechtigten Personen (Namen, Geburtsdaten, Adressen, Aktenzeichen, Diagnosen, Kontaktdaten)
• Sozialdaten gemäß § 67 SGB X
• Gesundheitsdaten gemäß Art. 9 DSGVO
• Berichtsinhalte und Stichpunkte der Fachkräfte
• Zuordnungstabellen der Pseudonymisierung (verschlüsselt mit AES-256-GCM)

3.2 An den API-Provider übermittelte Daten:
• AUSSCHLIESSLICH pseudonymisierte Texte, in denen alle personenbezogenen Daten durch Platzhalter ersetzt wurden (z.B. [PERSON_001], [DATUM_001])
• KEINE Klarnamen, Geburtsdaten, Adressen, Telefonnummern, E-Mail-Adressen oder Aktenzeichen

4. PSEUDONYMISIERUNGSVERFAHREN

4.1 Die App implementiert ein Mensch-Maschine-Prinzip:
a) Die Pseudonymisierungs-Engine erkennt automatisch personenbezogene Daten durch Regex-Pattern-Matching, Wörterbuch-Abgleich und Heuristiken.
b) Die Fachkraft MUSS den pseudonymisierten Text auf einem Vorschau-Bildschirm prüfen, bevor er an die API übermittelt wird.
c) Eine Pflicht-Bestätigung ist technisch erzwungen und nicht überspringbar.

4.2 Die Zuordnungstabelle (Platzhalter ↔ Originaldaten) verlässt NIEMALS das Gerät. Sie wird lokal mit AES-256-GCM verschlüsselt und mit einem aus der Benutzer-Passphrase abgeleiteten Schlüssel (PBKDF2, 100.000 Iterationen) gesichert.

5. API-PROVIDER UND DRITTLANDTRANSFER

5.1 Die App unterstützt folgende API-Provider:
• Anthropic (Claude) – Sitz: San Francisco, USA
• OpenAI (GPT) – Sitz: San Francisco, USA

5.2 Da die übermittelten Daten aus Sicht des API-Providers anonym sind (kein Zugang zur Zuordnungstabelle, keine eigenen Mittel zur Re-Identifizierung), liegt KEINE Auftragsverarbeitung im Sinne von Art. 28 DSGVO vor. Ein Auftragsverarbeitungsvertrag (AVV) ist daher nicht erforderlich.

5.3 Beide Provider bieten Data Processing Addenda (DPA) mit EU-Standardvertragsklauseln (SCCs) an, die als zusätzliches Sicherheitsnetz dienen.

5.4 DRITTLANDTRANSFER – SUPPLEMENTARY MEASURES (Schrems II)

Gemäß dem Urteil des EuGH in der Rechtssache C-311/18 ("Schrems II") werden folgende ergänzende Maßnahmen implementiert, um ein der EU gleichwertiges Schutzniveau zu gewährleisten:

a) TECHNISCHE MASSNAHMEN:
   • Pseudonymisierung ALLER personenbezogenen Daten VOR der Übermittlung
   • Die Zuordnungstabelle verbleibt ausschließlich auf dem lokalen Gerät
   • Der API-Provider hat KEINE technischen Mittel zur Re-Identifizierung
   • Verschlüsselung in Transit mittels TLS 1.3
   • Aus Sicht des Providers handelt es sich um anonyme Daten

b) VERTRAGLICHE MASSNAHMEN:
   • EU-Standardvertragsklauseln (SCCs) sind Bestandteil der DPA beider Provider
   • Anthropic: DPA mit Modul 2 (Controller → Processor) und Modul 3 (Processor → Processor)
   • OpenAI: DPA mit SCCs nach Durchführungsbeschluss (EU) 2021/914
   • Zero Data Retention: Beide Provider verpflichten sich, API-Inputs nicht für Training zu verwenden

c) ORGANISATORISCHE MASSNAHMEN:
   • Pflicht-Prüfung durch die Fachkraft vor jeder API-Übermittlung (technisch erzwungen)
   • Audit-Log protokolliert jeden API-Aufruf (ohne personenbezogene Daten)
   • Datenschutzerklärung mit elektronischer Signatur der Fachkraft

d) RISIKOBEWERTUNG:
   Da die übermittelten Daten aus Sicht des API-Providers anonym sind (kein Zugang zur Zuordnungstabelle), ist das Risiko einer Offenlegung personenbezogener Daten gegenüber US-Behörden NICHT gegeben. Selbst bei einem Zugriff auf die API-Logs des Providers können keine natürlichen Personen identifiziert werden.

6. DATENSPEICHERUNG UND LÖSCHUNG

6.1 Alle Daten werden ausschließlich lokal auf dem Gerät der Fachkraft gespeichert (Hive-Datenbank, verschlüsselte Boxen).
6.2 Es existiert KEIN Server-Backend und KEIN Cloud-Speicher.
6.3 API-Keys werden nur lokal gespeichert und niemals an Dritte weitergegeben.
6.4 Die Löschung aller Daten ist jederzeit durch Deinstallation der App oder über die Einstellungen möglich.

7. BESONDERER SCHUTZ: BRP SEITE 4

Die psychiatrische Anamnese (Seite 4 des BRP) darf gemäß Berliner Rahmenvertrag nicht an den Kostenträger weitergeleitet werden. Die App erkennt diese Inhalte automatisch und BLOCKIERT ihre Übermittlung an die API – auch nicht in pseudonymisierter Form.

8. AUDIT-LOG

8.1 Die App führt ein lokales Audit-Log, das alle sicherheitsrelevanten Aktionen protokolliert:
• Berichtsgenerierungen (Modell, Anzahl Pseudonymisierungen, Berichtstyp)
• Passwort-Events (Setzen, erfolgreiche/fehlgeschlagene Anmeldungen, Sperrungen)
• Datenschutz-Unterschriften
• Wörterbuch-Exporte und -Importe
• BRP Seite 4 Blockierungen
• Daten-Löschungen

8.2 Das Audit-Log enthält KEINE personenbezogenen Daten – nur Metadaten und Zeitstempel.

8.3 Das Audit-Log kann über die Einstellungen als JSON-Datei exportiert werden und dient als Nachweis für den Datenschutzbeauftragten des Trägers.

9. TECHNISCHE UND ORGANISATORISCHE MASSNAHMEN

• Verschlüsselung at Rest: AES-256-GCM für Zuordnungstabellen
• Verschlüsselung in Transit: TLS 1.3 für API-Kommunikation
• Datenminimierung: Nur anonymisierte Platzhalter-Texte an API
• Zugriffskontrolle: Benutzer-Passphrase für Zuordnungstabelle
• Validierungs-Layer: Automatische + manuelle Prüfung vor jedem API-Aufruf
• Plattform-Sicherheit: App Sandbox (macOS/iOS/Android)

10. RECHTE DER BETROFFENEN PERSONEN

Die Rechte der leistungsberechtigten Personen (Auskunft, Berichtigung, Löschung, Einschränkung, Widerspruch, Datenübertragbarkeit) werden durch den jeweils verantwortlichen Leistungserbringer gewährleistet.

11. PFLICHTEN DER FACHKRAFT

Mit der Unterzeichnung dieser Erklärung bestätigt die Fachkraft:

a) Den pseudonymisierten Text VOR JEDER API-Übermittlung sorgfältig zu prüfen und sicherzustellen, dass keine personenbezogenen Daten enthalten sind.

b) Die Pflicht-Bestätigung vor dem API-Aufruf gewissenhaft und wahrheitsgemäß abzugeben.

c) Keine Inhalte aus BRP Seite 4 (psychiatrische Anamnese) in die App einzugeben.

d) Den API-Key vertraulich zu behandeln und nicht an unbefugte Dritte weiterzugeben.

e) Bei Verdacht auf eine Datenschutzverletzung (z.B. wenn personenbezogene Daten versehentlich an die API übermittelt wurden) unverzüglich die verantwortliche Stelle und den Datenschutzbeauftragten des Trägers zu informieren.

12. RESTRISIKO

Trotz der Kombination aus automatischer Engine und menschlicher Prüfung besteht ein Restrisiko, dass personenbezogene Daten nicht erkannt werden (z.B. seltene Vornamen im Fließtext, kontextuelle Identifizierung durch Kombination von Diagnose + Bezirk + Alter). Die App minimiert dieses Risiko durch Über-Erkennung und Lernfunktion, kann es aber nicht auf Null reduzieren. Die letzte Verantwortung liegt bei der prüfenden Fachkraft.

13. RECHTSGRUNDLAGEN

• DSGVO Art. 6 Abs. 1 lit. f (berechtigtes Interesse an effizienter Berichterstellung)
• DSGVO Art. 9 Abs. 2 lit. h (Verarbeitung zu Zwecken der Gesundheitsversorgung)
• SGB IX §§ 117-118 (Gesamtplanverfahren)
• SGB X § 67 ff. (Sozialdatenschutz)

═══════════════════════════════════════════════════

Durch meine Unterschrift bestätige ich, dass ich diese Datenschutzerklärung vollständig gelesen und verstanden habe und die oben genannten Pflichten anerkenne.
''';
