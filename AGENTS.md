# Working on this repo

Read this before changing anything. It is written for a coding agent picking the project up
cold, and it is mostly a list of things that look wrong but aren't, plus things that look
fine and will bite you.

---

## What this is

Yappie is push-to-talk dictation. Hold a key, talk, release, and cleaned-up text is typed
into whatever had focus. Two independent implementations:

| | macOS | Windows |
|---|---|---|
| Language | Swift 6 | C# / .NET 10 |
| UI | SwiftUI | Avalonia *(not written yet)* |
| Speech | Apple `SpeechAnalyzer`, or Parakeet via FluidAudio | Parakeet via sherpa-onnx |
| Location | repo root | `windows/` |

**The macOS app works and is in daily use. The Windows app is a dictionary engine plus a
detailed specification — no audio, hotkey, injection or UI yet.** Do not describe it as
working.

---

## The one rule that matters

**`shared/dictionary-test-vectors.json` is the specification for correction behaviour.**

Both implementations run it in CI. If you change how corrections work, change the vectors
first, watch both sides go red, then make them green. Changing one implementation to "fix"
a failing vector without changing the other is how the two silently diverge — and only one
of them can be exercised by hand.

```bash
swift test --filter VectorTests    # macOS dictionary
swift test --filter ActivityTests  # words / streak / heatmap
cd windows && dotnet test Yappie.sln # Windows dictionary
```

The Swift copy at `Tests/YappieDictionaryTests/dictionary-test-vectors.json` is a copy, and
CI fails if it drifts from `shared/`. After editing the shared file:

```bash
cp shared/dictionary-test-vectors.json Tests/YappieDictionaryTests/
```

---

## Things that look like bugs and are not

**`swift build` fails with "input file was modified during the build."** The repo lives in an
iCloud-synced folder and the sync engine touches files mid-compile. **Always build with
`make`**, which uses `--scratch-path` outside the synced tree. A bare `swift build` also
writes a `.build/` directory into iCloud, which makes every subsequent build minutes slower.
If you see this error, wait a few seconds and retry.

**Compare mode doesn't type anything.** By design — `Settings.compareMode` runs every engine
on one recording and shows them side by side. If both injected, two transcripts would fight
over one text field. This is the single most confusing behaviour in the app.

**The timing column isn't comparing like with like.** Apple and Parakeet are timed on local
compute with the clock started *after* model load. Wispr Flow's number is its own
`e2eLatency`, which includes a network round trip and its cleanup pass. Don't present them
as one ranking.

**`MainActor.assumeIsolated` will crash the process.** It does not check the claim, it
asserts it. Use `await MainActor.run` from any non-main-actor context. This took the app
down once already.

**Mutating `@State` inside a `Canvas` draw closure floods the log and corrupts state.**
`LevelMeter` keeps its sample trace and ballistics in a plain reference type the view merely
holds, which is invisible to SwiftUI's state graph. Don't "clean that up" into `@State`.

**`YearRamp` measures its width in a `.background { GeometryReader }`, not by wrapping
itself in one.** Its height is a function of its width — it sizes 371 cells to fit — so
reading the width in the same pass that sets the height is circular, and the symptom is a
clipped bottom row rather than an error.

---

## Design system

`Sources/Yappie/UI/DesignSystem.swift` defines every colour, size, radius, alpha, font and
duration token. **Views must not contain literal values.** If a component needs a number
that isn't a token, add the token rather than inlining it. `DS.Color.Alpha` exists for the
same reason — an accent tinted at some inline `0.35` cannot be re-tuned centrally.

The direction is a **copy desk for speech**. Three surfaces, and each is a distinct value in
*both* appearances:

| Token | Light | Dark |
|---|---|---|
| `chassis` — the window | violet limestone | plum night-ink |
| `bar` — raised chrome, cards, sheets | one step lighter | one step lighter |
| `page` — where transcripts live | warm paper | aubergine phosphor |

**A surface you cannot see is not a surface.** The first version pinned `page` to a fixed
dark aubergine in both appearances, which put `#130E1C` next to a `#100C16` chassis — two
values nobody can tell apart, so in dark mode the whole window read as one flat slab and the
"one memorable surface" idea was invisible. If you re-tune the palette, check both
appearances at once and keep the three steps separable.

Type: system sans for chrome, **New York serif for the words you spoke** — a transcript
should read like copy, not like a log line. Counters are monospaced so a running clock
doesn't jitter. `Eyebrow` is the small editorial label; it is sentence case, not
silkscreened all-caps.

Three rules that are not negotiable:

- **Red means recording.** Nothing else in the app is red.
- **The HUD never takes focus.** It is a non-activating panel.
- **Row actions are always in the view tree**, fading in on hover rather than being built
  inside `if isHovering`. A view that isn't built does not exist for VoiceOver or the
  keyboard, which is how Copy, Teach, Edit and Delete were unreachable for a while.

Ruled out: cassette-deck pastiche, AI-SaaS purple, default SwiftUI gray, neon, glowing text.

The window has **no title bar** (`.windowStyle(.hiddenTitleBar)` plus
`.ignoresSafeArea(.container, edges: .top)`). `TopBar` *is* the title bar, and
`DS.Size.trafficLights` is the leading gutter the close/minimise/zoom buttons sit in — if
you change the bar's leading padding, they will overlap the first control.

---

## macOS specifics

**Code signing is load-bearing, not cosmetic.** TCC stores a code-signing *requirement* per
entry, not just a path. An ad-hoc signature changes every build, so the rebuilt binary stops
satisfying the stored requirement — and the symptom lies: the Accessibility toggle still
shows as **on** while the app is untrusted. The `Makefile` auto-detects a Developer ID via
`security find-identity`. Don't replace that with `--sign -`.

If a grant does get wedged, reset that one row — never toggle, and never omit the bundle ID:

```bash
tccutil reset Accessibility com.jaicodes77.yappie
```

A bare `tccutil reset Accessibility` wipes every app on the machine. Then quit System
Settings entirely (⌘Q) before reopening; the Privacy pane caches its list.

**`log` may be shadowed in the user's shell.** Use `/usr/bin/log` explicitly.

**Don't run the `.app` from the repo folder.** It's iCloud-synced and the sync engine can
corrupt the signature. `make install` puts the running copy in `/Applications`.

---

## Windows specifics

Everything here was researched and verified but **never run on Windows.** Treat the specifics
as load-bearing; they were expensive to establish. Full detail in `windows/README.md` and
`docs/PARAKEET-WINDOWS.md`.

**Three pinned versions that break silently at "latest":**

| Package | Pin | Why |
|---|---|---|
| `NAudio` | 2.3.0 | 3.x targets .NET 9+ and will not restore |
| `Avalonia.Headless.XUnit` | 11.3.20 | 12.x requires xUnit **v3**, a different package line |
| `org.k2fsa.sherpa.onnx` | 1.13.5 | Bundles ONNX Runtime — never also reference `Microsoft.ML.OnnxRuntime` |

**Right Alt is AltGr** on German, Polish, UK, Nordic and most Latin-American layouts. Binding
push-to-talk there — and especially suppressing it — breaks typing `@`, `€`, `\`, `|` for
those users. Default is **Right Ctrl**, and the hook **observes without swallowing**: if the
key-down is swallowed and the key-up escapes, the target app believes Ctrl is held forever.

**UI Automation cannot inject text.** `TextPattern` is documented read-only and
`ValuePattern` replaces a whole field rather than inserting at the caret. `SendInput` is the
primary path, not a fallback.

**Keep `Yappie.Platform.Windows` logic-free.** Anything living there is code CI cannot
exercise. Retries, debouncing and device-change handling belong in the platform-neutral
projects behind an interface — those target plain `net10.0`, so `CA1416` turns any accidental
Win32 call into a build error.

**CI is the only place the Windows code is compiled.** Warnings are errors and the analyzers
are strict on purpose. `--no-incremental` is mandatory: Roslyn does not re-emit analyzer
warnings on a cached build, so without it the gate proves nothing.

---

## Regex, if you touch the dictionary

The two engines are not identical. Measured across 30 cases, **9 diverged**. Two affect this
code and are handled — don't remove either:

- `RegexOptions.CultureInvariant` on the C# side, or Turkish `İ` matches `i`.
- **NFC normalization on both sides.** macOS returns decomposed strings, so without it an
  accented trigger silently never fires.

Two more are unfixable and simply avoided: ICU folds `ß` to `ss` and .NET doesn't; .NET's `.`
splits surrogate pairs. Stay inside the safe subset — `\b`, `\d`, `\w`, `\s`, character
classes, greedy/lazy quantifiers, alternation, `(?<name>…)`, fixed-length lookbehind,
lookahead, `\p{L}`, and `$1`–`$9` in replacements. Nothing else.

---

## What isn't built

1. **The whole Windows platform layer** — audio, hotkey, injection, UI.
2. **Command Mode** — select text, hold a second key, "make this more formal."
3. **Onboarding** — a first-run window walking through both macOS permissions.
4. **Notarization** — signing works; notarization would end the Gatekeeper warning.

And one thing CI structurally cannot verify on either platform: **text injection into a
foreground application.** GitHub runners have an interactive desktop but cannot take the
foreground. That needs a real machine and a human.
