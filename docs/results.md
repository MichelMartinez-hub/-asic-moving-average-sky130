# Implementation results

Setup / hold timing entries are worst reported slack in ns. Setup and hold total negative slack were zero at TT, SS and FF for all eight configurations. Buffer counts track added buffers.

| Architecture | N | Synth. area (µm²) | Placed cell area (µm²) | Registers | Buffers added | Wire (µm) | TT | SS | FF |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Direct | 4 | 2707.60 | 3068.00 | 52 | 23 | 6126 | 15.350 / 0.210 | 11.060 / 0.490 | 16.900 / 0.130 |
| Direct | 8 | 5771.79 | 6284.78 | 101 | 28 | 12430 | 14.412 / 0.217 | 8.704 / 0.560 | 16.333 / 0.146 |
| Direct | 16 | 12025.28 | 13056.27 | 198 | 34 | 25523 | 13.688 / 0.097 | 7.108 / 0.291 | 15.902 / 0.074 |
| Direct | 32 | 25020.25 | 27077.22 | 391 | 91 | 51949 | 13.035 / 0.273 | 5.897 / 0.689 | 15.753 / 0.147 |
| Recursive | 4 | 3276.89 | 3726.07 | 78 | 31 | 7650 | 14.230 / 0.164 | 8.471 / 0.379 | 16.595 / 0.085 |
| Recursive | 8 | 4948.50 | 5886.90 | 128 | 55 | 11145 | 14.555 / 0.112 | 9.143 / 0.309 | 16.366 / 0.078 |
| Recursive | 16 | 8149.07 | 9417.78 | 226 | 89 | 17453 | 14.796 / 0.103 | 9.425 / 0.287 | 16.266 / 0.077 |
| Recursive | 32 | 14527.68 | 16245.58 | 420 | 89 | 28444 | 14.230 / 0.115 | 8.668 / 0.304 | 16.087 / 0.080 |

| Architecture | N | Route DRC | KLayout DRC | LVS | Antenna pins before → after | Diodes added | Power (µW) | Energy (pJ/sample) |
|---|---:|---:|---:|---|---:|---:|---:|---:|
| Direct | 4 | 0 | 0 | PASS | 0 → 0 | 0 | 302.04 | 6.04 |
| Direct | 8 | 0 | 0 | PASS | 1 → 0 | 1 | 801.62 | 16.03 |
| Direct | 16 | 0 | 0 | PASS | 0 → 0 | 0 | 3079.01 | 61.58 |
| Direct | 32 | 0 | 0 | PASS | 1 → 0 | 2 | 11878.52 | 237.57 |
| Recursive | 4 | 0 | 0 | PASS | 0 → 0 | 0 | 545.32 | 10.91 |
| Recursive | 8 | 0 | 0 | PASS | 1 → 0 | 1 | 821.02 | 16.42 |
| Recursive | 16 | 0 | 0 | PASS | 1 → 0 | 1 | 1154.21 | 23.08 |
| Recursive | 32 | 0 | 0 | PASS | 0 → 0 | 0 | 1717.83 | 34.36 |

Each repaired configuration ended with zero affected nets and pins. Direct N=32 required two diode insertion and routing passes. Energy assumes one accepted sample per cycle at 50 MHz.

The [original verified CSV](../evidence/data/summary_final_verified.csv) preserves both Direct N=4 rows. The eight-case tables use the historical row, also used by the [power CSV](../evidence/data/power_summary.csv). The CSV source paths record the original environment. The [GDSII manifest](../evidence/gds_manifest.csv) maps those sources to the archived files.
