# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-15

### Added
- **Gemma 4 e2b Inference**: Support for high-performance localized LLM inference.
- **Clinical Dashboard**: A dashboard-first UI for medical investigative work.
- **Mermaid Flowcharts**: Vertical clinical diagnostic path rendering using Mermaid TD.
- **Wide Column Tables**: Professional medical reference tables with horizontal scrolling.
- **Isolate-Based Execution**: Responsive UI during heavy local inference.
- **KV Cache Warmup**: Strategic system prompt caching for faster TTFT.

### Changed
- Replaced traditional chatbot "bubbles" with structured clinical Markdown reporting.

### Security
- **Privacy-First Core**: 100% offline operation. No patient data or logs leave the device.

### 📈 Performance Benchmarks (Gemma 4 e2b)
- **Prompt Processing**: > 50 t/s
- **Token Generation**: > 10–15 t/s
- **TTFT**: < 800ms
- **Peak RAM**: < 3.5 GB

---

### Hardware Requirements
- **Recommended**: 8GB+ RAM. 
- **Minimum**: Devices with <8GB RAM may experience instability during the generation phase.
- **Android Support**: Certain OS variants (MIUI, ColorOS, etc.) may terminate the app during high-memory inference spikes to save battery. User-level "Battery Optimization" exclusion is recommended.
