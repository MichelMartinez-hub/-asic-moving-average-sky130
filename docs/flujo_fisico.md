# Flujo físico reproducible en SKY130 HD

Desde la raíz del proyecto, con Verilator, Yosys, OpenROAD, KLayout, Magic,
Netgen y Python 3.11 o posterior disponibles en el entorno:

```sh
python3 run_flow.py --validate
python3 run_flow.py --architecture recursive --window 4
python3 run_flow.py --architecture direct --window 16
python3 run_flow.py --all
python3 run_flow.py --summary
```

`--validate` usa `results/physical/validation_direct_n4/` y reproduce el
objetivo histórico de utilización del 40 %. `--all` omite direct N=4 y ejecuta
las siete configuraciones restantes de forma secuencial. La selección
individual, incluido direct N=4, usa `results/physical/<arquitectura>_n<N>/`.
`--output-root RUTA` permite cambiar la raíz de trabajo para un experimento
independiente. El caso histórico está en `results/physical/n4/`.

Por defecto el objetivo de floorplan para las nuevas configuraciones es 47 %.
`--utilization 45` establece otro objetivo porcentual. OpenROAD dimensiona el
core a partir de las celdas enlazadas de la síntesis, con aspecto 1:1, margen de
10 µm, sitio `unithd` y las pistas del script validado. La cuadrícula de sitios
y las filas se generan con el LEF de SKY130 HD. El CSV mide la utilización real
tras optimización física. El flujo utiliza el PDK en `/foss/pdks/sky130A` y
`/foss/designs/orfs/flow/util/def2stream.py` para exportar DEF a GDSII.

## Dependencias del diseño

Ambos módulos usan `DATA_W=12` y `WINDOW_N`, con puertos `clk`, `rst_n`,
`enable`, `in_valid`, `in_data`, `out_valid` y `out_data`. Para direct se
ejecuta `tb_direct_param`. Para recursive se ejecuta `tb_filter_equivalence`,
que compara ambas arquitecturas con un modelo matemático. En recursive,
el desplazamiento empieza en `WINDOW_N-1`, último índice de `history`.
Antes de la corrección, la primera iteración intentaba escribir
`history[WINDOW_N]` en cada flanco ascendente con reset liberado,
`enable=1` e `in_valid=1`, para las cuatro ventanas. La escritura
no actualizaba ninguna entrada válida. El límite corregido conserva los
desplazamientos válidos y el cálculo del acumulador. El último elemento
del historial se sobreescribe con una muestra aceptada antes de que el
contador habilite su lectura tras reset.

La corrección pasó `tb_filter_equivalence` en N=4, 8, 16 y 32, con
10 000 muestras aleatorias aceptadas por ventana, pruebas de reset y pausas
con `enable` o `in_valid` desactivados. Verilator ejecutó el lint del
módulo con `-Wall` sin advertencias. La síntesis mapeada superó
`check -assert -mapped` y la comparación antes/después del RTL elaborado
superó `equiv_status -assert` en Yosys para las cuatro ventanas.

Yosys elabora el módulo elegido, mapea los registros con la Liberty TT y
ejecuta ABC con las exclusiones de celdas incompatibles. OpenROAD reutiliza los
Tcl de N=4 y el SDC de 20 ns, incluidos los retardos de entrada y salida. Cada
copia Tcl materializada queda en `tcl/`. Los nombres internos de los artefactos
OpenROAD conservan el prefijo histórico `direct_` incluso en ejecuciones
recursive. El directorio y el nombre del módulo identifican la arquitectura.

El orden de las etapas es simulación, síntesis, importación, floorplan,
colocación de pines, tapcells, PDN, colocación global y detallada, reparación
de diseño, CTS, reparación de hold en TT y FF, y enrutamiento global y
detallado. El flujo extrae SPEF desde el ODB enrutado y calcula STA con reloj
propagado para TT (25 °C, 1.80 V, RC nominal), SS (100 °C, 1.60 V, RC máximo)
y FF (−40 °C, 1.95 V, RC mínimo). A continuación verifica antenas, añade
fillers, comprueba la red de alimentación y exporta el GDSII.

KLayout usa `sky130A_mr.drc` con FEOL, BEOL y off-grid activos y seal
desactivado. El conteo procede de los ítems del `.lyrdb`. La referencia LVS
se exporta del ODB final con `-include_fillers` y se concatena con las
definiciones maestras SPICE. Magic extrae el GDSII con la configuración de
SKY130A. Netgen usa `sky130A_setup.tcl` y el informe final debe contener
`Final result: Circuits match uniquely.`.

## Resultados y reanudación

- `logs/` conserva el comando y toda la salida de cada intento.
- `state.json` registra las etapas pendientes, en ejecución, completadas,
  fallidas o completadas con una verificación fallida (`failed_check`).
- Los puntos de control ODB, DEF, guías de ruta, SPEF, GDSII, `.lyrdb`,
  CDL y reportes LVS quedan junto al manifiesto. Magic escribe sus archivos
  intermedios en `lvs_magic/extfiles/`.
- `summary.csv` se actualiza en la raíz de salida y puede regenerarse con
  `--summary`. Incluye WNS y TNS para setup y hold en los tres escenarios,
  DRC de ruta, DRC de KLayout, antenas y LVS.
  Los campos sin datos quedan vacíos. El caso histórico se incorpora a
  partir de los reportes conservados.

El área de celdas colocadas y el número de instancias se miden en el ODB
enrutado antes de fillers, incluyendo tapcells. Los registros se cuentan con
`all_registers`. Para contar buffers añadidos se comparan los identificadores
de instancias de las familias de buffer y retardo de SKY130 HD entre la
netlist sintetizada y el DEF enrutado. La longitud de interconexiones procede
del reporte de detailed routing. El área colocada y la utilización de la fila
histórica conservan la precisión del reporte de la última reparación de hold.

Para reanudar, repite el mismo comando con la misma raíz y utilización.
El ejecutor reutiliza las etapas con artefactos disponibles y retoma la
primera interrumpida, con error de ejecución o con archivos faltantes.
Una violación de STA, antenas, DRC independiente o LVS queda registrada y
permite recopilar el resto de verificaciones. Un error de herramienta o una
ruta incompleta detiene esa implementación. Para probar un cambio de
insumos o repetir una verificación física fallida con otro objetivo de
utilización, usa un nuevo `--output-root`. La salida distingue `PASS`,
`FAIL` e `INCOMPLETE`. El ejecutor devuelve un código distinto de cero
cuando alguna implementación seleccionada falla.
