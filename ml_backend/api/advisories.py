"""Bangla-language disease advisory content.

Each entry mirrors the shape of `Disease` in the Flutter app so the
response payload can be mapped straight onto the `Diagnosis` model
without an extra translation step. `severity` is one of:
    low | medium | high
matching the `Severity` enum in `lib/data/models/disease.dart`.
"""

from __future__ import annotations

from typing import TypedDict


class Advisory(TypedDict):
    name_bn: str          # বাংলা নাম
    name_en: str          # ইংরেজি নাম (fallback)
    severity: str         # low | medium | high
    symptoms: list[str]
    causes: list[str]
    management: list[str]
    prevention: list[str]


ADVISORIES: dict[str, Advisory] = {
    "rice_healthy": {
        "name_bn": "সুস্থ ধান",
        "name_en": "Healthy rice leaf",
        "severity": "low",
        "symptoms": [
            "পাতার রং সবুজ ও চকচকে",
            "কোনো দাগ, ছত্রাক বা পোকার আক্রমণ নেই",
            "গাছের বৃদ্ধি স্বাভাবিক",
        ],
        "causes": [
            "যথাযথ পরিচর্যা ও পুষ্টি",
            "রোগমুক্ত বীজ ও সুষম সার ব্যবস্থাপনা",
        ],
        "management": [
            "বর্তমান চাষাবাদ চালিয়ে যান",
            "নিয়মিত মাঠ পরিদর্শন করুন",
            "পরবর্তী ফসলের জন্য ভালো বীজ সংরক্ষণ করুন",
        ],
        "prevention": [
            "ফসল পর্যায় অবলম্বন করুন",
            "সুষম সার ও সেচ বজায় রাখুন",
            "রোগ প্রতিরোধী জাত ব্যবহার করুন",
        ],
    },
    "rice_blast": {
        "name_bn": "ধানের ব্লাস্ট (Rice Blast)",
        "name_en": "Rice Blast",
        "severity": "high",
        "symptoms": [
            "পাতায় চোখের আকৃতির ধূসর-সবুজ দাগ",
            "দাগের কেন্দ্র ধূসর, কিনারা গাঢ় বাদামী",
            "গলায় (neck) আক্রমণ হলে শীষ সাদা হয়ে যায়",
        ],
        "causes": [
            "Magnaporthe oryzae ছত্রাক",
            "বেশি আর্দ্রতা, ঘন কুয়াশা ও মেঘলা আবহাওয়া",
            "নাইট্রোজেন সারের অতিরিক্ত ব্যবহার",
        ],
        "management": [
            "ট্রাইসাইক্লাজোল ৭৫% WP (০.৬ গ্রাম/লিটার পানি) স্প্রে করুন",
            "কার্বেন্ডাজিম ৫০% WP (১ গ্রাম/লিটার) বিকল্প হিসেবে ব্যবহার করুন",
            "আক্রান্ত গাছ সংগ্রহ করে ধ্বংস করুন",
        ],
        "prevention": [
            "প্রতিরোধী জাত যেমন BRRI dhan 28, 29 ব্যবহার করুন",
            "বীজ শোধন করুন (কার্বেন্ডাজিম ২ গ্রাম/কেজি বীজ)",
            "নাইট্রোজেন সার ভাগ করে প্রয়োগ করুন",
        ],
    },
    "rice_brown_spot": {
        "name_bn": "বাদামী দাগ (Brown Spot)",
        "name_en": "Brown Spot",
        "severity": "medium",
        "symptoms": [
            "পাতায় গোলাকার বা ডিম্বাকার বাদামী দাগ",
            "দাগের চারপাশে হলুদ আভা",
            "বীজে কালো দাগ দেখা যায়",
        ],
        "causes": [
            "Bipolaris oryzae ছত্রাক",
            "মাটিতে পটাশ ও সিলিকার অভাব",
            "দুর্বল ও রোগাক্রান্ত বীজ",
        ],
        "management": [
            "ম্যানকোজেব ৬৩% WP (২.৫ গ্রাম/লিটার) স্প্রে করুন",
            "আক্রান্ত পাতা ও ভারা সংগ্রহ করে পুড়িয়ে ফেলুন",
            "পটাশ সারের ঘাটতি পূরণ করুন",
        ],
        "prevention": [
            "সুস্থ ও প্রত্যয়িত বীজ ব্যবহার করুন",
            "মাটি পরীক্ষা করে সুষম সার প্রয়োগ করুন",
            "ফসল পর্যায় অবলম্বন করুন",
        ],
    },
    "rice_bacterial_leaf_blight": {
        "name_bn": "ব্যাকটেরিয়াল লিফ ব্লাইট",
        "name_en": "Bacterial Leaf Blight",
        "severity": "high",
        "symptoms": [
            "পাতার কিনারা থেকে হলুদ-সাদা দাগ শুরু হয়",
            "দাগ ধীরে ধীরে পুরো পাতায় ছড়িয়ে পড়ে",
            "ভেজা আবহাওয়ায় দাগে হলুদ তরল বের হয়",
        ],
        "causes": [
            "Xanthomonas oryzae ব্যাকটেরিয়া",
            "বৃষ্টি ও ঝড়ো বাতাসে দ্রুত ছড়ায়",
            "আক্রান্ত বীজ ও পানি",
        ],
        "management": [
            "কপার অক্সিক্লোরাইড (২.৫ গ্রাম/লিটার) স্প্রে করুন",
            "আক্রান্ত জমি থেকে পানি সরিয়ে নিন",
            "আক্রান্ত গাছ সরিয়ে ধ্বংস করুন",
        ],
        "prevention": [
            "প্রতিরোধী জাত ব্যবহার করুন (যেমন BRRI dhan 31, 39)",
            "নাইট্রোজেন সার নিয়ন্ত্রিত পরিমাণে দিন",
            "ধান কাটার পর আগাছা ও ভারা পরিষ্কার করুন",
        ],
    },
    "rice_tungro": {
        "name_bn": "টুংরো (Tungro)",
        "name_en": "Rice Tungro Virus",
        "severity": "high",
        "symptoms": [
            "পাতা হলুদ বা কমলা-হলুদ হয়ে যায়",
            "গাছের বৃদ্ধি ব্যাহত হয়",
            "কুশি কম হয়, শীষ ছোট",
        ],
        "causes": [
            "Rice tungro bacilliform virus + Rice tungro spherical virus",
            "সবুজ পাতা ফড়িং (GLH) ভেক্টর",
            "আক্রান্ত চারা থেকে ছড়ায়",
        ],
        "management": [
            "আক্রান্ত গাছ তুলে ধ্বংস করুন",
            "ইমিডাক্লোপ্রিড (০.৫ মিলি/লিটার) স্প্রে করুন",
            "পরবর্তী ফসলে নতুন চারা রোপণ করুন",
        ],
        "prevention": [
            "প্রতিরোধী জাত যেমন BRRI dhan 36, 37 ব্যবহার করুন",
            "আগাছা পরিষ্কার রাখুন (GLH-এর আশ্রয়)",
            "সময়মতো রোপণ করুন, দেরি করবেন না",
        ],
    },
    "rice_sheath_blight": {
        "name_bn": "শিথ ব্লাইট (Sheath Blight)",
        "name_en": "Sheath Blight",
        "severity": "medium",
        "symptoms": [
            "গোড়ার দিকে পাতার খোলে ধূসর-সবুজ দাগ",
            "দাগের উপর সাদা ছাতার মতো ছত্রাক জাল",
            "গাছ শুকিয়ে যায়",
        ],
        "causes": [
            "Rhizoctonia solani ছত্রাক",
            "উচ্চ তাপমাত্রা ও আর্দ্রতা",
            "ঘন রোপণ দূরত্ব",
        ],
        "management": [
            "হেক্সাকোনাজল ৫% EC (১ মিলি/লিটার) স্প্রে করুন",
            "থায়োফ্যানেট মিথাইল ৭০% WP (১ গ্রাম/লিটার) ব্যবহার করুন",
            "আক্রান্ত পাতার খোল ও ভারা সংগ্রহ করে ধ্বংস করুন",
        ],
        "prevention": [
            "সঠিক দূরত্বে রোপণ করুন (২০×১৫ সেমি)",
            "নাইট্রোজেন সার ভাগ করে প্রয়োগ করুন",
            "জমি পরিষ্কার ও আগাছামুক্ত রাখুন",
        ],
    },
}


def get(key: str) -> Advisory:
    """Look up an advisory by class label key, with safe fallback."""
    return ADVISORIES.get(key) or ADVISORIES["rice_healthy"]


def severity_to_english(s: str) -> str:
    """Maps severity string to Bangla display (used by Flutter side too)."""
    return {"low": "কম", "medium": "মাঝারি", "high": "বেশি"}.get(s, "মাঝারি")