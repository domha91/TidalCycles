:set -XOverloadedStrings
:set prompt ""

import Sound.Tidal.Context

import System.IO (hSetEncoding, stdout, utf8)

import qualified Control.Concurrent.MVar as MV
import qualified Sound.Tidal.Tempo as Tempo
import qualified Sound.OSC.FD as O

hSetEncoding stdout utf8

-- total latency = oLatency + cFrameTimespan
-- Send OSC to Supercollder on PC
-- tidal <- startStream (defaultConfig {cCtrlAddr = "0.0.0.0", cCtrlListen = True, cFrameTimespan = 1/20}) [(superdirtTarget {oAddress = "192.168.1.1", oPort = 57120, oLatency = 0.1 , oSchedule = Live, oWindow = Nothing, oHandshake = False, oBusPort = Nothing}, [superdirtShape])]

-- Send OSC to Supercollider & Visuals on PC
tidal <- startStream (defaultConfig {cCtrlAddr = "0.0.0.0", cCtrlPort= 6010, cCtrlListen = True, cFrameTimespan = 1/10}) [(superdirtTarget {oAddress = "192.168.1.1", oPort = 57120, oLatency = 0.4 , oSchedule = Live, oWindow = Nothing, oHandshake = False, oBusPort = Nothing}, [superdirtShape]), (superdirtTarget {oAddress = "192.168.1.1", oPort = 57101, oLatency = 0.4, oSchedule = Live, oWindow = Nothing, oHandshake = False, oBusPort = Nothing}, [superdirtShape])]

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
    unsoloAll = streamUnsoloAll tidal
    solo = streamSolo tidal
    unsolo = streamUnsolo tidal
    once = streamOnce tidal
    first = streamFirst tidal
    asap = once
    nudgeAll = streamNudgeAll tidal
    all = streamAll tidal
    resetCycles = streamResetCycles tidal
    setcps = asap . cps
    getcps = do tempo <- MV.readMVar $ sTempoMV tidal
                return $ Tempo.cps tempo
    getnow = do tempo <- MV.readMVar $ sTempoMV tidal
                now <- O.time
                return $ fromRational $ Tempo.timeToCycles tempo now
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
:}

:{
let setI = streamSetI tidal
    setF = streamSetF tidal
    setS = streamSetS tidal
    setR = streamSetR tidal
    setB = streamSetB tidal
:}

:{
let degree = pF "degree"
    ctranspose = pF "ctranspose"
    mtranspose = pF "mtranspose"
    gtranspose = pF "gtranspose"
    harmonic = pF "harmonic"
    detune = pF "detune"
    scalename = pS "scaleName"
    tuning = pS "tuningName"
    stepsPerOctave = pI "stepsPerOctave"
    octaveRatio = pF "octaveRatio"
:}

:set prompt "tidal> "
:set prompt-cont ""