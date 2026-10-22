import os

target_files = ["web/update_html.js", "web/generate.js", "sync_r2_html.py"]
old_logos = ["zehut-logo2.png", "zehut-logo.png"]

for filepath in target_files:
    if os.path.exists(filepath):
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Check if the generator hardcodes a fallback logo in og:image
        for logo in old_logos:
            if logo in content:
                print(f"⚠️ Found '{logo}' inside {filepath}!")

print("Checking your dw script...")
for dw_path in ["./dw", "./dw.sh", os.path.expanduser("~/bin/dw")]:
    if os.path.exists(dw_path):
        print(f"--- Contents of {dw_path} ---")
        with open(dw_path, "r", encoding="utf-8") as f:
            print(f.read())
