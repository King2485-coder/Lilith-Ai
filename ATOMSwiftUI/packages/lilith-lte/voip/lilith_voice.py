#!/usr/bin/env python3
"""
================================================================================
  Lilith Voice System - Text-to-Speech Service
  
  Generates Lilith's voice responses for:
  1. Operator greeting when users dial '0'
  2. Focus state acknowledgment
  3. Thank you message
  
  Uses pyttsx3 for offline TTS or connects to ElevenLabs API
  for premium voice quality.
================================================================================
"""

import os
import sys
import json
import hashlib
import subprocess
from pathlib import Path
from typing import Optional, Dict
from dataclasses import dataclass

# Ensure output directory exists
OUTPUT_DIR = "/mnt/agents/output/lilith-lte/voip/audio"
os.makedirs(OUTPUT_DIR, exist_ok=True)

@dataclass
class LilithVoiceConfig:
    """Configuration for Lilith's voice"""
    voice_id: str = "XB0fDUnXU5powFXDhCwa"  # Default: Ally
    model_id: str = "eleven_turbo_v2"
    stability: float = 0.71
    similarity_boost: float = 0.87
    style: float = 0.45
    use_speaker_boost: bool = True

class LilithVoiceSystem:
    """
    Lilith's Voice System - Generates spoken responses
    for the Private LTE Network operator service.
    """

    # Lilith's script templates
    GREETING = """This is Operator Lilith. Which focus state should I initialize for your node? You may say: Red State for critical operations, Blue State for normal mode, Green State to initiate, or Amber State to hold and observe."""

    FOCUS_PROMPT = """Please say your desired focus state after the tone."""

    FOCUS_RESPONSES = {
        "red": "Focus state Red initialized. Critical operations mode engaged. All priority channels are now active. Proceed with caution.",
        "blue": "Focus state Blue confirmed. Normal operations mode active. All systems running within standard parameters.",
        "green": "Focus state Green initiated. Ready mode engaged. Your node is prepared for activation. Awaiting your command.",
        "amber": "Focus state Amber set. Observation mode active. Monitoring and analysis protocols engaged. Stand by for updates.",
        "unknown": "I'm sorry, I didn't understand your selection. Please try again. Say Red, Blue, Green, or Amber."
    }

    THANK_YOU = """Thank you for using Lilith Private LTE Network. Your session is logged and secured. Have a productive cycle."""

    NETWORK_STATUS = """Lilith Private LTE Network status: All systems operational. Your connection is secure. Signal strength optimal on band 7."""

    def __init__(self, config: Optional[LilithVoiceConfig] = None):
        self.config = config or LilithVoiceConfig()
        self.output_dir = OUTPUT_DIR
        self.audio_files = {}

    def _generate_cache_key(self, text: str) -> str:
        """Generate cache key for audio file"""
        return hashlib.md5(text.encode()).hexdigest()

    def generate_with_pyttsx3(self, text: str, filename: str) -> str:
        """Generate audio using pyttsx3 (offline)"""
        try:
            import pyttsx3
            
            filepath = os.path.join(self.output_dir, f"{filename}.wav")
            
            engine = pyttsx3.init()
            
            # Configure voice properties
            voices = engine.getProperty('voices')
            
            # Try to find a female voice
            female_voice = None
            for voice in voices:
                if 'female' in voice.name.lower() or 'zira' in voice.name.lower():
                    female_voice = voice.id
                    break
            
            if female_voice:
                engine.setProperty('voice', female_voice)
            
            engine.setProperty('rate', 165)  # Slightly slower for clarity
            engine.setProperty('volume', 0.9)
            
            engine.save_to_file(text, filepath)
            engine.runAndWait()
            engine.stop()
            
            print(f"[TTS] Generated (pyttsx3): {filepath}")
            return filepath
            
        except ImportError:
            print("[WARNING] pyttsx3 not available, using alternative method")
            return self._generate_placeholder_audio(filename)
        except Exception as e:
            print(f"[ERROR] TTS generation failed: {e}")
            return self._generate_placeholder_audio(filename)

    def generate_with_gtts(self, text: str, filename: str) -> str:
        """Generate audio using gTTS (Google Text-to-Speech)"""
        try:
            from gtts import gTTS
            
            filepath = os.path.join(self.output_dir, f"{filename}.mp3")
            
            tts = gTTS(
                text=text,
                lang='en',
                slow=False,
                lang_check=False
            )
            tts.save(filepath)
            
            print(f"[TTS] Generated (gTTS): {filepath}")
            return filepath
            
        except ImportError:
            return self.generate_with_pyttsx3(text, filename)
        except Exception as e:
            print(f"[ERROR] gTTS failed: {e}")
            return self.generate_with_pyttsx3(text, filename)

    def _generate_placeholder_audio(self, filename: str) -> str:
        """Generate a placeholder WAV file if TTS is unavailable"""
        filepath = os.path.join(self.output_dir, f"{filename}.wav")
        
        try:
            # Generate silent WAV file as placeholder
            import wave
            import struct
            
            sample_rate = 44100
            duration = 3  # seconds
            
            with wave.open(filepath, 'w') as wav:
                wav.setnchannels(1)
                wav.setsampwidth(2)
                wav.setframerate(sample_rate)
                
                # Write silence
                for _ in range(sample_rate * duration):
                    wav.writeframes(struct.pack('<h', 0))
            
            print(f"[TTS] Generated placeholder: {filepath}")
            return filepath
            
        except Exception as e:
            print(f"[ERROR] Placeholder generation failed: {e}")
            return filepath

    def generate_all_prompts(self):
        """Generate all Lilith voice prompts"""
        print("=" * 60)
        print("  Lilith Voice System - Generating Audio Prompts")
        print("=" * 60)

        # Generate greeting
        print("\n[1/4] Generating greeting...")
        greeting_path = self.generate_with_gtts(
            self.GREETING,
            "lilith_greeting"
        )
        self.audio_files['greeting'] = greeting_path

        # Generate focus prompt
        print("\n[2/4] Generating focus state prompt...")
        focus_prompt_path = self.generate_with_gtts(
            self.FOCUS_PROMPT,
            "lilith_focus_prompt"
        )
        self.audio_files['focus_prompt'] = focus_prompt_path

        # Generate thank you
        print("\n[3/4] Generating thank you message...")
        thankyou_path = self.generate_with_gtts(
            self.THANK_YOU,
            "lilith_thankyou"
        )
        self.audio_files['thankyou'] = thankyou_path

        # Generate network status
        print("\n[4/4] Generating network status...")
        status_path = self.generate_with_gtts(
            self.NETWORK_STATUS,
            "lilith_status"
        )
        self.audio_files['status'] = status_path

        # Generate focus state responses
        print("\n[Bonus] Generating focus state responses...")
        for state, response in self.FOCUS_RESPONSES.items():
            path = self.generate_with_gtts(
                response,
                f"lilith_focus_{state}"
            )
            self.audio_files[f'focus_{state}'] = path

        # Save manifest
        manifest_path = os.path.join(self.output_dir, "voice_manifest.json")
        with open(manifest_path, 'w') as f:
            json.dump({
                "voice_system": "Lilith TTS",
                "generated_at": str(__import__('datetime').datetime.utcnow()),
                "audio_files": self.audio_files,
                "scripts": {
                    "greeting": self.GREETING,
                    "focus_prompt": self.FOCUS_PROMPT,
                    "thankyou": self.THANK_YOU,
                    "network_status": self.NETWORK_STATUS,
                    "focus_responses": self.FOCUS_RESPONSES
                }
            }, f, indent=2)

        print("\n" + "=" * 60)
        print("  Voice Generation Complete")
        print(f"  Audio files: {self.output_dir}")
        print(f"  Manifest: {manifest_path}")
        print("=" * 60)

        return self.audio_files

    def get_focus_response(self, focus_state: str) -> str:
        """Get the appropriate response for a focus state"""
        focus_lower = focus_state.lower().strip()
        
        if "red" in focus_lower:
            return self.FOCUS_RESPONSES["red"]
        elif "blue" in focus_lower:
            return self.FOCUS_RESPONSES["blue"]
        elif "green" in focus_lower:
            return self.FOCUS_RESPONSES["green"]
        elif "amber" in focus_lower or "yellow" in focus_lower:
            return self.FOCUS_RESPONSES["amber"]
        else:
            return self.FOCUS_RESPONSES["unknown"]


# =============================================================================
# AGI Script for Focus State Processing
# =============================================================================

def generate_agi_script():
    """Generate the Asterisk AGI script for processing focus state"""
    
    agi_content = '''#!/usr/bin/env python3
"""
Lilith Focus State AGI Script
Processes user's focus state selection from voice input
"""

import sys
import os
from datetime import datetime

# Read AGI environment
agi_env = {}
while True:
    line = sys.stdin.readline().strip()
    if line == '':
        break
    if ': ' in line:
        key, value = line.split(': ', 1)
        agi_env[key] = value

# Get arguments
focus_state = sys.argv[1] if len(sys.argv) > 1 else "unknown"
caller_number = sys.argv[2] if len(sys.argv) > 2 else "unknown"

# Log the focus state selection
log_entry = f"{datetime.utcnow().isoformat()} | Caller: {caller_number} | Focus State: {focus_state}\\n"
with open('/var/log/lilith/focus_state.log', 'a') as f:
    f.write(log_entry)

# Send AGI response
print(f'SET VARIABLE LILITH_FOCUS_STATE "{focus_state}"')
print(f'SET VARIABLE LILITH_CALLER "{caller_number}"')
print(f'SET VARIABLE LILITH_RESULT "processed"')

# Return appropriate audio file based on focus state
focus_lower = focus_state.lower()
if "red" in focus_lower:
    print('SET VARIABLE LILITH_RESPONSE "lilith_focus_red"')
elif "blue" in focus_lower:
    print('SET VARIABLE LILITH_RESPONSE "lilith_focus_blue"')
elif "green" in focus_lower:
    print('SET VARIABLE LILITH_RESPONSE "lilith_focus_green"')
elif "amber" in focus_lower:
    print('SET VARIABLE LILITH_RESPONSE "lilith_focus_amber"')
else:
    print('SET VARIABLE LILITH_RESPONSE "lilith_focus_unknown"')

sys.stdout.flush()
'''

    agi_path = "/mnt/agents/output/lilith-lte/voip/asterisk/agi/lilith_process_focus.agi"
    os.makedirs(os.path.dirname(agi_path), exist_ok=True)
    
    with open(agi_path, 'w') as f:
        f.write(agi_content)
    
    os.chmod(agi_path, 0o755)
    print(f"[AGI] Generated: {agi_path}")


# =============================================================================
# Main Entry Point
# =============================================================================

def main():
    """Main entry point"""
    voice_system = LilithVoiceSystem()
    
    # Generate all audio prompts
    audio_files = voice_system.generate_all_prompts()
    
    # Generate AGI script
    generate_agi_script()
    
    return audio_files


if __name__ == "__main__":
    main()
