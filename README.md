# Yappie

Push-to-talk dictation for macOS. Hold a key, talk, release — cleaned-up text is typed
into whatever had focus. Fully on-device. Built as a native Swift app, not an Electron
wrapper around a cloud model.

Requires **macOS 26**.


---

## Features

### Dictation

- **Push-to-talk anywhere.** Hold the hotkey, speak, release. Text lands at the caret in
  the frontmost app. Default key is **Left Option (⌥)**; **Right ⌥**, **fn**, and
  **Right ⌘** are alternatives so it can sit next to Wispr Flow or Superwhisper
  without colliding.
- **Record button.** The main window has transport controls if you would rather click than
  hold a key.
- **Live HUD.** A floating overlay shows the level meter and (with Apple's engine) the
  transcript while you are still talking. It is a non-activating panel — it never steals
  focus from the field you are dictating into.
- **Menu bar item.** Status and the same controls while you are in another app.
- **Start/stop sounds.** Optional ticks when capture starts and finishes.

### Speech engines

- **Apple SpeechTranscriber (default).** Streaming, on-device, no extra download beyond
  the OS speech model for your locale. Text appears as you talk.
- **Parakeet TDT (optional).** NVIDIA's model on the Neural Engine via FluidAudio. Batch,
  not streaming — it resolves on release, typically in a fraction of a second. First use
  downloads ~470 MB; you can preload from the menu.
- **Compare mode.** One recording is run through every engine (Apple, Parakeet, and Wispr
  Flow if it is installed and its hotkey was held). Results show side by side. Nothing is
  typed into the focused app in this mode, so two transcripts cannot fight.

### Cleanup

- **Rule-based cleanup (on by default).** Strips fillers (`um`, `uh`), applies spoken
  punctuation (`new line`, `new paragraph`, `open paren`), capitalizes sentences, and
  adds terminal punctuation.
- **Smart cleanup.** Optional on-device Foundation Models pass (Apple Intelligence) for
  tone, lists, and spoken corrections like "make that three, actually". Times out to the
  rule-based pass so a stall never eats an utterance. Nothing leaves the Mac.

### Personal dictionary

Teach Yappie names, product terms, and jargon the recognizer keeps missing.

- **Term** — a word that should exist (`jistory`, an API name). Biases the speech engine
  toward that spelling.
- **Correction** — when you hear X, write Y (`cloud code -> Claude Code`). Applied after
  transcription, so it is guaranteed even if the engine still misspeaks.
- **Teach from a transcript.** On any past dictation, tap **Teach**, pick the wrong words
  as chips, type the spelling you want, save. Also **⌘⇧L**, the menu-bar item **Add
  dictionary word…**, or the Dictionary tab's Add button.
- **Plain-text file.** The same list lives at
  `~/Library/Application Support/Yappie/dictionary.txt` and can be edited in any editor.
  The app watches the file; changes show up immediately. **Reveal Dictionary File** in
  the app menu.

Example:

```
jistory
Spri
cloud code -> Claude Code
# off: whisper flow -> Wispr Flow
```

### History and comparison

- Searchable transcription list with copy, delete, and Teach on each row.
- Correction badges when a dictionary rule fired, so you can see whether a rule is
  earning its place.
- Dedicated **Engine comparison** window (⌘D from the menu bar) for side-by-side runs.

### Text injection

Inserts into the focused field via Accessibility when that actually moves the caret, and
falls back to a pasteboard + ⌘V path for Electron apps (Cursor, VS Code, Slack), Chrome,
and terminals that accept an AX write and then silently drop it. The previous clipboard
contents are restored afterwards.

---

## Install

```bash
git clone https://github.com/JaiCodes77/Yappie-.git
cd Yappie-
make install     # builds, signs, copies to /Applications, launches
```

Then grant two permissions — neither is optional:

| Permission | Where | Needed for |
|---|---|---|
| **Accessibility** | System Settings ▸ Privacy & Security ▸ Accessibility | The hotkey tap, and inserting text |
| **Microphone** | Prompted on first dictation | Audio capture |

Restart Yappie after granting Accessibility. Then hold **Left ⌥** and talk.

Left Option is consumed while Yappie is running so it doesn't leak into the focused
app. If you still need that key for Option+character shortcuts, switch the hotkey in
Settings to Right ⌥, fn, or Right ⌘.

If Gatekeeper blocks the first open: right-click → Open. This machine currently signs
ad-hoc unless a Developer ID is installed.

Other targets: `make app` (bundle only), `make run` (run from the staging dir),
`make clean`.

Always use `make`, not a bare `swift build`. The repo lives under Desktop, which is
iCloud-synced; `make` puts scratch files and the `.app` in `~/Library/Caches/YappieBuild`
so the sync engine cannot corrupt the signature mid-compile.

### Permissions after a rebuild

TCC stores a *code-signing requirement*, not just a path. An ad-hoc signature changes
every build, so Accessibility can show as **on** while the app is actually untrusted.
The Makefile signs with a Developer ID when one exists. If a grant gets wedged:

```bash
tccutil reset Accessibility com.jaicodes77.yappie
tccutil reset Microphone   com.jaicodes77.yappie
```

Always pass the bundle ID. A bare `tccutil reset Accessibility` wipes **every** app on
the machine. Then quit System Settings entirely (⌘Q) before reopening.

### Coexisting with Wispr Flow (or Superwhisper)

Give each app a different push-to-talk key. Two apps on the same key both record, and
whichever injects will fight the other. Bundle ID `com.jaicodes77.yappie` and executable
`Yappie` are distinct, so permissions and `pkill` never collide with another dictation
app.

---

## Settings

Open with **⌘,** or the menu bar.

| Setting | What it does |
|---|---|
| Push to talk | Left ⌥ (default) / Right ⌥ / fn / Right ⌘ |
| Model | Apple (streaming) or Parakeet (batch) |
| Clean up transcripts | Rule-based pass. Dictionary corrections run either way. |
| Smart cleanup | On-device Apple Intelligence. Off if the model is unavailable. |
| Sound | Ticks on start/stop |
| Compare mode | Run every engine; type nothing |

---

## Speech engines

| | Apple SpeechTranscriber | Parakeet TDT (FluidAudio) |
|---|---|---|
| Default | yes | optional |
| Dependency | none | SwiftPM |
| Model | OS-managed | ~470–600 MB download |
| Live text while speaking | yes | no — resolves on release |
| Where it runs | on-device | Neural Engine |

The first Apple run for a locale may pause while the OS installs speech assets.

---

## Look

Violet limestone chrome, a deep **aubergine phosphor page** with lavender type where
transcripts live, and copper for selection. Red is recording and nothing else. The compact
HUD uses the same phosphor glass and never takes focus.

---

## Architecture

```
 hold key ─► HotkeyMonitor ──► DictationController ◄── Settings
                                │
                     ┌──────────┼──────────┐
                     ▼          ▼          ▼
              AudioCapture  HUDPanel   TranscriptionEngine
                     │                      │
                (AudioChunk) ──ordered──► Apple / Parakeet
                                            │
                                       (transcript)
                                            ▼
                                      TextFormatter
                                            ▼
                                      DictionaryCorrector
                                            ▼
                                      TextInjector ─► focused app
```

| Path | Role |
|---|---|
| `Sources/Yappie/` | macOS app (SwiftUI, Speech, HUD, injection) |
| `Sources/YappieDictionary/` | Correction engine — shared contract with Windows |
| `Tests/YappieDictionaryTests/` | Vector tests |
| `shared/dictionary-test-vectors.json` | Spec both platforms must match |
| `windows/` | C# dictionary engine. No audio, hotkey, injection, or UI yet. |
| `bench/` | Apple vs Parakeet scoring harness |

The HUD must never take focus. The hotkey is a `CGEventTap` (needed for `fn` and
left/right modifier discrimination). Audio is fed in capture order through a single
stream — unstructured tasks per buffer would scramble the transcript.

---

## Windows

The Windows side is a dictionary engine plus a specification. **It cannot transcribe,
listen, or type yet.** Do not treat it as a working app. Details in
[`windows/README.md`](windows/README.md) and [`docs/PARAKEET-WINDOWS.md`](docs/PARAKEET-WINDOWS.md).

---

## Not built yet

1. **Command Mode** — select text, hold a second key, "make this more formal."
2. **Onboarding** — a first-run walkthrough of both macOS permissions.
3. **Notarization** — signing works; notarization would end the Gatekeeper warning.
4. **The Windows platform layer** — audio, hotkey, injection, UI.

Text injection into a real foreground app cannot be verified in CI. That needs a Mac
and a human.

---

## Logs

```bash
/usr/bin/log show --predicate 'subsystem == "com.jaicodes77.yappie"' --last 10m
```

Use `/usr/bin/log` explicitly; `log` is often shadowed in the shell.
