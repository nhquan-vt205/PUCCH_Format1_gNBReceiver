# pucch_f1_gold_gen – Specification / Đặc tả
Type: leaf · Parent: `pucch_f1_lowpapr_phase_gen` · Level: L2

## Function / Chức năng

Length-31 Gold sequence generator (TS 38.211 §5.2.1, source 03 §4). On `start` it initializes `x1 = 1` (bit 0 only) and `x2 = c_init`, runs 1600 warm-up steps, then outputs `c(t)` for `t = 0, 1, 2 …` one bit per clock with its index. Instantiated twice by the parent.

_VI:_ Bộ sinh chuỗi Gold độ dài 31 (TS 38.211 §5.2.1, source 03 §4). Khi `start`, khởi tạo `x1 = 1` (chỉ bit 0) và `x2 = c_init`, chạy 1600 bước warm-up, rồi xuất `c(t)` với `t = 0, 1, 2 …` mỗi clock một bit kèm chỉ số. Được module cha instance hai lần.

## Interface

| Port name | Direction | Width | Type | Connects to | Description |
| --- | --- | --- | --- | --- | --- |
| `clk` | in | 1 | CLK/RST | `pucch_f1_lowpapr_phase_gen.clk` | Clock |
| `rst_n` | in | 1 | CLK/RST | `pucch_f1_lowpapr_phase_gen.rst_n` | Sync active-low reset |
| `start` | in | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.txn_start` | Load init, begin warm-up |
| `clr` | in | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.txn_clr` | Stop and clear (priority over `start`) |
| `c_init` | in | 31 | DATA | `pucch_f1_lowpapr_phase_gen` (glue: `u_gold_gh`: `{21'b0, n_id / 30}`; `u_gold_cs`: `{21'b0, n_id}`) | Initial value of x2 |
| `c_valid` | out | 1 | CTRL | `pucch_f1_lowpapr_phase_gen` (internal: Gold bit capture logic) | `c_bit` valid |
| `c_bit` | out | 1 | DATA | `pucch_f1_lowpapr_phase_gen` (internal: Gold bit capture logic) | c(t) |
| `c_idx` | out | 12 | DATA | `pucch_f1_lowpapr_phase_gen` (internal: Gold bit capture logic) | t, 0..4095 |

## Structure / Cấu trúc

| Register | Width | Role |
| --- | --- | --- |
| `x1_q` | 31 | `x1(t) .. x1(t+30)`, bit k = x1(t+k) |
| `x2_q` | 31 | `x2(t) .. x2(t+30)` |
| `warm_cnt_q` | 11 | Warm-up steps done, 0..1600 |
| `c_idx_q` | 12 | Output index t |
| `run_q`, `out_q` | 1, 1 | Running; output phase |

## Behavior / Hành vi

- Each running clock shifts both registers right by one: new bit 30 of `x1` = `x1[3] ^ x1[0]`; new bit 30 of `x2` = `x2[3] ^ x2[2] ^ x2[1] ^ x2[0]`.
  - _VI:_ Mỗi clock khi chạy, dịch phải cả hai thanh ghi một bit: bit 30 mới của `x1` = `x1[3] ^ x1[0]`; bit 30 mới của `x2` = `x2[3] ^ x2[2] ^ x2[1] ^ x2[0]`.
- After exactly 1600 shifts, `c_valid = 1`, `c_bit = x1_q[0] ^ x2_q[0]` (= c(t), t = `c_idx`), and every following clock shifts once and increments `c_idx`.
  - _VI:_ Sau đúng 1600 lần dịch, `c_valid = 1`, `c_bit = x1_q[0] ^ x2_q[0]` (= c(t), t = `c_idx`), và mỗi clock sau đó dịch một lần và tăng `c_idx`.
- Output stops (`c_valid = 0`, `run_q = 0`) after `c_idx == 4095` or on `clr`. The parent needs at most t = 2239.
  - _VI:_ Ngừng xuất (`c_valid = 0`, `run_q = 0`) sau `c_idx == 4095` hoặc khi `clr`. Module cha cần tối đa t = 2239.
- The PRBS is reinitialized on every `start`; never reset per data symbol.
  - _VI:_ PRBS được khởi tạo lại ở mỗi `start`; không reset theo từng data symbol.

## Reset

All registers 0, `c_valid = 0`.

_VI:_ Mọi thanh ghi bằng 0, `c_valid = 0`.
