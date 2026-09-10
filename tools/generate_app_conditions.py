#!/usr/bin/env python3
"""
generate_app_conditions.py
──────────────────────────
Downloads Homebrew Cask .rb files from GitHub for popular macOS apps,
parses their `zap trash:` stanzas, and generates ready-to-use AppCondition
Swift code for Conditions.swift.

Usage:
    python3 tools/generate_app_conditions.py

Output:
    tools/generated_conditions.swift  — paste into Conditions.swift
    tools/cask_paths.json             — reference JSON

License of Homebrew Cask data: BSD 2-Clause (can use in commercial projects)
"""

import re
import json
import time
import urllib.request
from pathlib import Path

# ──────────────────────────────────────────────────────────────────────
# Apps to process: (cask_name, bundle_id)
# ──────────────────────────────────────────────────────────────────────
APPS = [
    # Browsers
    ("firefox",              "org.mozilla.firefox"),
    ("google-chrome",        "com.google.Chrome"),
    ("brave-browser",        "com.brave.Browser"),
    ("arc",                  "company.thebrowser.Browser"),
    ("opera",                "com.operasoftware.Opera"),
    ("vivaldi",              "com.vivaldi.Vivaldi"),
    ("microsoft-edge",       "com.microsoft.edgemac"),

    # Communication
    ("telegram",             "ru.keepcoder.Telegram"),
    ("slack",                "com.tinyspeck.slackmacgap"),
    ("discord",              "com.hnc.Discord"),
    ("zoom",                 "us.zoom.xos"),
    ("whatsapp",             "net.whatsapp.WhatsApp"),
    ("signal",               "org.whispersystems.signal-desktop"),
    ("skype",                "com.skype.skype"),

    # Productivity
    ("notion",               "notion.id"),
    ("obsidian",             "md.obsidian"),
    ("1password",            "com.1password.1password"),
    ("bitwarden",            "com.bitwarden.desktop"),
    ("alfred",               "com.runningwithcrayons.Alfred"),
    ("raycast",              "com.raycast.macos"),
    ("rectangle",            "com.knollsoft.Rectangle"),

    # Development
    ("visual-studio-code",   "com.microsoft.VSCode"),
    ("iterm2",               "com.googlecode.iterm2"),
    ("github",               "com.github.GitHubClient"),
    ("sourcetree",           "com.torusknot.SourceTreeNotMAS"),
    ("tableplus",            "com.tinyapp.TablePlus"),
    ("postman",              "com.postmanlabs.mac"),
    ("docker",               "com.docker.docker"),

    # Media & Design
    ("spotify",              "com.spotify.client"),
    ("vlc",                  "org.videolan.vlc"),
    ("iina",                 "com.colliderli.iina"),
    ("figma",                "com.figma.Desktop"),

    # Utilities
    ("the-unarchiver",       "cx.c3.theunarchiver"),
    ("keka",                 "com.aone.keka"),
    ("transmission",         "org.m0k.transmission"),
    ("handbrake",            "fr.handbrake.HandBrake"),
    ("cyberduck",            "ch.sudo.cyberduck"),

    # Gaming
    ("steam",                "com.valvesoftware.steam"),

    # Microsoft Office
    ("microsoft-word",       "com.microsoft.Word"),
    ("microsoft-excel",      "com.microsoft.Excel"),
    ("microsoft-powerpoint", "com.microsoft.Powerpoint"),
    ("microsoft-outlook",    "com.microsoft.Outlook"),
]

CASK_RAW_BASE = "https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks"

RE_ZAP = re.compile(r'zap\s+(?:trash|delete):\s*\[([^\]]+)\]', re.DOTALL)
RE_UNINSTALL_TRASH = re.compile(r'uninstall(?:[^[]*?)trash:\s*\[([^\]]+)\]', re.DOTALL)
RE_STRING = re.compile(r'"([^"]+)"')


def fetch_cask(cask_name):
    first = cask_name[0]
    url = f"{CASK_RAW_BASE}/{first}/{cask_name}.rb"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "byMakerCleaner/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.read().decode("utf-8")
    except Exception as e:
        print(f"  ⚠️  Could not fetch {cask_name}: {e}")
        return None


def parse_paths(rb_content):
    paths = []

    zap_match = RE_ZAP.search(rb_content)
    if zap_match:
        paths = RE_STRING.findall(zap_match.group(1))

    if not paths:
        uninstall_match = RE_UNINSTALL_TRASH.search(rb_content)
        if uninstall_match:
            paths = RE_STRING.findall(uninstall_match.group(1))

    filtered = []
    for p in paths:
        if p.count("*") > 1:
            continue
        if "Library/" in p or p.startswith("~/."):
            filtered.append(p)

    return filtered


def swift_condition(bundle_id, paths, cask_name):
    home_paths = [p.replace("~", "\\(home)") for p in paths]
    paths_swift = ",\n            ".join(f'"{p}"' for p in home_paths)
    return f"""    // Source: brew install --cask {cask_name}
    AppCondition(
        bundleID: "{bundle_id}",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            {paths_swift}
        ]
    ),"""


def main():
    output_lines = [
        "// ═══════════════════════════════════════════════════════════════════",
        "// AUTO-GENERATED by tools/generate_app_conditions.py",
        "// Source: Homebrew Cask (BSD 2-Clause License)",
        "// https://github.com/Homebrew/homebrew-cask",
        "//",
        "// DO NOT EDIT MANUALLY — regenerate with:",
        "//   python3 tools/generate_app_conditions.py",
        "// ═══════════════════════════════════════════════════════════════════",
        "",
        "// Paste these AppCondition entries into Conditions.swift",
        "// inside the `let appConditions: [AppCondition] = [` array.",
        "",
        "// ---------------------------------------------------------------",
        "// Homebrew Cask-sourced exact paths (community verified)",
        "// ---------------------------------------------------------------",
        "",
    ]

    results = {}
    total_with_paths = 0

    for cask_name, bundle_id in APPS:
        print(f"Fetching {cask_name}...")
        rb = fetch_cask(cask_name)
        if rb is None:
            continue

        paths = parse_paths(rb)
        results[bundle_id] = paths

        if paths:
            total_with_paths += 1
            output_lines.append(swift_condition(bundle_id, paths, cask_name))
            output_lines.append("")
        else:
            print(f"  ↳ No zap paths found for {cask_name}")

        time.sleep(0.3)

    out_path = Path(__file__).parent / "generated_conditions.swift"
    out_path.write_text("\n".join(output_lines), encoding="utf-8")

    json_path = Path(__file__).parent / "cask_paths.json"
    json_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"\n✅ Done!")
    print(f"   Apps processed : {len(APPS)}")
    print(f"   With zap paths : {total_with_paths}")
    print(f"   Output Swift   : {out_path}")
    print(f"   Output JSON    : {json_path}")
