# 🦅 CareNest v1.0.0 — The Release

We are proud to announce the initial public release of **CareNest**, a production-grade medical investigative instrument designed for the modern practitioner. CareNest bridges the gap between high-performance local AI and clinical utility, delivering a strictly offline, privacy-first diagnostic experience.

## 🩺 The "Dashboard-First" Philosophy

CareNest treats every interaction as a clinical consultation, producing structured Markdown reports, high-fidelity medical tables, and vertical diagnostic paths.

## 🚀 Key Features

### 🧠 Local-First Medical Intelligence

* **Gemma 4 e2b Integration**: Powered by a custom `llama.cpp` native FFI layer.
* **100% Offline**: All inference happens on-device. No health data ever leaves your pocket.
* **Predictive Diagnostics**: Optimized for clinical reasoning and structured medical output.

### 📊 Clinical Rendering Engine

* **Vertical Flowcharts**: Automated rendering of **Mermaid TD** diagrams to visualize clinical logic and symptom paths.
* **Wide-Column Data**: Professional rendering of complex reference tables with horizontal scrolling to prevent data compression.
* **Structural Markdown**: Fully formatted clinical sections and sub-sections for maximum readability.

### ⚡ Architectural Excellence

* **Isolate-Hardened Inference**: A dedicated Dart isolate runner ensures the UI remains responsive (60fps) even during heavy LLM computation.
* **KV Cache Warmup**: Strategic system prompt caching reduces Time-To-First-Token (TTFT) significantly.

## 📈 Performance Benchmarks

CareNest is engineered for baseline performance on modern Android silicon. The following targets are the "Gold Standard" for our current optimizations:

| Metric | Goal for Gemma 4 e2b | Why it matters |
| :--- | :--- | :--- |
| **Prompt Processing (pp)** | > 50 t/s | How fast the model "reads" the user's input. |
| **Token Generation (tg)** | > 10–15 t/s | Needs to feel faster than a human can read. |
| **Time to First Token (TTFT)** | < 800ms | Users in emergencies won't wait 5 seconds for a response. |
| **Peak RAM Usage** | < 3.5 GB | Critical for preventing the mobile OS from killing your app. |

---

---

## ⚠️ Important: Hardware Requirements & Stability

To ensure a stable experience, please note the following hardware requirements:

* **Memory**: **8GB RAM is strictly required**.
* **Stability Note**: Devices with less than 8GB of RAM, or those with aggressive background memory management, may experience application crashes immediately after the first token is generated (Post-TTFT).
* **Android Resource Management**: Due to the high memory pressure during local inference, some Android OS variants (e.g., MIUI, ColorOS) may terminate the application to conserve battery or system resources.
* **Optimization Tip**: For the best experience, we recommend closing high-memory background apps and disabling "Battery Optimization" for CareNest in your system settings.
* **Storage**: Approx. 3GB - 5GB for the initial model download.

---

## 🛠️ Developer & Contributor Info

* **Native Core**: C++ wrapper around `llama.cpp`.
* **Frontend**: Flutter / Dart.
* **Design System**: Outfit Medical Design.

## ⚖️ License & Disclaimer

This software is intended for **research and educational purposes only**. It is not a replacement for professional medical advice, diagnosis, or treatment.

Licensed under the **MIT License**.
