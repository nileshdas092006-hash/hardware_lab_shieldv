# M-unit Standalone Synthesis Size Report

## Scope

This report records the standalone, out-of-context synthesis result for the `munit` top module. It includes the multiplier and divider instantiated by the M-unit. It is **not** a full-SoC utilization report and does not represent a placed-and-routed design.

## Tool and target

- **Tool:** AMD Vivado 2025.2 (64-bit)
- **Target part:** `xc7a100tcsg324-1` (Nexys A7-100T device)
- **Synthesis top:** `munit`
- **Synthesis mode:** Out-of-context (`synth_design -top munit -mode out_of_context`)

## Measured resource usage

| Resource | Count | Source in Vivado output |
|---|---:|---|
| LUT cells | 462 | Final synthesis summary: 99 LUT1, 87 LUT2, 74 LUT3, 56 LUT4, 11 LUT5, 135 LUT6 |
| Flip-flops | 214 | 213 `FDRE` + 1 `FDSE` |
| Latches | 0 | Summary printed by `synth_block.tcl` |
| DSP blocks | 4 | `DSP48E1` cells in final cell-usage report |
| Carry-chain cells | 53 | `CARRY4` cells in final cell-usage report |
| Total reported cells | 733 | Instance-area summary for the synthesized `top` hierarchy |

The component counts sum to 733: 462 LUTs + 214 flip-flops + 4 DSP48E1 cells + 53 CARRY4 cells.

## Synthesis outcome

- **Synthesis status:** Completed successfully
- **Errors:** 0
- **Critical warnings:** 0
- **Warnings:** 62

The log includes warnings about unused upper bits of multiplier result registers being removed. It also reports that no constraint files were found and warns that the clock port's `HD.CLK_SRC` property is not set in out-of-context mode, which prevents timing estimation for clock delay/skew. The successful synthesis result therefore establishes the reported resource counts, but this log alone does not establish final timing closure.

## Reports and artifacts

The synthesis Tcl script reported these output artifacts:

- Utilization report: `build/fpga/blocks/munit_utilization.rpt`
- Timing summary: `build/fpga/blocks/munit_timing.rpt`
- Vivado log: `build/vivado_block.log`

The console output did not include a numeric timing-slack result; consult the timing summary file if a slack value is required. No slack value is inferred in this report.

## Reproduction

The planned project command is:

```bash
make block BLOCK=munit
```

In this WSL environment, that command initially selected a Linux Vivado launcher that was not installed. The successful synthesis was run via the installed Windows Vivado batch launcher from Windows Command Prompt:

```bat
call C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -nojournal -log C:\Users\nisha\Downloads\hardware_lab_shieldv-work\build\vivado_block.log -source C:\Users\nisha\Downloads\hardware_lab_shieldv-work\G2\Nilesh\fpga\synth_block.tcl -tclargs munit
```

The Vivado log records `synth_design completed successfully` and `0 Errors encountered`.
