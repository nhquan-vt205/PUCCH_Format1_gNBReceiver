# pucch_f1_ctrl – Specification / Đặc tả
Type: leaf · Parent: `pucch_f1_rx_core` · Level: L2

## Function / Chức năng

Transaction controller: captures the config snapshot, validates it, derives `N_SF0/N_SF1/N_RE`, runs the transaction FSM, joins the phase and data streams (ready generation), checks RE tags/markers against `q_expected`, latches the first error, and drives the result record (MLE payload or error record).

_VI:_ Controller transaction: capture snapshot config, kiểm tra hợp lệ, suy ra `N_SF0/N_SF1/N_RE`, chạy FSM transaction, ghép stream pha và stream dữ liệu (tạo ready), kiểm tra tag/marker RE so với `q_expected`, chốt lỗi đầu tiên, và lái result record (payload MLE hoặc error record).

## Interface

See `doc/spec/interface/pucch_f1_ctrl_interface.md`.

_VI:_ Xem `doc/spec/interface/pucch_f1_ctrl_interface.md`.

## Structure / Cấu trúc

| Register | Width | Role |
| --- | --- | --- |
| `state_q` | 3 | FSM state (8 states) |
| Snapshot `m_bit_q`, `nsymb_q`, `start_symbol_q`, `hopping_q`, `gh_mode_q`, `n_id_q`, `m0_q`, `occ_i_q`, `slot_idx_q` | 2/4/4/1/2/10/4/3/5 | Captured on `cfg_valid && cfg_ready` |
| `q_expected_q` | 7 | Expected RE index, advances on `join_fire` |
| `err_q`, `err_code_q` | 1, 4 | First error latched, held to REPORT |

Derived (combinational from snapshot): `n_data = nsymb_q >> 1`; hopping: `n_sf0 = n_data >> 1`, `n_sf1 = n_data − n_sf0`; no hopping: `n_sf0 = n_data`, `n_sf1 = 0`; `n_re = 12 · n_data`. This equals the table in source 05 §5 (24/36/48/60/72/84).

_VI:_ Suy ra (tổ hợp từ snapshot): `n_data = nsymb_q >> 1`; có hopping: `n_sf0 = n_data >> 1`, `n_sf1 = n_data − n_sf0`; không hopping: `n_sf0 = n_data`, `n_sf1 = 0`; `n_re = 12 · n_data`. Bằng bảng ở source 05 §5 (24/36/48/60/72/84).

Validation (combinational from snapshot, used in VALIDATE):

_VI:_ Kiểm tra hợp lệ (tổ hợp từ snapshot, dùng trong VALIDATE):

| Check | Error code |
| --- | --- |
| `m_bit ∉ {1,2}`, `nsymb ∉ 4..14`, `start_symbol > 10`, `start_symbol + nsymb > 14` (5-bit sum), `gh_mode == 3`, `m0 > 11`, `slot_idx > 19` | 1 CFG_RANGE |
| No range error and (`occ_i ≥ n_sf0` or (`hopping` and `occ_i ≥ n_sf1`)) | 2 CFG_OCC |

## Behavior / Hành vi

| From | To | Condition | Action |
| --- | --- | --- | --- |
| IDLE | VALIDATE | `cfg_valid` (`cfg_ready=1`) | Capture snapshot; clear `err_q`, `q_expected_q` |
| VALIDATE | REPORT | range or OCC error | Latch code 1 or 2 (range first) |
| VALIDATE | PREPARE | legal config | `txn_start=1` this clock |
| PREPARE | RECEIVE | `gen_ready && tbl_valid` | – |
| RECEIVE | DRAIN | `join_fire` with `q_expected == n_re−1` and no error | – |
| DRAIN | NORMALIZE | `acc_done` | – |
| NORMALIZE | DETECT | `d_valid && d_ready` | – |
| DETECT | REPORT | `mle_valid` | – |
| REPORT | IDLE | `res_ready` | `txn_clr=1` this clock |
| PREPARE..DETECT | REPORT | error event (below) | Latch code, `txn_clr=1` this clock |
| any | IDLE | `rst_n == 0` | Clear all registers |

Outputs: `cfg_ready = (state==IDLE)`, `busy = (state!=IDLE)`, `res_valid = (state==REPORT)`, `y_ready = RECEIVE && phase_valid`, `phase_ready = RECEIVE && y_valid`, `join_fire = RECEIVE && y_valid && phase_valid` (phase and data always transfer on the same edge; the join register in `pucch_f1_rx_inverse` always has room because the CORDIC never stalls). `q_expected_q` increments on each `join_fire` without error.

_VI:_ Output: `cfg_ready = (state==IDLE)`, `busy = (state!=IDLE)`, `res_valid = (state==REPORT)`, `y_ready = RECEIVE && phase_valid`, `phase_ready = RECEIVE && y_valid`, `join_fire = RECEIVE && y_valid && phase_valid` (pha và dữ liệu luôn transfer cùng một sườn; join register trong `pucch_f1_rx_inverse` luôn còn chỗ vì CORDIC không bao giờ stall). `q_expected_q` tăng ở mỗi `join_fire` không lỗi.

Error events (states PREPARE..DETECT), priority on the same edge (highest first), only the first error is latched:

_VI:_ Sự kiện lỗi (trạng thái PREPARE..DETECT), ưu tiên trong cùng một sườn (cao nhất trước), chỉ chốt lỗi đầu tiên:

| Priority | Condition | Code |
| --- | --- | --- |
| 1 | `cand_err`, `lut_err`, or at `join_fire`: `occ_err`, `phase_sample_q != q_expected`, `phase_first != (q_expected==0)`, `phase_last != (q_expected==n_re−1)` | 6 INTERNAL_ALIGN |
| 2 | at `join_fire`: `y_sample_q != q_expected` | 3 SAMPLE_ORDER |
| 3 | at `join_fire`: `y_first != (q_expected==0)` or `y_last != (q_expected==n_re−1)` | 4 SAMPLE_MARKER |
| 4 | `num_err` | 5 NUMERIC |

Result record (combinational from registers): `res_error = err_q`, `res_error_code = err_code_q`, `res_m_bit = m_bit_q`; all other payload = `err_q ? 0 : mle_*`. Payload is stable during REPORT (all sources are registers). `txn_clr` is the single flush to all blocks (error abort and end of transaction) and has priority over every other action in those blocks.

_VI:_ Result record (tổ hợp từ thanh ghi): `res_error = err_q`, `res_error_code = err_code_q`, `res_m_bit = m_bit_q`; mọi payload khác = `err_q ? 0 : mle_*`. Payload ổn định trong REPORT (mọi nguồn là thanh ghi). `txn_clr` là tín hiệu flush duy nhất tới mọi khối (abort do lỗi và kết thúc transaction) và ưu tiên hơn mọi hành động khác trong các khối đó.

## Reset

`state_q = IDLE`; snapshot, `q_expected_q`, `err_q`, `err_code_q` = 0.

_VI:_ `state_q = IDLE`; snapshot, `q_expected_q`, `err_q`, `err_code_q` = 0.
