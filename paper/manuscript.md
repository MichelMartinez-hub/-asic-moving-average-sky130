# Physical implementation of direct and recursive moving-average filters in SKY130

*Research article draft*

## Abstract

We compare two unsigned moving-average filters with 12-bit samples and window lengths of 4, 8, 16 and 32 in the SKY130 HD standard-cell library. Both architectures use the same clock constraint and sample acceptance protocol. Across eight routed implementations, the recursive design at N=32 used 40.0% less placed cell area and 45.25% less routed wirelength than the direct design. Its TT power estimate was 85.5% lower under the probabilistic input activity model used in this study.

## Method

The direct filter sums the current sample and its history with a balanced tree. The recursive filter subtracts the outgoing sample from an accumulator and adds the incoming sample. Both truncate the mean using a power-of-two shift. A reference-model testbench checks outputs during normal operation, reset and input stalls.

Yosys maps both filters to SKY130 HD. OpenROAD implements each configuration with a 20 ns clock constraint and extracts routed parasitics. Static timing analysis uses TT, SS and FF with corresponding interconnect models. KLayout checks the exported GDSII against the selected SKY130 rules. Magic extracts connectivity and Netgen compares it with the final layout reference. Four configurations required antenna diode insertion and detailed rerouting.

## Results and discussion

The recursive N=4 design had higher placed area and power than its direct counterpart. At N=8 the recursive design reduced placed area while its estimated power remained slightly higher. At N=32 it used 16,245.58 µm² of placed cell area and 28,444 µm of routed wire, compared with 27,077.22 µm² and 51,949 µm for the direct design. The corresponding TT estimates were 1,717.83 µW and 11,878.52 µW. The recursive design used more registers at every studied window size. [Full comparison](../docs/results.md)

## Limitations and reproducibility

The estimates apply to one vectorless activity scenario and the specific constraints, tool builds and library used. The layouts were evaluated with the documented open-source checks. Fabrication, silicon measurements and industrial signoff were outside the scope of the study. [Reproduction procedure](../docs/reproduction.md)
