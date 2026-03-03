#!/bin/bash
# App Scheduler — Build .app
# Run this once: bash build_app.sh

echo ""
echo "╔══════════════════════════════════╗"
echo "║   App Scheduler — Build .app     ║"
echo "╚══════════════════════════════════╝"
echo ""

# Find Python 3.11 or newer (required for rumps compatibility)
PYTHON=""
for cmd in python3.13 python3.12 python3.11; do
    if command -v $cmd &>/dev/null; then
        PYTHON=$cmd
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo "❌ Python 3.11 or newer is required."
    echo ""
    echo "Your current Python is too old (3.9). To fix this:"
    echo ""
    echo "  1. Install Homebrew (if not already installed):"
    echo '     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
    echo "  2. Install Python 3.11:"
    echo "     brew install python@3.11"
    echo ""
    echo "  3. Re-run this script:"
    echo "     bash build_app.sh"
    exit 1
fi

echo "✅ Using $PYTHON ($(${PYTHON} --version))"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
$PYTHON -m pip install rumps pyinstaller Pillow --quiet
echo "✅ Dependencies installed."

# Create app icon (simple clock emoji rendered as icns)
echo ""
echo "🎨 Creating app icon..."
mkdir -p AppIcon.iconset

$PYTHON - <<'EOF'
from PIL import Image, ImageDraw, ImageFont
import os

sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background circle
    margin = size * 0.05
    draw.ellipse([margin, margin, size - margin, size - margin],
                 fill="#0e0f11")

    # Clock face
    margin2 = size * 0.12
    draw.ellipse([margin2, margin2, size - margin2, size - margin2],
                 fill="#16181c", outline="#c8f060",
                 width=max(1, size // 32))

    # Clock hands
    cx, cy = size / 2, size / 2
    import math
    # Hour hand (pointing to ~10)
    angle_h = math.radians(-60)
    length_h = size * 0.25
    draw.line([cx, cy,
               cx + length_h * math.sin(angle_h),
               cy - length_h * math.cos(angle_h)],
              fill="#e8eaf0", width=max(1, size // 24))
    # Minute hand (pointing to ~12)
    angle_m = math.radians(0)
    length_m = size * 0.33
    draw.line([cx, cy,
               cx + length_m * math.sin(angle_m),
               cy - length_m * math.cos(angle_m)],
              fill="#c8f060", width=max(1, size // 32))
    # Center dot
    dot = size * 0.05
    draw.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill="#c8f060")

    img.save(f"AppIcon.iconset/icon_{size}x{size}.png")
    if size <= 512:
        img2 = img.resize((size * 2, size * 2), Image.LANCZOS)
        img2.save(f"AppIcon.iconset/icon_{size}x{size}@2x.png")

print("Icon frames created.")
EOF

# Try to install Pillow if needed
if [ $? -ne 0 ]; then
    echo "Installing Pillow for icon generation..."
    pip3 install Pillow --quiet
    $PYTHON - <<'EOF'
from PIL import Image, ImageDraw
import math, os

sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    margin = size * 0.05
    draw.ellipse([margin, margin, size-margin, size-margin], fill="#0e0f11")
    margin2 = size * 0.12
    draw.ellipse([margin2, margin2, size-margin2, size-margin2],
                 fill="#16181c", outline="#c8f060", width=max(1, size//32))
    cx, cy = size/2, size/2
    angle_h = math.radians(-60)
    length_h = size * 0.25
    draw.line([cx, cy, cx + length_h*math.sin(angle_h), cy - length_h*math.cos(angle_h)],
              fill="#e8eaf0", width=max(1, size//24))
    angle_m = math.radians(0)
    length_m = size * 0.33
    draw.line([cx, cy, cx + length_m*math.sin(angle_m), cy - length_m*math.cos(angle_m)],
              fill="#c8f060", width=max(1, size//32))
    dot = size * 0.05
    draw.ellipse([cx-dot, cy-dot, cx+dot, cy+dot], fill="#c8f060")
    img.save(f"AppIcon.iconset/icon_{size}x{size}.png")
    if size <= 512:
        img.resize((size*2, size*2), Image.LANCZOS).save(f"AppIcon.iconset/icon_{size}x{size}@2x.png")
print("Icons created.")
EOF
fi

# Convert to .icns
iconutil -c icns AppIcon.iconset -o AppIcon.icns 2>/dev/null || echo "⚠️  Could not generate .icns, using default icon."
echo "✅ Icon ready."

# Create PyInstaller spec
echo ""
echo "🔧 Configuring build..."

cat > AppScheduler.spec <<'SPEC'
# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['app_scheduler_app.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=['rumps', 'tkinter', 'tkinter.ttk', 'tkinter.messagebox'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='AppScheduler',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=True,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='AppScheduler',
)

app = BUNDLE(
    coll,
    name='App Scheduler.app',
    icon='AppIcon.icns' if __import__('os').path.exists('AppIcon.icns') else None,
    bundle_identifier='com.appscheduler.app',
    info_plist={
        'LSUIElement': True,          # Hides from Dock (menu bar only)
        'CFBundleName': 'App Scheduler',
        'CFBundleDisplayName': 'App Scheduler',
        'CFBundleVersion': '1.0.0',
        'CFBundleShortVersionString': '1.0.0',
        'NSHighResolutionCapable': True,
        'NSAppleEventsUsageDescription': 'App Scheduler needs this to open and close apps.',
        'NSPrincipalClass': 'NSApplication',
    },
)
SPEC

# Build
echo "🏗️  Building .app (this may take ~1 minute)..."
echo ""
$PYTHON -m PyInstaller AppScheduler.spec --noconfirm --clean

# Check result
if [ -d "dist/App Scheduler.app" ]; then
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║  ✅  Build successful!                   ║"
    echo "║                                          ║"
    echo "║  Your app is at:                         ║"
    echo "║  dist/App Scheduler.app                  ║"
    echo "║                                          ║"
    echo "║  👉 Drag it to your Applications folder  ║"
    echo "║     and double-click to launch!          ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    # Open the dist folder in Finder
    open dist/
else
    echo ""
    echo "❌ Build failed. Check the output above for errors."
    echo "   Common fix: make sure app_scheduler_app.py is in the same folder."
fi

# Cleanup
rm -rf AppIcon.iconset AppIcon.icns AppScheduler.spec build __pycache__ 2>/dev/null
