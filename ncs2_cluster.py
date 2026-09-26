import os
import time
import numpy as np
from openvino.runtime import Core, AsyncInferQueue

# Verhindert XLink-Log-Spam
os.environ["OPENVINO_LOG_LEVEL"] = "0"

class NCS2Cluster:
    def __init__(self, model):
        self.core = Core()
        devices = self.core.available_devices
        self.myriad_devices = [d for d in devices if "MYRIAD" in d]
        
        if not self.myriad_devices:
            raise RuntimeError("Keine NCS2 Sticks gefunden! Bitte USB-Verbindung prüfen.")
            
        print(f"[NCS2 Cluster] {len(self.myriad_devices)} Sticks gefunden: {self.myriad_devices}")
        
        # Phase 1: Staggered Boot (verhindert gleichzeitigen USB-Stromspitzen-Reset)
        print("[NCS2 Cluster] Initialisiere Sticks sequenziell...")
        for idx, dev in enumerate(self.myriad_devices, 1):
            tmp = self.core.compile_model(model, dev)
            req = tmp.create_infer_request()
            req.infer({0: np.zeros((1, 3, 224, 224), dtype=np.float32)})
            print(f" -> [{idx}/{len(self.myriad_devices)}] {dev} aktiv.")
            time.sleep(0.5)

        # Phase 2: MULTI-Device Verbundschaltung
        target_str = f"MULTI:{','.join(self.myriad_devices)}"
        print(f"[NCS2 Cluster] Schalte Verbund aktiv: {target_str}")
        self.compiled_model = self.core.compile_model(model, target_str)
        
        # Phase 3: Asynchrone Queue (2 Jobs pro VPU für maximalen Durchsatz)
        self.queue = AsyncInferQueue(self.compiled_model, jobs=len(self.myriad_devices) * 2)
        self.queue.set_callback(self._callback)
        self.results = {}

    def _callback(self, infer_request, userdata):
        card_id = userdata
        self.results[card_id] = infer_request.get_output_tensor(0).data

    def infer_async(self, card_id, image_tensor):
        """Übergibt einen Scan asynchron an den nächsten freien VPU-Stick."""
        self.queue.start_async({0: image_tensor}, userdata=card_id)

    def wait_all(self):
        """Wartet auf den Abschluss aller laufenden Berechnungen."""
        self.queue.wait_all()
        return self.results


if __name__ == "__main__":
    from openvino.runtime import Model, opset8

    # Testmodell im RAM erzeugen
    param = opset8.parameter(shape=[1, 3, 224, 224], dtype=np.float32, name="input")
    relu = opset8.relu(param)
    dummy_model = Model([relu], [param], "test_net")

    # Cluster starten
    cluster = NCS2Cluster(dummy_model)

    print("\nFeuere 32 Test-Kartenbilder über den Cluster...")
    t0 = time.time()
    for i in range(32):
        dummy_data = np.random.randn(1, 3, 224, 224).astype(np.float32)
        cluster.infer_async(f"Card_{i:02d}", dummy_data)

    res = cluster.wait_all()
    duration = time.time() - t0
    print(f"\nErfolg: {len(res)} Inferenzen in {duration:.2f}s ({len(res)/duration:.1f} FPS)")

    # Sauberer Kernel-Exit zur Vermeidung des libusb-Destruktor-Konflikts
    os._exit(0)
