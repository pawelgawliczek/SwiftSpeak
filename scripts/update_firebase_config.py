#!/usr/bin/env python3
"""
================================================================================
SwiftSpeak Firebase Remote Config Updater
================================================================================

PURPOSE
-------
This script automatically updates Firebase Remote Config with the latest AI
provider information (pricing, models, language support, capabilities) by
using Claude CLI to fetch live data from provider websites.

The iOS app (SwiftSpeak) fetches this config on launch to display current
pricing, available models, and language support without requiring app updates.

ARCHITECTURE
------------
┌─────────────────────────────────────────────────────────────────────────────┐
│  Cron Job (weekly, Sunday 3 AM)                                             │
│    │                                                                        │
│    ▼                                                                        │
│  update_firebase_config.py                                                  │
│    │                                                                        │
│    ├──► For each provider (openai, anthropic, google, etc.):               │
│    │      │                                                                 │
│    │      ▼                                                                 │
│    │    claude -p "Visit URLs, extract data, return JSON..."               │
│    │      │                                                                 │
│    │      ▼                                                                 │
│    │    Claude visits provider websites, extracts:                          │
│    │      - Current pricing (per minute, per token, per character)         │
│    │      - Available models with exact API IDs                             │
│    │      - Supported languages with quality ratings                        │
│    │      - Feature capabilities                                            │
│    │      │                                                                 │
│    │      ▼                                                                 │
│    │    Returns structured JSON                                             │
│    │      │                                                                 │
│    │      ▼                                                                 │
│    │    Script validates JSON structure and data                            │
│    │                                                                        │
│    ├──► Merge all provider data                                             │
│    │                                                                        │
│    ▼                                                                        │
│  Push to Firebase Remote Config (REST API)                                  │
│    │                                                                        │
│    ▼                                                                        │
│  iOS App fetches config on launch                                           │
└─────────────────────────────────────────────────────────────────────────────┘

REQUIREMENTS
------------
1. Python 3.8+
2. Dependencies: pip3 install google-auth requests
3. Claude CLI: npm install -g @anthropic-ai/claude-code && claude login
4. Firebase service account JSON file (from Firebase Console)

SETUP ON HOSTINGER
------------------
1. Create directory: mkdir -p /opt/SwiftSpeakScript
2. Create venv: python3 -m venv /opt/SwiftSpeakScript/venv
3. Install deps: /opt/SwiftSpeakScript/venv/bin/pip install google-auth requests
4. Install Claude CLI: npm install -g @anthropic-ai/claude-code
5. Authenticate Claude: claude login
6. Copy this script to /opt/SwiftSpeakScript/update_firebase_config.py
7. Copy service-account.json to /opt/SwiftSpeakScript/service-account.json
8. Add cron job:
   crontab -e
   0 3 * * 0 /opt/SwiftSpeakScript/venv/bin/python /opt/SwiftSpeakScript/update_firebase_config.py >> /var/log/swiftspeak-config.log 2>&1

USAGE
-----
# Fetch live data from all providers and update Firebase
python3 update_firebase_config.py

# Preview what would be updated (dry run)
python3 update_firebase_config.py --dry-run

# Update only a specific provider
python3 update_firebase_config.py --provider openai

# Fetch data without updating Firebase (for testing)
python3 update_firebase_config.py --skip-firebase

# Run validation tests only
python3 update_firebase_config.py --test

================================================================================
JSON SCHEMA SPECIFICATION
================================================================================

Each provider MUST return JSON matching this exact schema. Claude is instructed
to follow this precisely.

PROVIDER OBJECT STRUCTURE:
{
  "displayName": string,           // Human-readable name (e.g., "OpenAI")
  "status": string,                // "operational" | "degraded" | "down"
  "transcription": CapabilityObject | {"enabled": false},
  "translation": CapabilityObject | {"enabled": false},
  "powerMode": CapabilityObject | {"enabled": false},
  "formatting": CapabilityObject | {"enabled": false},
  "pricing": PricingObject,        // REQUIRED - at least one model
  "freeCredits": string | null,    // e.g., "$5 for new accounts"
  "apiKeyUrl": string,             // URL to get API key
  "notes": string | null           // Optional notes/limitations
}

CAPABILITY OBJECT (for enabled capabilities):
{
  "enabled": true,
  "models": [ModelObject],         // At least one model
  "languages": LanguageObject,     // Language support ratings
  "features": [string]             // Feature list
}

MODEL OBJECT:
{
  "id": string,                    // EXACT API model ID (e.g., "gpt-4o-mini")
  "name": string,                  // Human-readable name
  "isDefault": boolean,            // true for recommended model (one per capability)
  "tier": string | null            // Optional: "power" for premium models
}

LANGUAGE OBJECT:
{
  "<ISO 639-1 code>": "<quality>"  // e.g., "en": "excellent"
}
Quality values: "excellent" | "good" | "limited"
Supported language codes: en, es, fr, de, ja, zh, ko, pl, pt, ru, it, ar, hi, nl, sv, tr, uk, vi

PRICING OBJECT:
{
  "<model_id>": {
    // For audio/transcription models:
    "unit": "minute",
    "cost": number                 // USD per minute

    // For translation models:
    "unit": "character",
    "cost": number                 // USD per character

    // For LLM models:
    "inputPerMToken": number,      // USD per million input tokens
    "outputPerMToken": number      // USD per million output tokens
  }
}

================================================================================
VALIDATION RULES
================================================================================

The script validates all data before pushing to Firebase:

1. REQUIRED FIELDS
   - displayName: non-empty string
   - status: must be "operational", "degraded", or "down"
   - pricing: must have at least one model with valid pricing

2. CAPABILITY VALIDATION
   - At least one capability must be enabled
   - If enabled, must have at least one model
   - One model must be marked isDefault: true
   - Model IDs must match pricing keys

3. PRICING VALIDATION
   - Audio models: must have "unit": "minute" and "cost" > 0
   - Translation models: must have "unit": "character" and "cost" >= 0
   - LLM models: must have "inputPerMToken" and "outputPerMToken"
   - Prices must be reasonable (not negative, not absurdly high)

4. LANGUAGE VALIDATION
   - Language codes must be valid ISO 639-1 (2-letter)
   - Quality must be "excellent", "good", or "limited"

================================================================================
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from typing import Optional, List, Tuple

try:
    import requests
    from google.oauth2 import service_account
    from google.auth.transport.requests import Request
except ImportError as e:
    print(f"Error: Missing dependency. Run: pip3 install google-auth requests")
    print(f"Details: {e}")
    sys.exit(1)

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_ACCOUNT_PATH = os.path.join(SCRIPT_DIR, "service-account.json")
FIREBASE_PROJECT_ID = "swiftspeak-845e0"

REMOTE_CONFIG_URL = f"https://firebaseremoteconfig.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/remoteConfig"
SCOPES = ["https://www.googleapis.com/auth/firebase.remoteconfig"]

# Valid values for validation
VALID_STATUSES = ["operational", "degraded", "down"]
VALID_QUALITY_TIERS = ["excellent", "good", "limited"]
VALID_LANGUAGE_CODES = [
    "en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru",
    "it", "ar", "hi", "nl", "sv", "tr", "uk", "vi"
]
VALID_PRICING_UNITS = ["minute", "character"]
CAPABILITIES = ["transcription", "translation", "powerMode", "formatting"]

# Reasonable pricing bounds for validation
MAX_PRICE_PER_MINUTE = 1.0       # $1/minute max for transcription
MAX_PRICE_PER_CHAR = 0.001      # $0.001/char max for translation
MAX_PRICE_PER_MTOKEN = 100.0    # $100/MTok max for LLMs

# =============================================================================
# JSON SCHEMA (for Claude's reference)
# =============================================================================

JSON_SCHEMA = '''
{
  "displayName": "<string: Provider's official display name>",
  "status": "<string: 'operational' | 'degraded' | 'down'>",
  "transcription": {
    "enabled": <boolean: true if provider offers speech-to-text>,
    "models": [
      {
        "id": "<string: exact API model ID>",
        "name": "<string: human-readable name>",
        "isDefault": <boolean: true for recommended model>
      }
    ],
    "languages": {
      "<2-letter ISO code>": "<'excellent' | 'good' | 'limited'>"
    },
    "features": ["<string: e.g., 'languageDetection', 'timestamps', 'speakerDiarization'>"]
  },
  "translation": {
    "enabled": <boolean: true if provider offers text translation>,
    "models": [<same structure as above>],
    "languages": {<same structure as above>},
    "features": ["<string: e.g., 'contextAware', 'formality', 'glossary'>"]
  },
  "powerMode": {
    "enabled": <boolean: true if provider offers LLM/chat capabilities>,
    "models": [
      {
        "id": "<string: exact API model ID>",
        "name": "<string: human-readable name>",
        "isDefault": <boolean>,
        "tier": "<optional string: 'power' for premium models>"
      }
    ],
    "features": ["streaming"]
  },
  "formatting": {
    "enabled": <boolean: true if provider has LLM for text formatting>,
    "models": [<same structure, typically fast/cheap model>]
  },
  "pricing": {
    "<model_id>": {
      "unit": "<'minute' | 'character'>",
      "cost": <number: cost per unit in USD>
    },
    "<llm_model_id>": {
      "inputPerMToken": <number: USD per million input tokens>,
      "outputPerMToken": <number: USD per million output tokens>
    }
  },
  "freeCredits": "<string: description of free tier, or null if none>",
  "apiKeyUrl": "<string: URL where users get their API key>",
  "notes": "<optional string: important limitations or info>"
}
'''

# =============================================================================
# PROVIDER CONFIGURATIONS
# =============================================================================

PROVIDER_CONFIGS = {
    "openai": {
        "name": "OpenAI",
        "urls": [
            "https://platform.openai.com/docs/pricing",
            "https://platform.openai.com/docs/models"
        ],
        "capabilities": {
            "transcription": "Whisper API (whisper-1 model)",
            "translation": "GPT models can translate (gpt-4o-mini, gpt-4o)",
            "powerMode": "GPT models for AI chat (gpt-4o, gpt-4o-mini, o1, o3-mini)",
            "formatting": "GPT-4o-mini for text formatting"
        },
        "notes": "Check for latest model versions. o1/o3 are reasoning models (tier: power)."
    },
    "anthropic": {
        "name": "Anthropic Claude",
        "urls": [
            "https://www.anthropic.com/pricing",
            "https://docs.anthropic.com/en/docs/about-claude/models"
        ],
        "capabilities": {
            "transcription": "Not available (enabled: false)",
            "translation": "Claude models for translation (Sonnet, Haiku)",
            "powerMode": "Claude models for AI (Sonnet 4, Haiku, Opus 4)",
            "formatting": "Claude 3.5 Haiku for text formatting"
        },
        "notes": "Use exact model IDs like 'claude-sonnet-4-20250514'. Opus 4 is tier: power."
    },
    "google": {
        "name": "Google Gemini",
        "urls": [
            "https://ai.google.dev/pricing",
            "https://ai.google.dev/gemini-api/docs/models/gemini"
        ],
        "capabilities": {
            "transcription": "Google Speech-to-Text (separate service, use 'google-stt' as ID)",
            "translation": "Gemini models for translation (gemini-2.0-flash, gemini-1.5-pro)",
            "powerMode": "Gemini models for AI chat",
            "formatting": "Gemini 2.0 Flash for formatting"
        },
        "notes": "Use Gemini API pricing, not Vertex AI. Check for latest model versions."
    },
    "deepgram": {
        "name": "Deepgram",
        "urls": [
            "https://deepgram.com/pricing",
            "https://developers.deepgram.com/docs/models"
        ],
        "capabilities": {
            "transcription": "Nova-2, Nova, Enhanced models for speech-to-text",
            "translation": "Not available (enabled: false)",
            "powerMode": "Not available (enabled: false)",
            "formatting": "Not available (enabled: false)"
        },
        "notes": "Pricing is often per-hour, convert to per-minute. Features: speakerDiarization, smartFormatting, punctuation."
    },
    "assemblyai": {
        "name": "AssemblyAI",
        "urls": [
            "https://www.assemblyai.com/pricing"
        ],
        "capabilities": {
            "transcription": "Best and Nano models for speech-to-text",
            "translation": "Not available (enabled: false)",
            "powerMode": "Not available (enabled: false)",
            "formatting": "Not available (enabled: false)"
        },
        "notes": "Features: speakerDiarization, punctuation, chapters."
    },
    "elevenlabs": {
        "name": "ElevenLabs",
        "urls": [
            "https://elevenlabs.io/pricing",
            "https://elevenlabs.io/docs/api-reference/speech-to-text"
        ],
        "capabilities": {
            "transcription": "Scribe v1 for speech-to-text (scribe_v1)",
            "translation": "Not available (enabled: false)",
            "powerMode": "Not available (enabled: false)",
            "formatting": "Not available (enabled: false)"
        },
        "notes": "Primarily TTS provider, transcription is secondary. Feature: speakerDiarization."
    },
    "deepl": {
        "name": "DeepL",
        "urls": [
            "https://www.deepl.com/pro#pricing",
            "https://developers.deepl.com/docs/resources/supported-languages"
        ],
        "capabilities": {
            "transcription": "Not available (enabled: false)",
            "translation": "DeepL API for translation (use 'default' as model ID)",
            "powerMode": "Not available (enabled: false)",
            "formatting": "Not available (enabled: false)"
        },
        "notes": "Best for European languages. Arabic NOT supported. Features: formality, glossary. Pricing is per character."
    },
    "azure": {
        "name": "Azure Translator",
        "urls": [
            "https://azure.microsoft.com/en-us/pricing/details/cognitive-services/translator/"
        ],
        "capabilities": {
            "transcription": "Not available (enabled: false)",
            "translation": "Azure Translator API (use 'default' as model ID)",
            "powerMode": "Not available (enabled: false)",
            "formatting": "Not available (enabled: false)"
        },
        "notes": "Use S1 tier pricing. Features: formality, profanityFiltering. Pricing is per character."
    }
}

# Static config for local/on-device (no external API needed)
LOCAL_PROVIDER_CONFIG = {
    "displayName": "On-Device",
    "status": "operational",
    "transcription": {
        "enabled": True,
        "models": [
            {"id": "whisperkit-base", "name": "WhisperKit Base", "isDefault": True},
            {"id": "whisperkit-small", "name": "WhisperKit Small"},
            {"id": "whisperkit-large", "name": "WhisperKit Large"}
        ],
        "languages": {
            "en": "excellent", "es": "good", "fr": "good",
            "de": "good", "ja": "limited", "zh": "limited",
            "ko": "limited", "pl": "limited", "pt": "good",
            "ru": "limited", "it": "good"
        },
        "features": ["offline", "privacyFirst"]
    },
    "translation": {
        "enabled": True,
        "models": [
            {"id": "apple-translation", "name": "Apple Translation", "isDefault": True}
        ],
        "languages": {
            "en": "excellent", "es": "excellent", "fr": "excellent",
            "de": "excellent", "ja": "excellent", "zh": "excellent",
            "ko": "excellent", "pl": "good", "pt": "excellent",
            "ru": "excellent", "it": "excellent", "ar": "good"
        },
        "features": ["offline", "privacyFirst"]
    },
    "powerMode": {
        "enabled": True,
        "models": [
            {"id": "apple-intelligence", "name": "Apple Intelligence", "isDefault": True}
        ],
        "features": ["offline", "privacyFirst", "streaming"]
    },
    "formatting": {
        "enabled": True,
        "models": [
            {"id": "apple-intelligence", "name": "Apple Intelligence", "isDefault": True}
        ]
    },
    "pricing": {
        "whisperkit-base": {"unit": "minute", "cost": 0},
        "whisperkit-small": {"unit": "minute", "cost": 0},
        "whisperkit-large": {"unit": "minute", "cost": 0},
        "apple-translation": {"unit": "character", "cost": 0},
        "apple-intelligence": {"inputPerMToken": 0, "outputPerMToken": 0}
    },
    "notes": "100% on-device processing. No data leaves your device."
}


# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

def validate_provider_data(provider_key: str, data: dict) -> Tuple[bool, List[str]]:
    """
    Validate provider data against the schema.
    Returns (is_valid, list_of_errors).
    """
    errors = []

    # Check required fields
    if not data.get("displayName"):
        errors.append("Missing or empty displayName")

    if data.get("status") not in VALID_STATUSES:
        errors.append(f"Invalid status: {data.get('status')}. Must be one of: {VALID_STATUSES}")

    if not data.get("pricing"):
        errors.append("Missing pricing object")

    # Check at least one capability is enabled
    enabled_capabilities = []
    for cap in CAPABILITIES:
        cap_data = data.get(cap, {})
        if cap_data.get("enabled", False):
            enabled_capabilities.append(cap)

            # Validate capability structure
            cap_errors = validate_capability(cap, cap_data, data.get("pricing", {}))
            errors.extend([f"{cap}: {e}" for e in cap_errors])

    if not enabled_capabilities:
        errors.append("At least one capability must be enabled")

    # Validate pricing
    pricing_errors = validate_pricing(data.get("pricing", {}))
    errors.extend([f"pricing: {e}" for e in pricing_errors])

    # Validate apiKeyUrl
    api_key_url = data.get("apiKeyUrl", "")
    if not api_key_url.startswith("http"):
        errors.append(f"Invalid apiKeyUrl: {api_key_url}")

    return len(errors) == 0, errors


def validate_capability(cap_name: str, cap_data: dict, pricing: dict) -> List[str]:
    """Validate a capability object."""
    errors = []

    if not cap_data.get("enabled"):
        return errors  # Disabled capabilities don't need validation

    # Check models
    models = cap_data.get("models", [])
    if not models:
        errors.append("No models defined")
        return errors

    # Check at least one default model
    default_count = sum(1 for m in models if m.get("isDefault"))
    if default_count == 0:
        errors.append("No default model (isDefault: true)")
    elif default_count > 1:
        errors.append("Multiple default models (only one should be isDefault: true)")

    # Validate each model
    for model in models:
        if not model.get("id"):
            errors.append(f"Model missing id: {model}")
        if not model.get("name"):
            errors.append(f"Model missing name: {model}")

        # Check model has pricing
        model_id = model.get("id", "")
        if model_id and model_id not in pricing:
            errors.append(f"Model '{model_id}' not found in pricing")

    # Validate languages (if present)
    languages = cap_data.get("languages", {})
    for lang_code, quality in languages.items():
        if len(lang_code) != 2:
            errors.append(f"Invalid language code: {lang_code} (must be 2 letters)")
        if quality not in VALID_QUALITY_TIERS:
            errors.append(f"Invalid quality for {lang_code}: {quality}. Must be one of: {VALID_QUALITY_TIERS}")

    return errors


def validate_pricing(pricing: dict) -> List[str]:
    """Validate pricing object."""
    errors = []

    if not pricing:
        errors.append("Pricing object is empty")
        return errors

    for model_id, price_data in pricing.items():
        if not model_id:
            errors.append("Empty model ID in pricing")
            continue

        # Check for LLM-style pricing
        if "inputPerMToken" in price_data or "outputPerMToken" in price_data:
            input_price = price_data.get("inputPerMToken")
            output_price = price_data.get("outputPerMToken")

            if input_price is None:
                errors.append(f"{model_id}: Missing inputPerMToken")
            elif not isinstance(input_price, (int, float)):
                errors.append(f"{model_id}: inputPerMToken must be a number")
            elif input_price < 0:
                errors.append(f"{model_id}: inputPerMToken cannot be negative")
            elif input_price > MAX_PRICE_PER_MTOKEN:
                errors.append(f"{model_id}: inputPerMToken ${input_price} seems too high (max ${MAX_PRICE_PER_MTOKEN})")

            if output_price is None:
                errors.append(f"{model_id}: Missing outputPerMToken")
            elif not isinstance(output_price, (int, float)):
                errors.append(f"{model_id}: outputPerMToken must be a number")
            elif output_price < 0:
                errors.append(f"{model_id}: outputPerMToken cannot be negative")
            elif output_price > MAX_PRICE_PER_MTOKEN:
                errors.append(f"{model_id}: outputPerMToken ${output_price} seems too high (max ${MAX_PRICE_PER_MTOKEN})")

        # Check for unit-based pricing
        elif "unit" in price_data or "cost" in price_data:
            unit = price_data.get("unit")
            cost = price_data.get("cost")

            if unit not in VALID_PRICING_UNITS:
                errors.append(f"{model_id}: Invalid unit '{unit}'. Must be one of: {VALID_PRICING_UNITS}")

            if cost is None:
                errors.append(f"{model_id}: Missing cost")
            elif not isinstance(cost, (int, float)):
                errors.append(f"{model_id}: cost must be a number")
            elif cost < 0:
                errors.append(f"{model_id}: cost cannot be negative")
            else:
                # Check reasonable bounds based on unit
                if unit == "minute" and cost > MAX_PRICE_PER_MINUTE:
                    errors.append(f"{model_id}: cost ${cost}/minute seems too high (max ${MAX_PRICE_PER_MINUTE})")
                if unit == "character" and cost > MAX_PRICE_PER_CHAR:
                    errors.append(f"{model_id}: cost ${cost}/char seems too high (max ${MAX_PRICE_PER_CHAR})")

        else:
            errors.append(f"{model_id}: Invalid pricing format (need either inputPerMToken/outputPerMToken or unit/cost)")

    return errors


def run_validation_tests():
    """Run validation tests on sample data."""
    print("=" * 60)
    print("RUNNING VALIDATION TESTS")
    print("=" * 60)

    test_cases = [
        # Valid OpenAI-style data
        {
            "name": "Valid OpenAI data",
            "data": {
                "displayName": "OpenAI",
                "status": "operational",
                "transcription": {
                    "enabled": True,
                    "models": [{"id": "whisper-1", "name": "Whisper", "isDefault": True}],
                    "languages": {"en": "excellent", "es": "good"},
                    "features": ["languageDetection"]
                },
                "translation": {"enabled": False},
                "powerMode": {"enabled": False},
                "formatting": {"enabled": False},
                "pricing": {
                    "whisper-1": {"unit": "minute", "cost": 0.006}
                },
                "apiKeyUrl": "https://platform.openai.com/api-keys"
            },
            "should_pass": True
        },
        # Missing displayName
        {
            "name": "Missing displayName",
            "data": {
                "status": "operational",
                "transcription": {"enabled": True, "models": [{"id": "test", "name": "Test", "isDefault": True}]},
                "pricing": {"test": {"unit": "minute", "cost": 0.01}},
                "apiKeyUrl": "https://example.com"
            },
            "should_pass": False
        },
        # Invalid status
        {
            "name": "Invalid status",
            "data": {
                "displayName": "Test",
                "status": "invalid",
                "transcription": {"enabled": True, "models": [{"id": "test", "name": "Test", "isDefault": True}]},
                "pricing": {"test": {"unit": "minute", "cost": 0.01}},
                "apiKeyUrl": "https://example.com"
            },
            "should_pass": False
        },
        # No capabilities enabled
        {
            "name": "No capabilities enabled",
            "data": {
                "displayName": "Test",
                "status": "operational",
                "transcription": {"enabled": False},
                "translation": {"enabled": False},
                "powerMode": {"enabled": False},
                "formatting": {"enabled": False},
                "pricing": {"test": {"unit": "minute", "cost": 0.01}},
                "apiKeyUrl": "https://example.com"
            },
            "should_pass": False
        },
        # Missing default model
        {
            "name": "Missing default model",
            "data": {
                "displayName": "Test",
                "status": "operational",
                "transcription": {
                    "enabled": True,
                    "models": [{"id": "test", "name": "Test", "isDefault": False}]
                },
                "pricing": {"test": {"unit": "minute", "cost": 0.01}},
                "apiKeyUrl": "https://example.com"
            },
            "should_pass": False
        },
        # Model not in pricing
        {
            "name": "Model not in pricing",
            "data": {
                "displayName": "Test",
                "status": "operational",
                "transcription": {
                    "enabled": True,
                    "models": [{"id": "test", "name": "Test", "isDefault": True}]
                },
                "pricing": {"other-model": {"unit": "minute", "cost": 0.01}},
                "apiKeyUrl": "https://example.com"
            },
            "should_pass": False
        },
        # Negative price
        {
            "name": "Negative price",
            "data": {
                "displayName": "Test",
                "status": "operational",
                "transcription": {
                    "enabled": True,
                    "models": [{"id": "test", "name": "Test", "isDefault": True}]
                },
                "pricing": {"test": {"unit": "minute", "cost": -0.01}},
                "apiKeyUrl": "https://example.com"
            },
            "should_pass": False
        },
        # Valid LLM pricing
        {
            "name": "Valid LLM pricing",
            "data": {
                "displayName": "Test LLM",
                "status": "operational",
                "powerMode": {
                    "enabled": True,
                    "models": [{"id": "gpt-4", "name": "GPT-4", "isDefault": True}],
                    "features": ["streaming"]
                },
                "pricing": {"gpt-4": {"inputPerMToken": 10.0, "outputPerMToken": 30.0}},
                "apiKeyUrl": "https://example.com"
            },
            "should_pass": True
        },
        # Invalid language quality
        {
            "name": "Invalid language quality",
            "data": {
                "displayName": "Test",
                "status": "operational",
                "transcription": {
                    "enabled": True,
                    "models": [{"id": "test", "name": "Test", "isDefault": True}],
                    "languages": {"en": "perfect"}  # Invalid quality
                },
                "pricing": {"test": {"unit": "minute", "cost": 0.01}},
                "apiKeyUrl": "https://example.com"
            },
            "should_pass": False
        },
    ]

    passed = 0
    failed = 0

    for test in test_cases:
        is_valid, errors = validate_provider_data("test", test["data"])
        test_passed = is_valid == test["should_pass"]

        if test_passed:
            print(f"✓ {test['name']}")
            passed += 1
        else:
            print(f"✗ {test['name']}")
            print(f"  Expected: {'valid' if test['should_pass'] else 'invalid'}")
            print(f"  Got: {'valid' if is_valid else 'invalid'}")
            if errors:
                print(f"  Errors: {errors}")
            failed += 1

    print()
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 60)

    return failed == 0


# =============================================================================
# CLAUDE PROMPT BUILDING
# =============================================================================

def build_claude_prompt(provider_key: str, config: dict) -> str:
    """
    Build a comprehensive prompt for Claude to fetch ALL provider data dynamically.
    """
    urls_list = "\n".join(f"- {url}" for url in config["urls"])
    languages_list = ", ".join(VALID_LANGUAGE_CODES)

    capabilities_info = "\n".join(
        f"- **{cap}**: {desc}"
        for cap, desc in config["capabilities"].items()
    )

    prompt = f'''You are a data extraction assistant. Your task is to visit the provided URLs and extract CURRENT, ACCURATE pricing and capability information for {config["name"]}.

## URLs to Visit
{urls_list}

## Provider Capabilities
{capabilities_info}

## Additional Context
{config["notes"]}

## Target Languages to Assess
For each capability, assess quality for these language codes: {languages_list}

Quality tier definitions:
- "excellent": Native-level quality, officially supported with high accuracy (>95%)
- "good": Supported with reasonable accuracy (80-95%)
- "limited": Basic support, may have accuracy issues (<80%)
- (omit language entirely if not supported at all)

## Required JSON Schema
Return ONLY valid JSON matching this EXACT structure.
NO markdown code blocks. NO explanation. JUST the JSON object.

{JSON_SCHEMA}

## Critical Requirements

1. **Model IDs**: Use EXACT API model IDs as documented (e.g., "gpt-4o-mini", "claude-sonnet-4-20250514", "whisper-1")

2. **Pricing Format**:
   - Transcription models: {{"unit": "minute", "cost": <USD per minute>}}
   - Translation models: {{"unit": "character", "cost": <USD per character>}}
   - LLM models: {{"inputPerMToken": <USD>, "outputPerMToken": <USD>}}

3. **Price Conversions**:
   - If pricing is per-hour, divide by 60 for per-minute
   - If pricing is per-1000-chars, divide by 1000 for per-char
   - If pricing is per-1K-tokens, multiply by 1000 for per-million

4. **Default Models**: Mark exactly ONE model as "isDefault": true per capability (best value option)

5. **Premium Models**: Add "tier": "power" for expensive/premium models (e.g., o1, Opus)

6. **Disabled Capabilities**: Use {{"enabled": false}} for unavailable capabilities

7. **apiKeyUrl**: Direct link to API key management page

Return ONLY the JSON object. No other text.
'''
    return prompt


# =============================================================================
# DATA FETCHING
# =============================================================================

def fetch_provider_data_with_claude(provider_key: str, prompt: str) -> Optional[dict]:
    """
    Use Claude CLI to fetch live provider data.
    Returns parsed JSON or None if failed.
    """
    print(f"  Fetching {provider_key} data with Claude...")

    try:
        result = subprocess.run(
            [
                "claude", "-p", prompt,
                "--output-format", "json",
                "--allowedTools", "WebFetch", "WebSearch",  # Allow web access
                "--permission-mode", "default"
            ],
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes for complex fetches
        )

        if result.returncode != 0:
            print(f"    ⚠ Claude CLI error (code {result.returncode}): {result.stderr[:500]}")
            return None

        raw_output = result.stdout
        if not raw_output.strip():
            print(f"    ⚠ Claude returned empty output")
            return None

        # Parse Claude's JSON wrapper response
        try:
            claude_response = json.loads(raw_output)
        except json.JSONDecodeError as e:
            print(f"    ⚠ Failed to parse Claude wrapper JSON: {e}")
            print(f"    Raw output (first 500 chars): {raw_output[:500]}")
            return None

        # Check for errors in the response
        if claude_response.get("is_error", False):
            print(f"    ⚠ Claude reported an error: {claude_response.get('result', 'Unknown error')}")
            return None

        # Extract the result field
        content = claude_response.get("result", "")
        if not content:
            print(f"    ⚠ No result in Claude response")
            return None

        # Remove markdown code blocks
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0]
        elif "```" in content:
            # Handle ```\n{...}\n``` format
            parts = content.split("```")
            for part in parts:
                part = part.strip()
                if part.startswith("json"):
                    part = part[4:].strip()
                if part.startswith("{"):
                    content = part
                    break

        content = content.strip()

        # Find JSON object boundaries
        start_idx = content.find("{")
        end_idx = content.rfind("}") + 1
        if start_idx == -1 or end_idx <= start_idx:
            print(f"    ⚠ No JSON object found in response")
            print(f"    Content (first 500 chars): {content[:500]}")
            return None

        json_str = content[start_idx:end_idx]

        # Parse the provider JSON
        try:
            provider_data = json.loads(json_str)
        except json.JSONDecodeError as e:
            print(f"    ⚠ Failed to parse provider JSON: {e}")
            print(f"    JSON string (first 500 chars): {json_str[:500]}")
            return None

        # Validate the data
        is_valid, errors = validate_provider_data(provider_key, provider_data)

        if not is_valid:
            print(f"    ⚠ Validation failed for {provider_key}:")
            for error in errors[:5]:  # Show first 5 errors
                print(f"      - {error}")
            if len(errors) > 5:
                print(f"      ... and {len(errors) - 5} more errors")
            return None

        print(f"    ✓ Successfully fetched and validated {provider_key} data")
        return provider_data

    except subprocess.TimeoutExpired:
        print(f"    ⚠ Timeout fetching {provider_key} (5 min limit)")
        return None
    except FileNotFoundError:
        print(f"    ⚠ Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code")
        return None
    except Exception as e:
        print(f"    ⚠ Error fetching {provider_key}: {e}")
        import traceback
        traceback.print_exc()
        return None


# =============================================================================
# CONFIG BUILDING
# =============================================================================

def load_existing_config() -> Optional[dict]:
    """Load existing config from local cache."""
    cache_path = os.path.join(SCRIPT_DIR, "config_cache.json")
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r") as f:
                return json.load(f)
        except:
            pass
    return None


def save_config_cache(config: dict):
    """Save config to local cache for fallback."""
    cache_path = os.path.join(SCRIPT_DIR, "config_cache.json")
    try:
        with open(cache_path, "w") as f:
            json.dump(config, f, indent=2)
    except Exception as e:
        print(f"  Warning: Could not save cache: {e}")


def build_config(providers_to_update: Optional[list] = None) -> dict:
    """
    Build the complete configuration object.
    Fetches live data from Claude for each provider.
    """
    now = datetime.now(timezone.utc)

    existing_config = load_existing_config()
    existing_providers = existing_config.get("providers", {}) if existing_config else {}

    providers = {}

    if providers_to_update:
        provider_keys = [p.lower() for p in providers_to_update]
    else:
        provider_keys = list(PROVIDER_CONFIGS.keys())

    print(f"Fetching data for {len(provider_keys)} providers...")

    for provider_key in provider_keys:
        if provider_key not in PROVIDER_CONFIGS:
            print(f"  ⚠ Unknown provider: {provider_key}")
            continue

        config = PROVIDER_CONFIGS[provider_key]
        prompt = build_claude_prompt(provider_key, config)

        data = fetch_provider_data_with_claude(provider_key, prompt)

        config_key = {
            "openai": "openAI",
            "anthropic": "anthropic",
            "google": "google",
            "deepgram": "deepgram",
            "assemblyai": "assemblyAI",
            "elevenlabs": "elevenLabs",
            "deepl": "deepL",
            "azure": "azure"
        }.get(provider_key, provider_key)

        if data:
            providers[config_key] = data
        elif config_key in existing_providers:
            providers[config_key] = existing_providers[config_key]
            print(f"  ⚠ Using cached data for {provider_key}")
        else:
            print(f"  ✗ No data available for {provider_key}")

    # Keep other providers from cache
    if providers_to_update and existing_providers:
        for key, value in existing_providers.items():
            if key not in providers and key != "local":
                providers[key] = value

    # Always add local provider
    providers["local"] = LOCAL_PROVIDER_CONFIG

    result = {
        "version": now.strftime("%Y.%m.%d"),
        "lastUpdated": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "schemaVersion": 1,
        "providers": providers
    }

    save_config_cache(result)

    return result


# =============================================================================
# FIREBASE FUNCTIONS
# =============================================================================

def get_access_token():
    """Get OAuth2 access token for Firebase API."""
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        print(f"Error: Service account file not found at {SERVICE_ACCOUNT_PATH}")
        print("Download it from Firebase Console: Project Settings > Service Accounts")
        sys.exit(1)

    credentials_obj = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_PATH,
        scopes=SCOPES
    )
    credentials_obj.refresh(Request())
    return credentials_obj.token


def get_current_config(access_token):
    """Get current Remote Config template."""
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept-Encoding": "gzip",
    }

    response = requests.get(REMOTE_CONFIG_URL, headers=headers)

    if response.status_code == 200:
        return response.json(), response.headers.get("ETag")
    else:
        print(f"Error getting config: {response.status_code} - {response.text}")
        return None, None


def update_remote_config(access_token, etag, config_data, dry_run=False):
    """Update Firebase Remote Config with new data."""
    config_json = json.dumps(config_data)

    new_template = {
        "parameters": {
            "provider_config": {
                "defaultValue": {
                    "value": config_json
                },
                "description": "Provider configuration including pricing, models, languages, and capabilities. Auto-updated weekly by Claude."
            }
        }
    }

    if dry_run:
        print("\n" + "=" * 60)
        print("DRY RUN: Would update Remote Config with:")
        print("=" * 60)
        print(f"Version: {config_data['version']}")
        print(f"Last Updated: {config_data['lastUpdated']}")
        print(f"Providers: {', '.join(config_data['providers'].keys())}")

        print("\n" + "-" * 60)
        print("PRICING SUMMARY")
        print("-" * 60)

        for provider_key, provider_data in sorted(config_data['providers'].items()):
            print(f"\n{provider_data.get('displayName', provider_key)}:")
            if 'pricing' in provider_data:
                for model, price in provider_data['pricing'].items():
                    if 'cost' in price:
                        print(f"  {model}: ${price['cost']:.6f}/{price.get('unit', 'unit')}")
                    elif 'inputPerMToken' in price:
                        print(f"  {model}: ${price['inputPerMToken']:.2f} in / ${price['outputPerMToken']:.2f} out per MTok")

        print("\n" + "-" * 60)
        print("CAPABILITIES")
        print("-" * 60)

        for provider_key, provider_data in sorted(config_data['providers'].items()):
            caps = []
            for cap in CAPABILITIES:
                if provider_data.get(cap, {}).get('enabled'):
                    caps.append(cap)
            print(f"{provider_data.get('displayName', provider_key)}: {', '.join(caps) if caps else 'none'}")

        return True

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json; UTF-8",
        "If-Match": etag,
    }

    response = requests.put(
        REMOTE_CONFIG_URL,
        headers=headers,
        json=new_template
    )

    if response.status_code == 200:
        print("✓ Remote Config updated successfully")
        print(f"  - Version: {config_data['version']}")
        print(f"  - Last Updated: {config_data['lastUpdated']}")
        print(f"  - Providers: {len(config_data['providers'])}")
        return True
    else:
        print(f"Error updating config: {response.status_code} - {response.text}")
        return False


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Update Firebase Remote Config for SwiftSpeak using Claude to fetch live provider data',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  python3 update_firebase_config.py                    # Update all providers
  python3 update_firebase_config.py --dry-run          # Preview changes
  python3 update_firebase_config.py --provider openai  # Update single provider
  python3 update_firebase_config.py --test             # Run validation tests
        '''
    )
    parser.add_argument('--dry-run', action='store_true',
                        help='Preview changes without updating Firebase')
    parser.add_argument('--provider', type=str,
                        help='Update only specific provider (e.g., openai, anthropic)')
    parser.add_argument('--skip-firebase', action='store_true',
                        help='Only fetch data, do not update Firebase')
    parser.add_argument('--test', action='store_true',
                        help='Run validation tests only')
    args = parser.parse_args()

    # Run tests if requested
    if args.test:
        success = run_validation_tests()
        sys.exit(0 if success else 1)

    print("=" * 60)
    print("SwiftSpeak Firebase Config Updater")
    print("Powered by Claude CLI for live data extraction")
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    providers_to_update = None
    if args.provider:
        providers_to_update = [args.provider]
        print(f"\nUpdating single provider: {args.provider}")
    else:
        print(f"\nUpdating all {len(PROVIDER_CONFIGS)} providers...")

    print("\n" + "-" * 60)
    config = build_config(providers_to_update)
    print("-" * 60)
    print(f"\n✓ Built config with {len(config['providers'])} providers")

    if args.skip_firebase:
        print("\n--skip-firebase specified, not updating Firebase")
        print(json.dumps(config, indent=2))
        return

    print("\nAuthenticating with Firebase...")
    access_token = get_access_token()
    print(f"✓ Authenticated for project: {FIREBASE_PROJECT_ID}")

    print("Fetching current Remote Config...")
    current_config, etag = get_current_config(access_token)

    if current_config is None:
        print("Warning: Could not fetch current config, will create new one")
        etag = "*"
    else:
        print("✓ Retrieved current Remote Config template")

    success = update_remote_config(access_token, etag, config, dry_run=args.dry_run)

    print("\n" + "=" * 60)
    if success:
        print("Update completed successfully!")
    else:
        print("Update failed!")
        sys.exit(1)
    print("=" * 60)


if __name__ == "__main__":
    main()
