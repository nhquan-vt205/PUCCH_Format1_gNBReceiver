# pucch_f1_cordic – Specification / Đặc tả
Type: leaf · Parent: `pucch_f1_rx_inverse` · Level: L1

## Function / Chức năng

Bit-exact full-circle rotation CORDIC (source 03 §7): rotates the input vector (signed16 F15) by `in_phase` (unsigned 16-bit, 1 turn = 65536) using quadrant pre-rotation and 16 micro-rotations, without gain compensation (output gain A16 ≈ 1.64676). Output signed18 F15. Fully pipelined, one token per clock, tags carried with each token.

_VI:_ CORDIC quay full-circle bit-exact (source 03 §7): quay vector đầu vào (signed16 F15) một góc `in_phase` (unsigned 16 bit, 1 vòng = 65536) bằng pre-rotation theo góc phần tư và 16 micro-rotation, không bù gain (gain output A16 ≈ 1.64676). Output signed18 F15. Pipeline hoàn toàn, mỗi clock một token, tag đi kèm từng token.

## Interface

| Port name | Direction | Width | Type | Connects to | Description |
| --- | --- | --- | --- | --- | --- |
| `clk` | in | 1 | CLK/RST | `pucch_f1_rx_inverse.clk` | Clock |
| `rst_n` | in | 1 | CLK/RST | `pucch_f1_rx_inverse.rst_n` | Sync active-low reset |
| `clr` | in | 1 | CTRL | `pucch_f1_rx_inverse.txn_clr` | Clear all stage valids |
| `in_valid` | in | 1 | CTRL | `pucch_f1_rx_inverse` (internal: join register `j_valid_q`) | Token valid |
| `in_i` | in | 16 | DATA | `pucch_f1_rx_inverse` (internal: join register `j_i_q`) | I, signed F15 |
| `in_q` | in | 16 | DATA | `pucch_f1_rx_inverse` (internal: join register `j_q_q`) | Q, signed F15 |
| `in_phase` | in | 16 | DATA | `pucch_f1_rx_inverse` (internal: join register `j_phase_q`) | Rotation angle, unsigned |
| `in_sample_q` | in | 7 | DATA | `pucch_f1_rx_inverse` (internal: join register `j_sample_q_q`) | Tag q |
| `in_first` | in | 1 | CTRL | `pucch_f1_rx_inverse` (internal: join register `j_first_q`) | Tag first |
| `in_last` | in | 1 | CTRL | `pucch_f1_rx_inverse` (internal: join register `j_last_q`) | Tag last |
| `out_valid` | out | 1 | CTRL | `pucch_f1_rx_inverse` (internal: accumulator) | Token valid |
| `out_i` | out | 18 | DATA | `pucch_f1_rx_inverse` (internal: accumulator) | I, signed F15, gain A16 |
| `out_q` | out | 18 | DATA | `pucch_f1_rx_inverse` (internal: accumulator) | Q, signed F15, gain A16 |
| `out_sample_q` | out | 7 | DATA | `pucch_f1_rx_inverse` (internal: accumulator, debug) | Tag q |
| `out_first` | out | 1 | CTRL | `pucch_f1_rx_inverse` (internal: accumulator) | Tag first |
| `out_last` | out | 1 | CTRL | `pucch_f1_rx_inverse` (internal: accumulator) | Tag last |
| `ovf_err` | out | 1 | STATUS | `pucch_f1_rx_inverse` (glue: `num_err`) | Pulse with an output token that overflowed or saturated |

## Structure / Cấu trúc

| Element | Width | Role |
| --- | --- | --- |
| Stage 0 register (x, y, z, tags, valid) | 24, 24, 24, … | Pre-rotated input |
| Stage 1..16 registers (x, y, z, ovf, tags, valid) | 24, 24, 24, 1, … | After micro-rotation j = stage − 1 (generate loop) |
| Output register (`out_*`, `ovf_err`) | 18, 18, … | RNE /64 and saturation |
| ATAN24 ROM | 16 × 24 | `RNE(atan(2^−j)/(2π)·2^24)`, source 07 §7 |

## Behavior / Hành vi

Stage 0 (combinational from `in_*`, registered): `x = sign_extend_24(in_i) << 6`, `y = sign_extend_24(in_q) << 6` (F21); `z = signed24({in_phase, 8'b0})`. Pre-rotation in signed25: if `z > 2^22`: `x = −x`, `y = −y`, `z = z − 2^23`; else if `z < −2^22`: `x = −x`, `y = −y`, `z = z + 2^23`; result narrowed to signed24 (z ∈ [−2^22, 2^22]). Only one pre-rotation.

_VI:_ Stage 0 (tổ hợp từ `in_*`, rồi đăng ký): `x = sign_extend_24(in_i) << 6`, `y = sign_extend_24(in_q) << 6` (F21); `z = signed24({in_phase, 8'b0})`. Pre-rotation trong signed25: nếu `z > 2^22`: `x = −x`, `y = −y`, `z = z − 2^23`; ngược lại nếu `z < −2^22`: `x = −x`, `y = −y`, `z = z + 2^23`; kết quả thu về signed24 (z ∈ [−2^22, 2^22]). Chỉ pre-rotate một lần.

Stage j+1 (j = 0..15), using the old x, y, z of stage j:

_VI:_ Stage j+1 (j = 0..15), dùng x, y, z cũ của stage j:

```text
dir    = (z >= 0) ? +1 : -1
x_next = x - dir * (y >>> j)        // signed25 temporary
y_next = y + dir * (x >>> j)        // signed25 temporary
z_next = z - dir * ATAN24[j]        // signed24
ovf    = ovf_prev | (x_next or y_next outside signed24)
```

`>>>` is an arithmetic right shift; no rounding per iteration.

_VI:_ `>>>` là dịch phải số học; không làm tròn ở mỗi iteration.

Output stage: `out = RNE(x16 / 64)` for x and y: `a = |x|`, `v = a >> 6`, `r = a & 63`, `v += 1` if `r > 32` or (`r == 32` and `v` odd), negate if `x < 0`; saturate to signed18 (only +131072 can exceed). `ovf_err = out_valid && (ovf || saturation)`.

_VI:_ Stage output: `out = RNE(x16 / 64)` cho x và y: `a = |x|`, `v = a >> 6`, `r = a & 63`, `v += 1` nếu `r > 32` hoặc (`r == 32` và `v` lẻ), đổi dấu nếu `x < 0`; bão hòa về signed18 (chỉ +131072 có thể vượt). `ovf_err = out_valid && (ovf || saturation)`.

Timing: a token on `in_*` at clock T−1 (join register) is in stage 0 after edge T, stage 16 after edge T+16, output register after edge T+17 (source 02 §6). The pipeline advances every clock; `clr` clears all valids.

_VI:_ Thời gian: token trên `in_*` ở clock T−1 (join register) vào stage 0 sau sườn T, stage 16 sau sườn T+16, thanh ghi output sau sườn T+17 (source 02 §6). Pipeline tiến mỗi clock; `clr` xóa mọi valid.

## Reset

All stage valids, `out_valid`, `ovf_err` = 0 (datapath registers need no reset).

_VI:_ Mọi valid của stage, `out_valid`, `ovf_err` = 0 (thanh ghi datapath không cần reset).
