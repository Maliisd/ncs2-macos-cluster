#!/bin/bash
set -e

cd "$(dirname "$0")"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BLUE}${BOLD}==============================================================${NC}"
echo -e "${BLUE}${BOLD}   Intel NCS2 Cluster - Vollautomatischer macOS Installer    ${NC}"
echo -e "${BLUE}${BOLD}==============================================================${NC}\n"

# 1. Architekturprüfung
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "${RED}[Fehler] Nur für macOS Intel x86_64 geeignet.${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Intel x86_64 Architektur erkannt.${NC}"

# 2. Blockierende Python-Prozesse beenden
killall -9 python python3 2>/dev/null || true

# 3. System-Abhängigkeiten
brew install libusb python@3.10 pkg-config

# 4. Virtuelle Umgebung
VENV_DIR="$HOME/ncs2_env"
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${BLUE}[+] Erstelle venv in $VENV_DIR...${NC}"
    /usr/local/opt/python@3.10/bin/python3.10 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# 5. OpenVINO & Python-Tools
pip install --upgrade pip -q
pip install "openvino==2022.3.0" "numpy<=1.23.4" pyusb -q

# 6. Treiber & Firmware einbinden
OV_LIBS="$VENV_DIR/lib/python3.10/site-packages/openvino/libs"
mkdir -p "$OV_LIBS"

DRIVER_NAME="ncs2_driver_macos_x86_64.tar.gz"
if [ -f "$HOME/Desktop/$DRIVER_NAME" ]; then
    tar -xzf "$HOME/Desktop/$DRIVER_NAME" -C "$OV_LIBS/"
elif [ -f "./$DRIVER_NAME" ]; then
    tar -xzf "./$DRIVER_NAME" -C "$OV_LIBS/"
else
    echo -e "${BLUE}[+] Lade Treiber von GitHub Releases...${NC}"
    curl -L "https://github.com/Maliisd/ncs2-macos-cluster/releases/download/v1.0.0/$DRIVER_NAME" -o "/tmp/$DRIVER_NAME"
    tar -xzf "/tmp/$DRIVER_NAME" -C "$OV_LIBS/"
    rm -f "/tmp/$DRIVER_NAME"
fi

cd "$OV_LIBS"
[ -f usb-ma2x8x.mvcmd ] && [ ! -f usb-ma248x.mvcmd ] && ln -s usb-ma2x8x.mvcmd usb-ma248x.mvcmd
cd "$(dirname "$0")"
echo -e "${GREEN}[✓] Treiber und Firmware eingerichtet.${NC}\n"

# 7. Hardware-Check
echo -e "${BLUE}${BOLD}=== Starte Hardware-Selbsttest des 4er-Clusters ===${NC}"
python3 - << 'PYEOF'
import os
import sys
import time
import numpy as np
from openvino.runtime import Core, Model, opset8

core = Core()
devices = [d for d in core.available_devices if "MYRIAD" in d]

if not devices:
    print("\033[0;31m[Fehler] Keine NCS2 Sticks erkannt. Bitte Hub prüfen.\033[0m")
    os._exit(1)

print(f"\033[0;32m[✓] {len(devices)} Sticks gefunden: {devices}\033[0m")

param = opset8.parameter(shape=[1, 3, 224, 224], dtype=np.float32, name="test_in")
test_net = Model([opset8.relu(param)], [param], "test_net")

print("Führe sequenziellen Bootloader-Check aus...")
for idx, dev in enumerate(devices, 1):
    try:
        tmp = core.compile_model(test_net, dev)
        req = tmp.create_infer_request()
        req.infer({0: np.zeros((1, 3, 224, 224), dtype=np.float32)})
        print(f" -> [{idx}/{len(devices)}] {dev} aktiv und einsatzbereit.")
        time.sleep(1.0)
    except Exception as e:
        print(f"\033[0;31m -> [{idx}/{len(devices)}] Fehler bei {dev}: {e}\033[0m")
        print("\033[0;33m[Tipp] Bitte Hub für 3 Sekunden ab- und wieder anstecken.\033[0m")
        os._exit(1)

# Verbund testen
multi_target = f"MULTI:{','.join(devices)}"
print(f"\nTeste MULTI-Cluster Verbund ({multi_target})...")
multi = core.compile_model(test_net, multi_target)
q = multi.create_infer_request()
q.infer({0: np.zeros((1, 3, 224, 224), dtype=np.float32)})

print("\033[0;32m\n=== ALLE 4 STICKS VOLL EINSATZBEREIT ===\033[0m")
os._exit(0)
PYEOF

echo -e "\n${GREEN}${BOLD}Installation und Selbsttest erfolgreich abgeschlossen!${NC}"
echo -e "Umgebung aktivieren mit: ${BOLD}source ~/ncs2_env/bin/activate${NC}\n"
