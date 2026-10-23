// ============================================================================
// Module : pucch_f1_ctrl
// Transaction controller: config snapshot, validation, derived counts, FSM
// IDLE..REPORT, phase/data join handshake, RE tag/marker checks, first-error
// latch and result record (MLE payload or error record).
// Spec    : doc/spec/architecture/pucch_f1_ctrl_spec.md
//           doc/spec/interface/pucch_f1_ctrl_interface.md
// Diagram : doc/diagram/pucch_f1_ctrl/pucch_f1_ctrl.svg (L1)
// Revision: 2.0 - regenerated from the S2 SVG model
// ============================================================================
`default_nettype none

module pucch_f1_ctrl (
  input  wire        clk,                     // clock, rising edge
  input  wire        rst_n,                   // synchronous active-low reset
  input  wire        cfg_valid,               // config valid
  output wire        cfg_ready,               // state == IDLE
  output wire        busy,                    // state != IDLE
  input  wire [1:0]  cfg_m_bit,               // config field
  input  wire [3:0]  cfg_nsymb,               // config field
  input  wire [3:0]  cfg_start_symbol,        // config field
  input  wire        cfg_intra_slot_hopping,  // config field
  input  wire [1:0]  cfg_group_hopping_mode,  // config field
  input  wire [9:0]  cfg_n_id,                // config field
  input  wire [3:0]  cfg_m0,                  // config field
  input  wire [2:0]  cfg_occ_i,               // config field
  input  wire [4:0]  cfg_slot_idx,            // config field
  input  wire        y_valid,                 // RE valid
  output wire        y_ready,                 // RECEIVE && phase_valid
  input  wire [6:0]  y_sample_q,              // checked against q_expected
  input  wire        y_first,                 // checked marker
  input  wire        y_last,                  // checked marker
  output wire        res_valid,               // state == REPORT
  input  wire        res_ready,               // consumer ready
  output wire        res_error,               // err_q
  output wire [3:0]  res_error_code,          // err_code_q
  output wire [1:0]  res_m_bit,               // snapshot m_bit (raw)
  output wire [1:0]  res_candidate_idx,       // err_q ? 0 : mle_candidate_idx
  output wire [1:0]  res_uci_bits,            // err_q ? 0 : mle_uci_bits
  output wire [25:0] res_d_rx_i,              // err_q ? 0 : mle_d_rx_i
  output wire [25:0] res_d_rx_q,              // err_q ? 0 : mle_d_rx_q
  output wire [42:0] res_metric_best,         // err_q ? 0 : mle_metric_best
  output wire [42:0] res_metric_second,       // err_q ? 0 : mle_metric_second
  output wire [43:0] res_metric_gap,          // err_q ? 0 : mle_metric_gap
  output wire [1:0]  m_bit,                   // snapshot M_bit
  output wire [9:0]  n_id,                    // snapshot n_ID
  output wire [1:0]  gh_mode,                 // snapshot group hopping mode
  output wire [4:0]  slot_idx,                // snapshot slot
  output wire [3:0]  start_symbol,            // snapshot start symbol
  output wire        hopping,                 // snapshot intra-slot hopping
  output wire [3:0]  m0,                      // snapshot m0
  output wire [2:0]  occ_i,                   // snapshot OCC index
  output wire [6:0]  n_re,                    // derived N_RE
  output wire [2:0]  n_sf0,                   // derived N_SF hop0
  output wire [2:0]  n_sf1,                   // derived N_SF hop1
  output wire        txn_start,               // 1-clock pulse: legal config
  output wire        txn_clr,                 // 1-clock flush
  input  wire        gen_ready,               // phase generator prepared
  input  wire        lut_err,                 // illegal base/CS ROM address
  input  wire        phase_valid,             // phase token valid
  output wire        phase_ready,             // RECEIVE && y_valid
  input  wire [6:0]  phase_sample_q,          // phase tag q
  input  wire        phase_first,             // phase tag first
  input  wire        phase_last,              // phase tag last
  output wire        join_fire,               // RECEIVE && y_valid && phase_valid
  input  wire        occ_err,                 // illegal OCC lookup
  input  wire        acc_done,                // last RE accumulated
  input  wire        num_err,                 // numeric overflow
  input  wire        d_valid,                 // scalar stream valid (observed)
  input  wire        d_ready,                 // scalar stream ready (observed)
  input  wire        tbl_valid,               // candidate table captured
  input  wire        cand_err,                // cand_m_bit mismatch
  input  wire        mle_valid,               // MLE result register full
  input  wire [1:0]  mle_candidate_idx,       // MLE result
  input  wire [1:0]  mle_uci_bits,            // MLE result
  input  wire [25:0] mle_d_rx_i,              // MLE result
  input  wire [25:0] mle_d_rx_q,              // MLE result
  input  wire [42:0] mle_metric_best,         // MLE result
  input  wire [42:0] mle_metric_second,       // MLE result
  input  wire [43:0] mle_metric_gap           // MLE result
);

  localparam [2:0] S_IDLE      = 3'd0;
  localparam [2:0] S_VALIDATE  = 3'd1;
  localparam [2:0] S_PREPARE   = 3'd2;
  localparam [2:0] S_RECEIVE   = 3'd3;
  localparam [2:0] S_DRAIN     = 3'd4;
  localparam [2:0] S_NORMALIZE = 3'd5;
  localparam [2:0] S_DETECT    = 3'd6;
  localparam [2:0] S_REPORT    = 3'd7;

  localparam [3:0] E_CFG_RANGE      = 4'd1;
  localparam [3:0] E_CFG_OCC        = 4'd2;
  localparam [3:0] E_SAMPLE_ORDER   = 4'd3;
  localparam [3:0] E_SAMPLE_MARKER  = 4'd4;
  localparam [3:0] E_NUMERIC        = 4'd5;
  localparam [3:0] E_INTERNAL_ALIGN = 4'd6;

  // ---------------- registers ----------------
  reg  [2:0] state_q;
  reg  [1:0] m_bit_q;         // snapshot
  reg  [3:0] nsymb_q;
  reg  [3:0] start_symbol_q;
  reg        hopping_q;
  reg  [1:0] gh_mode_q;
  reg  [9:0] n_id_q;
  reg  [3:0] m0_q;
  reg  [2:0] occ_i_q;
  reg  [4:0] slot_idx_q;
  reg  [6:0] q_expected_q;    // expected RE index
  reg        err_q;           // first error latched
  reg  [3:0] err_code_q;

  // ---------------- derived counts (blk_derive) ----------------
  wire [2:0] n_data;
  wire [2:0] n_sf0_w;
  wire [2:0] n_sf1_w;
  wire [6:0] n_re_w;

  assign n_data  = nsymb_q[3:1];
  assign n_sf0_w = hopping_q ? {1'b0, n_data[2:1]} : n_data;
  assign n_sf1_w = hopping_q ? (n_data - {1'b0, n_data[2:1]}) : 3'd0;
  assign n_re_w  = {1'b0, n_data, 3'b000} + {2'b00, n_data, 2'b00};

  // ---------------- validation (blk_valid) ----------------
  wire       range_err;
  wire       occ_cfg_err;

  assign range_err = ((m_bit_q != 2'd1) & (m_bit_q != 2'd2)) | (nsymb_q < 4'd4) | (nsymb_q > 4'd14)
                   | (start_symbol_q > 4'd10) | (({1'b0, start_symbol_q} + {1'b0, nsymb_q}) > 5'd14)
                   | (gh_mode_q == 2'd3) | (m0_q > 4'd11) | (slot_idx_q > 5'd19);
  assign occ_cfg_err = (occ_i_q >= n_sf0_w) | (hopping_q & (occ_i_q >= n_sf1_w));

  // ---------------- handshake decode ----------------
  wire       in_rcv;

  assign cfg_ready   = (state_q == S_IDLE);
  assign busy        = ~cfg_ready;
  assign res_valid   = (state_q == S_REPORT);
  assign in_rcv      = (state_q == S_RECEIVE);
  assign y_ready     = in_rcv & phase_valid;
  assign phase_ready = in_rcv & y_valid;
  assign join_fire   = in_rcv & y_valid & phase_valid;

  // ---------------- tag checks (blk_check) ----------------
  wire       q_is_first;
  wire       q_is_last;
  wire       align_ev;
  wire       order_ev;
  wire       marker_ev;
  wire       active;
  wire       err_ev;
  wire [3:0] ev_code;

  assign q_is_first = (q_expected_q == 7'd0);
  assign q_is_last  = (q_expected_q == (n_re_w - 7'd1));
  assign align_ev   = cand_err | lut_err
                    | (join_fire & (occ_err | (phase_sample_q != q_expected_q)
                                   | (phase_first != q_is_first) | (phase_last != q_is_last)));
  assign order_ev   = join_fire & (y_sample_q != q_expected_q);
  assign marker_ev  = join_fire & ((y_first != q_is_first) | (y_last != q_is_last));
  assign active     = (state_q >= S_PREPARE) & (state_q <= S_DETECT);
  assign err_ev     = active & (align_ev | order_ev | marker_ev | num_err);
  assign ev_code    = align_ev  ? E_INTERNAL_ALIGN :
                      order_ev  ? E_SAMPLE_ORDER   :
                      marker_ev ? E_SAMPLE_MARKER  : E_NUMERIC;

  // ---------------- FSM and control (cloud_next) ----------------
  wire       cfg_fire;
  wire       vld_err;
  reg  [2:0] state_d;

  assign cfg_fire  = cfg_valid & (state_q == S_IDLE);
  assign vld_err   = (state_q == S_VALIDATE) & (range_err | occ_cfg_err);
  assign txn_start = (state_q == S_VALIDATE) & ~range_err & ~occ_cfg_err;
  assign txn_clr   = err_ev | ((state_q == S_REPORT) & res_ready);

  always @(*) begin
    state_d = state_q;
    case (state_q)
      S_IDLE: begin
        if (cfg_valid) begin
          state_d = S_VALIDATE;
        end
      end
      S_VALIDATE: begin
        state_d = (range_err | occ_cfg_err) ? S_REPORT : S_PREPARE;
      end
      S_PREPARE: begin
        if (err_ev) begin
          state_d = S_REPORT;
        end
        else if (gen_ready & tbl_valid) begin
          state_d = S_RECEIVE;
        end
      end
      S_RECEIVE: begin
        if (err_ev) begin
          state_d = S_REPORT;
        end
        else if (join_fire & q_is_last) begin
          state_d = S_DRAIN;
        end
      end
      S_DRAIN: begin
        if (err_ev) begin
          state_d = S_REPORT;
        end
        else if (acc_done) begin
          state_d = S_NORMALIZE;
        end
      end
      S_NORMALIZE: begin
        if (err_ev) begin
          state_d = S_REPORT;
        end
        else if (d_valid & d_ready) begin
          state_d = S_DETECT;
        end
      end
      S_DETECT: begin
        if (err_ev | mle_valid) begin
          state_d = S_REPORT;
        end
      end
      S_REPORT: begin
        if (res_ready) begin
          state_d = S_IDLE;
        end
      end
      default: begin
        state_d = S_IDLE;
      end
    endcase
  end

  // ---------------- sequential ----------------
  always @(posedge clk) begin
    if (!rst_n) begin
      state_q        <= S_IDLE;
      m_bit_q        <= 2'd0;
      nsymb_q        <= 4'd0;
      start_symbol_q <= 4'd0;
      hopping_q      <= 1'b0;
      gh_mode_q      <= 2'd0;
      n_id_q         <= 10'd0;
      m0_q           <= 4'd0;
      occ_i_q        <= 3'd0;
      slot_idx_q     <= 5'd0;
      q_expected_q   <= 7'd0;
      err_q          <= 1'b0;
      err_code_q     <= 4'd0;
    end
    else begin
      state_q <= state_d;

      // Config snapshot
      if (cfg_fire) begin
        m_bit_q        <= cfg_m_bit;
        nsymb_q        <= cfg_nsymb;
        start_symbol_q <= cfg_start_symbol;
        hopping_q      <= cfg_intra_slot_hopping;
        gh_mode_q      <= cfg_group_hopping_mode;
        n_id_q         <= cfg_n_id;
        m0_q           <= cfg_m0;
        occ_i_q        <= cfg_occ_i;
        slot_idx_q     <= cfg_slot_idx;
      end

      // Expected RE index
      if (cfg_fire) begin
        q_expected_q <= 7'd0;
      end
      else if (join_fire & ~err_ev) begin
        q_expected_q <= q_expected_q + 7'd1;
      end

      // First error latch
      if (cfg_fire) begin
        err_q      <= 1'b0;
        err_code_q <= 4'd0;
      end
      else if (vld_err) begin
        err_q      <= 1'b1;
        err_code_q <= range_err ? E_CFG_RANGE : E_CFG_OCC;
      end
      else if (err_ev) begin
        err_q      <= 1'b1;
        err_code_q <= ev_code;
      end
    end
  end

  // ---------------- outputs ----------------
  assign m_bit        = m_bit_q;
  assign n_id         = n_id_q;
  assign gh_mode      = gh_mode_q;
  assign slot_idx     = slot_idx_q;
  assign start_symbol = start_symbol_q;
  assign hopping      = hopping_q;
  assign m0           = m0_q;
  assign occ_i        = occ_i_q;
  assign n_re         = n_re_w;
  assign n_sf0        = n_sf0_w;
  assign n_sf1        = n_sf1_w;

  // Result record (blk_res): payload zero on error records
  assign res_error         = err_q;
  assign res_error_code    = err_code_q;
  assign res_m_bit         = m_bit_q;
  assign res_candidate_idx = err_q ? 2'd0  : mle_candidate_idx;
  assign res_uci_bits      = err_q ? 2'd0  : mle_uci_bits;
  assign res_d_rx_i        = err_q ? 26'd0 : mle_d_rx_i;
  assign res_d_rx_q        = err_q ? 26'd0 : mle_d_rx_q;
  assign res_metric_best   = err_q ? 43'd0 : mle_metric_best;
  assign res_metric_second = err_q ? 43'd0 : mle_metric_second;
  assign res_metric_gap    = err_q ? 44'd0 : mle_metric_gap;

endmodule

`default_nettype wire
