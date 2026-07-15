#!/usr/bin/env python3
"""
Enhanced Polyphonic Elevator Music Generator
Generates complex, layered elevator music with multiple threads, samples, and creative sounds
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
import random
from typing import List, Dict, Tuple

class SystemMonitor:
    """Monitors system metrics to provide entropy for music generation"""
    
    def __init__(self):
        self.cpu_percent = 0
        self.cpu_temp = 20
        self.memory_percent = 0
        self.disk_io = 0
        self.network_io = 0
        self.running = False
        self.data_queue = queue.Queue()
    
    def get_cpu_temperature(self):
        """Get CPU temperature with fallbacks"""
        try:
            temps = psutil.sensors_temperatures()
            if 'coretemp' in temps:
                return temps['coretemp'][0].current
            elif 'k10temp' in temps:
                return temps['k10temp'][0].current
            elif 'acpi' in temps:
                return temps['acpi'][0].current
            else:
                try:
                    with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                        temp_millidegrees = int(f.read().strip())
                        return temp_millidegrees / 1000.0
                except:
                    return 25.0
        except:
            return 25.0
    
    def update_metrics(self):
        """Update comprehensive system metrics"""
        self.cpu_percent = psutil.cpu_percent(interval=0.1)
        self.cpu_temp = self.get_cpu_temperature()
        self.memory_percent = psutil.virtual_memory().percent
        
        # Get disk and network I/O for additional entropy
        try:
            disk_io = psutil.disk_io_counters()
            self.disk_io = disk_io.read_bytes + disk_io.write_bytes if disk_io else 0
            
            net_io = psutil.net_io_counters()
            self.network_io = net_io.bytes_sent + net_io.bytes_recv if net_io else 0
        except:
            self.disk_io = 0
            self.network_io = 0
    
    def get_music_params(self):
        """Convert system metrics to comprehensive music parameters"""
        # Multiple entropy sources for different musical aspects
        tempo_factor = 0.6 + (self.cpu_percent / 100.0) * 0.8  # 0.6-1.4x
        
        # Temperature affects harmonic complexity
        temp_normalized = max(0, min(1, (self.cpu_temp - 20) / 60))
        harmonic_complexity = 0.3 + temp_normalized * 0.7
        
        # Memory affects layer density
        layer_density = 0.4 + (self.memory_percent / 100.0) * 0.6
        
        # I/O affects rhythmic variation
        io_hash = hash(str(self.disk_io + self.network_io)) % 1000
        rhythmic_variation = io_hash / 1000.0
        
        return {
            'tempo_factor': tempo_factor,
            'harmonic_complexity': harmonic_complexity,
            'layer_density': layer_density,
            'rhythmic_variation': rhythmic_variation,
            'cpu_percent': self.cpu_percent,
            'cpu_temp': self.cpu_temp,
            'memory_percent': self.memory_percent,
            'entropy_seed': hash(f"{self.cpu_percent}{self.cpu_temp}{self.memory_percent}{io_hash}")
        }

class SampleGenerator:
    """Generates various sample-based and synthetic sounds"""
    
    def __init__(self, sample_rate=44100):
        self.sample_rate = sample_rate
        
    def generate_ambient_pad(self, freq, duration, params):
        """Generate warm ambient pad sounds"""
        samples = int(duration * self.sample_rate)
        t = np.linspace(0, duration, samples, False)
        
        # Multiple oscillators for richness
        wave1 = np.sin(2 * np.pi * freq * t) * 0.3
        wave2 = np.sin(2 * np.pi * freq * 1.005 * t) * 0.25  # Slight detune
        wave3 = np.sin(2 * np.pi * freq * 0.5 * t) * 0.2     # Sub-oscillator
        
        # Add some harmonics based on system complexity
        harmonics = int(3 + params['harmonic_complexity'] * 4)
        for i in range(2, harmonics + 1):
            amplitude = 0.1 / i
            wave1 += np.sin(2 * np.pi * freq * i * t) * amplitude
        
        combined = wave1 + wave2 + wave3
        
        # Gentle low-pass filtering effect
        cutoff_mod = 1 + 0.3 * np.sin(2 * np.pi * 0.1 * t)  # Slow modulation
        combined *= cutoff_mod
        
        # Envelope
        attack = int(0.2 * samples)
        release = int(0.3 * samples)
        if attack > 0:
            combined[:attack] *= np.linspace(0, 1, attack)
        if release > 0:
            combined[-release:] *= np.linspace(1, 0, release)
            
        return combined * 0.15
    
    def generate_bell_sample(self, freq, duration, params):
        """Generate bell-like tones"""
        samples = int(duration * self.sample_rate)
        t = np.linspace(0, duration, samples, False)
        
        # Bell-like harmonics (inharmonic overtones)
        overtones = [1.0, 2.76, 5.4, 8.93]
        amplitudes = [1.0, 0.6, 0.25, 0.15]
        
        bell = np.zeros(samples)
        for overtone, amp in zip(overtones, amplitudes):
            bell += np.sin(2 * np.pi * freq * overtone * t) * amp
        
        # Exponential decay envelope
        decay_rate = 2.0 + params['harmonic_complexity'] * 2
        envelope = np.exp(-decay_rate * t)
        bell *= envelope
        
        return bell * 0.12
    
    def generate_texture_noise(self, duration, params):
        """Generate ambient texture sounds"""
        samples = int(duration * self.sample_rate)
        
        # Colored noise based on system entropy
        noise = np.random.normal(0, 1, samples)
        
        # Filter noise to create texture
        freq_mod = 0.5 + params['rhythmic_variation'] * 0.5
        
        # Simple low-pass effect
        filtered_noise = np.zeros_like(noise)
        alpha = freq_mod * 0.1
        for i in range(1, len(noise)):
            filtered_noise[i] = alpha * noise[i] + (1 - alpha) * filtered_noise[i-1]
        
        # Modulate amplitude slowly
        t = np.linspace(0, duration, samples)
        amp_mod = 0.5 + 0.3 * np.sin(2 * np.pi * 0.05 * t)  # Very slow modulation
        
        return filtered_noise * amp_mod * 0.02
    
    def generate_percussion(self, drum_type, params):
        """Generate simple percussion sounds"""
        if drum_type == "kick":
            duration = 0.8
            samples = int(duration * self.sample_rate)
            t = np.linspace(0, duration, samples)
            
            # Kick drum: low frequency with quick pitch drop
            freq_env = 60 * np.exp(-15 * t)
            kick = np.sin(2 * np.pi * freq_env * t)
            amp_env = np.exp(-8 * t)
            
            return kick * amp_env * 0.2
            
        elif drum_type == "hihat":
            duration = 0.15
            samples = int(duration * self.sample_rate)
            
            # Hi-hat: filtered noise
            noise = np.random.normal(0, 1, samples)
            t = np.linspace(0, duration, samples)
            
            # High-pass effect (emphasize high frequencies)
            filtered = np.zeros_like(noise)
            for i in range(1, len(noise)):
                filtered[i] = noise[i] - 0.95 * noise[i-1]
            
            envelope = np.exp(-20 * t)
            return filtered * envelope * 0.08
            
        elif drum_type == "snap":
            duration = 0.3
            samples = int(duration * self.sample_rate)
            t = np.linspace(0, duration, samples)
            
            # Snap: mix of noise and tone
            noise = np.random.normal(0, 1, samples) * 0.7
            tone = np.sin(2 * np.pi * 200 * t) * 0.3
            
            envelope = np.exp(-12 * t)
            return (noise + tone) * envelope * 0.1

class PolyphonicMusicGenerator:
    """Advanced polyphonic music generator with multiple layers"""
    
    def __init__(self, sample_rate=44100):
        self.sample_rate = sample_rate
        self.base_tempo = 75  # BPM
        self.sample_gen = SampleGenerator(sample_rate)
        
        # Extended musical scales and modes
        self.scales = {
            'pentatonic_major': [0, 2, 4, 7, 9],
            'pentatonic_minor': [0, 3, 5, 7, 10],
            'major': [0, 2, 4, 5, 7, 9, 11],
            'natural_minor': [0, 2, 3, 5, 7, 8, 10],
            'dorian': [0, 2, 3, 5, 7, 9, 10],
            'mixolydian': [0, 2, 4, 5, 7, 9, 10],
            'jazz_minor': [0, 2, 3, 5, 7, 9, 11]
        }
        
        # Rich chord progressions
        self.progressions = [
            [0, 5, 3, 4],    # I-vi-IV-V (classic)
            [0, 3, 4, 0],    # I-vi-V-I 
            [0, 4, 5, 3],    # I-V-vi-IV (pop progression)
            [0, 7, 4, 5],    # I-vii-V-vi
            [0, 2, 5, 4],    # I-iii-vi-V
            [0, 6, 4, 5],    # I-ii-V-vi (jazz-ish)
        ]
        
        # Rhythmic patterns for different layers
        self.bass_patterns = [
            [1, 0, 0.5, 0, 0.8, 0, 0.3, 0],     # Root-fifth pattern
            [1, 0, 0, 0, 0.6, 0, 0.4, 0.2],     # Syncopated
            [1, 0.3, 0.6, 0, 0.8, 0.2, 0, 0.4], # Walking bass feel
        ]
        
        self.perc_patterns = [
            [1, 0, 0.6, 0, 0.8, 0, 0.6, 0],     # Basic 4/4
            [1, 0.3, 0, 0.7, 0.9, 0, 0.4, 0.2], # Syncopated
            [1, 0, 0.4, 0.3, 0.8, 0.2, 0.6, 0], # Swing feel
        ]
    
    def select_musical_elements(self, params):
        """Select scale, progression, and patterns based on system state"""
        entropy = params['entropy_seed']
        
        # Check for scale override first
        if 'scale_override' in params and params['scale_override']:
            scale_override = params['scale_override']
            if scale_override == 'random':
                scale_names = list(self.scales.keys())
                scale_name = scale_names[entropy % len(scale_names)]
            elif scale_override == 'pentatonic':
                scale_name = 'pentatonic_major'
            elif scale_override == 'major':
                scale_name = 'major'
            elif scale_override == 'jazz':
                scale_name = 'jazz_minor'
            else:
                scale_name = scale_override if scale_override in self.scales else 'major'
        else:
            # Select scale based on harmonic complexity
            if params['harmonic_complexity'] < 0.3:
                scale_name = 'pentatonic_major'
            elif params['harmonic_complexity'] < 0.5:
                scale_name = 'major'
            elif params['harmonic_complexity'] < 0.7:
                scale_name = 'dorian'
            else:
                scale_name = 'jazz_minor'
            
        scale = self.scales[scale_name]
        progression = self.progressions[entropy % len(self.progressions)]
        
        bass_pattern = self.bass_patterns[entropy % len(self.bass_patterns)]
        perc_pattern = self.perc_patterns[(entropy >> 8) % len(self.perc_patterns)]
        
        return scale, progression, bass_pattern, perc_pattern
    
    def generate_bass_layer(self, duration, params, progression, pattern):
        """Generate bass layer"""
        actual_tempo = self.base_tempo * params['tempo_factor']
        beat_duration = 60.0 / actual_tempo
        pattern_duration = beat_duration * len(pattern)
        
        total_samples = int(duration * self.sample_rate)
        bass_layer = np.zeros(total_samples)
        
        current_time = 0
        chord_index = 0
        
        while current_time < duration:
            chord_root = progression[chord_index % len(progression)]
            base_freq = self.midi_to_freq(36 + chord_root)  # Low bass notes
            
            for i, intensity in enumerate(pattern):
                if intensity > 0 and current_time < duration:
                    note_duration = beat_duration * 0.8
                    bass_note = self.sample_gen.generate_ambient_pad(
                        base_freq, note_duration, params
                    ) * intensity
                    
                    start_sample = int(current_time * self.sample_rate)
                    end_sample = min(start_sample + len(bass_note), len(bass_layer))
                    bass_layer[start_sample:end_sample] += bass_note[:end_sample - start_sample]
                
                current_time += beat_duration
                
            chord_index += 1
            
        return bass_layer
    
    def generate_harmony_layer(self, duration, params, scale, progression):
        """Generate harmonic pad layer"""
        actual_tempo = self.base_tempo * params['tempo_factor']
        chord_duration = (60.0 / actual_tempo) * 8  # Longer chords
        
        total_samples = int(duration * self.sample_rate)
        harmony_layer = np.zeros(total_samples)
        
        current_time = 0
        
        while current_time < duration:
            chord_root = progression[int(current_time / chord_duration) % len(progression)]
            
            # Generate chord tones
            chord_tones = [0, 2, 4]  # Triad
            if params['harmonic_complexity'] > 0.6:
                chord_tones.append(6)  # Add 7th
            
            chord_wave = np.zeros(int(min(chord_duration, duration - current_time) * self.sample_rate))
            
            for i, tone_index in enumerate(chord_tones):
                scale_degree = (chord_root + tone_index) % len(scale)
                midi_note = 48 + scale[scale_degree] + (chord_root // len(scale)) * 12
                freq = self.midi_to_freq(midi_note)
                
                note_wave = self.sample_gen.generate_ambient_pad(
                    freq, len(chord_wave) / self.sample_rate, params
                )
                chord_wave += note_wave[:len(chord_wave)] * (0.6 / len(chord_tones))
            
            start_sample = int(current_time * self.sample_rate)
            end_sample = min(start_sample + len(chord_wave), len(harmony_layer))
            harmony_layer[start_sample:end_sample] += chord_wave[:end_sample - start_sample]
            
            current_time += chord_duration
            
        return harmony_layer
    
    def generate_melody_layer(self, duration, params, scale, progression):
        """Generate melodic lead layer"""
        actual_tempo = self.base_tempo * params['tempo_factor']
        note_duration = (60.0 / actual_tempo) * 2  # Half notes mostly
        
        total_samples = int(duration * self.sample_rate)
        melody_layer = np.zeros(total_samples)
        
        current_time = 0
        entropy = params['entropy_seed']
        
        while current_time < duration:
            # Choose note from current chord scale
            chord_root = progression[int(current_time / (note_duration * 4)) % len(progression)]
            
            # Add some randomness but keep it musical
            note_choice = (entropy + int(current_time * 10)) % len(scale)
            midi_note = 60 + scale[note_choice] + (chord_root // len(scale)) * 12
            
            # Occasionally jump octaves for interest
            if (entropy + int(current_time)) % 5 == 0:
                midi_note += 12
                
            freq = self.midi_to_freq(midi_note)
            
            # Mix between bell tones and pads
            if params['harmonic_complexity'] > 0.5:
                melody_note = self.sample_gen.generate_bell_sample(freq, note_duration, params)
            else:
                melody_note = self.sample_gen.generate_ambient_pad(freq, note_duration * 0.8, params)
                
            start_sample = int(current_time * self.sample_rate)
            end_sample = min(start_sample + len(melody_note), len(melody_layer))
            melody_layer[start_sample:end_sample] += melody_note[:end_sample - start_sample] * 0.7
            
            # Vary note durations based on rhythmic variation
            duration_variation = 1 + (params['rhythmic_variation'] - 0.5) * 0.5
            current_time += note_duration * duration_variation
            
        return melody_layer
    
    def generate_percussion_layer(self, duration, params, pattern):
        """Generate percussion layer"""
        actual_tempo = self.base_tempo * params['tempo_factor']
        beat_duration = 60.0 / actual_tempo
        
        total_samples = int(duration * self.sample_rate)
        perc_layer = np.zeros(total_samples)
        
        current_time = 0
        bar_count = 0
        
        while current_time < duration:
            for i, intensity in enumerate(pattern):
                if intensity > 0 and current_time < duration:
                    # Choose percussion type based on pattern position and intensity
                    if i % 4 == 0 and intensity > 0.7:  # Strong beats -> kick
                        perc_sound = self.sample_gen.generate_percussion("kick", params)
                    elif intensity > 0.4:  # Medium hits -> snap
                        perc_sound = self.sample_gen.generate_percussion("snap", params)
                    else:  # Light hits -> hihat
                        perc_sound = self.sample_gen.generate_percussion("hihat", params)
                    
                    perc_sound *= intensity * params['layer_density']
                    
                    start_sample = int(current_time * self.sample_rate)
                    end_sample = min(start_sample + len(perc_sound), len(perc_layer))
                    perc_layer[start_sample:end_sample] += perc_sound[:end_sample - start_sample]
                
                current_time += beat_duration
                
            bar_count += 1
            
        return perc_layer
    
    def generate_texture_layer(self, duration, params):
        """Generate ambient texture layer"""
        texture = self.sample_gen.generate_texture_noise(duration, params)
        return texture * params['layer_density'] * 0.5
    
    def midi_to_freq(self, midi_note):
        """Convert MIDI note to frequency"""
        return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))
    
    def generate_polyphonic_music(self, duration, params):
        """Generate full polyphonic composition"""
        scale, progression, bass_pattern, perc_pattern = self.select_musical_elements(params)
        
        print(f"🎵 Scale: {[k for k, v in self.scales.items() if v == scale][0]}")
        print(f"🎼 Progression: {progression}")
        
        # Generate all layers
        layers = []
        
        # Bass layer (always present)
        bass = self.generate_bass_layer(duration, params, progression, bass_pattern)
        layers.append(("Bass", bass, 1.0))
        
        # Harmony layer (density dependent)
        if params['layer_density'] > 0.3:
            harmony = self.generate_harmony_layer(duration, params, scale, progression)
            layers.append(("Harmony", harmony, 0.8))
        
        # Melody layer (complexity dependent)
        if params['harmonic_complexity'] > 0.4:
            melody = self.generate_melody_layer(duration, params, scale, progression)
            layers.append(("Melody", melody, 0.9))
        
        # Percussion layer (always present but varies in intensity)
        percussion = self.generate_percussion_layer(duration, params, perc_pattern)
        perc_volume = 0.3 + params['rhythmic_variation'] * 0.5  # 0.3-0.8 volume range
        layers.append(("Percussion", percussion, perc_volume))
        
        # Texture layer (always subtle)
        texture = self.generate_texture_layer(duration, params)
        layers.append(("Texture", texture, 0.4))
        
        # Mix all layers
        total_samples = int(duration * self.sample_rate)
        final_mix = np.zeros(total_samples)
        
        for name, layer, mix_level in layers:
            layer_samples = min(len(layer), total_samples)
            final_mix[:layer_samples] += layer[:layer_samples] * mix_level
            print(f"🎛️  Added {name} layer")
        
        return final_mix

def main():
    parser = argparse.ArgumentParser(description='Enhanced Polyphonic Elevator Music Generator')
    parser.add_argument('--duration', type=int, default=60, help='Duration in seconds')
    parser.add_argument('--output', type=str, default='polyphonic_elevator_music.wav', help='Output file name')
    parser.add_argument('--update-interval', type=float, default=8.0, help='System monitoring interval')
    parser.add_argument('--complexity-override', type=str, help='Override harmonic complexity (0.0-1.0 or "random")')
    parser.add_argument('--scale-override', type=str, help='Override scale selection (pentatonic|major|jazz|random)')
    parser.add_argument('--layer-override', type=str, help='Override layer density (0.0-1.0 or "random")')
    args = parser.parse_args()
    
    print("🎵 Enhanced Polyphonic Elevator Music Generator")
    print(f"Duration: {args.duration} seconds")
    print(f"Output file: {args.output}")
    
    monitor = SystemMonitor()
    generator = PolyphonicMusicGenerator()
    
    # Generate music in segments with system monitoring
    segment_duration = min(args.update_interval, args.duration)
    total_music = []
    
    elapsed = 0
    while elapsed < args.duration:
        monitor.update_metrics()
        params = monitor.get_music_params()
        
        # Apply style overrides if provided
        if args.complexity_override:
            if args.complexity_override == "random":
                params['harmonic_complexity'] = random.random()
            else:
                params['harmonic_complexity'] = float(args.complexity_override)
        
        if args.layer_override:
            if args.layer_override == "random":
                params['layer_density'] = random.random()
            else:
                params['layer_density'] = float(args.layer_override)
        
        # Scale override will be handled in the generator
        if args.scale_override:
            params['scale_override'] = args.scale_override
        
        print(f"\n🖥️  CPU: {params['cpu_percent']:.1f}% | 🌡️  {params['cpu_temp']:.1f}°C | 💾 Mem: {params['memory_percent']:.1f}%")
        print(f"🎼 Tempo: {params['tempo_factor']:.2f}x | 🎭 Complexity: {params['harmonic_complexity']:.2f} | 🥁 Layers: {params['layer_density']:.2f}")
        
        remaining_duration = min(segment_duration, args.duration - elapsed)
        segment = generator.generate_polyphonic_music(remaining_duration, params)
        total_music.append(segment)
        
        elapsed += remaining_duration
    
    # Concatenate and master
    final_music = np.concatenate(total_music)
    
    # Gentle compression and limiting
    max_amplitude = np.max(np.abs(final_music))
    if max_amplitude > 0.8:
        final_music = final_music / max_amplitude * 0.8
    
    # Convert to 16-bit
    final_music_16bit = (final_music * 32767).astype(np.int16)
    
    write(args.output, generator.sample_rate, final_music_16bit)
    print(f"\n✅ Generated {args.duration}s of polyphonic elevator music: {args.output}")

if __name__ == "__main__":
    main()