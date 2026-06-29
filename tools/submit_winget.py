#!/usr/bin/env python3
import os
import sys
import subprocess

token = os.environ.get("WINGET_CREATE_GITHUB_TOKEN")
if not token:
    print("WINGET_CREATE_GITHUB_TOKEN is not set; skipping automatic Winget submission.")
    sys.exit(0)

repo = os.environ["REPOSITORY"]
tag = os.environ["RELEASE_TAG"]
version = os.environ["APP_VERSION"]
mode = os.environ.get("WINGET_SUBMIT_MODE", "update")

installer_url = (
    f"https://github.com/{repo}/releases/download/{tag}/"
    f"BirdNET_Live_v{version}_windows_x64_setup.exe"
)

cmd = [
    "wingetcreate",
    mode,
    "--submit",
    "BirdNET-Team.BirdNETLive",
    "--urls", installer_url,
    "--version", version,
    #"--out", "manifests",
    "--token", token
]

print("Running:", " ".join(cmd))
result = subprocess.run(cmd)
sys.exit(result.returncode)
