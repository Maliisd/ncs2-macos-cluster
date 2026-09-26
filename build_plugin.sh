#!/bin/bash
set -e

echo "=== 1. Abhängigkeiten prüfen ==="
brew install cmake ninja libusb pkg-config python@3.10

echo "=== 2. OpenVINO 2022.3.0 Source clonen ==="
git clone --recurse-submodules --shallow-submodules --depth 1 --branch 2022.3.0 https://github.com/openvinotoolkit/openvino.git openvino_src

cd openvino_src
mkdir -p build && cd build

echo "=== 3. CMake konfigurieren ==="
cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTREAT_WARNING_AS_ERROR=OFF \
  -DENABLE_INTEL_MYRIAD=ON \
  -DENABLE_INTEL_CPU=OFF \
  -DENABLE_INTEL_GPU=OFF \
  -DENABLE_OPENCV=OFF \
  -DENABLE_TESTS=OFF \
  -DENABLE_SAMPLES=OFF \
  -DLIBUSB_INCLUDE_DIR="/usr/local/opt/libusb/include/libusb-1.0" \
  -DLIBUSB_LIBRARIES="/usr/local/opt/libusb/lib/libusb-1.0.dylib" \
  ..

echo "=== 4. Myriad-Plugin kompilieren ==="
ninja openvino_intel_myriad_plugin

echo "=== 5. Treiberpaket schnüren ==="
mkdir -p ~/Desktop/ncs2_driver
cp bin/intel64/Release/*myriad* ~/Desktop/ncs2_driver/
find .. -name "*.mvcmd" -exec cp {} ~/Desktop/ncs2_driver/ \;
cd ~/Desktop/ncs2_driver/
[ -f usb-ma2x8x.mvcmd ] && [ ! -f usb-ma248x.mvcmd ] && ln -s usb-ma2x8x.mvcmd usb-ma248x.mvcmd
tar -czvf ~/Desktop/ncs2_driver_macos_x86_64.tar.gz .
rm -rf ~/Desktop/ncs2_driver

echo "Fertig! Treiberpaket liegt auf dem Schreibtisch."
