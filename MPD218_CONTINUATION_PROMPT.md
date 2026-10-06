# MPD218 Pad & Knob Setup — Continuation Prompt

The Launchpad Mini MK3 pattern-triggering work is now **fully confirmed
working end-to-end** — trigger pipeline, Programmer-mode note layout, and
the `n`/`s` pattern-ordering fix are all done, and Dom has confirmed the
Launchpad now triggers every pattern in `renaissance.tidal` correctly. That
thread is closed. This document starts a **new, separate task**: setting up
the Akai MPD218's pads and knobs.

Full project context (system stack, file locations, musical framework) is
in memory at `/projects/019d59a6-fafb-7387-8935-da577e9905b3/overview.md`,
`technical-learnings.md`, and `ways-of-working.md` — read those first
rather than assuming this document repeats everything. This file covers
only what's specific to the MPD218 task.

## Scope for this task (confirmed directly by Dom)

- 3 banks of 16 pads (48 pads total) should each trigger **an FX hit, a
  percussion sting, or some other one-shot sample** — sample-based
  one-shots, not the synth-triggered hits currently wired in.
- Dom will supply the actual samples himself. Which specific sample goes on
  which pad has **not been decided or discussed yet** — don't assume a
  layout, ask.
- Dom would also like to use the MPD218's 3 control banks of 6 rotary
  knobs (18 knobs total) for effects — but by his own explicit statement he
  does **not yet know what effects they'd control or how the audio routing
  would work**. Treat the knob side as genuinely unscoped, not a smaller
  version of the pad task. This needs a design conversation with Dom before
  any code gets written, not an implementation pass.

## Current implementation (read this before proposing changes)

The MPD218 is already fully wired up and working — for a *different*
purpose than what Dom now wants. Don't debug it; understand it, then decide
what to keep.

- **Architecture is deliberately simple and bypasses Tidal entirely.** Each
  pad is its own `MIDIdef.noteOn`, calling a shared `~earCandy` helper that
  sends a raw `/dirt/play` OSC message straight to SuperDirt via `~dirtAddr
  = NetAddr("127.0.0.1", 57120)` — SuperDirt's own listening port, not
  Tidal's control port (57160, which is what the Launchpad's OSC messages
  go through). There is no IORef, no grid, no `streamReplace` involved
  anywhere in the MPD218 path. For one-shot, fire-and-forget triggers this
  is almost certainly still the right shape — Tidal's pattern/stream
  semantics exist to solve a different problem than "play this hit once."
- **Currently triggers synths, not samples.** All 47 assigned pads
  (`\mpd_a1`–`\mpd_a16`, `\mpd_b1`–`\mpd_b16`, `\mpd_c1`–`\mpd_c15`) call
  `~earCandy.(instrumentName, note, vel, sustain, orbitIdx)`, where
  `instrumentName` is one of the existing renaissance SynthDefs (recorder,
  fiddle, crumhorn, cornett, rebec, pipe, dulcian, viol_consort,
  pluck_bright, lute, theorbo, harpsichord, virginal, sackbut_bass,
  tabor_snare, frame_drum, tambourine, drone) at a specific note. This is
  the part that needs to change to point at Dom's sample names instead —
  it's a real rework, not a re-map, since `~earCandy` currently takes
  `note` as a pitch for a synth, and a sample-based one-shot would more
  naturally take a sample name and index (`"s"`/`"n"` in the `/dirt/play`
  args) instead.
- **Bank C is only 15 pads, not 16 — the 16th slot is PANIC.** Pad indices
  run 0–15 (bank A), 16–31 (bank B), 32–46 (bank C, only `c1`–`c15`), with
  index **47** bound to `\mpd_panic` — a hush-all-and-clear-Launchpad-LEDs
  emergency stop, not a bank C content pad. Dom's "3 banks of 16" framing
  is the physical layout; the current code already carves one pad out of
  that grid for safety. Worth explicitly asking whether PANIC stays where
  it is (recommended — it's a genuinely useful live-safety feature) before
  any redesign assumes all 48 physical pads are available for samples.
- **All 3 banks currently route to the same place**: orbit 6 (d7,
  percussion/ear-candy) — consolidated there from an earlier per-bank
  spread across d5/d6/d7 (per `~earCandy`'s `orbitIdx` argument, currently
  hardcoded to `6` on every single call). Whether Dom wants the new
  one-shot pads to all stay on orbit 6, or split across orbits by bank or
  by sample type, hasn't been discussed — ask rather than assume either
  way.
- **The 18 knobs currently do nothing.** Each one (`MIDIdef.cc`, one per
  knob) just stores its normalized 0–1 value into an env var (`~mpdA1`
  … `~mpdC6`) and stops there — nothing reads any of them yet. This
  matches Dom's own statement that this side is unscoped.
- **Source filtering is simple** — a single `~mpdSrcID` (not the
  Launchpad's dual-port `~lpSrcID`/`~lpSrcID + 1` situation), discovered
  the same way as `~ezSrcID`. Nothing unusual to work around here.

## One risk worth checking before changing anything

`~earCandy`'s hand-built `/dirt/play` message has a leading placeholder
value right after the address, before the real key/value pairs. A shared
parser elsewhere in the file (`~parseDirtParams`, used by the visual-mirror
system in Sections 3f/3h) was specifically built to tolerate this — there's
a comment right above it explaining that a fixed-offset scan broke
silently because of this exact placeholder. If the new one-shot design
changes the shape of the outgoing `/dirt/play` message (different argument
order, no placeholder, etc.), check whether that mirror/parser still
matches correctly. Not a reason to preserve the old message shape
unnecessarily — just something to verify rather than discover later as an
unrelated-looking bug.

## Gotcha with precedent, worth flagging to Dom early

The `loop_release_1`–`8` samples (Launchpad orbit 8) are silent because
their sample folder (`/media/projects/Audio/Samples/release-current/`) is
confirmed empty — SuperDirt just prints "no synth or sample named
'release-current' could be found" and moves on, easy to miss in a busy
post window. When Dom adds his own one-shot samples for the MPD218, worth
confirming early that the actual sample files exist in whatever folder(s)
SuperDirt expects, rather than only discovering it the same way this
project already has once.

## Where the relevant code lives

- `startup.scd` — Section 3e "AKAI MPD218 EAR CANDY" (currently ~line
  510–603): the `~earCandy` helper, all 47 pad `MIDIdef.noteOn` calls,
  `\mpd_panic`, and the 18 spare-knob `MIDIdef.cc` calls. This is the
  section to rework.
- `startup.scd` header (top of file) — the SC 3.11 hard rules (`var`
  declaration placement, the vel > 63 NoteOff-arrives-as-NoteOn guard,
  no `SystemClock.sched` in SysEx callbacks, etc.). Any new `MIDIdef.noteOn`
  added here needs to follow these the same way the existing ones do —
  read them before adding pad definitions, don't rediscover them the hard
  way.
- `~dirtAddr` definition — `startup.scd`, ~line 180.
- `~mpdSrcID` discovery — `startup.scd`, ~line 161–176 (same
  scan-and-match pattern as `~ezSrcID`).
- `~parseDirtParams` and its explanatory comment — `startup.scd`, ~line
  606–639 (the risk noted above).
- `BootTidal.hs` header comment (~line 5–20) has the authoritative,
  currently-correct orbit table (d1 soprano/orbit 0 through d8
  loops/orbit 7, with MPD218's current routing noted against d7) — a
  cleaner reference than re-deriving it from `renaissance.tidal`'s section
  comments, which use their own row-numbering convention that doesn't map
  1:1 onto physical anything.

## Suggested order of work

1. Clarify with Dom before touching code: which pad(s) get which sample
   (or whether he wants an auto-mapping scheme — e.g. "load whatever's in
   folder X, pad N = the Nth file" — instead of naming all 48 by hand);
   whether orbit 6 stays the target for everything or splits by
   bank/type; and confirm Pad 47 stays PANIC.
2. Given 48 individual hardcoded `MIDIdef.noteOn` calls is a lot of
   repetition, and the exact sample-to-pad mapping is going to change as
   Dom adds content, consider proposing a data-driven version — an
   array/dictionary of `(padIndex -> sampleName)` feeding one shared
   `MIDIdef.noteOn` per bank (or one shared dispatcher keyed by note
   number) — rather than preserving 48 near-identical lines. Worth raising
   as a suggestion, not assuming Dom wants a rewrite of the structure
   versus a like-for-like content swap.
3. Rework `~earCandy` (or a new equivalent helper) to trigger samples
   (`"s"`/`"n"` args) rather than synth pitches, once the above is settled.
4. Check the `~parseDirtParams` risk noted above against whatever new
   message shape results.
5. Only after pads are working: come back to the knobs as its own design
   conversation — what effect(s) to build, and how they'd hook into the
   existing per-orbit reverb/gain chain (`~orbitBuses` → `~reverbSynths` →
   `~postReverbBuses` → `~gainControlSynths`, all in `startup.scd`) or
   whether they need a new stage of their own.
