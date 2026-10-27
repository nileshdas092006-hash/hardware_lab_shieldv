# ShieldV's own cost, and the two cores (Vivado 2025.2, xc7a100tcsg324-1, 2026-10-11)

Built with `scripts/fpga.py` (program `attack` in the RAMs, 50 MHz system clock from the MMCM).
Reports: `build/fpga/<variant>/utilization.rpt`, `utilization_hier.rpt`, `timing.rpt`.
These are Vivado results on the laptop; nothing has run on the board yet.

| Build | Command | LUTs | Flip-flops | BRAM tiles | DSP | WNS at 50 MHz | Rough max clock |
|---|---|---|---|---|---|---|---|
| in-order core + ShieldV | `fpga.py build attack` | 2,110 (3.3 %) | 1,083 | 8 | 4 | +0.461 ns, met | about 51 MHz |
| in-order core, ShieldV replaced by its stub | `fpga.py build attack --no-shield` | 1,793 (2.8 %) | 830 | 8 | 4 | +1.480 ns, met | about 54 MHz |
| out-of-order core + ShieldV | `fpga.py build attack --ooo` | 9,806 (15.5 %) | 5,981 | 8 | 4 | +0.159 ns, met | about 50 MHz |

"Rough max clock" is 1 / (20 ns − WNS). It is only an estimate: the design was built for 50 MHz,
and Vivado stops optimising once that is met. 100 MHz (the stretch target) was not tried.

## ShieldV with versus without

| Measure | Value | Where it comes from |
|---|---|---|
| ShieldV module alone (in-order build) | **198 LUTs** (44 of them LUTRAM for the 32-entry shadow stack), 150 flip-flops, **0 BRAM** | `utilization_hier.rpt`, row `g_shield.u_sh` |
| Whole design, with minus without | **+317 LUTs**, +253 flip-flops | the two `utilization.rpt` files |
| Worst slack, with minus without | 1.02 ns less slack with ShieldV | `timing.rpt` |
| Extra cycles per call / return | **0** on every workload, both cores | `docs/results/overhead.md` |

Why "with minus without" (317) is larger than the ShieldV module (198): with the stub, `sh_trap`
and `sh_freeze` are constant 0 and the event counters never count, so Vivado also deletes the trap
path in the core (`core_pipe` shrinks from 1,490 to 1,296 LUTs) and the CALLS / RETS / VIOL
counters. Both numbers are honest; the 317 is the true cost of adding ShieldV to the system.

Abstract targets: ShieldV ≤ 500 LUTs and 0 BRAM (**met**, 198 LUTs); whole SoC ≤ 25 % of LUTs
(**met** for both cores: 3.3 % and 15.5 %); in-order clock ≥ 50 MHz (**met**); out-of-order clock
"reported as measured": **50 MHz met** with +0.159 ns to spare. Its critical path starts in the
load/store queue (`u_lsq/vb_reg`).

## Out-of-order core, largest blocks (`build/fpga/fpga_top_ooo/utilization_hier.rpt`)

| Block | LUTs | Flip-flops |
|---|---|---|
| core_ooo total | 9,225 | 5,211 |
| rob (16 entries) | 2,908 | 1,180 |
| rs, ALU station (4 entries) | 2,407 | 300 |
| lsq (8 entries) | 1,620 | 901 |
| bp_tournament | 952 | 784 |
| shieldv (in this build) | 136 | 150 |
