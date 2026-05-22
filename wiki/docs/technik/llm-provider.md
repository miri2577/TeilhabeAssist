# LLM-Provider

FEGH-Bericht nutzt Cloud-LLMs zur Textgenerierung. Lokale Modelle
(Ollama, llama.cpp) sind technisch möglich und in der
[Roadmap](Roadmap#lokale-llm-modelle) skizziert, aktuell aber nicht
implementiert.

## Unterstützte Provider

| Provider | Standard-Modell | Streaming | Caching |
| --- | --- | --- | --- |
| **Anthropic Claude** | `claude-sonnet-4-6` | SSE | Prompt-Caching aktiv |
| **OpenAI GPT** | `gpt-5.4` | SSE | — |

Wechsel zwischen Providern jederzeit über *Einstellungen → API → Provider*.

## Adapter-Architektur

Alle Provider implementieren das `LLMAdapter`-Interface
(`lib/features/api/adapters/llm_adapter.dart`):

```dart
abstract class LLMAdapter {
  String get name;
  String get defaultModel;
  List<String> get availableModels;

  Future<ReportResponse> generateReport(ReportRequest request);
  Stream<String> generateReportStream(ReportRequest request);
  Future<bool> validateApiKey(String key);
}
```

Konkrete Adapter:
- `AnthropicAdapter` — `/v1/messages` mit `anthropic-version: 2023-06-01`
- `OpenAIAdapter` — `/v1/chat/completions`

Beide werden als **Riverpod-Singleton** mit `ref.keepAlive()` gehalten
(siehe `api_providers.dart`). Das ist wichtig, damit Dio's
Connection-Pooling und HTTP-Keep-Alive funktionieren — bei jeder
Provider-Auswahl eine neue Dio-Instanz zu erzeugen wäre Verschwendung.

## Anthropic

### Modelle (Stand Mai 2026)

| Modell | Use-Case | Stärke | Kosten / 1 M Token |
| --- | --- | --- | --- |
| `claude-opus-4-7` | Komplexe Fälle, höchste Qualität | Höchste | Hoch |
| `claude-sonnet-4-6` | Standardberichte (empfohlen) | Sehr hoch | Mittel |
| `claude-haiku-4-5-20251001` | Schnelle Massenberichte, Drafts | Hoch | Gering |

### Request-Aufbau

```
POST https://api.anthropic.com/v1/messages
x-api-key: sk-ant-…
anthropic-version: 2023-06-01

{
  "model": "claude-sonnet-4-6",
  "max_tokens": 8000,
  "temperature": 0.7,
  "system": [
    {
      "type": "text",
      "text": "<Berichtstyp-spezifischer Prompt>",
      "cache_control": {"type": "ephemeral"}  ← Prompt-Caching
    }
  ],
  "messages": [
    {"role": "user", "content": "## VORBERICHT (pseudonymisiert):\n…\n\n## AKTUELLE STICHPUNKTE:\n…"}
  ]
}
```

### Prompt-Caching

Der System-Prompt ist groß (mehrere KB Fach-Anweisungen) und ändert sich
zwischen Berichten nicht. Mit `cache_control: ephemeral` wird er für
5 Minuten serverseitig gecached, sodass Folgegenerierungen ~90 % der
Input-Token-Kosten sparen. Cache-Hits sind in den `usage`-Feldern der
Response sichtbar (`cache_read_input_tokens`).

### Streaming

`generateReportStream` nutzt Server-Sent Events. Der Decoder ist
**Multi-Byte-sicher**:

```dart
final textStream = const Utf8Decoder(allowMalformed: false).bind(stream);
// statt: utf8.decode(chunk) -- bricht bei geteilten Umlauten
```

Aktuell wird im Produktiveinsatz **Non-Streaming** verwendet, weil die
`usage`-Felder mit Token-Verbrauch dann zuverlässig zurückkommen. Streaming
bleibt als Pfad erhalten für zukünftige UI-Modi.

## OpenAI

### Modelle (Stand Mai 2026)

| Modell | Use-Case |
| --- | --- |
| `gpt-5.5` | Frontier; komplexe Fälle |
| `gpt-5.4` | Standardberichte (empfohlen) |
| `gpt-5.4-mini` | Schneller, günstiger |
| `gpt-5.4-nano` | Kleinstmodelle für Routine |
| `o3` | Reasoning-Modell für mehrstufige Argumentation |
| `gpt-4o` | Legacy-Kompatibilität |

### Request-Unterschiede

OpenAI nimmt nicht `max_tokens` für die neueren Modelle, sondern
`max_completion_tokens`. Der Adapter unterscheidet:

```dart
if (request.model.startsWith('gpt-5') || request.model.startsWith('o3')) {
  body['max_completion_tokens'] = 8000;
} else {
  body['max_tokens'] = 8000;
  body['temperature'] = request.temperature;  // o3/gpt-5 mögen kein temperature
}
```

### Key-Validierung

Anthropic-Adapter macht einen Dummy-Request `{"role":"user","content":"Hi"}`,
weil das das einzige `/v1/messages`-Aufruf-Muster ist, das einen
401/403-Status sicher abprüfen kann.

OpenAI-Adapter ruft `/v1/models` auf — ein billiger GET, der bei gültigem
Key 200 liefert.

## ReportRequest / ReportResponse

`lib/features/api/models/report_request.dart`

```dart
class ReportRequest {
  final String apiKey;
  final String model;
  final ReportType reportType;
  final String pseudonymizedNotes;
  final String? pseudonymizedPreviousReport;
  final String? pseudonymizedReferenceReport;
  final double temperature;       // Default 0.7
}

class ReportResponse {
  final String text;
  final int inputTokens;
  final int outputTokens;
  final String model;
  final String? stopReason;
  double get costUsd;             // Modellbasierte Kostenschätzung
  String get tokenDisplay;        // "1.2k → 850 tokens"
  String get costDisplay;         // "$0.0042"
}
```

## System-Prompts

`lib/features/api/prompts/system_prompts.dart` hält die Prompts:

| `ReportType` | Prompt |
| --- | --- |
| `informationsbericht` | Berlin Informationsbericht v1.01 — Format, Module, Sprache |

Custom-Prompts können in *Einstellungen → System-Prompt* überschrieben
werden — werden in `SettingsStorage.customInfoPrompt` /
`customBrpPrompt` persistiert und ersetzen den Default.

## Kostenkontrolle

Jede Antwort enthält Token-Verbrauch und eine Kosten-Schätzung. Die
App zeigt nach jedem Bericht:

```
API-Verbrauch: 2 845 → 1 612 Token
Modell: claude-sonnet-4-6 · Kosten: $0.018
```

Diese Werte landen auch im Audit-Log und können beim Träger als Argument
für ein Budget verwendet werden.

### Erwartete Größenordnungen

| Berichtstyp | Input | Output | Kosten Sonnet 4.6 | Kosten Opus 4.7 |
| --- | --- | --- | --- | --- |
| Informationsbericht | 2 000 – 5 000 | 1 200 – 2 500 | $0.01 – 0.03 | $0.05 – 0.13 |

Realwerte hängen vom Umfang des Vorberichts und der Stichpunkte ab.

## Netzwerk-Verhalten

| Parameter | Wert |
| --- | --- |
| `connectTimeout` | 30 Sekunden |
| `receiveTimeout` | 120 Sekunden |
| Retries | aktuell keine — Fehler werden direkt an UI propagiert |
| Verschlüsselung | TLS 1.3 (Dio Standard) |
| Proxy-Support | über System-Proxy (Dio nutzt OS-Settings) |

## Provider-spezifische Risiken

| Risiko | Anthropic | OpenAI |
| --- | --- | --- |
| Sitz | USA, San Francisco | USA, San Francisco |
| EU-Region verfügbar | Über AWS Bedrock (eu-central-1) | Über Azure OpenAI (eu-Regionen) |
| DPA / SCCs | Ja, mit Modul 2 + 3 | Ja, nach EU 2021/914 |
| Zero Data Retention | Standardmäßig nicht, in Enterprise verfügbar | "Enterprise" / "API Platform" mit ZDR-Opt-in |
| Training auf API-Inputs | Nein, beide haben das vertraglich ausgeschlossen | siehe Anthropic |

Für sensitive Anwendung **wird empfohlen**, mit dem jeweiligen Provider
einen DPA mit SCCs abzuschließen und Zero-Data-Retention zu beantragen.
Siehe [Datenschutz](Datenschutz) für die rechtliche Argumentation.

## Lokale LLM-Alternativen (geplant)

Siehe [Roadmap](Roadmap#lokale-llm-modelle). Konzept:

1. `OllamaAdapter` mit lokalem `http://localhost:11434/api/generate`
2. Standardmodelle: `llama3.1:70b-instruct`, `qwen2.5:32b-instruct`
3. Pseudonymisierung wird dann zu einem **Defense-in-Depth**, weil das
   Modell ohnehin lokal läuft — aber sie bleibt als zweite Sicherung
   aktiv, falls jemand einmal versehentlich den Lokalmodell-Endpunkt
   auf einen Cloud-Proxy umstellt.
