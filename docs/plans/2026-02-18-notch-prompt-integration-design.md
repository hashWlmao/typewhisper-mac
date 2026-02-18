# Notch Prompt Integration - Design

## Problem

After dictation, if no text field is focused, the transcribed text silently goes to the clipboard with no further action. Users have no way to apply prompt actions (translate, formalize, summarize, etc.) through the Notch Indicator. The PromptPalettePanel exists as a separate floating panel but is disconnected from the dictation flow.

## Solution

Extend the Notch Indicator's state machine with two new states (`promptSelection`, `promptProcessing`) to show prompt actions directly in the notch. When no text field is focused after dictation, the notch expands to offer prompt actions. The same UI is used when the prompt palette hotkey is pressed (standalone mode).

## State Machine

```
Current:  idle -> recording -> processing -> inserting -> idle
                                          -> error -> idle

New:      idle -> recording -> processing -> inserting -> idle          (text field found)
                                          -> promptSelection -> idle   (no text field / dismiss)
                                          -> promptSelection -> promptProcessing -> idle
                                          -> error -> idle
```

### New States

- `promptSelection(String)` - transcribed text is ready, user chooses a prompt action. The associated String is the text to process.
- `promptProcessing(String)` - LLM is running, the associated String is the prompt action name for display.

### Trigger Logic (Post-Dictation)

1. Transcription completes, text is ready
2. Check `hasFocusedTextField()` via Accessibility API
3. **Text field found**: normal flow - `insertText()` -> `.inserting`
4. **No text field**: copy to clipboard -> `.promptSelection(text)`
5. **Profile has prompt assigned**: always auto-process (existing behavior, no change)

### Trigger Logic (Standalone/Hotkey)

1. User presses prompt palette hotkey
2. Get text via `getSelectedText()` or clipboard content
3. -> `.promptSelection(text)`

## Notch UI

### promptSelection Layout

```
+------------------------------------------+
|          [Notch Hardware Area]            |
+------------------------------------------+
| "Transcribed text preview here,          |
|  showing what's in the clipboard..."     |
+------------------------------------------+
| icon  Action Name                    1   |  <- highlighted (selected)
| icon  Action Name                    2   |
| icon  Action Name                    3   |
| icon  Action Name                    4   |
| icon  Action Name                    5   |
+------------------------------------------+
|            [Esc] Close                   |
+------------------------------------------+
```

- Width: ~400-450px (wider than recording state)
- Scrollable if many actions
- Text preview limited to 2-3 lines with ellipsis

### promptProcessing Layout

```
+------------------------------------------+
|          [Notch Hardware Area]            |
+------------------------------------------+
| icon  Action Name...                     |
| [spinner]  Processing...                 |
+------------------------------------------+
```

After completion:
```
+------------------------------------------+
|          [Notch Hardware Area]            |
+------------------------------------------+
| checkmark  Copied to clipboard           |
+------------------------------------------+
```

- Purple/violet glow instead of blue (visual distinction from recording)
- Success display for ~2 seconds, then auto-dismiss to idle

### Interaction

**Keyboard:**
- Digits 1-9: direct selection
- Arrow up/down: navigate list
- Enter: confirm selection
- Esc: dismiss (text stays in clipboard)

**Mouse:**
- Hover: highlight row
- Click: select action

**Auto-dismiss:** 30 seconds of inactivity -> back to idle

## Component Changes

### TextInsertionService
- New: `hasFocusedTextField() -> Bool` - checks via AX API if focused element is a text input (role == kAXTextFieldRole or kAXTextAreaRole)

### DictationViewModel
- State enum: add `promptSelection(String)`, `promptProcessing(String)`
- New properties: `availablePromptActions: [PromptAction]`, `selectedPromptIndex: Int`, `promptResultText: String`
- New methods: `selectPromptAction(_:)`, `dismissPromptSelection()`
- Modified `stopDictation()`: check `hasFocusedTextField()` before deciding flow

### NotchIndicatorPanel
- `ignoresMouseEvents`: dynamic, `false` during `promptSelection`
- `canBecomeKey`: dynamic, `true` during `promptSelection`
- Key event handler for navigation (1-9, arrows, Enter, Esc)

### NotchIndicatorView
- New ViewBuilder for `promptSelection` state: text preview + scrollable action list
- New ViewBuilder for `promptProcessing` state: action name + spinner
- Purple glow during `promptProcessing`

### PromptPalettePanel
- Stays for now, hotkey rewired to trigger Notch UI instead
- Can be removed later once Notch integration is stable

## Not in Phase 1

- LLM response streaming (word-by-word display) - spinner + full result for now
- Removal of PromptPalettePanel
- Search/filter within the notch prompt list
