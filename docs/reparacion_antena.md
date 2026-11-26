# Reparación de antena en SKY130 HD

Los reportes originales `direct_ff_antenna.rpt` de cada configuración identifican una violación del cociente parcial de área lateral del metal respecto al área de puerta.

| Configuración | Red | Terminal | Capa | Cociente | Límite |
|---|---|---|---|---:|---:|
| direct N=8 | `clk` | `clkbuf_0_clk/A` | met4 | 413.82 | 400 |
| direct N=32 | `clknet_0_clk` | `clkbuf_4_9_0_clk/A` | met3 | 437.07 | 400 |
| recursive N=8 | `in_data[0]` | `hold17/A` | met3 | 447.30 | 400 |
| recursive N=16 | `clk` | `clkbuf_0_clk/A` | met4 | 577.28 | 400 |

Para met3 y met4, `sky130_fd_sc_hd__nom.tlef` define la curva de difusión `ANTENNADIFFSIDEAREARATIO PWL`. El tramo inicial admite un cociente de 400 y el límite crece con la difusión. El LEF de celdas declara `sky130_fd_sc_hd__diode_2` como `CORE ANTENNACELL` con 0.434700 µm² de difusión en `DIODE`.

OpenROAD `26Q3-2443-g50432012f` ofrece `repair_antennas diode_cell -diode_only`. La detección sobre rutas globales necesita confirmación sobre el trazado detallado porque cambia la geometría del metal. El primer caso de validación es direct N=8.

En el piloto, la detección sobre rutas globales encontró cero infracciones. Al cargar la base de datos del routing detallado, OpenROAD detectó una infracción e insertó un diodo. La reparación usa el trazado detallado original y sus guías globales, comprueba la ausencia de fillers, conecta la alimentación del diodo y guarda las guías para el nuevo routing detallado. Esta secuencia reutiliza el floorplan, la colocación y CTS.

`repair_antenna.py` ejecuta el routing detallado y verifica antena antes de extraer SPEF con OpenRCX para TT, SS y FF, verificar STA, insertar fillers y regenerar GDSII, KLayout DRC y LVS con Magic y Netgen. Cada ejecución guarda los logs, los Tcl, los archivos físicos y un manifiesto `verification.json` con los SHA-256 de los archivos originales y del checkpoint en `results/physical/antenna_repairs/`. La ejecución de publicación sustituye solo la fila de la configuración y únicamente después de aprobar todas las comprobaciones. El campo `source` apunta al directorio verificado. La regeneración histórica con `run_flow.py --summary` usa los estados del barrido original.

En la primera iteración de direct N=32, el routing corrigió el terminal original y dejó una infracción en `clkbuf_4_6_0_clk/A`, en la misma red `clknet_0_clk`. El cociente parcial de área lateral en met3 fue 465.69 frente al límite de 400. La segunda iteración parte del ODB sin fillers de ese intento y conserva el primer diodo.

Para reproducir cualquiera de los cuatro casos a partir de sus archivos originales, usa `--verify-only`. Por ejemplo:

```sh
python3 -B repair_antenna.py direct_n8 --verify-only
python3 -B repair_antenna.py direct_n32 --verify-only \
  --checkpoint results/physical/antenna_repairs/direct_n32_ibi7gnh_
```

## STA después del nuevo routing

WNS de setup y hold en ns. TNS de setup y hold es 0 para todos los casos y esquinas.

| Configuración | TT setup / hold | SS setup / hold | FF setup / hold |
|---|---:|---:|---:|
| direct N=8 | 14.412029 / 0.217322 | 8.704386 / 0.560121 | 16.333406 / 0.145567 |
| direct N=32 | 13.035073 / 0.272677 | 5.896743 / 0.689415 | 15.752605 / 0.146909 |
| recursive N=8 | 14.555264 / 0.111935 | 9.142827 / 0.309196 | 16.365850 / 0.078420 |
| recursive N=16 | 14.795774 / 0.103362 | 9.425336 / 0.286814 | 16.265993 / 0.077295 |

La comparación de los DEF antes de insertar fillers confirmó que las instancias existentes conservan sus ubicaciones y orientaciones. Cada reparación añadió un diodo en la red afectada. Direct N=32 añadió dos diodos en `clknet_0_clk`, uno por iteración.

Los recuentos de routing y antena se leen en `logs/detailed_route.log` y `logs/antenna.log`. OpenROAD deja vacíos los archivos de infracciones cuando no encuentra ninguna. El reporte `direct_ff_drc.lyrdb` contiene el resultado de KLayout y `lvs_comp.out` contiene la comparación de Netgen.

Los cuatro resultados publicados en `summary.csv` tienen routing completo, cero violaciones DRC de routing y KLayout, cero redes y terminales con violaciones de antena y LVS `Circuits match uniquely`.

| Configuración | Manifiesto de verificación |
|---|---|
| direct N=8 | [verification.json](../evidence/verification/direct_n8/verification.json) |
| direct N=32 | [verification.json](../evidence/verification/direct_n32/verification.json) |
| recursive N=8 | [verification.json](../evidence/verification/recursive_n8/verification.json) |
| recursive N=16 | [verification.json](../evidence/verification/recursive_n16/verification.json) |
