// ============================================================================
// Module : pucch_f1_scalar_mle
// Captures the candidate table and the scalar d_rx, computes the exact metric
// M_k = d_i*cand_i[k] + d_q*cand_q[k] (signed43, F30), ranks by (metric desc,
// k asc) and holds best/second metrics, gap, winning k and its packed bits.
// Spec    : doc/spec/architecture/pucch_f1_scalar_mle_spec.md
// Diagram : doc/diagram/pucch_f1_scalar_mle/pucch_f1_scalar_mle.svg (L1)
// Revision: 2.0 - regenerated from the S2 SVG model
// ============================================================================
`default_nettype none

module pucch_f1_scalar_mle (
  input  wire        clk,                // clock, rising edge
  input  wire        rst_n,              // synchronous active-low reset
  input  wire        txn_clr,            // drop table, scalar and result
  input  wire [1:0]  m_bit,              // snapshot M_bit
  input  wire        cand_valid,         // table valid
  output wire        cand_ready,         // !tbl_valid
  input  wire [3:0]  cand_mask,          // active entries
  input  wire [1:0]  cand_m_bit,         // table M_bit
  input  wire [63:0] cand_i,             // 4 x signed16 F15
  input  wire [63:0] cand_q,             // 4 x signed16 F15
  input  wire [7:0]  cand_bits,          // 4 x packed bits
  output wire        tbl_valid,          // table captured
  output wire        cand_err,           // cand_m_bit != m_bit pulse
  input  wire        d_valid,            // d_rx valid
  output wire        d_ready,            // d_rx ready
  input  wire [25:0] d_i,                // d_rx I, signed F15
  input  wire [25:0] d_q,                // d_rx Q, signed F15
  output wire        mle_valid,          // result register full
  output wire [1:0]  mle_candidate_idx,  // winning k
  output wire [1:0]  mle_uci_bits,       // cand_bits[k_best]
  output wire [25:0] mle_d_rx_i,         // captured d_i
  output wire [25:0] mle_d_rx_q,         // captured d_q
  output wire [42:0] mle_metric_best,    // signed F30
  output wire [42:0] mle_metric_second,  // signed F30
  output wire [43:0] mle_metric_gap      // best - second, unsigned F30
);

  // Captured candidate table
  reg         tbl_valid_q;
  reg  [3:0]  mask_q;
  reg  [63:0] ci_q;
  reg  [63:0] cq_q;
  reg  [7:0]  bits_q;
  reg         cand_err_q;
  // Captured scalar
  reg         d_held_q;
  reg  [25:0] di_q;
  reg  [25:0] dq_q;
  // Result registers
  reg         mle_valid_q;
  reg  [1:0]  k_q;
  reg  [1:0]  uci_q;
  reg  [25:0] rdi_q;
  reg  [25:0] rdq_q;
  reg  [42:0] best_q;
  reg  [42:0] second_q;
  reg  [43:0] gap_q;

  wire        tbl_load;
  wire        d_load;
  wire        det;

  // Metrics and ranking (combinational)
  reg  signed [42:0] metric [0:3];
  reg  [1:0]         k_best;
  reg  [1:0]         k_second;
  reg                found_b;
  reg                found_s;
  reg  signed [42:0] best_m;
  reg  signed [42:0] second_m;
  wire [43:0]        gap_m;
  integer            km;
  integer            kb;
  integer            ks;

  assign cand_ready = ~tbl_valid_q;
  assign tbl_load   = cand_valid & cand_ready;
  assign d_ready    = tbl_valid_q & ~d_held_q & ~mle_valid_q;
  assign d_load     = d_valid & d_ready;
  assign det        = d_held_q & ~mle_valid_q;

  always @(*) begin
    for (km = 0; km < 4; km = km + 1) begin
      metric[km] = $signed(di_q) * $signed(ci_q[16*km +: 16]) + $signed(dq_q) * $signed(cq_q[16*km +: 16]);
    end
  end

  // Best: largest metric, ties keep the smaller k
  always @(*) begin
    k_best = 2'd0;
    found_b = 1'b0;
    for (kb = 0; kb < 4; kb = kb + 1) begin
      if (mask_q[kb] && (!found_b || (metric[kb] > metric[k_best]))) begin
        k_best = kb[1:0];
        found_b = 1'b1;
      end
    end
  end

  // Runner-up among the remaining active entries, same rule
  always @(*) begin
    k_second = 2'd0;
    found_s  = 1'b0;
    for (ks = 0; ks < 4; ks = ks + 1) begin
      if (mask_q[ks] && (ks[1:0] != k_best) && (!found_s || (metric[ks] > metric[k_second]))) begin
        k_second = ks[1:0];
        found_s  = 1'b1;
      end
    end
  end

  always @(*) begin
    best_m   = metric[k_best];
    second_m = metric[k_second];
  end

  assign gap_m = {best_m[42], best_m} - {second_m[42], second_m};

  always @(posedge clk) begin
    if (!rst_n) begin
      tbl_valid_q <= 1'b0;
      mask_q      <= 4'd0;
      ci_q        <= 64'd0;
      cq_q        <= 64'd0;
      bits_q      <= 8'd0;
      cand_err_q  <= 1'b0;
      d_held_q    <= 1'b0;
      di_q        <= 26'd0;
      dq_q        <= 26'd0;
      mle_valid_q <= 1'b0;
      k_q         <= 2'd0;
      uci_q       <= 2'd0;
      rdi_q       <= 26'd0;
      rdq_q       <= 26'd0;
      best_q      <= 43'd0;
      second_q    <= 43'd0;
      gap_q       <= 44'd0;
    end
    else begin
      // Table capture
      if (tbl_load) begin
        mask_q <= cand_mask;
        ci_q   <= cand_i;
        cq_q   <= cand_q;
        bits_q <= cand_bits;
      end
      if (txn_clr) begin
        tbl_valid_q <= 1'b0;
      end
      else if (tbl_load) begin
        tbl_valid_q <= 1'b1;
      end
      cand_err_q <= tbl_load & (cand_m_bit != m_bit) & ~txn_clr;

      // Scalar capture
      if (d_load) begin
        di_q <= d_i;
        dq_q <= d_q;
      end
      if (txn_clr) begin
        d_held_q <= 1'b0;
      end
      else if (d_load) begin
        d_held_q <= 1'b1;
      end

      // Detect one clock after the scalar capture
      if (txn_clr) begin
        mle_valid_q <= 1'b0;
        k_q         <= 2'd0;
        uci_q       <= 2'd0;
        rdi_q       <= 26'd0;
        rdq_q       <= 26'd0;
        best_q      <= 43'd0;
        second_q    <= 43'd0;
        gap_q       <= 44'd0;
      end
      else if (det) begin
        mle_valid_q <= 1'b1;
        k_q         <= k_best;
        uci_q       <= bits_q[2*k_best +: 2];
        rdi_q       <= di_q;
        rdq_q       <= dq_q;
        best_q      <= best_m;
        second_q    <= second_m;
        gap_q       <= gap_m;
      end
    end
  end

  assign tbl_valid         = tbl_valid_q;
  assign cand_err          = cand_err_q;
  assign mle_valid         = mle_valid_q;
  assign mle_candidate_idx = k_q;
  assign mle_uci_bits      = uci_q;
  assign mle_d_rx_i        = rdi_q;
  assign mle_d_rx_q        = rdq_q;
  assign mle_metric_best   = best_q;
  assign mle_metric_second = second_q;
  assign mle_metric_gap    = gap_q;

endmodule

`default_nettype wire
