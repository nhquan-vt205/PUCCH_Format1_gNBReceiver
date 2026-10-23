# pucch_f1_rx_inverse – Specification / Đặc tả
Type: block · Parent: `pucch_f1_rx_core` · Level: L1

## Function / Chức năng

For each joined RE, adds the OCC phase to `r_phase`, negates the total modulo 65536, rotates `Y_hat` once with the CORDIC, sign-extends the 18-bit output and accumulates all REs of both hops into one complex sum `S` (26-bit F15). After the last RE it starts the normalizer, which outputs `d_rx = RNE(RNE(S·KINV)/N_RE)` on the `d_*` stream. It owns the OCC ROM.

_VI:_ Với mỗi RE đã join, cộng pha OCC vào `r_phase`, lấy đối của tổng modulo 65536, quay `Y_hat` một lần bằng CORDIC, mở rộng dấu output 18 bit và tích lũy mọi RE của cả hai hop thành một tổng phức `S` (26 bit F15). Sau RE cuối, khởi động normalizer, khối này xuất `d_rx = RNE(RNE(S·KINV)/N_RE)` trên stream `d_*`. Khối sở hữu OCC ROM.

## Interface

| Port name | Direction | Width | Type | Connects to | Description |
| --- | --- | --- | --- | --- | --- |
| `clk` | in | 1 | CLK/RST | `pucch_f1_rx_core.clk` | Clock |
| `rst_n` | in | 1 | CLK/RST | `pucch_f1_rx_core.rst_n` | Sync active-low reset |
| `txn_clr` | in | 1 | CTRL | `pucch_f1_ctrl.txn_clr` | Flush join, pipeline, sum, normalizer |
| `join_fire` | in | 1 | CTRL | `pucch_f1_ctrl.join_fire` | Capture data + phase pair |
| `y_i` | in | 16 | DATA | `pucch_f1_rx_core.y_i` | Y_hat I, signed F15 |
| `y_q` | in | 16 | DATA | `pucch_f1_rx_core.y_q` | Y_hat Q, signed F15 |
| `r_phase` | in | 16 | DATA | `pucch_f1_lowpapr_phase_gen.r_phase` | base + CS phase |
| `phase_sample_q` | in | 7 | DATA | `pucch_f1_lowpapr_phase_gen.phase_sample_q` | Tag q |
| `phase_hop` | in | 1 | DATA | `pucch_f1_lowpapr_phase_gen.phase_hop` | Tag h |
| `phase_m` | in | 3 | DATA | `pucch_f1_lowpapr_phase_gen.phase_m` | Tag m |
| `phase_first` | in | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.phase_first` | Tag first |
| `phase_last` | in | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.phase_last` | Tag last |
| `occ_i` | in | 3 | DATA | `pucch_f1_ctrl.occ_i` | OCC index |
| `n_sf0` | in | 3 | DATA | `pucch_f1_ctrl.n_sf0` | N_SF hop0 |
| `n_sf1` | in | 3 | DATA | `pucch_f1_ctrl.n_sf1` | N_SF hop1 |
| `n_re` | in | 7 | DATA | `pucch_f1_ctrl.n_re` | N_RE |
| `occ_err` | out | 1 | STATUS | `pucch_f1_ctrl.occ_err` | Illegal OCC (N, i, m) for current phase tag (combinational) |
| `acc_done` | out | 1 | STATUS | `pucch_f1_ctrl.acc_done` | 1-clock pulse: last RE accumulated |
| `num_err` | out | 1 | STATUS | `pucch_f1_ctrl.num_err` | Numeric overflow/saturation pulse |
| `d_valid` | out | 1 | CTRL | `pucch_f1_ctrl.d_valid`, `pucch_f1_scalar_mle.d_valid` | d_rx valid |
| `d_ready` | in | 1 | CTRL | `pucch_f1_scalar_mle.d_ready` | d_rx ready |
| `d_i` | out | 26 | DATA | `pucch_f1_scalar_mle.d_i` | d_rx I, signed F15 |
| `d_q` | out | 26 | DATA | `pucch_f1_scalar_mle.d_q` | d_rx Q, signed F15 |
| `d_n_re` | out | 7 | DATA | open (debug, input 04 §8) | = `n_re` |

## Structure / Cấu trúc

| Instance | Module | Role |
| --- | --- | --- |
| `u_cordic` | `pucch_f1_cordic` | One rotation per RE, 18-clock pipeline from join register |
| `u_normalize` | `pucch_f1_normalize` | Gain correction + divide by N_RE |

Own logic:

_VI:_ Logic riêng:

| Element | Width | Role |
| --- | --- | --- |
| OCC ROM | 140 × 16 | addr `offset[N] + occ_i·N + m`, `offset = {0,1,5,14,30,55,91}` for N = 1..7, source 07 §3 (N=4 Walsh rows) |
| Join register `j_valid_q`, `j_i_q`, `j_q_q`, `j_phase_q`, `j_sample_q_q`, `j_first_q`, `j_last_q` | 1, 16, 16, 16, 7, 1, 1 | Data + remove-phase pair, feeds `u_cordic` |
| Accumulator `s_i_q`, `s_q_q` | 26, 26 | Coherent sum S, signed F15 |
| `acc_done_q`, `acc_ovf_q` | 1, 1 | Last-accumulated pulse, overflow pulse |

## Behavior / Hành vi

- OCC lookup (combinational from phase tag): `N = phase_hop ? n_sf1 : n_sf0`; `occ_phase = OCC[offset[N] + occ_i·N + phase_m]`; `occ_err = (N == 0) || (occ_i ≥ N) || (phase_m ≥ N)`, ROM output 0 when illegal.
  - _VI:_ Tra OCC (tổ hợp từ tag pha): `N = phase_hop ? n_sf1 : n_sf0`; `occ_phase = OCC[offset[N] + occ_i·N + phase_m]`; `occ_err = (N == 0) || (occ_i ≥ N) || (phase_m ≥ N)`, ROM trả 0 khi không hợp lệ.
- Join register: on `join_fire` capture `y_i`, `y_q`, `j_phase = (−((r_phase + occ_phase) mod 65536)) mod 65536`, and the phase tags; `j_valid_q = join_fire`. Forward OCC is added, then the total is negated once (never negate the OCC table separately).
  - _VI:_ Join register: khi `join_fire` capture `y_i`, `y_q`, `j_phase = (−((r_phase + occ_phase) mod 65536)) mod 65536`, và các tag pha; `j_valid_q = join_fire`. Cộng OCC xuôi rồi lấy đối tổng đúng một lần (không lấy đối bảng OCC riêng).
- The CORDIC pipeline advances every clock (the accumulator always accepts, so the global pipeline enable of source 02 §6 is permanently 1 and there is no back-pressure into the join register).
  - _VI:_ Pipeline CORDIC tiến mỗi clock (accumulator luôn nhận, nên global pipeline enable của source 02 §6 luôn bằng 1 và không có back-pressure vào join register).
- Accumulator on `u_cordic.out_valid`: `x = sign_extend_26(out)`; `out_first` → `S = x`, else `S = S + x` (27-bit sum, result outside signed26 → `acc_ovf_q` pulse). `out_first` only acts on a valid token. On `out_last` (no overflow): `acc_done_q` pulses the next clock with `S` already containing the last sample; `u_normalize.start = acc_done_q`.
  - _VI:_ Accumulator khi `u_cordic.out_valid`: `x = sign_extend_26(out)`; `out_first` → `S = x`, ngược lại `S = S + x` (tổng 27 bit, kết quả ra ngoài signed26 → xung `acc_ovf_q`). `out_first` chỉ tác dụng với token hợp lệ. Khi `out_last` (không tràn): `acc_done_q` lên một xung ở clock sau với `S` đã gồm sample cuối; `u_normalize.start = acc_done_q`.
- Glue: `num_err = u_cordic.ovf_err | acc_ovf_q | u_normalize.sat_err`; `d_n_re = n_re`; `d_valid`, `d_i`, `d_q` come directly from `u_normalize`.
  - _VI:_ Glue: `num_err = u_cordic.ovf_err | acc_ovf_q | u_normalize.sat_err`; `d_n_re = n_re`; `d_valid`, `d_i`, `d_q` lấy thẳng từ `u_normalize`.
- `txn_clr` clears the join register, accumulator, pulses and both children (priority over capture/accumulate).
  - _VI:_ `txn_clr` xóa join register, accumulator, các xung và cả hai module con (ưu tiên hơn capture/tích lũy).

## Reset

All valids, pulses, join register and accumulator = 0.

_VI:_ Mọi valid, xung, join register và accumulator = 0.
