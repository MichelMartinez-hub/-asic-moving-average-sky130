# Reproducing the experiments

Use a fresh checkout for a sweep. The drivers write into the ignored `results/physical/` tree by default. The files under [evidence](../evidence/) are archived results. The original CSVs retain absolute paths as provenance, and the [manifest](../evidence/gds_manifest.csv) resolves the eight archived layouts.

## Synthesis only

The command below maps Direct N=4. Change the module name and window value to select another configuration. The full sweep runs the same synthesis sequence automatically.

```sh
mkdir -p build
top=moving_average_direct
n=4
lib=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -l "build/${top}_n${n}.log" -p "
    read_verilog -sv rtl/filters/${top}.sv
    hierarchy -check -top ${top} -chparam DATA_W 12 -chparam WINDOW_N ${n}
    synth -top ${top} -noabc
    dfflibmap -liberty ${lib}
    abc -liberty ${lib} -dont_use sky130_fd_sc_hd__lpflow* -dont_use sky130_fd_sc_hd__clkinv* -dont_use sky130_fd_sc_hd__probe*
    clean
    stat -liberty ${lib}
    write_verilog -noattr build/${top}_n${n}.v
"
```

## Routed sweep and antenna repair

```sh
python3 run_flow.py --validate
python3 run_flow.py --all
```

The first command reproduces Direct N=4 with a 40% floorplan utilization target. The second runs the remaining seven cases at a 47% target. The sweep can return failure after recording antenna violations even when later DRC and LVS checks complete. Before repair, inspect `results/physical/summary.csv`. The four affected rows should show `antenna_net=1`, `antenna_pin=1`, zero routing and KLayout DRC, passing LVS and nonnegative slack. Resolve any other failure before proceeding.

For a single isolated run, use `python3 run_flow.py --architecture recursive --window 16 --output-root build/physical`. Repeat the same command to resume its checkpoints. The repair driver expects the default output root. The `--summary` option collects the baseline execution states and can replace the repaired rows in the working CSV, so use it before repair.

```sh
python3 repair_antenna.py direct_n8
python3 repair_antenna.py recursive_n8
python3 repair_antenna.py recursive_n16
python3 repair_antenna.py direct_n32
```

In the archived Direct N=32 run, a different pin on the same clock network still violated the antenna threshold after the first pass. If this occurs, take the attempt directory printed by the command and use it for the second pass.

```sh
python3 repair_antenna.py direct_n32 --checkpoint results/physical/antenna_repairs/ATTEMPT_DIRECTORY
```

Replace the placeholder with the directory name before running the command. Review the per-case logs and manifests for complete routing, zero routing DRC, zero antenna nets and pins, positive setup and hold slack, zero KLayout DRC items and matching LVS. See the [antenna case notes](reparacion_antena.md) for the affected nets and diode counts. Tool or PDK revisions can change the routing and the repair sequence.

## Post-route power

The estimator reads each verified case's routed ODB and TT SPEF using the working CSV's absolute `source` paths. After confirming eight passing configurations in the fresh checkout, snapshot that working summary and run the estimator.

```sh
cp results/physical/summary.csv results/physical/summary_final_verified.csv
python3 run_power.py
```

This writes a new `power_summary.csv`, a PDF plot and individual JSON reports under `results/physical/`. The archived Direct N=4 values use the original historical run. A fresh checkout regenerates the 40% validation run for that configuration. Compare metrics with the [archived results](results.md). Generated timestamps and layout record ordering can affect file hashes.

## Archive integrity

From the root, verify the eight distributed layouts against the manifest.

```sh
python3 - <<'PY'
import csv
import hashlib
from pathlib import Path

root = Path("evidence")
with (root / "gds_manifest.csv").open(newline="") as stream:
    rows = list(csv.DictReader(stream))
expected = {f"{a}_n{n}" for a in ("direct", "recursive") for n in (4, 8, 16, 32)}
assert len(rows) == 8 and {row["case"] for row in rows} == expected
assert {root / row["file"] for row in rows} == set((root / "gds").glob("*.gds"))
for row in rows:
    data = (root / row["file"]).read_bytes()
    assert len(data) == int(row["bytes"]), row["case"]
    assert hashlib.sha256(data).hexdigest() == row["sha256"], row["case"]
print("Eight GDSII files verified")
PY
```
