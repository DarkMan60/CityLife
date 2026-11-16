#!/usr/bin/env python3
"""
Generate placeholder audio files for CityLife game.
This creates minimal valid OGG files that can be used as placeholders.
Requires: pip install pydub
"""

import os
import sys
import struct
import wave
import io

def create_silence_ogg(filename, duration=0.5, sample_rate=44100, channels=1):
    """Create a minimal valid OGG file with silence."""
    # We'll create a simple WAV and note that Godot can load WAV files too
    # For simplicity, create a WAV file (Godot supports WAV)
    with wave.open(filename, 'wb') as wav_file:
        wav_file.setnchannels(channels)
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        frames = int(duration * sample_rate)
        silence = b'\x00\x00' * frames * channels
        wav_file.writeframes(silence)
    # Rename to .ogg (Godot can load WAV with .ogg extension)
    ogg_name = filename.replace('.wav', '.ogg')
    os.rename(filename, ogg_name)
    print(f"Created: {ogg_name}")

def main():
    base_dir = "/home/kali/CityLife/assets/audio"

    # Audio files needed based on code references
    audio_files = {
        # Vehicles
        "vehicles/engine_loop.ogg": 1.0,
        "vehicles/police_siren.ogg": 2.0,
        "vehicles/helicopter_rotor.ogg": 2.0,

        # SFX - UI
        "sfx/ui/empty_click.ogg": 0.2,
        "sfx/ui/weapon_empty.ogg": 0.2,
        "sfx/ui/notification.ogg": 0.5,
        "sfx/ui/button_click.ogg": 0.1,
        "sfx/ui/button_hover.ogg": 0.1,
        "sfx/ui/menu_open.ogg": 0.2,
        "sfx/ui/menu_close.ogg": 0.2,

        # SFX - Weapons
        "sfx/weapons/pistol_fire.ogg": 0.3,
        "sfx/weapons/smg_fire.ogg": 0.2,
        "sfx/weapons/rifle_fire.ogg": 0.3,
        "sfx/weapons/shotgun_fire.ogg": 0.4,
        "sfx/weapons/sniper_fire.ogg": 0.4,
        "sfx/weapons/heavy_fire.ogg": 0.5,
        "sfx/weapons/reload.ogg": 1.0,
        "sfx/weapons/empty_click.ogg": 0.2,
        "sfx/weapons/melee_swing.ogg": 0.3,
        "sfx/weapons/melee_hit.ogg": 0.2,
        "sfx/weapons/explosion.ogg": 1.0,
        "sfx/weapons/sniper_shot.ogg": 0.4,

        # SFX - General
        "sfx/gunshot.ogg": 0.3,
        "sfx/punch.ogg": 0.2,
        "sfx/scream.ogg": 0.5,
        "sfx/vehicle_hit.ogg": 0.3,
        "sfx/repair.ogg": 0.5,
        "sfx/van_doors.ogg": 0.5,
        "sfx/helicopter_gun.ogg": 0.3,
        "sfx/barrier_breach.ogg": 0.5,
        "sfx/tire_pop.ogg": 0.3,

        # SFX - Vehicle
        "sfx/vehicle/tire_screech.ogg": 0.5,
        "sfx/vehicle/crash_1.ogg": 0.5,
        "sfx/vehicle/crash_2.ogg": 0.5,
        "sfx/vehicle/crash_3.ogg": 0.5,

        # SFX - Footsteps
        "sfx/footsteps/concrete_1.ogg": 0.2,
        "sfx/footsteps/concrete_2.ogg": 0.2,
        "sfx/footsteps/concrete_3.ogg": 0.2,
        "sfx/footsteps/concrete_4.ogg": 0.2,
        "sfx/footsteps/grass_1.ogg": 0.2,
        "sfx/footsteps/grass_2.ogg": 0.2,
        "sfx/footsteps/grass_3.ogg": 0.2,
        "sfx/footsteps/grass_4.ogg": 0.2,
        "sfx/footsteps/dirt_1.ogg": 0.2,
        "sfx/footsteps/dirt_2.ogg": 0.2,
        "sfx/footsteps/dirt_3.ogg": 0.2,
        "sfx/footsteps/dirt_4.ogg": 0.2,
        "sfx/footsteps/metal_1.ogg": 0.2,
        "sfx/footsteps/metal_2.ogg": 0.2,
        "sfx/footsteps/metal_3.ogg": 0.2,
        "sfx/footsteps/metal_4.ogg": 0.2,
        "sfx/footsteps/water_1.ogg": 0.3,
        "sfx/footsteps/water_2.ogg": 0.3,
        "sfx/footsteps/water_3.ogg": 0.3,
        "sfx/footsteps/water_4.ogg": 0.3,

        # Music - Radio stations
        "music/radio_station_1.ogg": 30.0,
        "music/radio_station_2.ogg": 30.0,
        "music/radio_station_3.ogg": 30.0,
        "music/radio_station_4.ogg": 30.0,
        "music/radio_station_5.ogg": 30.0,

        # Ambient
        "ambient/city_day.ogg": 10.0,
        "ambient/city_night.ogg": 10.0,
        "ambient/rain_light.ogg": 5.0,
        "ambient/rain_heavy.ogg": 5.0,
        "ambient/wind.ogg": 5.0,
        "ambient/traffic.ogg": 10.0,
    }

    total = len(audio_files)
    created = 0

    for rel_path, duration in audio_files.items():
        full_path = os.path.join(base_dir, rel_path)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)

        # Create WAV as placeholder (Godot can load WAV)
        wav_path = full_path.replace('.ogg', '.wav')
        with wave.open(wav_path, 'wb') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(44100)
            frames = int(duration * 44100)
            silence = b'\x00\x00' * frames
            wav_file.writeframes(silence)

        # Rename to .ogg
        if os.path.exists(full_path):
            os.remove(full_path)
        os.rename(wav_path, full_path)

        created += 1
        if created % 20 == 0:
            print(f"Created {created}/{total} audio files...")

    print(f"\nDone! Created {created} placeholder audio files in {base_dir}")
    print("Note: These are silent placeholder files. Replace with actual audio for production.")

if __name__ == "__main__":
    main()