// ============================================================================
// Module : pucch_f1_rx_core
// PUCCH Format 1 inverse-phase receiver core (top): instances of the
// controller, low-PAPR phase generator, RX inverse, modulation candidates and
// scalar MLE, connected by name. No glue logic.
// Spec    : doc/spec/architecture/pucch_f1_rx_core_spec.md
//           doc/spec/interface/pucch_f1_rx_core_interface.md
// Diagram : doc/diagram/pucch_f1_rx_core/pucch_f1_rx_core.svg (L0)
// Revision: 2.0 - regenerated from the S2 SVG model
// ============================================================================
`default_nettype none

module pucch_f1_rx_core (
  input  wire         clk,                   // Clock, rising edge
  input  wire         rst_n,                 // Synchronous active-low reset
  input  wire         cfg_valid,             // Config valid
  output wire         cfg_ready,             // 1 only in IDLE
  output wire         busy,                  // 1 from after config handshake until after result handshake
  input  wire [1:0]   cfg_m_bit,             // Number of UCI bits; legal 1, 2
  input  wire [3:0]   cfg_nsymb,             // PUCCH duration L; legal 4..14
  input  wire [3:0]   cfg_start_symbol,      // Start symbol; legal 0..10 and start+nsymb <= 14
  input  wire         cfg_intra_slot_hopping, // 1 = intra-slot hopping
  input  wire [1:0]   cfg_group_hopping_mode, // 0 neither, 1 enable, 2 disable, 3 invalid
  input  wire [9:0]   cfg_n_id,              // Effective hoppingId / cell ID, 0..1023
  input  wire [3:0]   cfg_m0,                // Initial cyclic shift; legal 0..11
  input  wire [2:0]   cfg_occ_i,             // OCC index; legal < N_SF of every active hop
  input  wire [4:0]   cfg_slot_idx,          // Slot in frame; legal 0..19
  input  wire         y_valid,               // RE valid
  output wire         y_ready,               // RE ready (RECEIVE and phase available only)
  input  wire [15:0]  y_i,                   // Y_hat in-phase, signed F15
  input  wire [15:0]  y_q,                   // Y_hat quadrature, signed F15
  input  wire [6:0]   y_sample_q,            // RE index q, 0..N_RE-1
  input  wire         y_first,               // 1 only at q = 0
  input  wire         y_last,                // 1 only at q = N_RE-1
  output wire         res_valid,             // Result record valid (success or error), held until res_ready
  input  wire         res_ready,             // Consumer ready
  output wire         res_error,             // 1 = error record
  output wire [3:0]   res_error_code,        // 0 NONE, 1 CFG_RANGE, 2 CFG_OCC, 3 SAMPLE_ORDER, 4 SAMPLE_MARKER, 5 NUMERIC, 6 INTERNAL_ALIGN
  output wire [1:0]   res_m_bit,             // Captured cfg_m_bit (raw, also for error records)
  output wire [1:0]   res_candidate_idx,     // Winning k; 0 on error
  output wire [1:0]   res_uci_bits,          // [0]=b(0), [1]=b(1); [1]=0 when M_bit=1; 0 on error
  output wire [25:0]  res_d_rx_i,            // d_rx I, signed F15; 0 on error
  output wire [25:0]  res_d_rx_q,            // d_rx Q, signed F15; 0 on error
  output wire [42:0]  res_metric_best,       // Best metric, signed F30; 0 on error
  output wire [42:0]  res_metric_second,     // Runner-up metric, signed F30; 0 on error
  output wire [43:0]  res_metric_gap         // best - second, unsigned F30; 0 on error
);

  // Internal nets (named after the driving child port)
  wire [1:0]   m_bit;
  wire [9:0]   n_id;
  wire [1:0]   gh_mode;
  wire [4:0]   slot_idx;
  wire [3:0]   start_symbol;
  wire         hopping;
  wire [3:0]   m0;
  wire [2:0]   occ_i;
  wire [6:0]   n_re;
  wire [2:0]   n_sf0;
  wire [2:0]   n_sf1;
  wire         txn_start;
  wire         txn_clr;
  wire         phase_ready;
  wire         join_fire;
  wire         gen_ready;
  wire         lut_err;
  wire         phase_valid;
  wire [15:0]  r_phase;
  wire [6:0]   phase_sample_q;
  wire         phase_hop;
  wire [2:0]   phase_m;
  wire         phase_first;
  wire         phase_last;
  wire         occ_err;
  wire         acc_done;
  wire         num_err;
  wire         d_valid;
  wire [25:0]  d_i;
  wire [25:0]  d_q;
  wire         cand_valid;
  wire [3:0]   cand_mask;
  wire [1:0]   cand_m_bit;
  wire [63:0]  cand_i;
  wire [63:0]  cand_q;
  wire [7:0]   cand_bits;
  wire         cand_ready;
  wire         tbl_valid;
  wire         cand_err;
  wire         d_ready;
  wire         mle_valid;
  wire [1:0]   mle_candidate_idx;
  wire [1:0]   mle_uci_bits;
  wire [25:0]  mle_d_rx_i;
  wire [25:0]  mle_d_rx_q;
  wire [42:0]  mle_metric_best;
  wire [42:0]  mle_metric_second;
  wire [43:0]  mle_metric_gap;

  // Debug outputs left open (input 04): phase_n, phase_l_abs, cand_phase, d_n_re
  wire [3:0]   phase_n_unused;
  wire [3:0]   phase_l_abs_unused;
  wire [63:0]  cand_phase_unused;
  wire [6:0]   d_n_re_unused;

  pucch_f1_ctrl u_ctrl (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .cfg_valid              (cfg_valid),
    .cfg_ready              (cfg_ready),
    .busy                   (busy),
    .cfg_m_bit              (cfg_m_bit),
    .cfg_nsymb              (cfg_nsymb),
    .cfg_start_symbol       (cfg_start_symbol),
    .cfg_intra_slot_hopping (cfg_intra_slot_hopping),
    .cfg_group_hopping_mode (cfg_group_hopping_mode),
    .cfg_n_id               (cfg_n_id),
    .cfg_m0                 (cfg_m0),
    .cfg_occ_i              (cfg_occ_i),
    .cfg_slot_idx           (cfg_slot_idx),
    .y_valid                (y_valid),
    .y_ready                (y_ready),
    .y_sample_q             (y_sample_q),
    .y_first                (y_first),
    .y_last                 (y_last),
    .res_valid              (res_valid),
    .res_ready              (res_ready),
    .res_error              (res_error),
    .res_error_code         (res_error_code),
    .res_m_bit              (res_m_bit),
    .res_candidate_idx      (res_candidate_idx),
    .res_uci_bits           (res_uci_bits),
    .res_d_rx_i             (res_d_rx_i),
    .res_d_rx_q             (res_d_rx_q),
    .res_metric_best        (res_metric_best),
    .res_metric_second      (res_metric_second),
    .res_metric_gap         (res_metric_gap),
    .m_bit                  (m_bit),
    .n_id                   (n_id),
    .gh_mode                (gh_mode),
    .slot_idx               (slot_idx),
    .start_symbol           (start_symbol),
    .hopping                (hopping),
    .m0                     (m0),
    .occ_i                  (occ_i),
    .n_re                   (n_re),
    .n_sf0                  (n_sf0),
    .n_sf1                  (n_sf1),
    .txn_start              (txn_start),
    .txn_clr                (txn_clr),
    .gen_ready              (gen_ready),
    .lut_err                (lut_err),
    .phase_valid            (phase_valid),
    .phase_ready            (phase_ready),
    .phase_sample_q         (phase_sample_q),
    .phase_first            (phase_first),
    .phase_last             (phase_last),
    .join_fire              (join_fire),
    .occ_err                (occ_err),
    .acc_done               (acc_done),
    .num_err                (num_err),
    .d_valid                (d_valid),
    .d_ready                (d_ready),
    .tbl_valid              (tbl_valid),
    .cand_err               (cand_err),
    .mle_valid              (mle_valid),
    .mle_candidate_idx      (mle_candidate_idx),
    .mle_uci_bits           (mle_uci_bits),
    .mle_d_rx_i             (mle_d_rx_i),
    .mle_d_rx_q             (mle_d_rx_q),
    .mle_metric_best        (mle_metric_best),
    .mle_metric_second      (mle_metric_second),
    .mle_metric_gap         (mle_metric_gap)
  );

  pucch_f1_lowpapr_phase_gen u_lowpapr (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .txn_start              (txn_start),
    .txn_clr                (txn_clr),
    .n_id                   (n_id),
    .gh_mode                (gh_mode),
    .slot_idx               (slot_idx),
    .start_symbol           (start_symbol),
    .hopping                (hopping),
    .m0                     (m0),
    .n_sf0                  (n_sf0),
    .n_re                   (n_re),
    .gen_ready              (gen_ready),
    .lut_err                (lut_err),
    .phase_valid            (phase_valid),
    .phase_ready            (phase_ready),
    .r_phase                (r_phase),
    .phase_sample_q         (phase_sample_q),
    .phase_hop              (phase_hop),
    .phase_m                (phase_m),
    .phase_n                (phase_n_unused),
    .phase_l_abs            (phase_l_abs_unused),
    .phase_first            (phase_first),
    .phase_last             (phase_last)
  );

  pucch_f1_rx_inverse u_rx_inverse (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .txn_clr                (txn_clr),
    .join_fire              (join_fire),
    .y_i                    (y_i),
    .y_q                    (y_q),
    .r_phase                (r_phase),
    .phase_sample_q         (phase_sample_q),
    .phase_hop              (phase_hop),
    .phase_m                (phase_m),
    .phase_first            (phase_first),
    .phase_last             (phase_last),
    .occ_i                  (occ_i),
    .n_sf0                  (n_sf0),
    .n_sf1                  (n_sf1),
    .n_re                   (n_re),
    .occ_err                (occ_err),
    .acc_done               (acc_done),
    .num_err                (num_err),
    .d_valid                (d_valid),
    .d_ready                (d_ready),
    .d_i                    (d_i),
    .d_q                    (d_q),
    .d_n_re                 (d_n_re_unused)
  );

  pucch_f1_mod_candidates u_mod_cand (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .txn_start              (txn_start),
    .txn_clr                (txn_clr),
    .m_bit                  (m_bit),
    .cand_valid             (cand_valid),
    .cand_ready             (cand_ready),
    .cand_mask              (cand_mask),
    .cand_m_bit             (cand_m_bit),
    .cand_i                 (cand_i),
    .cand_q                 (cand_q),
    .cand_phase             (cand_phase_unused),
    .cand_bits              (cand_bits)
  );

  pucch_f1_scalar_mle u_mle (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .txn_clr                (txn_clr),
    .m_bit                  (m_bit),
    .cand_valid             (cand_valid),
    .cand_ready             (cand_ready),
    .cand_mask              (cand_mask),
    .cand_m_bit             (cand_m_bit),
    .cand_i                 (cand_i),
    .cand_q                 (cand_q),
    .cand_bits              (cand_bits),
    .tbl_valid              (tbl_valid),
    .cand_err               (cand_err),
    .d_valid                (d_valid),
    .d_ready                (d_ready),
    .d_i                    (d_i),
    .d_q                    (d_q),
    .mle_valid              (mle_valid),
    .mle_candidate_idx      (mle_candidate_idx),
    .mle_uci_bits           (mle_uci_bits),
    .mle_d_rx_i             (mle_d_rx_i),
    .mle_d_rx_q             (mle_d_rx_q),
    .mle_metric_best        (mle_metric_best),
    .mle_metric_second      (mle_metric_second),
    .mle_metric_gap         (mle_metric_gap)
  );

endmodule

`default_nettype wire
