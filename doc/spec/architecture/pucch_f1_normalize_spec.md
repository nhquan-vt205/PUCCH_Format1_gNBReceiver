# pucch_f1_normalize – Specification / Đặc tả
Type: leaf · Parent: `pucch_f1_rx_inverse` · Level: L2

## Function / Chức năng

Once per transaction: corrects the CORDIC gain of the sum `S` and divides by `N_RE`, with two separate RNE steps in this order (source 03 §8), and presents `d_rx` on a valid/ready stream.

_VI:_ Một lần mỗi transaction: bù gain CORDIC của tổng `S` và chia cho `N_RE`, với hai bước RNE riêng theo đúng thứ tự (source 03 §8), và đưa `d_rx` ra stream valid/ready.

```text
P = S * 652032874            // KINV_Q30, signed 26 x 31 -> signed57, full precision
Z = RNE_div(P, 2^30)         // signed26 F15, saturation -> sat_err
d = RNE_div(Z, n_re)         // signed26 F15, saturation -> sat_err
```

`RNE_div(P, D)`, D > 0: `a = |P|`, `v = a / D`, `r = a % D`; `v += 1` if `2r > D` or (`2r == D` and `v` odd); result `−v` if `P < 0`; 0 → 0.

_VI:_ `RNE_div(P, D)`, D > 0: `a = |P|`, `v = a / D`, `r = a % D`; `v += 1` nếu `2r > D` hoặc (`2r == D` và `v` lẻ); kết quả `−v` nếu `P < 0`; 0 → 0.

## Interface

| Port name | Direction | Width | Type | Connects to | Description |
| --- | --- | --- | --- | --- | --- |
| `clk` | in | 1 | CLK/RST | `pucch_f1_rx_inverse.clk` | Clock |
| `rst_n` | in | 1 | CLK/RST | `pucch_f1_rx_inverse.rst_n` | Sync active-low reset |
| `clr` | in | 1 | CTRL | `pucch_f1_rx_inverse.txn_clr` | Abort, back to IDLE |
| `start` | in | 1 | CTRL | `pucch_f1_rx_inverse` (internal: `acc_done_q`) | Start with current S |
| `s_i` | in | 26 | DATA | `pucch_f1_rx_inverse` (internal: accumulator `s_i_q`) | S I, signed F15 |
| `s_q` | in | 26 | DATA | `pucch_f1_rx_inverse` (internal: accumulator `s_q_q`) | S Q, signed F15 |
| `n_re` | in | 7 | DATA | `pucch_f1_rx_inverse.n_re` | Divisor N_RE (24..84) |
| `d_valid` | out | 1 | CTRL | `pucch_f1_rx_inverse.d_valid` | d_rx valid, held until `d_ready` |
| `d_ready` | in | 1 | CTRL | `pucch_f1_rx_inverse.d_ready` | d_rx ready |
| `d_i` | out | 26 | DATA | `pucch_f1_rx_inverse.d_i` | d_rx I, signed F15 |
| `d_q` | out | 26 | DATA | `pucch_f1_rx_inverse.d_q` | d_rx Q, signed F15 |
| `sat_err` | out | 1 | STATUS | `pucch_f1_rx_inverse` (glue: `num_err`) | 1-clock pulse: Z or d outside signed26 |

## Structure / Cấu trúc

| Register | Width | Role |
| --- | --- | --- |
| `state_q` | 2 | IDLE / DIV / ROUND / OUT |
| `z_neg_q[I,Q]` | 2 × 1 | Sign of Z |
| `a_q[I,Q]` | 2 × 26 | Remaining dividend bits (|Z|) |
| `rem_q[I,Q]` | 2 × 8 | Partial remainder (< N_RE ≤ 84) |
| `quo_q[I,Q]` | 2 × 26 | Quotient |
| `cnt_q` | 5 | Divider iteration 0..25 |
| `d_i_q`, `d_q_q`, `d_valid_q` | 26, 26, 1 | Output stream register |

Datapath: one 26 × 31 signed multiplier per lane (I, Q in parallel), constant RNE by 2^30, two restoring dividers (1 quotient bit per clock, 26 iterations) in parallel.

_VI:_ Datapath: mỗi lane (I, Q song song) một bộ nhân signed 26 × 31, RNE hằng chia 2^30, hai bộ chia restoring (1 bit thương mỗi clock, 26 iteration) song song.

## Behavior / Hành vi

| From | To | Condition | Action |
| --- | --- | --- | --- |
| IDLE | DIV | `start` and Z in signed26 | Compute P, Z for I and Q; load `|Z|`, sign, `cnt=0`, `rem=0` |
| IDLE | IDLE | `start` and Z outside signed26 | `sat_err` pulse |
| DIV | DIV | `cnt < 25` | One restoring step per lane, `cnt += 1` |
| DIV | ROUND | `cnt == 25` | Last step |
| ROUND | OUT | always | RNE increment (`2·rem > n_re`, or `== n_re` and quotient odd), apply sign, register `d_i/d_q`, `d_valid=1` (saturation check → `sat_err`, back to IDLE) |
| OUT | IDLE | `d_ready` | `d_valid = 0` |

Latency `start` → `d_valid`: 28 clocks (≤ 64 required). Saturation cannot occur for legal inputs (|Z| ≤ |S|, |d| ≤ |Z|) but is checked as required by source 03 §8. `clr` has priority in every state.

_VI:_ Latency `start` → `d_valid`: 28 clock (yêu cầu ≤ 64). Bão hòa không thể xảy ra với input hợp lệ (|Z| ≤ |S|, |d| ≤ |Z|) nhưng vẫn được kiểm tra theo source 03 §8. `clr` ưu tiên ở mọi trạng thái.

## Reset

`state_q = IDLE`, `d_valid = 0`, `sat_err = 0`.

_VI:_ `state_q = IDLE`, `d_valid = 0`, `sat_err = 0`.
