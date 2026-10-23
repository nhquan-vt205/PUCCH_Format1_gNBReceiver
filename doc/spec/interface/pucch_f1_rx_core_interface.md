# pucch_f1_rx_core – Interface

External interface of the core (input 04 §1–§4). Port names are exactly as in the input. All signals are synchronous to `clk` (rising edge). Transfer = `valid && ready`; producers hold valid and payload while `ready=0`.

_VI:_ Interface ngoài của core (input 04 §1–§4). Tên port đúng như input. Mọi tín hiệu đồng bộ với `clk` (sườn lên). Transfer = `valid && ready`; producer giữ valid và payload khi `ready=0`.

| Port name | Direction | Width | Type | Connects to | Description |
| --- | --- | --- | --- | --- | --- |
| `clk` | in | 1 | CLK/RST | external | Clock, rising edge |
| `rst_n` | in | 1 | CLK/RST | external | Synchronous active-low reset |
| `cfg_valid` | in | 1 | CTRL | external | Config valid |
| `cfg_ready` | out | 1 | CTRL | external | 1 only in IDLE |
| `busy` | out | 1 | STATUS | external | 1 from after config handshake until after result handshake |
| `cfg_m_bit` | in | 2 | DATA | external | Number of UCI bits; legal 1, 2 |
| `cfg_nsymb` | in | 4 | DATA | external | PUCCH duration L; legal 4..14 |
| `cfg_start_symbol` | in | 4 | DATA | external | Start symbol; legal 0..10 and start+nsymb ≤ 14 |
| `cfg_intra_slot_hopping` | in | 1 | DATA | external | 1 = intra-slot hopping |
| `cfg_group_hopping_mode` | in | 2 | DATA | external | 0 neither, 1 enable, 2 disable, 3 invalid |
| `cfg_n_id` | in | 10 | DATA | external | Effective hoppingId / cell ID, 0..1023 |
| `cfg_m0` | in | 4 | DATA | external | Initial cyclic shift; legal 0..11 |
| `cfg_occ_i` | in | 3 | DATA | external | OCC index; legal < N_SF of every active hop |
| `cfg_slot_idx` | in | 5 | DATA | external | Slot in frame; legal 0..19 |
| `y_valid` | in | 1 | CTRL | external | RE valid |
| `y_ready` | out | 1 | CTRL | external | RE ready (RECEIVE and phase available only) |
| `y_i` | in | 16 | DATA | external | Y_hat in-phase, signed F15 |
| `y_q` | in | 16 | DATA | external | Y_hat quadrature, signed F15 |
| `y_sample_q` | in | 7 | DATA | external | RE index q, 0..N_RE-1 |
| `y_first` | in | 1 | CTRL | external | 1 only at q = 0 |
| `y_last` | in | 1 | CTRL | external | 1 only at q = N_RE-1 |
| `res_valid` | out | 1 | CTRL | external | Result record valid (success or error), held until `res_ready` |
| `res_ready` | in | 1 | CTRL | external | Consumer ready |
| `res_error` | out | 1 | STATUS | external | 1 = error record |
| `res_error_code` | out | 4 | STATUS | external | 0 NONE, 1 CFG_RANGE, 2 CFG_OCC, 3 SAMPLE_ORDER, 4 SAMPLE_MARKER, 5 NUMERIC, 6 INTERNAL_ALIGN |
| `res_m_bit` | out | 2 | DATA | external | Captured `cfg_m_bit` (raw, also for error records) |
| `res_candidate_idx` | out | 2 | DATA | external | Winning k; 0 on error |
| `res_uci_bits` | out | 2 | DATA | external | [0]=b(0), [1]=b(1); [1]=0 when M_bit=1; 0 on error |
| `res_d_rx_i` | out | 26 | DATA | external | d_rx I, signed F15; 0 on error |
| `res_d_rx_q` | out | 26 | DATA | external | d_rx Q, signed F15; 0 on error |
| `res_metric_best` | out | 43 | DATA | external | Best metric, signed F30; 0 on error |
| `res_metric_second` | out | 43 | DATA | external | Runner-up metric, signed F30; 0 on error |
| `res_metric_gap` | out | 44 | DATA | external | best − second, unsigned F30; 0 on error |

## Protocol rules / Quy tắc giao thức

- `cfg_ready=1` only in IDLE; no config is accepted on the same edge as the result handshake (the next edge at the earliest).
  - _VI:_ `cfg_ready=1` chỉ trong IDLE; không nhận config ở cùng sườn với handshake result (sớm nhất là sườn kế tiếp).
- RE order: data symbol ascending (hop0 before hop1), subcarrier n = 0..11 fastest; no DM-RS. Gaps are allowed and do not advance counters. After the accepted last RE no further RE is accepted for that transaction.
  - _VI:_ Thứ tự RE: data symbol tăng dần (hop0 trước hop1), subcarrier n = 0..11 chạy nhanh nhất; không có DM-RS. Cho phép gap và gap không tiến counter. Sau RE cuối đã nhận, không nhận thêm RE cho transaction đó.
- Result fields are meaningful only when `res_valid=1`; UCI and metrics only when `res_error=0`. The record is stable until `res_valid && res_ready`.
  - _VI:_ Các field result chỉ có nghĩa khi `res_valid=1`; UCI và metric chỉ khi `res_error=0`. Record ổn định đến khi `res_valid && res_ready`.
- After an error the upstream source must drop the rest of the stream of that transaction and restart with a new config. No timeout exists for missing REs or consumer stall.
  - _VI:_ Sau lỗi, nguồn upstream phải bỏ phần stream còn lại của transaction đó và bắt đầu lại với config mới. Không có timeout cho RE thiếu hay consumer stall.
