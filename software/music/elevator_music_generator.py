#!/usr/bin/env python3
"""
Algorithmic Elevator Music Generator
Generates unique, gentle elevator music based on system metrics (CPU load, temperature)
"""

import numpy as np
import psutil
import time
import argparse
import sys
from scipy.io.wavfile import write
import threading
import queue
import math

class SystemMonitor:
    """Monitors system metrics to provide entropy for music generation"""
    
    def __init__(self):
        self.cpu_percent = 0
        self.cpu_temp = 20  # Default fallback temperature
        self.running = False
        self.data_queue = queue.Queue()
    
    def get_cpu_temperature(self):
        """Get CPU temperature, with fallbacks for different systems"""
        try:
            # Try different temperature sources
            temps = psutil.sensors_temperatures()
            if 'coretemp' in temps:
                return temps['coretemp'][0].current
            elif 'k10temp' in temps:
                return temps['k10temp'][0].current
            elif 'acpi' in temps:
                return temps['acpi'][0].current
            else:
                # Fallback: try to read from /sys/class/thermal
                try:
                    with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                        temp_millidegrees = int(f.read().strip())
                        return temp_millidegrees / 1000.0
                except:
                    return 25.0  # Default room temperature
        except:
            return 25.0
    
    def update_metrics(self):
        """Update system metrics"""
        self.cpu_percent = psutil.cpu_percent(interval=0.1)
        self.cpu_temp = self.get_cpu_temperature()
    
    def get_music_params(self):
        """Convert system metrics to music parameters"""
        # Normalize CPU (0-100) to tempo multiplier (0.7-1.3)
        tempo_factor = 0.7 + (self.cpu_percent / 100.0) * 0.6
        
        # Normalize temperature (20-80°C) to tension factor (0.3-1.0)
        temp_normalized = max(0, min(1, (self.cpu_temp - 20) / 60))
        tension_factor = 0.3 + temp_normalized * 0.7
        
        return {
            'tempo_factor': tempo_factor,
            'tension_factor': tension_factor,
            'cpu_percent': self.cpu_percent,
            'cpu_temp': self.cpu_temp
        }

class MusicGenerator:
    """Generates algorithmic elevator music"""
    
    def __init__(self, sample_rate=44100):
        self.sample_rate = sample_rate
        self.base_tempo = 72  # BPM
        
        # Gentle elevator music scales (pentatonic and major)
        self.scales = {
            'pentatonic': [0, 2, 4, 7, 9],  # C pentatonic
            'major': [0, 2, 4, 5, 7, 9, 11],  # C major
            'gentle_minor': [0, 2, 3, 5, 7, 8, 10]  # Natural minor
        }
        
        # Chord progressions typical for elevator music
        self.progressions = [
            [0, 3, 4, 0],    # I-vi-V-I
            [0, 5, 3, 4],    # I-IV-vi-V
            [0, 4, 3, 0],    # I-V-vi-I
            [0, 2, 5, 4]     # I-iii-IV-V
        ]
    
    def midi_to_freq(self, midi_note):
        """Convert MIDI note to frequency"""
        return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))
    
    def generate_sine_wave(self, freq, duration, amplitude=0.3, envelope='gentle'):
        """Generate a sine wave with envelope"""
        samples = int(duration * self.sample_rate)
        t = np.linspace(0, duration, samples, False)
        
        # Basic sine wave
        wave = np.sin(2 * np.pi * freq * t) * amplitude
        
        # Apply gentle envelope
        if envelope == 'gentle':
            attack_samples = int(0.1 * samples)
            release_samples = int(0.3 * samples)
            
            # Attack
            if attack_samples > 0:
                wave[:attack_samples] *= np.linspace(0, 1, attack_samples)
            
            # Release
            if release_samples > 0:
                wave[-release_samples:] *= np.linspace(1, 0, release_samples)
        
        return wave
    
    def generate_chord(self, root_midi, chord_type, duration, amplitude=0.2):
        """Generate a chord"""
        chord_intervals = {
            'major': [0, 4, 7],
            'minor': [0, 3, 7],
            'major7': [0, 4, 7, 11],
            'minor7': [0, 3, 7, 10]
        }
        
        intervals = chord_intervals.get(chord_type, [0, 4, 7])
        chord_wave = np.zeros(int(duration * self.sample_rate))
        
        for interval in intervals:
            freq = self.midi_to_freq(root_midi + interval)
            note_wave = self.generate_sine_wave(freq, duration, amplitude / len(intervals))
            chord_wave += note_wave
        
        return chord_wave
    
    def generate_melody_note(self, scale_notes, base_octave, duration, params):
        """Generate a single melody note based on system parameters"""
        # Use CPU percentage to influence note selection (more entropy)
        cpu_hash = hash(str(params['cpu_percent'])) % len(scale_notes)
        temp_hash = hash(str(params['cpu_temp'])) % len(scale_notes)
        
        # Combine hashes for note selection
        note_index = (cpu_hash + temp_hash) % len(scale_notes)
        
        # Higher tension = higher octave tendency
        octave_offset = 1 if params['tension_factor'] > 0.7 else 0
        
        midi_note = 60 + base_octave * 12 + scale_notes[note_index] + octave_offset
        freq = self.midi_to_freq(midi_note)
        
        return self.generate_sine_wave(freq, duration, 0.15)
    
    def generate_segment(self, duration_seconds, params):
        """Generate a musical segment based on system parameters"""
        # Choose scale based on tension
        if params['tension_factor'] < 0.4:
            scale_name = 'pentatonic'
        elif params['tension_factor'] < 0.7:
            scale_name = 'major'
        else:
            scale_name = 'gentle_minor'
        
        scale_notes = self.scales[scale_name]
        
        # Adjust tempo based on CPU
        actual_tempo = self.base_tempo * params['tempo_factor']
        beat_duration = 60.0 / actual_tempo
        
        # Generate progression
        progression = self.progressions[hash(str(params['cpu_temp'])) % len(self.progressions)]
        
        total_samples = int(duration_seconds * self.sample_rate)
        music = np.zeros(total_samples)
        
        current_time = 0
        chord_duration = beat_duration * 4  # Whole note chords
        melody_note_duration = beat_duration  # Quarter note melody
        
        while current_time < duration_seconds:
            # Add chord
            if current_time + chord_duration <= duration_seconds:
                chord_root = 48 + progression[int(current_time / chord_duration) % len(progression)] * 2
                chord_type = 'major7' if params['tension_factor'] < 0.6 else 'minor7'
                chord = self.generate_chord(chord_root, chord_type, chord_duration, 0.1)
                
                start_sample = int(current_time * self.sample_rate)
                end_sample = min(start_sample + len(chord), len(music))
                music[start_sample:end_sample] += chord[:end_sample - start_sample]
            
            # Add melody notes
            melody_time = current_time
            while melody_time < current_time + chord_duration and melody_time < duration_seconds:
                melody_note = self.generate_melody_note(scale_notes, 1, melody_note_duration, params)
                
                start_sample = int(melody_time * self.sample_rate)
                end_sample = min(start_sample + len(melody_note), len(music))
                music[start_sample:end_sample] += melody_note[:end_sample - start_sample]
                
                melody_time += melody_note_duration
            
            current_time += chord_duration
        
        return music

def main():
    parser = argparse.ArgumentParser(description='Generate algorithmic elevator music')
    parser.add_argument('--duration', type=int, default=60, help='Duration in seconds')
    parser.add_argument('--output', type=str, default='elevator_music.wav', help='Output file name')
    parser.add_argument('--monitor-interval', type=float, default=5.0, help='System monitoring interval')
    args = parser.parse_args()
    
    print("🎵 Starting Algorithmic Elevator Music Generator")
    print(f"Duration: {args.duration} seconds")
    print(f"Output file: {args.output}")
    
    monitor = SystemMonitor()
    generator = MusicGenerator()
    
    # Generate music in segments, updating system metrics
    segment_duration = min(args.monitor_interval, args.duration)
    total_music = []
    
    elapsed = 0
    while elapsed < args.duration:
        # Update system metrics
        monitor.update_metrics()
        params = monitor.get_music_params()
        
        print(f"🖥️  CPU: {params['cpu_percent']:.1f}% | 🌡️  Temp: {params['cpu_temp']:.1f}°C | "
              f"🎼 Tempo: {params['tempo_factor']:.2f}x | 🎭 Tension: {params['tension_factor']:.2f}")
        
        # Generate segment
        remaining_duration = min(segment_duration, args.duration - elapsed)
        segment = generator.generate_segment(remaining_duration, params)
        total_music.append(segment)
        
        elapsed += remaining_duration
    
    # Concatenate all segments
    final_music = np.concatenate(total_music)
    
    # Normalize and save
    final_music = final_music / np.max(np.abs(final_music)) * 0.8
    final_music_16bit = (final_music * 32767).astype(np.int16)
    
    write(args.output, generator.sample_rate, final_music_16bit)
    print(f"✅ Generated {args.duration}s of unique elevator music: {args.output}")

if __name__ == "__main__":
    main()