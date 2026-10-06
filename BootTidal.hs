-- ============================================================
-- BootTidal.hs
-- Renaissance Counterpoint Live Performance System
-- TidalCycles 1.9.5 / SuperDirt 1.7.2 / SuperCollider 3.11.2
-- JACK 48000 Hz / Rubix24 stereo interface
-- File location: /media/projects/TidalCycles/BootTidal.hs
--
-- Orbit layout (matches EZ-Creator fader rows in startup.scd):
--   d1  orbit 0  Soprano / soprano counter  (recorder, cornett, fiddle, pipe)
--   d2  orbit 1  Alto / alto counter        (viol_consort, crumhorn)
--   d3  orbit 2  Tenor / tenor counter      (viol_consort, crumhorn)
--   d4  orbit 3  Bass                       (dulcian, sackbut_bass, theorbo low)
--   d5  orbit 4  Chords / arpeggio          (harpsichord, virginal, clavichord, lute)
--   d6  orbit 5  Pulse / drone              (drone, pluck_bright pulse, hurdy_gurdy_bagpipes)
--   d7  orbit 6  Percussion / ear candy     (tabor_snare, frame_drum, nakers)
--   d8  orbit 7  Loops / embellishment      (release-current samples: triggered
--                                            whole via Launchpad, or sliced
--                                            live via chop/striate at the prompt)
--   (MPD218's 48 sample pads are not a Tidal stream and use no orbit at
--    all: MIDI note on -> PlayBuf -> Out.ar(0, ...) directly, in
--    startup.scd Section 3e)
--   V   (mic + Microkorg, not a numbered stream -- see startup.scd EZ-Creator V
--        channel. Microphone is pure SC-side passthrough+FX, never touched by
--        Tidal. Microkorg's own audio is the same passthrough, but the
--        instrument itself is separately live-codable via Tidal MIDI-out
--        through the Midihub -- s "microkorg" patterns, dispatched via any
--        stream above d8 (d9 etc, since these carry no audio and don't use
--        the SATB orbit chain at all). See renaissance.tidal SECTION 11B
--        for parameter conventions and test patterns.)
-- ============================================================

:set -XOverloadedStrings
:set prompt ""

import Sound.Tidal.Context

import System.IO (hSetEncoding, stdout, utf8)
hSetEncoding stdout utf8

-- OSC listener for hardware controller bridge from SuperCollider.
-- hosc-0.20 renamed the module from Sound.OSC.FD to Sound.Osc.Fd.
-- If this still fails, check: ghc-pkg list hosc
-- The Datum constructors (Int32, Float, Double) come from this import.
import Sound.Osc.Fd
import Control.Concurrent (forkIO)
import Control.Monad (forever, void)
import Data.IORef
-- `when` is omitted here: Control.Monad.when conflicts with
-- Sound.Tidal.Context.when (a pattern function). The one monadic
-- `when` usage in soloOrb is replaced with an explicit `if` below.

-- total latency = oLatency + cFrameTimespan
tidal <- startTidal (superdirtTarget {oLatency = 0.2, oAddress = "127.0.0.1", oPort = 57120}) (defaultConfig {cVerbose = True, cFrameTimespan = 1/20})

-- ============================================================
-- CORE STREAM CONTROLS, TRANSITIONS, ORBIT ASSIGNMENTS
-- AND CUSTOM PARAMETERS
-- (All original content preserved exactly)
-- ============================================================

:{
let only = (hush >>)
    p = streamReplace tidal
    hush = streamHush tidal
    panic = do hush
               once $ sound "superpanic"
    list = streamList tidal
    mute = streamMute tidal
    unmute = streamUnmute tidal
    unmuteAll = streamUnmuteAll tidal
    solo = streamSolo tidal
    unsolo = streamUnsolo tidal
    once = streamOnce tidal
    first = streamFirst tidal
    asap = once
    nudgeAll = streamNudgeAll tidal
    all = streamAll tidal
    resetCycles = streamResetCycles tidal
    setcps = asap . cps
    getcps = streamGetcps tidal
    getnow = streamGetnow tidal
    xfade i = transition tidal True (Sound.Tidal.Transition.xfadeIn 4) i
    xfadeIn i t = transition tidal True (Sound.Tidal.Transition.xfadeIn t) i
    histpan i t = transition tidal True (Sound.Tidal.Transition.histpan t) i
    wait i t = transition tidal True (Sound.Tidal.Transition.wait t) i
    waitT i f t = transition tidal True (Sound.Tidal.Transition.waitT f t) i
    jump i = transition tidal True (Sound.Tidal.Transition.jump) i
    jumpIn i t = transition tidal True (Sound.Tidal.Transition.jumpIn t) i
    jumpIn' i t = transition tidal True (Sound.Tidal.Transition.jumpIn' t) i
    jumpMod i t = transition tidal True (Sound.Tidal.Transition.jumpMod t) i
    mortal i lifespan release = transition tidal True (Sound.Tidal.Transition.mortal lifespan release) i
    interpolate i = transition tidal True (Sound.Tidal.Transition.interpolate) i
    interpolateIn i t = transition tidal True (Sound.Tidal.Transition.interpolateIn t) i
    clutch i = transition tidal True (Sound.Tidal.Transition.clutch) i
    clutchIn i t = transition tidal True (Sound.Tidal.Transition.clutchIn t) i
    anticipate i = transition tidal True (Sound.Tidal.Transition.anticipate) i
    anticipateIn i t = transition tidal True (Sound.Tidal.Transition.anticipateIn t) i
    forId i t = transition tidal False (Sound.Tidal.Transition.mortalOverlay t) i
    d1 = p 1 . (|< orbit 0)
    d2 = p 2 . (|< orbit 1)
    d3 = p 3 . (|< orbit 2)
    d4 = p 4 . (|< orbit 3)
    d5 = p 5 . (|< orbit 4)
    d6 = p 6 . (|< orbit 5)
    d7 = p 7 . (|< orbit 6)
    d8 = p 8 . (|< orbit 7)
    d9 = p 9 . (|< orbit 8)
    d10 = p 10 . (|< orbit 9)
    d11 = p 11 . (|< orbit 10)
    d12 = p 12 . (|< orbit 11)
    d13 = p 13 . (|< orbit 12)
    d14 = p 14 . (|< orbit 13)
    d15 = p 15 . (|< orbit 14)
    d16 = p 16 . (|< orbit 15)

    -- ── Custom parameters ─────────────────────────────────
    -- timbre :: Pattern Double  (0.0–1.0)
    -- Timbral modifier passed to SynthDef \timbre arg.
    -- Instrument-specific meaning: brightness (harpsichord/virginal),
    -- bow pressure (fiddle/viol_consort/rebec), reed width
    -- (crumhorn/dulcian), breath noise (recorder/pipe/air_noise).
    timbre       = pF "timbre"

    -- vibratoDepth :: Pattern Double  (0.0–1.0, default 0.0)
    -- Passed to melodic SynthDefs that implement vibrato.
    -- Period-appropriate values:
    --   fiddle/rebec  0.02–0.05   gut string, arm vibrato
    --   vocal         0.03–0.08   natural voice, restrained
    --   viol_consort  0.01–0.03   very gentle bow arm vibrato
    --   recorder      0.0         straight tone (authentic)
    --   crumhorn      0.0         double reed, no vibrato
    vibratoDepth = pF "vibratoDepth"

    -- scaleName :: Pattern String
    -- Selects the microtonal tuning table built in mySynths.scd.
    -- The DirtEvent.sc patch intercepts every event after calcTimeSpan
    -- and rewrites ~freq from the named lookup table (t[snKey][midi]).
    -- Falls back to 12TET if scaleName is absent or unrecognised.
    -- See microtonal system documentation for full scale list.
    scaleName    = pS "scaleName"

    -- midichan :: Pattern Int  (0-15, default 0 if absent)
    -- MIDI channel for s "microkorg" / "external" / "midihub" patterns --
    -- read by the \midiMirror OSCdef in startup.scd (Section 3f), NOT
    -- part of standard SuperDirt. Only matters for those three sound
    -- names; has no effect on ordinary SuperDirt-triggered patterns.
    midichan     = pI "midichan"
:}

-- mkorg: like d1-d16, but deliberately WITHOUT their automatic orbit
-- tagging (d9 = p 9 . (|< orbit 8) -- and orbit 8 doesn't exist, only
-- orbits 0-7 are configured for d1-d8, so d9 makes SuperDirt reject the
-- event outright: "event falls out of existing orbits, index (8)").
-- s "microkorg"/"external"/"midihub" patterns don't need an orbit at all
-- -- they never reach SuperDirt's audio engine, startup.scd's
-- \midiMirror OSCdef intercepts them before that and sends real MIDI
-- instead -- so this uses streamReplace directly, same primitive the
-- Launchpad handler above uses, just on stream slot 9 (shares that slot
-- with d9 -- fine while d9 itself is unused, but don't use both at once).
let mkorg = streamReplace tidal 9

:{
let setI = streamSetI tidal
    setF = streamSetF tidal
    setS = streamSetS tidal
    setR = streamSetR tidal
    setB = streamSetB tidal
:}

-- ============================================================
-- SCALE / MODE SHORTHAND BINDINGS
-- ============================================================
-- Convenience aliases for all loaded tuning tables.
-- Use in pattern chains instead of typing scaleName "..." each time.
--
-- Examples:
--   d1 $ s "recorder" # n "0 2 4 5 7" # meantone
--   d2 $ s "viol_consort" # n "0 3 5 7" # aeolianA
--   d4 $ s "harpsichord" # n "0 4 7 11" # dorianD
--
-- For ensemble retuning: assign a scale shorthand to a variable,
-- reference that variable in all pattern chains, and change it once.
--   let mode = aeolianA
--   d1 $ s "recorder" # n "0 2 4" # mode
--   d2 $ s "viol_consort" # n "0 3 5" # mode
--   -- Now: let mode = dorianD   then re-evaluate d1 and d2

:{
let meantone      = scaleName "meanquar"

    -- Aeolian (natural minor) — most common renaissance mode
    aeolianA      = scaleName "A_JI_Aeolian"
    aeolianAsh    = scaleName "A#_JI_Aeolian"
    aeolianB      = scaleName "B_JI_Aeolian"
    aeolianC      = scaleName "C_JI_Aeolian"
    aeolianCsh    = scaleName "C#_JI_Aeolian"
    aeolianD      = scaleName "D_JI_Aeolian"
    aeolianDsh    = scaleName "D#_JI_Aeolian"
    aeolianE      = scaleName "E_JI_Aeolian"
    aeolianF      = scaleName "F_JI_Aeolian"
    aeolianFsh    = scaleName "F#_JI_Aeolian"
    aeolianG      = scaleName "G_JI_Aeolian"
    aeolianGsh    = scaleName "G#_JI_Aeolian"

    -- Dorian — common for dance forms, minor-feeling pavane and galliard
    dorianA       = scaleName "A_JI_Dorian"
    dorianAsh     = scaleName "A#_JI_Dorian"
    dorianB       = scaleName "B_JI_Dorian"
    dorianC       = scaleName "C_JI_Dorian"
    dorianCsh     = scaleName "C#_JI_Dorian"
    dorianD       = scaleName "D_JI_Dorian"
    dorianDsh     = scaleName "D#_JI_Dorian"
    dorianE       = scaleName "E_JI_Dorian"
    dorianF       = scaleName "F_JI_Dorian"
    dorianFsh     = scaleName "F#_JI_Dorian"
    dorianGsh     = scaleName "G#_JI_Dorian"

    -- Ionian (major) — galliard, saltarello, festive dances
    ionianA       = scaleName "A_JI_Ionian"
    ionianAsh     = scaleName "A#_JI_Ionian"
    ionianB       = scaleName "B_JI_Ionian"
    ionianC       = scaleName "C_JI_Ionian"
    ionianCsh     = scaleName "C#_JI_Ionian"
    ionianD       = scaleName "D_JI_Ionian"
    ionianDsh     = scaleName "D#_JI_Ionian"
    ionianE       = scaleName "E_JI_Ionian"
    ionianF       = scaleName "F_JI_Ionian"
    ionianFsh     = scaleName "F#_JI_Ionian"
    ionianG       = scaleName "G_JI_Ionian"
    ionianGsh     = scaleName "G#_JI_Ionian"

    -- Phrygian — archaic, Spanish-tinged, estampie
    phrygianA     = scaleName "A_JI_Phrygian"
    phrygianAsh   = scaleName "A#_JI_Phrygian"
    phrygianB     = scaleName "B_JI_Phrygian"
    phrygianC     = scaleName "C_JI_Phrygian"
    phrygianCsh   = scaleName "C#_JI_Phrygian"
    phrygianD     = scaleName "D_JI_Phrygian"
    phrygianDsh   = scaleName "D#_JI_Phrygian"
    phrygianE     = scaleName "E_JI_Phrygian"
    phrygianF     = scaleName "F_JI_Phrygian"
    phrygianFsh   = scaleName "F#_JI_Phrygian"
    phrygianG     = scaleName "G_JI_Phrygian"
    phrygianGsh   = scaleName "G#_JI_Phrygian"

    -- Lydian — elevated, upward quality, fanfare-like
    lydianA       = scaleName "A_JI_Lydian"
    lydianAsh     = scaleName "A#_JI_Lydian"
    lydianB       = scaleName "B_JI_Lydian"
    lydianC       = scaleName "C_JI_Lydian"
    lydianCsh     = scaleName "C#_JI_Lydian"
    lydianD       = scaleName "D_JI_Lydian"
    lydianDsh     = scaleName "D#_JI_Lydian"
    lydianE       = scaleName "E_JI_Lydian"
    lydianF       = scaleName "F_JI_Lydian"
    lydianFsh     = scaleName "F#_JI_Lydian"
    lydianG       = scaleName "G_JI_Lydian"
    lydianGsh     = scaleName "G#_JI_Lydian"

    -- Mixolydian — modal, bagpipe-adjacent, hurdy-gurdy music
    mixolydianA   = scaleName "A_JI_Mixolydian"
    mixolydianAsh = scaleName "A#_JI_Mixolydian"
    mixolydianB   = scaleName "B_JI_Mixolydian"
    mixolydianC   = scaleName "C_JI_Mixolydian"
    mixolydianCsh = scaleName "C#_JI_Mixolydian"
    mixolydianD   = scaleName "D_JI_Mixolydian"
    mixolydianDsh = scaleName "D#_JI_Mixolydian"
    mixolydianE   = scaleName "E_JI_Mixolydian"
    mixolydianF   = scaleName "F_JI_Mixolydian"
    mixolydianFsh = scaleName "F#_JI_Mixolydian"
    mixolydianG   = scaleName "G_JI_Mixolydian"
    mixolydianGsh = scaleName "G#_JI_Mixolydian"

    -- Locrian — rare, unstable, theoretical
    locrianA      = scaleName "A_JI_Locrian"
    locrianAsh    = scaleName "A#_JI_Locrian"
    locrianB      = scaleName "B_JI_Locrian"
    locrianC      = scaleName "C_JI_Locrian"
    locrianCsh    = scaleName "C#_JI_Locrian"
    locrianD      = scaleName "D_JI_Locrian"
    locrianDsh    = scaleName "D#_JI_Locrian"
    locrianE      = scaleName "E_JI_Locrian"
    locrianF      = scaleName "F_JI_Locrian"
    locrianFsh    = scaleName "F#_JI_Locrian"
    locrianG      = scaleName "G_JI_Locrian"
    locrianGsh    = scaleName "G#_JI_Locrian"

    -- Chromatic JI — chromatic passages, musica ficta
    chromaticA    = scaleName "A_JI_Chromatic"
    chromaticAsh  = scaleName "A#_JI_Chromatic"
    chromaticB    = scaleName "B_JI_Chromatic"
    chromaticC    = scaleName "C_JI_Chromatic"
    chromaticCsh  = scaleName "C#_JI_Chromatic"
    chromaticD    = scaleName "D_JI_Chromatic"
    chromaticDsh  = scaleName "D#_JI_Chromatic"
    chromaticE    = scaleName "E_JI_Chromatic"
    chromaticF    = scaleName "F_JI_Chromatic"
    chromaticFsh  = scaleName "F#_JI_Chromatic"
    chromaticG    = scaleName "G_JI_Chromatic"
    chromaticGsh  = scaleName "G#_JI_Chromatic"

    -- Special scales
    ahavaRaba     = scaleName "Ahava_Raba"
    victoryScale  = scaleName "victory"
:}

-- ============================================================
-- TEMPO HELPERS — RENAISSANCE DANCE FORMS
-- ============================================================
-- setcps is defined above (asap . cps).
-- One cycle = one bar. All values are starting points; adjust by ear.
--
-- cps/bpm conversion for 4-beat bars: cps = bpm / 60 / 4
-- For 3-beat bars (galliard, courante): cps = bpm / 60 / 3
-- but it is simpler to keep 4-beat bars and write 3/4 patterns as
-- e.g.  n "0 2 4 ~ 0 2 4 ~"  (3 notes + rest per group).
--
-- Evaluate a single line with Ctrl-E to change tempo live:
--
--   setcps 0.22   -- Pavane stately:        ~53 bpm  (4/4)
--   setcps 0.25   -- Pavane moderate:       ~60 bpm  (4/4)
--   setcps 0.28   -- Allemande flowing:     ~67 bpm  (4/4)
--   setcps 0.30   -- Courante light:        ~72 bpm  (4/4)
--   setcps 0.33   -- Galliard bright:       ~80 bpm  (4/4)
--   setcps 0.38   -- Galliard lively:       ~91 bpm  (4/4)
--   setcps 0.40   -- Saltarello moderate:   ~96 bpm  (4/4)
--   setcps 0.42   -- Estampie driving:     ~101 bpm  (4/4)
--   setcps 0.47   -- Saltarello fast:      ~113 bpm  (4/4)
--   setcps 0.50   -- Estampie energetic:   ~120 bpm  (4/4)

-- ============================================================
-- COUNTERPOINT AND COMPOSITIONAL HELPERS
-- ============================================================

:{
-- Voice layering — for voices that must move together as a unit.
-- For independent voices with separate fader gain and FX, always
-- use d1..d8 directly with separate orbit assignments.
let cp  a b     = stack [a, b]
    cp3 a b c   = stack [a, b, c]
    cp4 a b c e = stack [a, b, c, e]

-- Rhythmic augmentation and diminution (classical counterpoint terms).
    aug   = slow 2      -- double all durations   (augmentation)
    dim   = fast 2      -- halve all durations    (diminution)
    aug3  = slow 3      -- triple augmentation

-- Hocket: medieval technique, voices interlock by filling each other's rests.
-- Apply hocketA to one voice and hocketB to another playing the same pattern.
-- For three-voice hocket use hocketA3/B3/C3.
    hocketA  p' = mask "1 0" p'
    hocketB  p' = mask "0 1" p'
    hocketA3 p' = mask "1 0 0" p'
    hocketB3 p' = mask "0 1 0" p'
    hocketC3 p' = mask "0 0 1" p'

-- Isorhythm: impose a rhythmic structure (talea) on a pitch sequence
-- (color) independently. Both cycle at their own lengths.
-- Central technique in Ars Nova. The shift between talea and color
-- creates slow long-range variation across many cycles.
-- Usage:
--   d1 $ iso "t f t t f t f t" (n "0 2 4 5 7 9" # s "viol_consort")
    iso talea color = struct talea color

-- Canon at the unison: delay voice B by n cycles relative to voice A.
-- usage: let mel = n "0 2 4 5" # s "recorder"
--        d1 $ mel
--        d2 $ canon 1 mel     -- voice enters one bar later
--        d2 $ canon 0.5 mel   -- stretto, half bar later
    canon n' p' = rotL (toRational n') p'
    stretto p'  = rotL 0.5 p'

-- Estampie ouvert/clos structure: phrase played twice with open/close endings.
-- phrase played: A–ouvert, A–clos (i.e. repeat with different cadence)
-- usage: d1 $ estampie ouvertPat closPat
    estampie a b = cat [a, b]
    estampieRep a b = cat [a, a, b]   -- full form: A A B

-- Proportional notation shortcuts (mensural music relationships)
    prop23 = fast (2/3)    -- sesquialtera: 3 notes in space of 2
    prop32 = slow (2/3)    -- reverse: 2 notes in space of 3
    prop34 = slow (3/4)    -- tripla: 4 notes in space of 3
    prop43 = fast (3/4)    -- reverse: 3 notes in space of 4

-- Ornament helper: apply diminution to a random subset of events.
-- Simulates selective ornamentation (not every note gets a trill).
-- chance is a probability 0.0–1.0.
    ornamentBy chance p' = sometimesBy chance (fast 2) p'
    ornament             = ornamentBy 0.3

-- Transpose a pattern by n semitone steps (adds to note values).
-- Note: the microtonal system maps note→freq per scale degree.
-- Transposing by 7 (a fifth) within a diatonic scale gives the
-- correct JI fifth only if both degrees exist in the scale table.
-- For exact JI transposition, change the scaleName root instead.
    trans n' p' = p' |+ note n'
:}

-- ============================================================
-- PERFORMANCE ORBIT UTILITIES
-- ============================================================

-- fadeOut: morph orbit i to silence over n cycles.
let fadeOut n' i = xfadeIn i n' silence
-- fadeIn: morph silence to pattern p over n cycles on orbit i.
let fadeIn n' i p' = xfadeIn i n' p'
-- Solo orbit n: silence all other orbits 1-8.
let soloOrb n' = mapM_ (\o -> if (o /= n') then p o silence else return ()) [1,2,3,4,5,6,7,8]
-- Mute all orbits (alias for hush).
let muteAll = hush

-- ============================================================
-- LAUNCHPAD MINI MK3 — PATTERN SLOT TABLE
-- ============================================================
-- The Launchpad grid maps to 8 orbits × 8 pattern slots.
-- Row = orbit (row 8 at top = d1, row 1 at bottom = d8 in SC mapping).
-- Column = slot number (1–8 left to right).
--
-- WHY THIS IS AN IORef, NOT A PLAIN `let`:
--   startControlThread (below) is defined ONCE, when this file loads,
--   and its OSC handler closes over whatever `launchpadGrid` means AT
--   THAT MOMENT. In GHCi, a later `let launchpadGrid = ...` (e.g. from
--   renaissance.tidal, once real patterns exist) creates a NEW,
--   separate binding — it shadows the name for anything typed
--   afterwards, but it does NOT rewrite the closure inside the
--   already-defined startControlThread, which keeps referencing the
--   OLD (placeholder/silence) grid forever. Calling startControlThread
--   again doesn't help either — calling re-runs the existing compiled
--   body, it doesn't recompile it. A plain `let` here would make every
--   Launchpad press silently play `silence` no matter what
--   renaissance.tidal says.
--   An IORef sidesteps this: the listener reads the CURRENT contents
--   of the reference on every incoming message, so updating the
--   reference's contents (not the name) after the fact works exactly
--   as expected, however many times you do it, however many times
--   startControlThread itself has already been called.
--
--   SECOND PITFALL, same root cause: every slot below starts as
--   `silence`, which is fully polymorphic (Pattern a — works as any
--   pattern type, not just ControlPattern). newIORef has no other
--   clue what concrete type to commit to, so without an explicit
--   annotation GHC defaults it to GHC.Types.Any instead of
--   ControlPattern — which then makes handleMsg's use of the grid
--   fail to typecheck, which in turn makes startControlThread fail to
--   compile at all ("Variable not in scope" when called, even though
--   it's right there in the file). The `:: [[ControlPattern]]` on the
--   newIORef call below is load-bearing — don't remove it even though
--   it looks redundant once renaissance.tidal's real patterns (which
--   already are ControlPattern) get written in later.
--
-- SETUP WORKFLOW:
--   1. Define pattern variables in renaissance.tidal (Deliverable 3).
--   2. At the end of renaissance.tidal (after all patterns exist),
--      ONE line: writeIORef launchpadGridRef [[...],[...],...]
--      renaissance.tidal builds and evaluates this for you — see its
--      final section. No further steps needed here; startControlThread
--      is already running (started automatically at the end of this
--      file) and will pick up the update on the very next OSC message.
--   3. SuperCollider (startup.scd) sends /launchpad/on <orbit> <slot>
--      via OSC to port 57160. startControlThread receives it, reads
--      launchpadGridRef fresh, and calls streamReplace with the
--      pattern at that slot.
--
-- LED feedback is managed entirely by SuperCollider (startup.scd).
-- When a slot triggers, SC lights the pad amber. When silenced, dim.
-- SC tracks active slots per orbit in its own state array.

let slot_1_1 = silence
let slot_1_2 = silence
let slot_1_3 = silence
let slot_1_4 = silence
let slot_1_5 = silence
let slot_1_6 = silence
let slot_1_7 = silence
let slot_1_8 = silence
let slot_2_1 = silence
let slot_2_2 = silence
let slot_2_3 = silence
let slot_2_4 = silence
let slot_2_5 = silence
let slot_2_6 = silence
let slot_2_7 = silence
let slot_2_8 = silence
let slot_3_1 = silence
let slot_3_2 = silence
let slot_3_3 = silence
let slot_3_4 = silence
let slot_3_5 = silence
let slot_3_6 = silence
let slot_3_7 = silence
let slot_3_8 = silence
let slot_4_1 = silence
let slot_4_2 = silence
let slot_4_3 = silence
let slot_4_4 = silence
let slot_4_5 = silence
let slot_4_6 = silence
let slot_4_7 = silence
let slot_4_8 = silence
let slot_5_1 = silence
let slot_5_2 = silence
let slot_5_3 = silence
let slot_5_4 = silence
let slot_5_5 = silence
let slot_5_6 = silence
let slot_5_7 = silence
let slot_5_8 = silence
let slot_6_1 = silence
let slot_6_2 = silence
let slot_6_3 = silence
let slot_6_4 = silence
let slot_6_5 = silence
let slot_6_6 = silence
let slot_6_7 = silence
let slot_6_8 = silence
let slot_7_1 = silence
let slot_7_2 = silence
let slot_7_3 = silence
let slot_7_4 = silence
let slot_7_5 = silence
let slot_7_6 = silence
let slot_7_7 = silence
let slot_7_8 = silence
let slot_8_1 = silence
let slot_8_2 = silence
let slot_8_3 = silence
let slot_8_4 = silence
let slot_8_5 = silence
let slot_8_6 = silence
let slot_8_7 = silence
let slot_8_8 = silence
-- launchpadGridRef now holds a LIST OF PAGES (each page is the same 8x8
-- shape as before) so the top-row arrow buttons can page through more
-- than 64 patterns; launchpadPageRef tracks which page is current.
-- This placeholder starts with a single page — renaissance.tidal's last
-- line (below, via :script) overwrites it with the real page(s).
launchpadGridRef <- newIORef ([[[slot_1_1,slot_1_2,slot_1_3,slot_1_4,slot_1_5,slot_1_6,slot_1_7,slot_1_8],[slot_2_1,slot_2_2,slot_2_3,slot_2_4,slot_2_5,slot_2_6,slot_2_7,slot_2_8],[slot_3_1,slot_3_2,slot_3_3,slot_3_4,slot_3_5,slot_3_6,slot_3_7,slot_3_8],[slot_4_1,slot_4_2,slot_4_3,slot_4_4,slot_4_5,slot_4_6,slot_4_7,slot_4_8],[slot_5_1,slot_5_2,slot_5_3,slot_5_4,slot_5_5,slot_5_6,slot_5_7,slot_5_8],[slot_6_1,slot_6_2,slot_6_3,slot_6_4,slot_6_5,slot_6_6,slot_6_7,slot_6_8],[slot_7_1,slot_7_2,slot_7_3,slot_7_4,slot_7_5,slot_7_6,slot_7_7,slot_7_8],[slot_8_1,slot_8_2,slot_8_3,slot_8_4,slot_8_5,slot_8_6,slot_8_7,slot_8_8]]] :: [[[ControlPattern]]])
launchpadPageRef <- newIORef (0 :: Int)

-- ============================================================
-- CONTROLLER OSC LISTENER — port 57160
-- ============================================================
-- SuperCollider (startup.scd) translates all hardware controller
-- events (Launchpad, EZ-Creator, MPD218) into OSC messages and
-- sends them here on localhost:57160. This keeps SuperCollider
-- as the single owner of all hardware MIDI/USB, and Tidal as
-- the single owner of all pattern state.
--
-- PROTOCOL — messages SC sends to port 57160:
--
--   /launchpad/on  <orbit:Int32> <slot:Int32>
--       SC sends this when a Launchpad pad is pressed and that
--       orbit is currently silent. Triggers the pattern currently at
--       launchpadGridRef[page][orbit-1][slot-1] on orbit via streamReplace
--       (read fresh from the IORef on every message — see the
--       PATTERN SLOT TABLE section above for why it's a ref). "page" is
--       whatever launchpadPageRef currently holds.
--
--   /launchpad/off <orbit:Int32>
--       SC sends this on second press of an active pad. Silences
--       the orbit. LED is dimmed by SC independently.
--
--   /launchpad/page <delta:Int32>
--       Sent from the Launchpad's top-row arrow buttons. delta is +1
--       (next) or -1 (prev); the page index wraps modulo however many
--       pages are currently in launchpadGridRef, so adding more pages
--       later doesn't require touching this handler. Only changes which
--       page subsequent /launchpad/on presses read from — on its own it
--       doesn't silence or retrigger anything already playing.
--
--   /tempo/cps     <value:Float>
--       Remote tempo set in cycles-per-second. SC sends this from
--       the EZ-Creator crossfader at top end, or from MPD knob.
--
--   /tempo/bpm     <value:Float>
--       Remote tempo set in BPM (4/4 assumed, cps = bpm / 60 / 4).
--
--   /hush
--       Emergency silence all orbits. Sent from EZ-Creator mute-all
--       button combination (faders 1+8 pressed together in SC).
--
-- USAGE:
--   startControlThread runs automatically at the end of this file (see
--   BOOT COMPLETE below) — no manual call needed. It runs in a
--   background thread and does not block the GHCi prompt. Errors are
--   printed to the terminal. Updating patterns later never requires
--   re-calling it: just update launchpadGridRef's contents (renaissance.tidal
--   does this as its last step).

:{
startControlThread :: IO ()
startControlThread = do
    sock <- udpServer "127.0.0.1" 57160
    putStrLn "=== Controller listener active on 127.0.0.1:57160 ==="
    void $ forkIO $ forever $ do
        pkt <- recvPacket sock
        mapM_ handleMsg (packetMessages pkt)
  where
    clamp lo hi = max lo . min hi

    handleMsg msg = do
        let addr = messageAddress msg
            args = messageDatum msg
        putStrLn $ "OSC RECEIVED: addr=" ++ show addr ++ " args=" ++ show args
        case addr of

          "/launchpad/on" ->
            case args of
              [Int32 orb, Int32 slot] -> do
                allPages <- readIORef launchpadGridRef
                page     <- readIORef launchpadPageRef
                let pageCount = max 1 (length allPages)
                    pg       = clamp 0 (pageCount - 1) page :: Int
                    grid     = allPages !! pg
                    oi       = clamp 0 7 (fromIntegral orb  - 1) :: Int
                    si       = clamp 0 7 (fromIntegral slot - 1) :: Int
                    basePat  = (grid !! oi) !! si
                    -- d1-d16 tag their pattern with orbit automatically
                    -- (d1 = p 1 . (|< orbit 0), i.e. stream slot is
                    -- 1-indexed but the orbit parameter is 0-indexed —
                    -- two different numbering schemes). streamReplace
                    -- called directly, as here, does neither on its own:
                    -- it only places the pattern in the right stream
                    -- slot, so without this every triggered pattern
                    -- fell through to SuperDirt's own default (orbit 0
                    -- for all of them, regardless of which row/orbit
                    -- was actually pressed).
                    taggedPat = basePat # orbit (pure (fromIntegral orb - 1 :: Int))
                putStrLn $ "Launchpad: streamReplace d" ++ show orb ++ " (page " ++ show pg ++ " slot " ++ show si ++ ")"
                streamReplace tidal (fromIntegral orb) taggedPat
              _ -> putStrLn "Warning /launchpad/on: unexpected args"

          "/launchpad/off" ->
            case args of
              [Int32 orb] ->
                streamReplace tidal (fromIntegral orb) silence
              _ -> putStrLn "Warning /launchpad/off: unexpected args"

          "/launchpad/page" ->
            case args of
              [Int32 delta] -> do
                allPages <- readIORef launchpadGridRef
                page     <- readIORef launchpadPageRef
                let pageCount = max 1 (length allPages)
                    newPage   = (page + fromIntegral delta) `mod` pageCount
                writeIORef launchpadPageRef newPage
                putStrLn $ "Launchpad page: " ++ show newPage ++ " of " ++ show pageCount
              _ -> putStrLn "Warning /launchpad/page: unexpected args"

          "/tempo/cps" ->
            case args of
              [Float  v] -> streamOnce tidal $ cps (realToFrac v)
              [Double v] -> streamOnce tidal $ cps (realToFrac v)
              _          -> putStrLn "Warning /tempo/cps: unexpected args"

          "/tempo/bpm" ->
            case args of
              [Float  v] -> streamOnce tidal $ cps (realToFrac v / 60 / 4)
              [Double v] -> streamOnce tidal $ cps (realToFrac v / 60 / 4)
              _          -> putStrLn "Warning /tempo/bpm: unexpected args"

          "/hush"    -> streamHush tidal

          other      -> putStrLn $ "Controller: unhandled OSC: " ++ other
:}

-- ============================================================
-- BOOT COMPLETE
-- ============================================================

:set prompt "tidal> "
:set prompt-cont ""

startControlThread

putStrLn ""
putStrLn "================================================================"
putStrLn " Renaissance Counterpoint — TidalCycles 1.9.5 ready"
putStrLn " Orbits d1–d8 | meanquar default | pS scaleName active"
putStrLn ""
putStrLn " Params:    # scaleName \"A_JI_Aeolian\"  (or shorthand # aeolianA)"
putStrLn "            # vibratoDepth 0.04"
putStrLn "            # timbre 0.7"
putStrLn ""
putStrLn " Tempo:     setcps 0.22  (pavane)   setcps 0.33  (galliard)"
putStrLn "            setcps 0.47  (saltarello)"
putStrLn ""
putStrLn " Load renaissance.tidal next — its last line populates"
putStrLn " launchpadGridRef, live, no further steps needed here."
putStrLn "================================================================"
putStrLn ""
