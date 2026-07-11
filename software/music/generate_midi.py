#!/usr/bin/env python3
"""
generate_midi.py - programmatic MIDI generation for non-musicians.

Describes music as simple data (key, tempo, style, length) and writes a
multi-track MIDI file: chords, bassline, melody, drums. Feed the result to
FluidSynth:

    python generate_midi.py --style reggae --key A --minor --bars 16 -o song.mid
    fluidsynth -ni "$SOUNDFONT" song.mid -F song.wav -r 44100

No music theory needed: pick a key and a style preset and it stays in tune,
because everything is derived from the scale.
"""

import argparse
import random

from mido import Message, MetaMessage, MidiFile, MidiTrack, bpm2tempo

TICKS = 480  # ticks per quarter note

NOTE_NAMES = {"C": 60, "C#": 61, "D": 62, "D#": 63, "E": 64, "F": 65,
              "F#": 66, "G": 67, "G#": 68, "A": 69, "A#": 70, "B": 71}

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]

# General MIDI drum notes (channel 10)
KICK, SNARE, HAT_CLOSED, HAT_OPEN, RIM = 36, 38, 42, 46, 37

STYLES = {
    # tempo, chord degrees (1-based scale degrees), GM programs, drum pattern
    "reggae": {
        "tempo": 75,
        "progression": [1, 4, 5, 4],
        "chord_program": 27,   # clean electric guitar (skank)
        "bass_program": 33,    # fingered bass
        "melody_program": 19,  # rock organ
        "drums": "one_drop",
        "chord_offbeat": True,
    },
    "ambient": {
        "tempo": 60,
        "progression": [1, 6, 4, 5],
        "chord_program": 89,   # warm pad
        "bass_program": 95,    # sweep pad as low layer
        "melody_program": 11,  # vibraphone
        "drums": "none",
        "chord_offbeat": False,
    },
    "classical": {
        "tempo": 90,
        "progression": [1, 4, 5, 1],
        "chord_program": 48,   # string ensemble
        "bass_program": 42,    # cello
        "melody_program": 40,  # violin
        "drums": "none",
        "chord_offbeat": False,
    },
    "electronic": {
        "tempo": 120,
        "progression": [6, 4, 1, 5],
        "chord_program": 81,   # saw lead as stabs
        "bass_program": 38,    # synth bass
        "melody_program": 80,  # square lead
        "drums": "four_floor",
        "chord_offbeat": False,
    },
}


def scale_note(root, scale, degree, octave=0):
    """1-based scale degree -> MIDI note number."""
    d = degree - 1
    return root + scale[d % 7] + 12 * (d // 7) + 12 * octave


def triad(root, scale, degree):
    return [scale_note(root, scale, degree + i) for i in (0, 2, 4)]


def add_notes(track, notes, start, dur, vel=80, channel=0):
    """Append simultaneous notes at absolute tick `start` (track-local delta handled by caller)."""
    events = []
    for n in notes:
        events.append((start, Message("note_on", note=n, velocity=vel,
                                      channel=channel, time=0)))
        events.append((start + dur, Message("note_off", note=n, velocity=0,
                                            channel=channel, time=0)))
    return events


def events_to_track(name, program, channel, events):
    track = MidiTrack()
    track.append(MetaMessage("track_name", name=name, time=0))
    if channel != 9:
        track.append(Message("program_change", program=program,
                             channel=channel, time=0))
    events.sort(key=lambda e: e[0])
    now = 0
    for abs_time, msg in events:
        msg.time = abs_time - now
        now = abs_time
        track.append(msg)
    track.append(MetaMessage("end_of_track", time=0))
    return track


def drum_bar(pattern, bar_start):
    ev = []
    q = TICKS
    if pattern == "one_drop":  # reggae: kick+snare together on beat 3
        ev += add_notes(None or [], [KICK, RIM], bar_start + 2 * q, q // 4,
                        vel=95, channel=9)
        for beat in range(4):
            for half in range(2):
                t = bar_start + beat * q + half * (q // 2)
                ev += add_notes([], [HAT_CLOSED], t, q // 8, vel=55, channel=9)
    elif pattern == "four_floor":
        for beat in range(4):
            t = bar_start + beat * q
            ev += add_notes([], [KICK], t, q // 4, vel=100, channel=9)
            ev += add_notes([], [HAT_CLOSED], t + q // 2, q // 8, vel=60,
                            channel=9)
            if beat in (1, 3):
                ev += add_notes([], [SNARE], t, q // 4, vel=90, channel=9)
    return ev


def build_song(style_name, key, minor, bars, seed):
    rng = random.Random(seed)
    style = STYLES[style_name]
    scale = MINOR if minor else MAJOR
    root = NOTE_NAMES[key]

    mid = MidiFile(ticks_per_beat=TICKS)

    meta = MidiTrack()
    meta.append(MetaMessage("set_tempo", tempo=bpm2tempo(style["tempo"]),
                            time=0))
    meta.append(MetaMessage("time_signature", numerator=4, denominator=4,
                            time=0))
    meta.append(MetaMessage("end_of_track", time=0))
    mid.tracks.append(meta)

    chord_ev, bass_ev, mel_ev, drum_ev = [], [], [], []
    bar_len = 4 * TICKS
    prog = style["progression"]

    for bar in range(bars):
        start = bar * bar_len
        degree = prog[bar % len(prog)]
        chord = triad(root, scale, degree)

        # chords: offbeat skank for reggae, sustained pad otherwise
        if style["chord_offbeat"]:
            for beat in range(4):
                t = start + beat * TICKS + TICKS // 2
                chord_ev += add_notes([], chord, t, TICKS // 3, vel=70,
                                      channel=0)
        else:
            chord_ev += add_notes([], chord, start, bar_len, vel=60, channel=0)

        # bass: root notes an octave down, simple rhythm
        bass_note = scale_note(root, scale, degree, octave=-1)
        for beat in (0, 2):
            bass_ev += add_notes([], [bass_note], start + beat * TICKS,
                                 TICKS, vel=85, channel=1)

        # melody: random walk on chord/scale tones, one octave up
        pos = degree
        for beat in range(4):
            if rng.random() < 0.25:
                continue  # rests keep it breathable
            pos = max(1, min(10, pos + rng.choice([-2, -1, 0, 1, 2])))
            n = scale_note(root, scale, pos, octave=1)
            dur = rng.choice([TICKS // 2, TICKS])
            mel_ev += add_notes([], [n], start + beat * TICKS, dur, vel=75,
                                channel=2)

        if style["drums"] != "none":
            drum_ev += drum_bar(style["drums"], start)

    mid.tracks.append(events_to_track("chords", style["chord_program"], 0,
                                      chord_ev))
    mid.tracks.append(events_to_track("bass", style["bass_program"], 1,
                                      bass_ev))
    mid.tracks.append(events_to_track("melody", style["melody_program"], 2,
                                      mel_ev))
    if drum_ev:
        mid.tracks.append(events_to_track("drums", 0, 9, drum_ev))
    return mid


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--style", choices=STYLES, default="ambient")
    p.add_argument("--key", choices=NOTE_NAMES, default="C")
    p.add_argument("--minor", action="store_true")
    p.add_argument("--bars", type=int, default=16)
    p.add_argument("--seed", type=int, default=None,
                   help="fix the random seed to reproduce a take you liked")
    p.add_argument("-o", "--output", default="song.mid")
    args = p.parse_args()

    seed = args.seed if args.seed is not None else random.randrange(1 << 30)
    mid = build_song(args.style, args.key, args.minor, args.bars, seed)
    mid.save(args.output)
    print(f"Wrote {args.output}  (style={args.style}, key={args.key}"
          f"{'m' if args.minor else ''}, bars={args.bars}, seed={seed})")


if __name__ == "__main__":
    main()
