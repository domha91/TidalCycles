#!/usr/bin/env bash
# setup_loops.sh
# Creates the audio loop folder structure for the Renaissance Counterpoint system.
# Run once: bash /media/projects/TidalCycles/setup_loops.sh
# Location: /media/projects/TidalCycles/setup_loops.sh

set -euo pipefail

BASE="/media/projects/Audio/Samples"

echo "Creating sample folder structure under $BASE ..."

mkdir -p "$BASE/loops-drone"
mkdir -p "$BASE/loops-rhythmic"
mkdir -p "$BASE/loops-melodic"
mkdir -p "$BASE/loops-ambient"
mkdir -p "$BASE/prepared"

# Write placeholder README files so SuperDirt does not warn about empty folders.
# SuperDirt skips folders with no audio files, so placeholders are text-only.

cat > "$BASE/loops-drone/README.txt" << 'EOF'
loops-drone/
Place sustained drone loop files here.
Naming: NNN_<root>_<description>.wav
e.g.:   001_A_drone_tonic.wav
        002_A_drone_fifth.wav
        003_G_drone_bagpipe.wav
        004_D_drone_viol.wav
Format: WAV 48000 Hz 24-bit stereo, seamlessly looped.
In Tidal: s "loops-drone" # n 0   (first file alphabetically)
EOF

cat > "$BASE/loops-rhythmic/README.txt" << 'EOF'
loops-rhythmic/
Place rhythmic pattern loop files here.
Naming: NNN_<description>_<bpm>bpm.wav
e.g.:   001_tabor_pavane_60bpm.wav
        002_tabor_galliard_80bpm.wav
        003_framedrum_estampie_100bpm.wav
Format: WAV 48000 Hz 24-bit stereo. Trim exactly to bar boundaries.
In Tidal: s "loops-rhythmic" # n 0
EOF

cat > "$BASE/loops-melodic/README.txt" << 'EOF'
loops-melodic/
Place melodic fragment loop files here.
Naming: NNN_<root>_<instrument>_<form>.wav
e.g.:   001_A_recorder_pavane_A.wav
        002_A_fiddle_galliard_A.wav
        003_A_viol_consort_slow.wav
Format: WAV 48000 Hz 24-bit stereo.
In Tidal: s "loops-melodic" # n 0
Speed-transpose: # speed (targetHz / sourceHz)
EOF

cat > "$BASE/loops-ambient/README.txt" << 'EOF'
loops-ambient/
Place ambient texture and atmosphere files here.
e.g.:   001_hall_reverb_tail.wav
        002_crowd_murmur.wav
        003_wind_exterior.wav
        004_church_atmos.wav
Format: WAV 48000 Hz 24-bit stereo.
In Tidal: striate 32 $ s "loops-ambient" # n 0 # gain 0.5
EOF

cat > "$BASE/prepared/README.txt" << 'EOF'
prepared/
Your own original compositions and prepared samples.
Any format SuperDirt supports (WAV, AIFF, FLAC).
No naming convention required — SuperDirt indexes alphabetically.
In Tidal: s "prepared" # n 0
EOF

echo ""
echo "Folder structure created:"
find "$BASE" -type d | sort
echo ""
echo "Next steps:"
echo "  1. Record or export your loop files into each folder."
echo "  2. Name files with NNN_ prefix to control SuperDirt index order."
echo "  3. Restart SuperCollider (or re-evaluate the loadSoundFiles"
echo "     lines in startup.scd) to load the new files."
echo "  4. In Tidal: once $ s \"loops-drone\" # n 0   to test."
echo ""
echo "Done."
