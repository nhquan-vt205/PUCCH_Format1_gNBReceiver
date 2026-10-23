# pucch_f1_lowpapr_phase_gen – Specification / Đặc tả
Type: block · Parent: `pucch_f1_rx_core` · Level: L1

## Function / Chức năng

Computes, from the snapshot, the sequence group `u[h]` per hop (group hopping Gold) and the cyclic shift `s_l` per absolute symbol (cyclic-shift Gold), then streams one forward phase token per data RE `q = 0..N_RE−1`: `r_phase = (BASE[12·u[h]+n] + CS[t]) mod 65536` with its tags. OCC and modulation are not included. It owns the base ROM and the CS ROM.

_VI:_ Từ snapshot, tính sequence group `u[h]` cho từng hop (Gold group hopping) và cyclic shift `s_l` cho từng symbol tuyệt đối (Gold cyclic shift), rồi phát một token pha xuôi cho mỗi data RE `q = 0..N_RE−1`: `r_phase = (BASE[12·u[h]+n] + CS[t]) mod 65536` kèm tag. Không gồm OCC và modulation. Khối sở hữu base ROM và CS ROM.

## Interface

| Port name | Direction | Width | Type | Connects to | Description |
| --- | --- | --- | --- | --- | --- |
| `clk` | in | 1 | CLK/RST | `pucch_f1_rx_core.clk` | Clock |
| `rst_n` | in | 1 | CLK/RST | `pucch_f1_rx_core.rst_n` | Sync active-low reset |
| `txn_start` | in | 1 | CTRL | `pucch_f1_ctrl.txn_start` | Start PREPARE |
| `txn_clr` | in | 1 | CTRL | `pucch_f1_ctrl.txn_clr` | Flush to IDLE |
| `n_id` | in | 10 | DATA | `pucch_f1_ctrl.n_id` | n_ID |
| `gh_mode` | in | 2 | DATA | `pucch_f1_ctrl.gh_mode` | 0 neither, 1 enable, 2 disable |
| `slot_idx` | in | 5 | DATA | `pucch_f1_ctrl.slot_idx` | Slot 0..19 |
| `start_symbol` | in | 4 | DATA | `pucch_f1_ctrl.start_symbol` | Start symbol |
| `hopping` | in | 1 | DATA | `pucch_f1_ctrl.hopping` | Intra-slot hopping |
| `m0` | in | 4 | DATA | `pucch_f1_ctrl.m0` | Initial cyclic shift |
| `n_sf0` | in | 3 | DATA | `pucch_f1_ctrl.n_sf0` | Data symbols in hop0 |
| `n_re` | in | 7 | DATA | `pucch_f1_ctrl.n_re` | Total RE count |
| `gen_ready` | out | 1 | STATUS | `pucch_f1_ctrl.gen_ready` | 1 from end of PREPARE until `txn_clr` |
| `lut_err` | out | 1 | STATUS | `pucch_f1_ctrl.lut_err` | `phase_valid` with illegal base/CS address |
| `phase_valid` | out | 1 | CTRL | `pucch_f1_ctrl.phase_valid` | Phase token valid |
| `phase_ready` | in | 1 | CTRL | `pucch_f1_ctrl.phase_ready` | Phase token ready |
| `r_phase` | out | 16 | DATA | `pucch_f1_rx_inverse.r_phase` | base + CS phase, unsigned |
| `phase_sample_q` | out | 7 | DATA | `pucch_f1_ctrl.phase_sample_q`, `pucch_f1_rx_inverse.phase_sample_q` | Tag q |
| `phase_hop` | out | 1 | DATA | `pucch_f1_rx_inverse.phase_hop` | Tag h |
| `phase_m` | out | 3 | DATA | `pucch_f1_rx_inverse.phase_m` | Tag m (data symbol in hop) |
| `phase_n` | out | 4 | DATA | open (debug tag, input 04 §6) | Tag n (subcarrier) |
| `phase_l_abs` | out | 4 | DATA | open (debug tag, input 04 §6) | Tag l_abs |
| `phase_first` | out | 1 | CTRL | `pucch_f1_ctrl.phase_first`, `pucch_f1_rx_inverse.phase_first` | q == 0 |
| `phase_last` | out | 1 | CTRL | `pucch_f1_ctrl.phase_last`, `pucch_f1_rx_inverse.phase_last` | q == n_re−1 |

## Structure / Cấu trúc

| Instance | Module | Role |
| --- | --- | --- |
| `u_gold_gh` | `pucch_f1_gold_gen` | Group-hopping Gold, `c_init = n_id / 30` |
| `u_gold_cs` | `pucch_f1_gold_gen` | Cyclic-shift Gold, `c_init = n_id` |

Own logic:

_VI:_ Logic riêng:

| Element | Width | Role |
| --- | --- | --- |
| `state_q` | 2 | IDLE / PREP / RUN / DONE |
| `fgh_q` | 16 | Gold bits `c_gh[16·slot .. 16·slot+15]`, bit b at position b |
| `ncs_byte_q` | 8 | n_cs byte being assembled (bit b at position b) |
| `s_cache_q[0..13]` | 14 × 4 | `s_l = (m0 + n_cs[l_abs]) mod 12` per absolute symbol |
| `u_q[0..1]` | 2 × 5 | Sequence group per hop |
| Cursor `q_q`, `g_q`, `n_q`, `t_q` | 7, 3, 4, 4 | RE index, data symbol (0..6), subcarrier, CS remainder |
| Base ROM | 360 × 16 | addr `12·u + n`, source 07 §2 |
| CS ROM | 12 × 16 | addr `t`, `floor(65536·t/12)`, source 07 §4 |

Decision: the cache stores `s_l` (4 bits) instead of `n_cs` (8 bits); it is computed once per symbol when its byte completes – functionally identical to caching `n_cs` (source 02 §7 storage is logical).

_VI:_ Quyết định: cache lưu `s_l` (4 bit) thay vì `n_cs` (8 bit); tính một lần mỗi symbol khi byte của nó hoàn tất – tương đương chức năng với cache `n_cs` (bảng storage ở source 02 §7 là logical).

## Behavior / Hành vi

PREPARE (state PREP, started by `txn_start`; both Gold generators start on the same edge):

_VI:_ PREPARE (trạng thái PREP, bắt đầu bởi `txn_start`; hai Gold generator bắt đầu cùng một sườn):

- Group hopping: on `u_gold_gh.c_valid` with `16·slot ≤ c_idx ≤ 16·slot+15`, store `c_bit` at `fgh_q[c_idx − 16·slot]`.
  - _VI:_ Group hopping: khi `u_gold_gh.c_valid` với `16·slot ≤ c_idx ≤ 16·slot+15`, lưu `c_bit` vào `fgh_q[c_idx − 16·slot]`.
- Cyclic shift: on `u_gold_cs.c_valid` with `112·slot ≤ c_idx ≤ 112·slot+111`, let `o = c_idx − 112·slot`, `l = o >> 3`, `b = o & 7`; put `c_bit` at bit `b` of the byte; when `b == 7` write `s_cache_q[l] = (m0 + n_cs) mod 12` with the completed byte `n_cs`.
  - _VI:_ Cyclic shift: khi `u_gold_cs.c_valid` với `112·slot ≤ c_idx ≤ 112·slot+111`, đặt `o = c_idx − 112·slot`, `l = o >> 3`, `b = o & 7`; đưa `c_bit` vào bit `b` của byte; khi `b == 7` ghi `s_cache_q[l] = (m0 + n_cs) mod 12` với byte hoàn tất `n_cs`.
- After the last CS bit (`c_idx == 112·slot+111`; the GH bits always finish earlier): `f_ss = n_id mod 30`; `f_gh[h] = (gh_mode == 1) ? (fgh_q[8h+7:8h] mod 30) : 0`; `u_q[h] = (f_ss + f_gh[h]) mod 30`; go to RUN, `gen_ready = 1`. Latency from `txn_start` ≈ 1600 + 112·(slot+1) + 3 clocks (≤ 3904 required).
  - _VI:_ Sau bit CS cuối (`c_idx == 112·slot+111`; bit GH luôn xong sớm hơn): `f_ss = n_id mod 30`; `f_gh[h] = (gh_mode == 1) ? (fgh_q[8h+7:8h] mod 30) : 0`; `u_q[h] = (f_ss + f_gh[h]) mod 30`; chuyển RUN, `gen_ready = 1`. Latency từ `txn_start` ≈ 1600 + 112·(slot+1) + 3 clock (yêu cầu ≤ 3904).

RUN – phase token from the cursor (combinational from cursor registers, stable while `phase_ready=0`):

_VI:_ RUN – token pha từ cursor (tổ hợp từ các thanh ghi cursor, ổn định khi `phase_ready=0`):

| Output | Value |
| --- | --- |
| `phase_hop` | `hopping && (g_q ≥ n_sf0)` |
| `phase_m` | `phase_hop ? g_q − n_sf0 : g_q` |
| `phase_l_abs` | `start_symbol + 2·g_q + 1` |
| `r_phase` | `(BASE[12·u_q[phase_hop] + n_q] + CS[t_q]) mod 65536` |
| `phase_sample_q`, `phase_n` | `q_q`, `n_q` |
| `phase_first`, `phase_last` | `q_q == 0`, `q_q == n_re−1` |
| `phase_valid` | `state == RUN` |

On `phase_valid && phase_ready`: `q_q += 1`; if `n_q == 11`: `n_q = 0`, `t_q = 0`, `g_q += 1`; else `n_q += 1`, `t_q = (t_q + s_cache_q[phase_l_abs]) mod 12` (5-bit sum, subtract 12 once if ≥ 12). If `phase_last`: go to DONE (`phase_valid = 0`, `gen_ready` stays 1). The remainder `t` restarts at 0 for every data symbol, never by repeated quantized phase steps (source 03 §6).

_VI:_ Khi `phase_valid && phase_ready`: `q_q += 1`; nếu `n_q == 11`: `n_q = 0`, `t_q = 0`, `g_q += 1`; ngược lại `n_q += 1`, `t_q = (t_q + s_cache_q[phase_l_abs]) mod 12` (tổng 5 bit, trừ 12 một lần nếu ≥ 12). Nếu `phase_last`: chuyển DONE (`phase_valid = 0`, `gen_ready` vẫn 1). Remainder `t` bắt đầu lại từ 0 ở mỗi data symbol, không bao giờ bằng cách lặp bước pha đã lượng tử (source 03 §6).

`lut_err = phase_valid && (u > 29 || n_q > 11 || t_q > 11 || phase_l_abs > 13)`; the ROM output for an illegal address is 0. This is unreachable for a validated config and exists only to avoid address aliasing (V11).

_VI:_ `lut_err = phase_valid && (u > 29 || n_q > 11 || t_q > 11 || phase_l_abs > 13)`; ROM trả 0 với địa chỉ không hợp lệ. Điều này không thể xảy ra với config đã kiểm tra, chỉ để tránh alias địa chỉ (V11).

`txn_clr` (priority over all) returns to IDLE and clears `gen_ready`, cursor and caches; the Gold generators are cleared by the same signal.

_VI:_ `txn_clr` (ưu tiên cao nhất) đưa về IDLE và xóa `gen_ready`, cursor và cache; Gold generator được xóa bởi cùng tín hiệu.

## Reset

State IDLE, all registers 0, `phase_valid = gen_ready = 0`.

_VI:_ Trạng thái IDLE, mọi thanh ghi bằng 0, `phase_valid = gen_ready = 0`.
