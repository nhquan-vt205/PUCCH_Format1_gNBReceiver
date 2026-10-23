# Spec status

STATUS: PASS
Input: doc/spec/source/README.md, 01_Requirements.md, 02_Architecture.md, 03_Algorithm.md, 04_Interface.md, 05_LUT.md, 06_Freeze_and_Verification.md, 07_LUT_Consolidated.md, VERIFICATION_REPORT.md

## Module list
| Module | Parent | Type | Level | Function |
| --- | --- | --- | --- | --- |
| `pucch_f1_rx_core` | – | top | L0 | PUCCH Format 1 inverse-phase receiver core (instances + wiring only) |
| `pucch_f1_ctrl` | `pucch_f1_rx_core` | leaf | L2 | Config snapshot, validation, derived counts, transaction FSM, RE tag checks, error latch, result record |
| `pucch_f1_lowpapr_phase_gen` | `pucch_f1_rx_core` | block | L1 | Gold prep, u per hop, cyclic-shift cache, per-RE base+CS phase stream |
| `pucch_f1_gold_gen` | `pucch_f1_lowpapr_phase_gen` | leaf | L2 | 31-bit Gold sequence generator, 1 bit/clock after 1600 warm-up (2 instances) |
| `pucch_f1_rx_inverse` | `pucch_f1_rx_core` | block | L1 | Join register, OCC lookup, total-phase negate, coherent accumulator |
| `pucch_f1_cordic` | `pucch_f1_rx_inverse` | leaf | L1 | 16-iteration full-circle rotation CORDIC pipeline |
| `pucch_f1_normalize` | `pucch_f1_rx_inverse` | leaf | L2 | Gain correction (KINV_Q30) + RNE divide by N_RE, d_rx output stream |
| `pucch_f1_mod_candidates` | `pucch_f1_rx_core` | leaf | L2 | 2/4 modulation candidates d_k(0) table |
| `pucch_f1_scalar_mle` | `pucch_f1_rx_core` | leaf | L2 | Scalar correlation metrics, ranking, tie-break, UCI mapping |

## OPEN
| ID | Description | Interim assumption | Impact |
| --- | --- | --- | --- |
| OPEN-001 | Input names the four compute blocks but not the top, controller, CORDIC, normalizer or Gold generator modules | Names `pucch_f1_rx_core`, `pucch_f1_ctrl`, `pucch_f1_cordic`, `pucch_f1_normalize`, `pucch_f1_gold_gen` | Rename only; no architecture change |
| OPEN-002 | `lut/` (`.mem`/`.csv`) and `tools/` referenced by 05/07 are not present in `doc/spec/source/` | ROM contents taken from the tables in `07_LUT_Consolidated.md` (canonical values reproduced there); RTL encodes them as constant case ROMs | ROM coding style only; values unchanged |
