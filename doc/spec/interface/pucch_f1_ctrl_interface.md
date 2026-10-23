# pucch_f1_ctrl – Interface

Snapshot outputs (`m_bit` … `m0`, `occ_i`) and derived outputs (`n_re`, `n_sf0`, `n_sf1`) are constant for the whole transaction (registered at the config handshake / derived combinationally from those registers).

_VI:_ Output snapshot (`m_bit` … `m0`, `occ_i`) và output suy ra (`n_re`, `n_sf0`, `n_sf1`) không đổi trong suốt transaction (đăng ký tại handshake config / suy tổ hợp từ các thanh ghi đó).

| Port name | Direction | Width | Type | Connects to | Description |
| --- | --- | --- | --- | --- | --- |
| `clk` | in | 1 | CLK/RST | `pucch_f1_rx_core.clk` | Clock |
| `rst_n` | in | 1 | CLK/RST | `pucch_f1_rx_core.rst_n` | Sync active-low reset |
| `cfg_valid` | in | 1 | CTRL | `pucch_f1_rx_core.cfg_valid` | Config valid |
| `cfg_ready` | out | 1 | CTRL | `pucch_f1_rx_core.cfg_ready` | `state == IDLE` |
| `busy` | out | 1 | STATUS | `pucch_f1_rx_core.busy` | `state != IDLE` |
| `cfg_m_bit` | in | 2 | DATA | `pucch_f1_rx_core.cfg_m_bit` | Config field |
| `cfg_nsymb` | in | 4 | DATA | `pucch_f1_rx_core.cfg_nsymb` | Config field |
| `cfg_start_symbol` | in | 4 | DATA | `pucch_f1_rx_core.cfg_start_symbol` | Config field |
| `cfg_intra_slot_hopping` | in | 1 | DATA | `pucch_f1_rx_core.cfg_intra_slot_hopping` | Config field |
| `cfg_group_hopping_mode` | in | 2 | DATA | `pucch_f1_rx_core.cfg_group_hopping_mode` | Config field |
| `cfg_n_id` | in | 10 | DATA | `pucch_f1_rx_core.cfg_n_id` | Config field |
| `cfg_m0` | in | 4 | DATA | `pucch_f1_rx_core.cfg_m0` | Config field |
| `cfg_occ_i` | in | 3 | DATA | `pucch_f1_rx_core.cfg_occ_i` | Config field |
| `cfg_slot_idx` | in | 5 | DATA | `pucch_f1_rx_core.cfg_slot_idx` | Config field |
| `y_valid` | in | 1 | CTRL | `pucch_f1_rx_core.y_valid` | RE valid |
| `y_ready` | out | 1 | CTRL | `pucch_f1_rx_core.y_ready` | `RECEIVE && phase_valid` |
| `y_sample_q` | in | 7 | DATA | `pucch_f1_rx_core.y_sample_q` | Checked against `q_expected` |
| `y_first` | in | 1 | CTRL | `pucch_f1_rx_core.y_first` | Checked marker |
| `y_last` | in | 1 | CTRL | `pucch_f1_rx_core.y_last` | Checked marker |
| `res_valid` | out | 1 | CTRL | `pucch_f1_rx_core.res_valid` | `state == REPORT` |
| `res_ready` | in | 1 | CTRL | `pucch_f1_rx_core.res_ready` | Consumer ready |
| `res_error` | out | 1 | STATUS | `pucch_f1_rx_core.res_error` | `err_q` |
| `res_error_code` | out | 4 | STATUS | `pucch_f1_rx_core.res_error_code` | `err_code_q` |
| `res_m_bit` | out | 2 | DATA | `pucch_f1_rx_core.res_m_bit` | Snapshot `m_bit` (raw) |
| `res_candidate_idx` | out | 2 | DATA | `pucch_f1_rx_core.res_candidate_idx` | `err_q ? 0 : mle_candidate_idx` |
| `res_uci_bits` | out | 2 | DATA | `pucch_f1_rx_core.res_uci_bits` | `err_q ? 0 : mle_uci_bits` |
| `res_d_rx_i` | out | 26 | DATA | `pucch_f1_rx_core.res_d_rx_i` | `err_q ? 0 : mle_d_rx_i` |
| `res_d_rx_q` | out | 26 | DATA | `pucch_f1_rx_core.res_d_rx_q` | `err_q ? 0 : mle_d_rx_q` |
| `res_metric_best` | out | 43 | DATA | `pucch_f1_rx_core.res_metric_best` | `err_q ? 0 : mle_metric_best` |
| `res_metric_second` | out | 43 | DATA | `pucch_f1_rx_core.res_metric_second` | `err_q ? 0 : mle_metric_second` |
| `res_metric_gap` | out | 44 | DATA | `pucch_f1_rx_core.res_metric_gap` | `err_q ? 0 : mle_metric_gap` |
| `m_bit` | out | 2 | DATA | `pucch_f1_mod_candidates.m_bit`, `pucch_f1_scalar_mle.m_bit` | Snapshot M_bit |
| `n_id` | out | 10 | DATA | `pucch_f1_lowpapr_phase_gen.n_id` | Snapshot n_ID |
| `gh_mode` | out | 2 | DATA | `pucch_f1_lowpapr_phase_gen.gh_mode` | Snapshot group hopping mode |
| `slot_idx` | out | 5 | DATA | `pucch_f1_lowpapr_phase_gen.slot_idx` | Snapshot slot |
| `start_symbol` | out | 4 | DATA | `pucch_f1_lowpapr_phase_gen.start_symbol` | Snapshot start symbol |
| `hopping` | out | 1 | DATA | `pucch_f1_lowpapr_phase_gen.hopping` | Snapshot intra-slot hopping |
| `m0` | out | 4 | DATA | `pucch_f1_lowpapr_phase_gen.m0` | Snapshot m0 |
| `occ_i` | out | 3 | DATA | `pucch_f1_rx_inverse.occ_i` | Snapshot OCC index |
| `n_re` | out | 7 | DATA | `pucch_f1_lowpapr_phase_gen.n_re`, `pucch_f1_rx_inverse.n_re` | Derived N_RE |
| `n_sf0` | out | 3 | DATA | `pucch_f1_lowpapr_phase_gen.n_sf0`, `pucch_f1_rx_inverse.n_sf0` | Derived N_SF hop0 |
| `n_sf1` | out | 3 | DATA | `pucch_f1_rx_inverse.n_sf1` | Derived N_SF hop1 (0 if no hopping) |
| `txn_start` | out | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.txn_start`, `pucch_f1_mod_candidates.txn_start` | 1-clock pulse: VALIDATE with legal config |
| `txn_clr` | out | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.txn_clr`, `pucch_f1_rx_inverse.txn_clr`, `pucch_f1_mod_candidates.txn_clr`, `pucch_f1_scalar_mle.txn_clr` | 1-clock flush: error abort or result handshake |
| `gen_ready` | in | 1 | STATUS | `pucch_f1_lowpapr_phase_gen.gen_ready` | Phase generator prepared |
| `lut_err` | in | 1 | STATUS | `pucch_f1_lowpapr_phase_gen.lut_err` | Illegal base/CS ROM address |
| `phase_valid` | in | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.phase_valid` | Phase token valid |
| `phase_ready` | out | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.phase_ready` | `RECEIVE && y_valid` |
| `phase_sample_q` | in | 7 | DATA | `pucch_f1_lowpapr_phase_gen.phase_sample_q` | Phase tag q |
| `phase_first` | in | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.phase_first` | Phase tag first |
| `phase_last` | in | 1 | CTRL | `pucch_f1_lowpapr_phase_gen.phase_last` | Phase tag last |
| `join_fire` | out | 1 | CTRL | `pucch_f1_rx_inverse.join_fire` | `RECEIVE && y_valid && phase_valid` |
| `occ_err` | in | 1 | STATUS | `pucch_f1_rx_inverse.occ_err` | Illegal OCC lookup for current phase tag |
| `acc_done` | in | 1 | STATUS | `pucch_f1_rx_inverse.acc_done` | Last RE accumulated |
| `num_err` | in | 1 | STATUS | `pucch_f1_rx_inverse.num_err` | CORDIC / sum / normalize overflow |
| `d_valid` | in | 1 | CTRL | `pucch_f1_rx_inverse.d_valid` | Scalar stream valid (observed) |
| `d_ready` | in | 1 | CTRL | `pucch_f1_scalar_mle.d_ready` | Scalar stream ready (observed) |
| `tbl_valid` | in | 1 | STATUS | `pucch_f1_scalar_mle.tbl_valid` | Candidate table captured |
| `cand_err` | in | 1 | STATUS | `pucch_f1_scalar_mle.cand_err` | `cand_m_bit` mismatch |
| `mle_valid` | in | 1 | STATUS | `pucch_f1_scalar_mle.mle_valid` | MLE result register full |
| `mle_candidate_idx` | in | 2 | DATA | `pucch_f1_scalar_mle.mle_candidate_idx` | MLE result |
| `mle_uci_bits` | in | 2 | DATA | `pucch_f1_scalar_mle.mle_uci_bits` | MLE result |
| `mle_d_rx_i` | in | 26 | DATA | `pucch_f1_scalar_mle.mle_d_rx_i` | MLE result |
| `mle_d_rx_q` | in | 26 | DATA | `pucch_f1_scalar_mle.mle_d_rx_q` | MLE result |
| `mle_metric_best` | in | 43 | DATA | `pucch_f1_scalar_mle.mle_metric_best` | MLE result |
| `mle_metric_second` | in | 43 | DATA | `pucch_f1_scalar_mle.mle_metric_second` | MLE result |
| `mle_metric_gap` | in | 44 | DATA | `pucch_f1_scalar_mle.mle_metric_gap` | MLE result |
