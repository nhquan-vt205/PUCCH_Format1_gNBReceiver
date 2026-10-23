# pucch_f1_mod_candidates – Specification / Đặc tả
Type: leaf · Parent: `pucch_f1_rx_core` · Level: L2

## Function / Chức năng

On `txn_start`, enumerates all bit combinations for `M_bit` and presents the candidate table `d_k(0)` (I/Q, phase, packed bits, mask) as one parallel transfer (source 03 §3, 04 §7). It uses only `M_bit`: no OCC, `u`, cyclic shift or RE count.

_VI:_ Khi `txn_start`, liệt kê mọi tổ hợp bit theo `M_bit` và đưa bảng candidate `d_k(0)` (I/Q, pha, bit đóng gói, mask) ra trong một transfer song song (source 03 §3, 04 §7). Chỉ dùng `M_bit`: không dùng OCC, `u`, cyclic shift hay số RE.

## Interface

Arrays of input 04 §7 are flattened: entry `k` of `cand_i/cand_q/cand_phase` is bits `[16k+15:16k]`, of `cand_bits` is bits `[2k+1:2k]`.

_VI:_ Mảng ở input 04 §7 được flatten: entry `k` của `cand_i/cand_q/cand_phase` là bit `[16k+15:16k]`, của `cand_bits` là bit `[2k+1:2k]`.

| Port name | Direction | Width | Type | Connects to | Description |
| --- | --- | --- | --- | --- | --- |
| `clk` | in | 1 | CLK/RST | `pucch_f1_rx_core.clk` | Clock |
| `rst_n` | in | 1 | CLK/RST | `pucch_f1_rx_core.rst_n` | Sync active-low reset |
| `txn_start` | in | 1 | CTRL | `pucch_f1_ctrl.txn_start` | Build table |
| `txn_clr` | in | 1 | CTRL | `pucch_f1_ctrl.txn_clr` | Drop table |
| `m_bit` | in | 2 | DATA | `pucch_f1_ctrl.m_bit` | 1 or 2 |
| `cand_valid` | out | 1 | CTRL | `pucch_f1_scalar_mle.cand_valid` | Table valid |
| `cand_ready` | in | 1 | CTRL | `pucch_f1_scalar_mle.cand_ready` | Table ready |
| `cand_mask` | out | 4 | DATA | `pucch_f1_scalar_mle.cand_mask` | `4'b0011` (M_bit=1) / `4'b1111` (M_bit=2) |
| `cand_m_bit` | out | 2 | DATA | `pucch_f1_scalar_mle.cand_m_bit` | Copy of `m_bit` |
| `cand_i` | out | 64 | DATA | `pucch_f1_scalar_mle.cand_i` | 4 × signed16 F15 |
| `cand_q` | out | 64 | DATA | `pucch_f1_scalar_mle.cand_q` | 4 × signed16 F15 |
| `cand_phase` | out | 64 | DATA | open (debug/reference, input 03 §3) | 4 × unsigned16 phase |
| `cand_bits` | out | 8 | DATA | `pucch_f1_scalar_mle.cand_bits` | 4 × packed `{b1, b0}` |

## Structure / Cấu trúc

Registers: `cand_valid_q`, `m_bit_q` (2). Table outputs are combinational constants selected by `m_bit_q`:

_VI:_ Thanh ghi: `cand_valid_q`, `m_bit_q` (2). Output bảng là hằng tổ hợp chọn theo `m_bit_q`:

| M_bit | k | b0 | b1 | cand_bits[k] | cand_phase[k] | cand_i[k] | cand_q[k] |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0 | 0 | 2'b00 | 16'h2000 | +23170 | +23170 |
| 1 | 1 | 1 | 0 | 2'b01 | 16'hA000 | −23170 | −23170 |
| 2 | 0 | 0 | 0 | 2'b00 | 16'h2000 | +23170 | +23170 |
| 2 | 1 | 0 | 1 | 2'b10 | 16'hE000 | +23170 | −23170 |
| 2 | 2 | 1 | 0 | 2'b01 | 16'h6000 | −23170 | +23170 |
| 2 | 3 | 1 | 1 | 2'b11 | 16'hA000 | −23170 | −23170 |

Inactive entries (k = 2, 3 when M_bit = 1) are all 0. `cand_bits[k]` is the packed UCI (`[0]=b0`, `[1]=b1`), not the binary value of `k`.

_VI:_ Entry không hoạt động (k = 2, 3 khi M_bit = 1) đều bằng 0. `cand_bits[k]` là UCI đóng gói (`[0]=b0`, `[1]=b1`), không phải giá trị nhị phân của `k`.

## Behavior / Hành vi

- `txn_start`: `m_bit_q = m_bit`, `cand_valid_q = 1`.
  - _VI:_ `txn_start`: `m_bit_q = m_bit`, `cand_valid_q = 1`.
- `cand_valid && cand_ready`: `cand_valid_q = 0` (one table transfer per transaction).
  - _VI:_ `cand_valid && cand_ready`: `cand_valid_q = 0` (một lần transfer bảng mỗi transaction).
- `txn_clr` (priority): `cand_valid_q = 0`.
  - _VI:_ `txn_clr` (ưu tiên): `cand_valid_q = 0`.

## Reset

`cand_valid_q = 0`, `m_bit_q = 0`.

_VI:_ `cand_valid_q = 0`, `m_bit_q = 0`.
