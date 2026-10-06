#!/usr/bin/env python3
"""
osc_receiver_test.py
Renaissance Counterpoint Live Performance System
Deliverable 7: OSC Visual Output Test Receiver

Location: /media/projects/TidalCycles/osc_receiver_test.py

PURPOSE:
    Listens on port 57200 for OSC messages sent by SuperCollider's
    visual sender (startup.scd OSCdef \visualSender and \beatSender).
    Prints received messages to the terminal so you can verify the
    OSC pipeline is working before connecting a visual application.

USAGE:
    python3 /media/projects/TidalCycles/osc_receiver_test.py

    Then play any Tidal pattern. You should see output like:
        [NOTE] recorder  note=62  freq=493.88  amp=0.80  pan=0.50  orbit=0  scale=A_JI_Aeolian  cps=0.22
        [BEAT] cycle=14  cps=0.22
        [MIC ] freq=220.0  midi=57  name=A3

    Press Ctrl-C to stop.

DEPENDENCIES:
    pip3 install python-osc
    (python-osc is the standard OSC library for Python 3)

OSC ADDRESS SCHEME (matches startup.scd):
    /tidal/note   instrument note freq amp pan orbit scaleName cps
    /tidal/beat   cycleNum cps
    /mic/pitch    freq midiNote noteName

PIXILANG / BLENDER INTEGRATION NOTES:
    This file also documents the OSC protocol for use in your
    visual application. See the INTEGRATION NOTES section below.

SUPERCOLLIDER SENDER (startup.scd):
    ~visualPort = 57200
    ~visualNet  = NetAddr("127.0.0.1", ~visualPort)
    OSCdef(\visualSender) listens on /play2 and sends /tidal/note
    OSCdef(\beatSender)   listens on /clock and sends /tidal/beat
    OSCdef(\micPitchReceiver) forwards to /mic/pitch
"""

import argparse
import sys
import time
from collections import defaultdict

try:
    from pythonosc import dispatcher, osc_server
    from pythonosc.osc_message_builder import OscMessageBuilder
    from pythonosc.udp_client import SimpleUDPClient
except ImportError:
    print("ERROR: python-osc not installed.")
    print("Run:  pip3 install python-osc")
    sys.exit(1)


# ── Configuration ─────────────────────────────────────────────
LISTEN_IP   = "127.0.0.1"
LISTEN_PORT = 57200

# Colour codes for terminal output (ANSI, works in any Linux terminal).
RESET   = "\033[0m"
CYAN    = "\033[96m"
YELLOW  = "\033[93m"
GREEN   = "\033[92m"
MAGENTA = "\033[95m"
DIM     = "\033[2m"
BOLD    = "\033[1m"

# Statistics counters.
stats = defaultdict(int)
start_time = time.time()


# ── Message Handlers ──────────────────────────────────────────

def handle_tidal_note(address, *args):
    """
    /tidal/note  instrument note freq amp pan orbit scaleName cps

    args[0]  instrument : String  e.g. "recorder"
    args[1]  note       : Int     MIDI note 0–127
    args[2]  freq       : Float   Hz (after microtonal lookup)
    args[3]  amp        : Float   0.0–1.0
    args[4]  pan        : Float   0.0–1.0
    args[5]  orbit      : Int     0–7
    args[6]  scaleName  : String  e.g. "A_JI_Aeolian" or ""
    args[7]  cps        : Float   cycles per second
    """
    if len(args) < 8:
        print(f"{DIM}[NOTE] malformed: {args}{RESET}")
        return

    instrument = str(args[0])
    note       = int(args[1])   if args[1] is not None else 0
    freq       = float(args[2]) if args[2] is not None else 0.0
    amp        = float(args[3]) if args[3] is not None else 0.0
    pan        = float(args[4]) if args[4] is not None else 0.5
    orbit      = int(args[5])   if args[5] is not None else 0
    scale      = str(args[6])   if args[6] is not None else ""
    cps        = float(args[7]) if args[7] is not None else 0.0

    # Colour-code by orbit for quick visual scanning.
    orbit_colours = [CYAN, YELLOW, GREEN, MAGENTA, CYAN, YELLOW, GREEN, MAGENTA]
    colour = orbit_colours[orbit % len(orbit_colours)]

    stats["notes"] += 1

    print(
        f"{colour}[NOTE]{RESET} "
        f"{BOLD}{instrument:<22}{RESET} "
        f"note={note:3d}  "
        f"freq={freq:7.2f} Hz  "
        f"amp={amp:.2f}  "
        f"pan={pan:.2f}  "
        f"orbit={orbit}  "
        f"scale={scale or '(default)'}  "
        f"cps={cps:.4f}"
    )


def handle_tidal_beat(address, *args):
    """
    /tidal/beat  cycleNum cps

    args[0]  cycleNum : Int    cycle number since TidalCycles start
    args[1]  cps      : Float  current tempo
    """
    if len(args) < 2:
        print(f"{DIM}[BEAT] malformed: {args}{RESET}")
        return

    cycle = int(args[0])   if args[0] is not None else 0
    cps   = float(args[1]) if args[1] is not None else 0.0
    bpm   = cps * 60 * 4   # assuming 4 beats per cycle

    stats["beats"] += 1

    print(
        f"{GREEN}[BEAT]{RESET} "
        f"cycle={cycle:6d}  "
        f"cps={cps:.4f}  "
        f"({bpm:.1f} bpm)"
    )


def handle_mic_pitch(address, *args):
    """
    /mic/pitch  freq midiNote noteName

    args[0]  freq     : Float  detected fundamental in Hz
    args[1]  midiNote : Int    nearest MIDI note
    args[2]  noteName : String e.g. "A3"
    """
    if len(args) < 3:
        return

    freq  = float(args[0]) if args[0] is not None else 0.0
    midi  = int(args[1])   if args[1] is not None else 0
    name  = str(args[2])   if args[2] is not None else "?"

    stats["pitches"] += 1

    print(
        f"{MAGENTA}[MIC ]{RESET} "
        f"freq={freq:7.2f} Hz  "
        f"midi={midi:3d}  "
        f"name={name}"
    )


def handle_default(address, *args):
    """Catch-all for any unrecognised OSC address."""
    print(f"{DIM}[????] {address}  args={args}{RESET}")


def print_stats(sig=None, frame=None):
    elapsed = time.time() - start_time
    print()
    print("─" * 60)
    print(f"  OSC receiver stopped after {elapsed:.1f} seconds")
    print(f"  Notes received : {stats['notes']}")
    print(f"  Beats received : {stats['beats']}")
    print(f"  Mic pitches    : {stats['pitches']}")
    if elapsed > 0:
        print(f"  Events/sec     : {(stats['notes'] + stats['beats']) / elapsed:.1f}")
    print("─" * 60)
    sys.exit(0)


# ── Main ──────────────────────────────────────────────────────

def main():
    import signal

    parser = argparse.ArgumentParser(
        description="Test receiver for SuperCollider → visual OSC pipeline."
    )
    parser.add_argument(
        "--port", type=int, default=LISTEN_PORT,
        help=f"UDP port to listen on (default: {LISTEN_PORT})"
    )
    parser.add_argument(
        "--ip", type=str, default=LISTEN_IP,
        help=f"IP address to bind (default: {LISTEN_IP})"
    )
    parser.add_argument(
        "--beats", action="store_true",
        help="Show beat messages (hidden by default to reduce noise)"
    )
    args = parser.parse_args()

    d = dispatcher.Dispatcher()
    d.map("/tidal/note", handle_tidal_note)
    d.map("/mic/pitch",  handle_mic_pitch)

    if args.beats:
        d.map("/tidal/beat", handle_tidal_beat)
    else:
        d.map("/tidal/beat", lambda *a: None)   # suppress beats

    d.set_default_handler(handle_default)

    signal.signal(signal.SIGINT, print_stats)

    print("=" * 60)
    print(f"  Renaissance Counterpoint — OSC Test Receiver")
    print(f"  Listening on {args.ip}:{args.port}")
    print(f"  Beat messages: {'ON' if args.beats else 'OFF  (use --beats to enable)'}")
    print(f"  Play any Tidal pattern to see events.")
    print(f"  Press Ctrl-C to stop and show statistics.")
    print("=" * 60)
    print()

    server = osc_server.ThreadingOSCUDPServer((args.ip, args.port), d)
    server.serve_forever()


if __name__ == "__main__":
    main()


# ============================================================
# INTEGRATION NOTES FOR PIXILANG
# ============================================================
#
# Pixilang has a built-in UDP socket API. To receive OSC:
#
#   // Open UDP socket on port 57200
#   sock = net_open_socket( NET_PROTO_UDP, 57200, 0 )
#
#   // In your main loop:
#   size = net_get_data( sock, buf, 1024 )
#   if size > 0
#     // OSC message format: address string + type tag string + args
#     // Parse manually: address is null-terminated at buf[0]
#     // Type tags follow after the address (padded to 4-byte boundary)
#     // Args follow after type tags (each 4 or 8 bytes)
#     addr = buf[ 0 ]   // Read address string
#     // See OSC 1.0 spec for full binary format
#   end
#
# The simplest approach for Pixilang is to write a small Python
# OSC-to-UDP bridge that converts OSC messages to a simpler
# fixed-width binary format, then read that from Pixilang.
# See osc_to_pixilang_bridge.py (create separately if needed).
#
#
# ============================================================
# INTEGRATION NOTES FOR BLENDER (Python scripting)
# ============================================================
#
# Blender's Python environment can receive OSC using python-osc
# running in a background thread. Add this to a Blender script:
#
#   import threading
#   from pythonosc import dispatcher, osc_server
#
#   def note_handler(address, instrument, note, freq, amp, pan,
#                    orbit, scale, cps):
#       # Update Blender object properties here.
#       # Use bpy.context.scene.objects to access scene objects.
#       # Example: set emissive strength based on amp
#       obj = bpy.data.objects.get("NoteLight_" + str(orbit))
#       if obj and obj.data.materials:
#           mat = obj.data.materials[0]
#           mat.node_tree.nodes["Emission"].inputs[1].default_value = amp * 5
#
#   d = dispatcher.Dispatcher()
#   d.map("/tidal/note", note_handler)
#   server = osc_server.ThreadingOSCUDPServer(("127.0.0.1", 57200), d)
#   thread = threading.Thread(target=server.serve_forever, daemon=True)
#   thread.start()
#
# Run this in Blender's Text Editor, then execute. The OSC thread
# runs in the background while Blender's main thread renders.
# Note: Blender property updates from background threads require
# using bpy.app.timers for thread-safe access in 3.x.
#
#
# ============================================================
# OSC ADDRESS REFERENCE (complete)
# ============================================================
#
# /tidal/note  String Int Float Float Float Int String Float
#   instrument  note  freq  amp   pan  orbit scale    cps
#   "recorder"  62    493.9  0.8  0.5   0   "A_JI.."  0.22
#
# /tidal/beat  Int Float
#   cycleNum   cps
#   14          0.22
#
# /mic/pitch   Float Int String
#   freq        midiNote  noteName
#   440.0       69        "A4"
#
# /crossfade   Float         (EZ-Creator crossfader position 0.0–1.0)
# /tempo/cps   Float         (current tempo, sent on change)
# /launchpad/on  Int Int     (orbit slot — for visual feedback)
# /launchpad/off Int         (orbit silenced)
