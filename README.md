# Intel NCS2 (Myriad X) Cluster auf macOS x86_64

Dieses Repository ermöglicht den Betrieb eines High-Performance Clusters aus Intel Neural Compute Sticks 2 (NCS2) unter modernen macOS-Versionen auf Intel-Macs (x86_64) via OpenVINO 2022.3.0.

## Gelöste Kernprobleme
1. **Fehlendes Myriad-Plugin:** Nativ kompiliert (`libopenvino_intel_myriad_plugin.so`) gegen modernes macOS Clang und Homebrew-`libusb`.
2. **Firmware-Zuweisung:** Automatische Einbindung der benötigten `usb-ma248x.mvcmd`.
3. **USB-Bus-Überlastung:** Durch gleichzeitiges Flashen aller Sticks bei Kaltstart stürzte der USB-Hub ab. Gelöst durch **Staggered Boot** (sequenzielle Initialisierung mit 500 ms Pause).
4. **macOS POSIX Mutex-Crash:** Beseitigung des `pthread_mutex_destroy`-Absturzes beim Skript-Ende durch atomaren Kernel-Exit (`os._exit(0)`).

## Schnellanleitung (Precompiled)
1. Lade `ncs2_driver_macos_x86_64.tar.gz` aus den Releases herunter.
2. Entpacke das Archiv direkt in das OpenVINO-Library-Verzeichnis deines Python-Environments:
   ```bash
   tar -xzvf ncs2_driver_macos_x86_64.tar.gz -C $KIRTUAL_ENV/lib/python3.10/site-packages/openvino/libs/
   ```
3. Führe den Cluster-Test aus:
   ```bash
   python ncs2_cluster.py
   ```
