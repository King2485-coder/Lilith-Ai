#!/usr/bin/env python3
"""
================================================================================
  Lilith Private LTE - eSIM Profile Generator
  
  Generates GSMA SGP.22 compliant eSIM profiles with:
  - LPA (Local Profile Assistant) activation strings
  - QR codes for easy eSIM provisioning
  - Custom carrier name: "LILITH"
  
  Profiles:
  - User A: IMSI 001010000000001, MSISDN 111
  - User B: IMSI 001010000000002, MSISDN 222
================================================================================
"""

import qrcode
import qrcode.image.svg
from PIL import Image, ImageDraw, ImageFont
import json
import base64
import hashlib
import os
from datetime import datetime, timedelta
from typing import Dict, NamedTuple
import textwrap

class eSIMProfile(NamedTuple):
    """Represents an eSIM profile"""
    iccid: str
    imsi: str
    msisdn: str
    carrier_name: str
    profile_name: str
    smdp_address: str
    matching_id: str
    confirmation_code: str
    imei: str

class LilithESIMGenerator:
    """
    Generates eSIM profiles for Lilith Private LTE Network.
    Creates QR codes following GSMA SGP.22 specification.
    """

    # Lilith network parameters
    CARRIER_NAME = "LILITH"
    NETWORK_NAME = "Lilith Private LTE"
    MCC = "001"
    MNC = "01"
    PLMN = f"{MCC}{MNC}"
    
    # SMDP+ server (Subscription Manager Data Preparation)
    SMDP_ADDRESS = "smdp.lilith-pvt-lte.local"
    SMDP_PORT = 443

    # Branding colors
    BRAND_COLOR = "#8B0000"  # Dark red for Lilith theme
    BRAND_BG = "#0A0A0A"     # Dark background
    ACCENT_COLOR = "#FF3333"  # Red accent

    def __init__(self, output_dir: str = "/mnt/agents/output/lilith-lte/esim"):
        self.output_dir = output_dir
        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(f"{output_dir}/qr_codes", exist_ok=True)
        os.makedirs(f"{output_dir}/profiles", exist_ok=True)

    def _generate_iccid(self, imsi: str, index: int) -> str:
        """Generate ICCID from IMSI"""
        # ICCID format: 89 (telecom) + MCC + MNC + IMSI suffix + checksum
        base = f"89{self.MCC}{self.MNC}{imsi[-9:]}{index:02d}"
        
        # Luhn checksum
        total = 0
        for i, digit in enumerate(reversed(base)):
            d = int(digit)
            if i % 2 == 1:
                d *= 2
                if d > 9:
                    d -= 9
            total += d
        
        checksum = (10 - (total % 10)) % 10
        return f"{base}{checksum}"

    def _generate_matching_id(self, imsi: str, msisdn: str) -> str:
        """Generate unique matching ID for SMDP+"""
        data = f"{imsi}:{msisdn}:{self.CARRIER_NAME}:{datetime.utcnow().isoformat()}"
        return base64.urlsafe_b64encode(
            hashlib.sha256(data.encode()).digest()
        ).decode()[:20]

    def _generate_lpa_string(self, profile: eSIMProfile) -> str:
        """
        Generate GSMA SGP.22 compliant LPA activation string.
        
        Format: LPA:$[activation code]
        activation code = [SMDP+ address]$[matching ID]$[OID]$[confirmation code]
        """
        # Build the activation code components
        smdp_with_port = f"{profile.smdp_address}:{self.SMDP_PORT}"
        
        # LPA string format following GSMA SGP.22
        lpa_components = [
            "1",  # Version
            smdp_with_port,
            profile.matching_id,
            "",   # OID (optional)
            profile.confirmation_code
        ]
        
        activation_code = "$".join(lpa_components)
        lpa_string = f"LPA:1${smdp_with_port}${profile.matching_id}"
        
        return lpa_string

    def _create_qr_code(self, lpa_string: str, profile: eSIMProfile, 
                        filename: str, user_label: str):
        """Create a branded QR code for eSIM activation"""
        
        # Create QR code
        qr = qrcode.QRCode(
            version=10,
            error_correction=qrcode.constants.ERROR_CORRECT_H,
            box_size=10,
            border=4,
        )
        qr.add_data(lpa_string)
        qr.make(fit=True)

        # Generate QR image with custom styling
        qr_img = qr.make_image(fill_color=self.BRAND_COLOR, back_color="white")
        qr_img = qr_img.convert('RGB')

        # Create branded frame
        frame_width = qr_img.size[0] + 100
        frame_height = qr_img.size[1] + 280
        
        frame = Image.new('RGB', (frame_width, frame_height), self.BRAND_BG)
        draw = ImageDraw.Draw(frame)

        # Add QR code to frame
        qr_x = 50
        qr_y = 120
        frame.paste(qr_img, (qr_x, qr_y))

        try:
            # Try to load a nice font, fallback to default
            title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 32)
            label_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
            info_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
            small_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
        except:
            title_font = ImageFont.load_default()
            label_font = ImageFont.load_default()
            info_font = ImageFont.load_default()
            small_font = ImageFont.load_default()

        # Header text
        title = "LILITH"
        subtitle = "Private LTE Network"
        
        # Center title
        title_bbox = draw.textbbox((0, 0), title, font=title_font)
        title_width = title_bbox[2] - title_bbox[0]
        title_x = (frame_width - title_width) // 2
        
        # Draw title with accent color
        draw.text((title_x, 20), title, fill=self.ACCENT_COLOR, font=title_font)
        
        # Subtitle
        sub_bbox = draw.textbbox((0, 0), subtitle, font=label_font)
        sub_width = sub_bbox[2] - sub_bbox[0]
        sub_x = (frame_width - sub_width) // 2
        draw.text((sub_x, 60), subtitle, fill="gray", font=label_font)

        # User label
        user_y = qr_y + qr_img.size[1] + 20
        user_bbox = draw.textbbox((0, 0), user_label, font=label_font)
        user_width = user_bbox[2] - user_bbox[0]
        user_x = (frame_width - user_width) // 2
        draw.text((user_x, user_y), user_label, fill="white", font=label_font)

        # IMSI info
        imsi_y = user_y + 40
        imsi_text = f"IMSI: {profile.imsi}"
        draw.text((50, imsi_y), imsi_text, fill="lightgray", font=info_font)

        # MSISDN
        msisdn_text = f"NUMBER: {profile.msisdn}"
        draw.text((50, imsi_y + 25), msisdn_text, fill="lightgray", font=info_font)

        # ICCID
        iccid_text = f"ICCID: {profile.iccid}"
        draw.text((50, imsi_y + 50), iccid_text, fill="lightgray", font=small_font)

        # Carrier branding box
        carrier_y = imsi_y + 85
        draw.rectangle([50, carrier_y, frame_width - 50, carrier_y + 35], 
                      fill=self.BRAND_COLOR)
        carrier_text = f"Carrier: {self.CARRIER_NAME}"
        carr_bbox = draw.textbbox((0, 0), carrier_text, font=info_font)
        carr_width = carr_bbox[2] - carr_bbox[0]
        carr_x = (frame_width - carr_width) // 2
        draw.text((carr_x, carrier_y + 7), carrier_text, fill="white", font=info_font)

        # Instructions
        instr_y = carrier_y + 55
        instructions = [
            "Scan to activate eSIM profile",
            "Settings > Network > Add eSIM",
            "Or enter LPA code manually"
        ]
        for i, line in enumerate(instructions):
            draw.text((50, instr_y + i * 20), line, fill="gray", font=small_font)

        # Save
        filepath = f"{self.output_dir}/qr_codes/{filename}"
        frame.save(filepath, quality=95)
        
        return filepath

    def generate_profile(self, imsi: str, msisdn: str, user_name: str, 
                        index: int) -> Dict:
        """Generate a complete eSIM profile with QR code"""
        
        iccid = self._generate_iccid(imsi, index)
        matching_id = self._generate_matching_id(imsi, msisdn)
        confirmation_code = base64.urlsafe_b64encode(
            os.urandom(16)
        ).decode()[:12]
        imei = f"3544900{index:06d}"

        profile = eSIMProfile(
            iccid=iccid,
            imsi=imsi,
            msisdn=msisdn,
            carrier_name=self.CARRIER_NAME,
            profile_name=f"LILITH-{user_name}",
            smdp_address=self.SMDP_ADDRESS,
            matching_id=matching_id,
            confirmation_code=confirmation_code,
            imei=imei
        )

        # Generate LPA string
        lpa_string = self._generate_lpa_string(profile)

        # Create QR code
        qr_filename = f"lilith_esim_{user_name.lower().replace(' ', '_')}.png"
        user_label = f"{user_name} - {msisdn}"
        qr_path = self._create_qr_code(lpa_string, profile, qr_filename, user_label)

        # Generate profile JSON
        profile_data = {
            "profile_metadata": {
                "carrier_name": self.CARRIER_NAME,
                "network_name": self.NETWORK_NAME,
                "profile_name": profile.profile_name,
                "iccid": profile.iccid,
                "imsi": profile.imsi,
                "msisdn": profile.msisdn,
                "mcc": self.MCC,
                "mnc": self.MNC,
                "plmn": self.PLMN
            },
            "activation": {
                "lpa_string": lpa_string,
                "smdp_address": profile.smdp_address,
                "smdp_port": self.SMDP_PORT,
                "matching_id": profile.matching_id,
                "confirmation_code": profile.confirmation_code
            },
            "security": {
                "authentication_key": self._get_key_for_imsi(imsi),
                "opc": self._get_opc_for_imsi(imsi),
                "amf": "0x9001"
            },
            "device": {
                "imei": profile.imei
            },
            "branding": {
                "carrier_name_display": self.CARRIER_NAME,
                "spn": self.CARRIER_NAME,
                "pnn": self.NETWORK_NAME,
                "opl": f"{self.MCC}{self.MNC};{self.CARRIER_NAME}"
            }
        }

        # Save profile JSON
        json_filename = f"lilith_profile_{user_name.lower().replace(' ', '_')}.json"
        json_path = f"{self.output_dir}/profiles/{json_filename}"
        with open(json_path, 'w') as f:
            json.dump(profile_data, f, indent=2)

        return {
            "profile": profile_data,
            "lpa_string": lpa_string,
            "qr_code_path": qr_path,
            "json_path": json_path,
            "user": user_name
        }

    def _get_key_for_imsi(self, imsi: str) -> str:
        """Get authentication key for IMSI"""
        keys = {
            "001010000000001": "00112233445566778899AABBCCDDEEFF",
            "001010000000002": "11223344556677889900AABBCCDDEEFF"
        }
        return keys.get(imsi, "")

    def _get_opc_for_imsi(self, imsi: str) -> str:
        """Get OPC for IMSI"""
        opcs = {
            "001010000000001": "000102030405060708090A0B0C0D0E0F",
            "001010000000002": "101112131415161718191A1B1C1D1E1F"
        }
        return opcs.get(imsi, "")

    def generate_all_profiles(self):
        """Generate profiles for all subscribers"""
        
        subscribers = [
            {
                "imsi": "001010000000001",
                "msisdn": "111",
                "name": "User A",
                "index": 1
            },
            {
                "imsi": "001010000000002",
                "msisdn": "222",
                "name": "User B",
                "index": 2
            }
        ]

        results = []
        print("=" * 60)
        print("  Lilith eSIM Profile Generator")
        print("=" * 60)

        for sub in subscribers:
            print(f"\n[Generating] Profile for {sub['name']} ({sub['msisdn']})")
            
            result = self.generate_profile(
                sub["imsi"],
                sub["msisdn"],
                sub["name"],
                sub["index"]
            )
            
            results.append(result)
            
            print(f"  ICCID: {result['profile']['profile_metadata']['iccid']}")
            print(f"  IMSI:  {sub['imsi']}")
            print(f"  MSISDN: {sub['msisdn']}")
            print(f"  LPA String: {result['lpa_string']}")
            print(f"  QR Code: {result['qr_code_path']}")
            print(f"  Profile JSON: {result['json_path']}")

        # Generate summary
        self._generate_summary(results)
        
        return results

    def _generate_summary(self, results):
        """Generate summary document"""
        summary = {
            "network": {
                "carrier_name": self.CARRIER_NAME,
                "network_name": self.NETWORK_NAME,
                "mcc": self.MCC,
                "mnc": self.MNC,
                "plmn": self.PLMN
            },
            "generated_at": datetime.utcnow().isoformat(),
            "profiles": [
                {
                    "user": r["user"],
                    "msisdn": r["profile"]["profile_metadata"]["msisdn"],
                    "imsi": r["profile"]["profile_metadata"]["imsi"],
                    "iccid": r["profile"]["profile_metadata"]["iccid"],
                    "lpa_string": r["lpa_string"],
                    "qr_code": r["qr_code_path"],
                    "profile_file": r["json_path"]
                }
                for r in results
            ]
        }

        summary_path = f"{self.output_dir}/esim_summary.json"
        with open(summary_path, 'w') as f:
            json.dump(summary, f, indent=2)

        print("\n" + "=" * 60)
        print("  eSIM Generation Complete")
        print(f"  Summary: {summary_path}")
        print(f"  QR Codes: {self.output_dir}/qr_codes/")
        print(f"  Profiles: {self.output_dir}/profiles/")
        print("=" * 60)


def main():
    generator = LilithESIMGenerator()
    return generator.generate_all_profiles()


if __name__ == "__main__":
    main()
