# pucch_f1_scalar_mle – Specification / Đặc tả
Type: leaf · Parent: `pucch_f1_rx_core` · Level: L2

## Function / Chức năng

Captures the candidate table once per transaction, then the scalar `d_rx`; computes the exact metric `M_k = d_i·cand_i[k] + d_q·cand_q[k]` (products signed42, sum signed43, F30) for every active `k`, ranks by (metric descending, `k` ascending), and holds the result: winning `k`, its packed bits, `d_rx`, best and runner-up metrics and their gap (source 03 §9).

_VI:_ Capture bảng candidate một lần mỗi transaction, rồi capture scalar `d_rx`; tính metric chính xác `M_k = d_i·cand_i[k] + d_q·cand_q[k]` (tích signed42, tổng signed43, F30) cho mọi `k` đang hoạt động, xếp hạng theo (metric giảm dần, `k` tăng dần), và giữ kết quả: `k` thắng, bit đóng gói của nó, `d_rx`, metric best và runner-up cùng gap (source 03 §9).

## Interface

| Port name | Direction | Width | Type | Connects to | Description |
| --- | --- | --- | --- | --- | --- |
| `clk` | in | 1 | CLK/RST | `pucch_f1_rx_core.clk` | Clock |
| `rst_n` | in | 1 | CLK/RST | `pucch_f1_rx_core.rst_n` | Sync active-low reset |
| `txn_clr` | in | 1 | CTRL | `pucch_f1_ctrl.txn_clr` | Drop table, scalar and result |
| `m_bit` | in | 2 | DATA | `pucch_f1_ctrl.m_bit` | Snapshot M_bit (consistency check) |
| `cand_valid` | in | 1 | CTRL | `pucch_f1_mod_candidates.cand_valid` | Table valid |
| `cand_ready` | out | 1 | CTRL | `pucch_f1_mod_candidates.cand_ready` | `!tbl_valid` |
| `cand_mask` | in | 4 | DATA | `pucch_f1_mod_candidates.cand_mask` | Active entries |
| `cand_m_bit` | in | 2 | DATA | `pucch_f1_mod_candidates.cand_m_bit` | Table M_bit |
| `cand_i` | in | 64 | DATA | `pucch_f1_mod_candidates.cand_i` | 4 × signed16 F15 |
| `cand_q` | in | 64 | DATA | `pucch_f1_mod_candidates.cand_q` | 4 × signed16 F15 |
| `cand_bits` | in | 8 | DATA | `pucch_f1_mod_candidates.cand_bits` | 4 × packed bits |
| `tbl_valid` | out | 1 | STATUS | `pucch_f1_ctrl.tbl_valid` | Table captured |
| `cand_err` | out | 1 | STATUS | `pucch_f1_ctrl.cand_err` | 1-clock pulse: `cand_m_bit != m_bit` at table capture |
| `d_valid` | in | 1 | CTRL | `pucch_f1_rx_inverse.d_valid` | d_rx valid |
| `d_ready` | out | 1 | CTRL | `pucch_f1_ctrl.d_ready`, `pucch_f1_rx_inverse.d_ready` | `tbl_valid && !d_held && !mle_valid` |
| `d_i` | in | 26 | DATA | `pucch_f1_rx_inverse.d_i` | d_rx I, signed F15 |
| `d_q` | in | 26 | DATA | `pucch_f1_rx_inverse.d_q` | d_rx Q, signed F15 |
| `mle_valid` | out | 1 | STATUS | `pucch_f1_ctrl.mle_valid` | Result register full, held until `txn_clr` |
| `mle_candidate_idx` | out | 2 | DATA | `pucch_f1_ctrl.mle_candidate_idx` | Winning k |
| `mle_uci_bits` | out | 2 | DATA | `pucch_f1_ctrl.mle_uci_bits` | `cand_bits[k_best]` |
| `mle_d_rx_i` | out | 26 | DATA | `pucch_f1_ctrl.mle_d_rx_i` | Captured d_i |
| `mle_d_rx_q` | out | 26 | DATA | `pucch_f1_ctrl.mle_d_rx_q` | Captured d_q |
| `mle_metric_best` | out | 43 | DATA | `pucch_f1_ctrl.mle_metric_best` | signed F30 |
| `mle_metric_second` | out | 43 | DATA | `pucch_f1_ctrl.mle_metric_second` | signed F30 |
| `mle_metric_gap` | out | 44 | DATA | `pucch_f1_ctrl.mle_metric_gap` | best − second, unsigned F30 |

## Structure / Cấu trúc

| Register | Width | Role |
| --- | --- | --- |
| `tbl_valid_q`, `mask_q`, `ci_q`, `cq_q`, `bits_q` | 1, 4, 64, 64, 8 | Captured candidate table |
| `d_held_q`, `di_q`, `dq_q` | 1, 26, 26 | Captured scalar |
| `mle_valid_q` + result registers | 1, 2, 2, 26, 26, 43, 43, 44 | Result |

Combinational: 8 signed 26 × 16 multipliers (generic form; the ±23170 add/sub form is allowed if it gives the same exact signed43 metric), 4 metric adders, best/second selection.

_VI:_ Tổ hợp: 8 bộ nhân signed 26 × 16 (dạng tổng quát; được dùng dạng cộng/trừ ±23170 nếu cho cùng metric signed43 chính xác), 4 bộ cộng metric, chọn best/second.

## Behavior / Hành vi

- Table: on `cand_valid && cand_ready` capture the table, `tbl_valid_q = 1`; `cand_err` pulses the next clock if `cand_m_bit != m_bit`.
  - _VI:_ Bảng: khi `cand_valid && cand_ready` capture bảng, `tbl_valid_q = 1`; `cand_err` lên một xung ở clock sau nếu `cand_m_bit != m_bit`.
- Scalar: on `d_valid && d_ready` capture `d_i`, `d_q`, `d_held_q = 1`. A scalar is never compared with a table of another transaction (both are cleared by `txn_clr`).
  - _VI:_ Scalar: khi `d_valid && d_ready` capture `d_i`, `d_q`, `d_held_q = 1`. Scalar không bao giờ được so với bảng của transaction khác (cả hai bị xóa bởi `txn_clr`).
- Detect (clock after scalar capture): `M_k` for active `k`; `k_best` = largest metric, ties → smallest `k`; `k_second` = largest among the remaining active `k` with the same rule. Register `mle_candidate_idx = k_best`, `mle_uci_bits = bits_q[k_best]`, `mle_d_rx_* = d*_q`, `mle_metric_best = M[k_best]`, `mle_metric_second = M[k_second]`, `mle_metric_gap = M[k_best] − M[k_second]` (44-bit, ≥ 0); `mle_valid_q = 1`. Metrics may be negative: signed comparison only, no rounding.
  - _VI:_ Detect (clock sau khi capture scalar): `M_k` cho các `k` hoạt động; `k_best` = metric lớn nhất, bằng nhau → `k` nhỏ nhất; `k_second` = lớn nhất trong các `k` hoạt động còn lại theo cùng quy tắc. Đăng ký `mle_candidate_idx = k_best`, `mle_uci_bits = bits_q[k_best]`, `mle_d_rx_* = d*_q`, `mle_metric_best = M[k_best]`, `mle_metric_second = M[k_second]`, `mle_metric_gap = M[k_best] − M[k_second]` (44 bit, ≥ 0); `mle_valid_q = 1`. Metric có thể âm: chỉ so sánh có dấu, không làm tròn.
- No numeric error output: with these widths the products (|·| ≤ 2^40), sums (≤ 2^41) and gap (< 2^43) cannot overflow, so the "metric overflow" condition of source 04 §4 is unreachable by construction.
  - _VI:_ Không có output lỗi số: với các width này, tích (|·| ≤ 2^40), tổng (≤ 2^41) và gap (< 2^43) không thể tràn, nên điều kiện "metric overflow" ở source 04 §4 không thể xảy ra theo cấu trúc.
- `d_rx = 0` still selects candidate 0 by the tie rule; no DTX/confidence threshold.
  - _VI:_ `d_rx = 0` vẫn chọn candidate 0 theo quy tắc tie; không có ngưỡng DTX/confidence.
- `txn_clr` (priority) clears `tbl_valid_q`, `d_held_q`, `mle_valid_q` and the result registers.
  - _VI:_ `txn_clr` (ưu tiên) xóa `tbl_valid_q`, `d_held_q`, `mle_valid_q` và các thanh ghi kết quả.

## Reset

All valids and result registers = 0.

_VI:_ Mọi valid và thanh ghi kết quả = 0.
