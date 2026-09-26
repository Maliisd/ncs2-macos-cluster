# Intel NCS2 (Myriad X) Cluster & Hybrid TCG Card Scanner auf macOS x86_64

Dieses Repository ermöglicht den Betrieb eines High-Performance Clusters aus Intel Neural Compute Sticks 2 (NCS2) unter modernen macOS-Versionen auf Intel-Macs (x86_64) via OpenVINO 2022.3.0. Zusätzlich verbindet es die Hardware-Beschleunigung mit einer modularen Magic: The Gathering (MTG) / TCG Scannersystem-Pipeline inklusive moderner Web-Oberfläche.

---

## ⚙️ Gelöste Kernprobleme des Clusters
1. **Fehlendes Myriad-Plugin:** Nativ kompiliert (`libopenvino_intel_myriad_plugin.so`) gegen modernes macOS Clang und Homebrew-`libusb`.
2. **Firmware-Zuweisung:** Automatische Einbindung der benötigten `usb-ma248x.mvcmd`.
3. **USB-Bus-Überlastung:** Durch gleichzeitiges Flashen aller Sticks bei Kaltstart stürzte der USB-Hub ab. Gelöst durch **Staggered Boot** (sequenzielle Initialisierung mit Pausen).
4. **macOS POSIX Mutex-Crash:** Beseitigung des `pthread_mutex_destroy`-Absturzes beim Skript-Ende durch atomaren Kernel-Exit (`os._exit(0)`).

---

## 🛠️ Systemvoraussetzungen
- **Hardware:** Intel-Mac (x86_64), aktiver USB-Hub mit **4x Intel NCS2 Sticks**.
- **Software:** 
  - Python 3.10
  - Tesseract OCR (`brew install tesseract`)

---

## 📦 Schritt-für-Schritt-Installationsanleitung

### 1. In den Projektordner wechseln
```bash
cd ~/ncs2-macos-cluster
```

### 2. Virtuelle Umgebung erstellen & aktivieren
```bash
python3.10 -m venv ~/ncs2_env
source ~/ncs2_env/bin/activate
```

### 3. Abhängigkeiten & OpenVINO installieren
*(Wichtig: OpenVINO 2022.3.0 erfordert zwingend NumPy ≤ 1.23.4)*
```bash
pip install "openvino-dev==2022.3.0" "numpy<=1.23.4" "opencv-python-headless<=4.8.1.78" pytesseract requests streamlit
```

### 4. Cluster-Treiber einrichten (Precompiled)
Lade die Datei `ncs2_driver_macos_x86_64.tar.gz` aus den GitHub Releases des Projekts herunter und entpacke sie direkt in das OpenVINO-Library-Verzeichnis deiner aktiven Umgebung:
```bash
tar -xzvf ncs2_driver_macos_x86_64.tar.gz -C $VIRTUAL_ENV/lib/python3.10/site-packages/openvino/libs/
```

### 5. Cluster-Test ausführen
Überprüfe, ob alle 4 Sticks korrekt erkannt werden und einsatzbereit sind:
```bash
python ncs2_cluster.py
```

---

## 🎮 Bedienung & Anwendung

### A) Weboberfläche starten (Streamlit UI - Empfohlen)
Ideal zum bequemen Hochladen von Kartenbildern (Drag & Drop) und Live-Analysieren im Browser:
```bash
source ~/ncs2_env/bin/activate
streamlit run app.py
```
Öffne anschließend die im Terminal angezeigte lokale Adresse (`http://localhost:8501`) in deinem Webbrowser.

### B) Direkt über das Terminal (CLI - Hybrid-Modus)
Du kannst das Skript flexibel mit verschiedenen Erkennungsmodi (`scryfall`, `ollama`, `gemini`) über die Konsole steuern:
```bash
source ~/ncs2_env/bin/activate
python card_scanner_hybrid.py --mode scryfall --image pfad/zu/karte.jpg
```

---

## ⚠️ Fehlerbehebung & Troubleshooting

### Problem 1: "VPU-Cluster: 0 NCS2 Sticks aktiv"
1. **Physischer Reset:** Ziehe den USB-Hub der Sticks kurz ab und stecke ihn nach 3 Sekunden wieder ein.
2. **Prüfen, ob macOS die Sticks sieht:**
   ```bash
   ioreg -p IOUSB -w0 | grep -i "Movidius"
   ```
   *(Es sollten exakt 4 Einträge mit `Movidius MyriadX` erscheinen).*
3. **OpenVINO-Verbindung testen:**
   ```bash
   python -c "from openvino.runtime import Core; print(Core().available_devices)"
   ```
   *(Es sollten 4 `MYRIAD`-Geräte aufgelistet werden).*

### Problem 2: NumPy-Konflikt (`openvino requires numpy<=1.23.4`)
Falls durch Paket-Updates versehentlich eine neuere NumPy-Version eingespielt wurde, erzwinge die kompatible Version:
```bash
pip install "numpy<=1.23.4" --force-reinstall
```
