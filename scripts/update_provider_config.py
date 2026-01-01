#!/usr/bin/env python3
"""
SwiftSpeak Provider Config Updater
===================================

Runs weekly via cron to update Firebase Remote Config with latest provider data.

Setup on Hostinger KVM:
1. pip3 install firebase-admin requests
2. Copy this script to /opt/swiftspeak/update_provider_config.py
3. Copy service-account.json to /opt/swiftspeak/
4. Add to crontab: 0 3 * * 0 /usr/bin/python3 /opt/swiftspeak/update_provider_config.py

Usage:
    python3 update_provider_config.py              # Update Firebase
    python3 update_provider_config.py --dry-run    # Preview config without updating
    python3 update_provider_config.py --output     # Write to local JSON file
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

# Firebase imports - only needed when actually updating
try:
    import firebase_admin
    from firebase_admin import credentials, remote_config
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False


# =============================================================================
# Provider Pricing Data (Updated manually when providers change pricing)
# =============================================================================

PRICING = {
    "openAI": {
        # Transcription models
        "whisper-1": {"unit": "minute", "cost": 0.006},
        "gpt-4o-transcribe": {"unit": "minute", "cost": 0.006},  # Same as whisper
        "gpt-4o-mini-transcribe": {"unit": "minute", "cost": 0.003},  # Cheaper mini model
        # LLM models
        "gpt-4o": {"inputPerMToken": 2.50, "outputPerMToken": 10.00},
        "gpt-4o-mini": {"inputPerMToken": 0.15, "outputPerMToken": 0.60},
        "o1": {"inputPerMToken": 15.00, "outputPerMToken": 60.00},
    },
    "anthropic": {
        "claude-3-5-sonnet-latest": {"inputPerMToken": 3.00, "outputPerMToken": 15.00},
        "claude-3-5-haiku-latest": {"inputPerMToken": 0.80, "outputPerMToken": 4.00},
        "claude-3-opus-latest": {"inputPerMToken": 15.00, "outputPerMToken": 75.00},
    },
    "google": {
        "google-stt": {"unit": "minute", "cost": 0.006},
        "gemini-1.5-flash": {"inputPerMToken": 0.075, "outputPerMToken": 0.30},
        "gemini-1.5-pro": {"inputPerMToken": 1.25, "outputPerMToken": 5.00},
    },
    "deepgram": {
        "nova-2": {"unit": "minute", "cost": 0.0043},
        "nova": {"unit": "minute", "cost": 0.0040},
        "enhanced": {"unit": "minute", "cost": 0.0036},
    },
    "assemblyAI": {
        "best": {"unit": "minute", "cost": 0.00025},
        "nano": {"unit": "minute", "cost": 0.00012},
    },
    "elevenLabs": {
        "scribe_v1": {"unit": "minute", "cost": 0.01},
    },
    "deepL": {
        "default": {"unit": "character", "cost": 0.00002},
    },
    "azure": {
        "default": {"unit": "character", "cost": 0.00001},
    },
    "local": {
        "whisperkit-base": {"unit": "minute", "cost": 0},
        "whisperkit-small": {"unit": "minute", "cost": 0},
        "whisperkit-large": {"unit": "minute", "cost": 0},
        "apple-translation": {"unit": "character", "cost": 0},
        "apple-intelligence": {"inputPerMToken": 0, "outputPerMToken": 0},
    },
}


# =============================================================================
# Language Support Data
# =============================================================================

# Quality levels: excellent, good, limited, unsupported
LANGUAGE_SUPPORT = {
    "openAI": {
        "transcription": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "excellent", "zh": "excellent",
            "ko": "excellent", "pl": "excellent", "pt": "excellent",
            "ru": "excellent", "it": "excellent", "ar": "excellent",
            "hi": "good", "nl": "excellent", "sv": "excellent",
            "tr": "good", "uk": "good", "vi": "good",
        },
        "translation": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "excellent", "zh": "excellent",
            "ko": "excellent", "pl": "excellent", "pt": "excellent",
            "ru": "excellent", "it": "excellent", "ar": "good",
            "hi": "good", "nl": "excellent", "sv": "excellent",
            "tr": "good", "uk": "good", "vi": "good",
        },
    },
    "anthropic": {
        "translation": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "good", "zh": "good",
            "ko": "good", "pl": "good", "pt": "excellent",
            "ru": "good", "it": "excellent", "ar": "limited",
        },
    },
    "google": {
        "transcription": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "excellent", "zh": "excellent",
            "ko": "excellent", "pl": "good", "pt": "excellent",
            "ru": "excellent", "it": "excellent", "ar": "good",
            "hi": "good", "nl": "excellent", "sv": "good",
        },
        "translation": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "excellent", "zh": "excellent",
            "ko": "excellent", "pl": "good", "pt": "excellent",
            "ru": "excellent", "it": "excellent", "ar": "good",
        },
    },
    "deepgram": {
        "transcription": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "good", "zh": "good",
            "ko": "good", "pl": "limited", "pt": "excellent",
            "ru": "good", "it": "good", "ar": "good",
            "hi": "good", "nl": "excellent",
        },
    },
    "assemblyAI": {
        "transcription": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "good", "zh": "good",
            "ko": "good", "pl": "good", "pt": "excellent",
            "ru": "good", "it": "excellent",
        },
    },
    "elevenLabs": {
        "transcription": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "good", "zh": "good",
            "ko": "good", "pl": "good", "pt": "excellent",
            "ru": "good", "it": "excellent",
        },
    },
    "deepL": {
        "translation": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "excellent", "zh": "excellent",
            "ko": "excellent", "pl": "excellent", "pt": "excellent",
            "ru": "excellent", "it": "excellent", "nl": "excellent",
            "sv": "excellent", "uk": "excellent",
        },
    },
    "azure": {
        "translation": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "excellent", "zh": "excellent",
            "ko": "excellent", "pl": "excellent", "pt": "excellent",
            "ru": "excellent", "it": "excellent", "ar": "excellent",
            "hi": "good", "nl": "excellent", "sv": "excellent",
            "tr": "excellent", "uk": "excellent", "vi": "excellent",
        },
    },
    "local": {
        "transcription": {
            "en": "excellent", "es": "good", "fr": "good",
            "de": "good", "ja": "limited", "zh": "limited",
            "ko": "limited", "pl": "limited", "pt": "good",
            "ru": "limited", "it": "good",
        },
        "translation": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "excellent", "zh": "excellent",
            "ko": "excellent", "pl": "good", "pt": "excellent",
            "ru": "excellent", "it": "excellent", "ar": "good",
        },
    },
}


# =============================================================================
# Model Configurations
# =============================================================================

MODELS = {
    "openAI": {
        "transcription": [
            {"id": "gpt-4o-transcribe", "name": "GPT-4o Transcribe", "isDefault": True, "streaming": True},
            {"id": "gpt-4o-mini-transcribe", "name": "GPT-4o Mini Transcribe", "streaming": True},
            {"id": "whisper-1", "name": "Whisper", "streaming": False},
        ],
        "translation": [
            {"id": "gpt-4o-mini", "name": "GPT-4o Mini", "isDefault": True},
            {"id": "gpt-4o", "name": "GPT-4o"},
        ],
        "powerMode": [
            {"id": "gpt-4o", "name": "GPT-4o", "isDefault": True},
            {"id": "gpt-4o-mini", "name": "GPT-4o Mini"},
            {"id": "o1", "name": "o1 (Reasoning)", "tier": "power"},
        ],
    },
    "anthropic": {
        "translation": [
            {"id": "claude-3-5-sonnet-latest", "name": "Claude 3.5 Sonnet", "isDefault": True},
            {"id": "claude-3-5-haiku-latest", "name": "Claude 3.5 Haiku"},
        ],
        "powerMode": [
            {"id": "claude-3-5-sonnet-latest", "name": "Claude 3.5 Sonnet", "isDefault": True},
            {"id": "claude-3-5-haiku-latest", "name": "Claude 3.5 Haiku"},
            {"id": "claude-3-opus-latest", "name": "Claude 3 Opus", "tier": "power"},
        ],
    },
    "google": {
        "transcription": [
            {"id": "google-stt", "name": "Google Speech-to-Text", "isDefault": True, "streaming": False},
        ],
        "translation": [
            {"id": "gemini-1.5-flash", "name": "Gemini 1.5 Flash", "isDefault": True},
            {"id": "gemini-1.5-pro", "name": "Gemini 1.5 Pro"},
        ],
        "powerMode": [
            {"id": "gemini-1.5-flash", "name": "Gemini 1.5 Flash", "isDefault": True},
            {"id": "gemini-1.5-pro", "name": "Gemini 1.5 Pro"},
        ],
    },
    "deepgram": {
        "transcription": [
            {"id": "nova-2", "name": "Nova 2", "isDefault": True, "streaming": True},
            {"id": "nova", "name": "Nova", "streaming": True},
            {"id": "enhanced", "name": "Enhanced", "streaming": True},
        ],
    },
    "assemblyAI": {
        "transcription": [
            {"id": "best", "name": "Best", "isDefault": True, "streaming": True},
            {"id": "nano", "name": "Nano", "streaming": True},
        ],
    },
    "elevenLabs": {
        "transcription": [
            {"id": "scribe_v1", "name": "Scribe v1", "isDefault": True, "streaming": False},
        ],
    },
    "deepL": {
        "translation": [
            {"id": "default", "name": "DeepL", "isDefault": True},
        ],
    },
    "azure": {
        "translation": [
            {"id": "default", "name": "Azure Translator", "isDefault": True},
        ],
    },
    "local": {
        "transcription": [
            {"id": "whisperkit-base", "name": "WhisperKit Base", "isDefault": True, "streaming": False},
            {"id": "whisperkit-small", "name": "WhisperKit Small", "streaming": False},
            {"id": "whisperkit-large", "name": "WhisperKit Large", "streaming": False},
        ],
        "translation": [
            {"id": "apple-translation", "name": "Apple Translation", "isDefault": True},
        ],
        "powerMode": [
            {"id": "apple-intelligence", "name": "Apple Intelligence", "isDefault": True},
        ],
    },
}


# =============================================================================
# Provider Metadata
# =============================================================================

PROVIDER_METADATA = {
    "openAI": {
        "displayName": "OpenAI",
        "freeCredits": "$5 for new accounts",
        "apiKeyUrl": "https://platform.openai.com/api-keys",
    },
    "anthropic": {
        "displayName": "Anthropic Claude",
        "freeCredits": "$5 for new accounts",
        "apiKeyUrl": "https://console.anthropic.com/settings/keys",
    },
    "google": {
        "displayName": "Google Gemini",
        "apiKeyUrl": "https://aistudio.google.com/app/apikey",
    },
    "deepgram": {
        "displayName": "Deepgram",
        "freeCredits": "$200 free credit",
        "apiKeyUrl": "https://console.deepgram.com/project/api-keys",
    },
    "assemblyAI": {
        "displayName": "AssemblyAI",
        "freeCredits": "Free tier with limits",
        "apiKeyUrl": "https://www.assemblyai.com/app/account",
    },
    "elevenLabs": {
        "displayName": "ElevenLabs",
        "notes": "Primarily known for TTS, transcription is secondary",
        "apiKeyUrl": "https://elevenlabs.io/app/settings/api-keys",
    },
    "deepL": {
        "displayName": "DeepL",
        "notes": "Arabic not supported. Best quality for European languages.",
        "freeCredits": "500,000 characters/month free",
        "apiKeyUrl": "https://www.deepl.com/account/summary",
    },
    "azure": {
        "displayName": "Azure Translator",
        "freeCredits": "2M characters/month free",
        "apiKeyUrl": "https://portal.azure.com/",
    },
    "local": {
        "displayName": "On-Device",
        "notes": "100% on-device processing. No data leaves your device.",
    },
}


# =============================================================================
# Build Configuration
# =============================================================================

def build_capability_config(provider_id: str, capability: str) -> dict | None:
    """Build configuration for a specific capability."""
    models = MODELS.get(provider_id, {}).get(capability)
    languages = LANGUAGE_SUPPORT.get(provider_id, {}).get(capability)

    if not models and not languages:
        return {"enabled": False}

    config = {"enabled": True}

    if models:
        config["models"] = models

    if languages:
        config["languages"] = languages

    # Add features based on capability
    if capability == "transcription":
        config["features"] = ["languageDetection"]
        if provider_id in ["deepgram", "assemblyAI", "elevenLabs"]:
            config["features"].append("speakerDiarization")
        if provider_id == "local":
            config["features"] = ["offline", "privacyFirst"]
    elif capability == "translation":
        config["features"] = ["contextAware"]
        if provider_id in ["deepL", "azure"]:
            config["features"].append("formality")
        if provider_id == "local":
            config["features"] = ["offline", "privacyFirst"]
    elif capability == "powerMode":
        config["features"] = ["streaming"]
        if provider_id == "local":
            config["features"] = ["offline", "privacyFirst", "streaming"]

    return config


def build_provider_config() -> dict:
    """Build the complete provider configuration."""
    now = datetime.now(timezone.utc)

    providers = {}

    for provider_id, metadata in PROVIDER_METADATA.items():
        provider_config = {
            "displayName": metadata["displayName"],
            "status": "operational",
            "transcription": build_capability_config(provider_id, "transcription"),
            "translation": build_capability_config(provider_id, "translation"),
            "powerMode": build_capability_config(provider_id, "powerMode"),
            "pricing": PRICING.get(provider_id, {}),
        }

        # Add optional metadata
        if "freeCredits" in metadata:
            provider_config["freeCredits"] = metadata["freeCredits"]
        if "apiKeyUrl" in metadata:
            provider_config["apiKeyUrl"] = metadata["apiKeyUrl"]
        if "notes" in metadata:
            provider_config["notes"] = metadata["notes"]

        providers[provider_id] = provider_config

    return {
        "version": now.strftime("%Y.%m.%d"),
        "lastUpdated": now.isoformat().replace("+00:00", "Z"),
        "schemaVersion": 1,
        "providers": providers,
    }


# =============================================================================
# Firebase Update
# =============================================================================

def update_firebase(config: dict, service_account_path: str) -> bool:
    """Push config to Firebase Remote Config."""
    if not FIREBASE_AVAILABLE:
        print("ERROR: firebase-admin is not installed.")
        print("Run: pip3 install firebase-admin")
        return False

    try:
        # Initialize Firebase if not already initialized
        if not firebase_admin._apps:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)

        # Get current template
        template = remote_config.get_server_template()

        # Update the provider_config parameter
        parameters = template.parameters if hasattr(template, 'parameters') else {}
        parameters["provider_config"] = {
            "defaultValue": {"value": json.dumps(config)}
        }

        # Create and publish new template
        template = remote_config.init_server_template(
            default_config={"provider_config": json.dumps(config)}
        )
        remote_config.set_server_template(template)

        print(f"Successfully updated Firebase Remote Config at {datetime.now()}")
        return True

    except Exception as e:
        print(f"ERROR updating Firebase: {e}")
        return False


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description="Update SwiftSpeak provider config")
    parser.add_argument("--dry-run", action="store_true", help="Preview config without updating")
    parser.add_argument("--output", type=str, help="Write config to local JSON file")
    parser.add_argument("--service-account", type=str,
                       default="/opt/swiftspeak/service-account.json",
                       help="Path to Firebase service account JSON")

    args = parser.parse_args()

    # Build config
    config = build_provider_config()

    if args.dry_run:
        print("=== DRY RUN - Preview Config ===")
        print(json.dumps(config, indent=2))
        return

    if args.output:
        with open(args.output, "w") as f:
            json.dump(config, f, indent=2)
        print(f"Config written to {args.output}")
        return

    # Update Firebase
    if not os.path.exists(args.service_account):
        print(f"ERROR: Service account file not found: {args.service_account}")
        print("Please copy your Firebase service account JSON to this location.")
        sys.exit(1)

    success = update_firebase(config, args.service_account)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
