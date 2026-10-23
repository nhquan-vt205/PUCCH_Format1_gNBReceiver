// ============================================================================
// Module : pucch_f1_normalize
// Once per transaction: Z = RNE_div(S * KINV_Q30, 2^30), d = RNE_div(Z, n_re)
// for I and Q in parallel (two restoring dividers, 1 bit per clock), then
// presents d_rx on a valid/ready stream. Saturation of Z or d -> sat_err.
// Spec    : doc/spec/architecture/pucch_f1_normalize_spec.md
// Diagram : doc/diagram/pucch_f1_normalize/pucch_f1_normalize.svg (L1)
// Revision: 2.0 - regenerated from the S2 SVG model
// ============================================================================
`default_nettype none

module pucch_f1_normalize (
  input  wire        clk,      // clock, rising edge
  input  wire        rst_n,    // synchronous active-low reset
  input  wire        clr,      // abort, back to IDLE
  input  wire        start,    // start with current S
  input  wire [25:0] s_i,      // S I, signed F15
  input  wire [25:0] s_q,      // S Q, signed F15
  input  wire [6:0]  n_re,     // divisor N_RE (24..84)
  output wire        d_valid,  // d_rx valid, held until d_ready
  input  wire        d_ready,  // d_rx ready
  output wire [25:0] d_i,      // d_rx I, signed F15
  output wire [25:0] d_q,      // d_rx Q, signed F15
  output wire        sat_err   // 1-clock pulse: Z or d outside signed26
);

  localparam [1:0]  ST_IDLE  = 2'd0;
  localparam [1:0]  ST_DIV   = 2'd1;
  localparam [1:0]  ST_ROUND = 2'd2;
  localparam [1:0]  ST_OUT   = 2'd3;
  localparam [30:0] KINV_Q30 = 31'd652032874;  // RNE((1/A16) * 2^30)
  localparam [29:0] HALF_Q30 = 30'h2000_0000;  // 2^29

  // ---------------- registers ----------------
  reg  [1:0]  state_q;
  reg  [4:0]  cnt_q;      // divider iteration 0..25
  reg  [25:0] a_i_q;      // remaining dividend bits |Z|
  reg  [25:0] a_q_q;
  reg  [7:0]  rem_i_q;    // partial remainder
  reg  [7:0]  rem_q_q;
  reg  [25:0] quo_i_q;    // quotient
  reg  [25:0] quo_q_q;
  reg         z_neg_i_q;  // sign of Z
  reg         z_neg_q_q;
  reg  [25:0] d_i_q;
  reg  [25:0] d_q_q;
  reg         d_valid_q;
  reg         sat_err_q;

  // ---------------- gain correction (blk_gain) ----------------
  wire signed [56:0] p_i;
  wire signed [56:0] p_q;
  wire        [56:0] pa_i;
  wire        [56:0] pa_q;
  wire        [27:0] zv_i;
  wire        [27:0] zv_q;
  wire               z_ovf_i;
  wire               z_ovf_q;
  wire               z_sat;

  assign p_i  = $signed(s_i) * $signed({1'b0, KINV_Q30});
  assign p_q  = $signed(s_q) * $signed({1'b0, KINV_Q30});
  assign pa_i = p_i[56] ? -p_i : p_i;
  assign pa_q = p_q[56] ? -p_q : p_q;
  assign zv_i = {1'b0, pa_i[56:30]} + {27'd0, ((pa_i[29:0] > HALF_Q30) | ((pa_i[29:0] == HALF_Q30) & pa_i[30]))};
  assign zv_q = {1'b0, pa_q[56:30]} + {27'd0, ((pa_q[29:0] > HALF_Q30) | ((pa_q[29:0] == HALF_Q30) & pa_q[30]))};
  assign z_ovf_i = p_i[56] ? (zv_i > 28'd33554432) : (zv_i > 28'd33554431);
  assign z_ovf_q = p_q[56] ? (zv_q > 28'd33554432) : (zv_q > 28'd33554431);
  assign z_sat   = z_ovf_i | z_ovf_q;

  // ---------------- restoring divider step (blk_div) ----------------
  wire [7:0] rs_i;
  wire [7:0] rs_q;
  wire       ge_i;
  wire       ge_q;

  assign rs_i = {rem_i_q[6:0], a_i_q[25]};
  assign rs_q = {rem_q_q[6:0], a_q_q[25]};
  assign ge_i = (rs_i >= {1'b0, n_re});
  assign ge_q = (rs_q >= {1'b0, n_re});

  // ---------------- rounding (blk_round) ----------------
  wire        inc_i;
  wire        inc_q;
  wire [26:0] dv_i;
  wire [26:0] dv_q;
  wire        dsat_i;
  wire        dsat_q;
  wire        d_sat;
  wire [25:0] d_new_i;
  wire [25:0] d_new_q;

  assign inc_i   = ({rem_i_q, 1'b0} > {2'b0, n_re}) | (({rem_i_q, 1'b0} == {2'b0, n_re}) & quo_i_q[0]);
  assign inc_q   = ({rem_q_q, 1'b0} > {2'b0, n_re}) | (({rem_q_q, 1'b0} == {2'b0, n_re}) & quo_q_q[0]);
  assign dv_i    = {1'b0, quo_i_q} + {26'd0, inc_i};
  assign dv_q    = {1'b0, quo_q_q} + {26'd0, inc_q};
  assign dsat_i  = z_neg_i_q ? (dv_i > 27'd33554432) : (dv_i > 27'd33554431);
  assign dsat_q  = z_neg_q_q ? (dv_q > 27'd33554432) : (dv_q > 27'd33554431);
  assign d_sat   = dsat_i | dsat_q;
  assign d_new_i = z_neg_i_q ? -dv_i[25:0] : dv_i[25:0];
  assign d_new_q = z_neg_q_q ? -dv_q[25:0] : dv_q[25:0];

  // ---------------- control (cloud_next) ----------------
  wire       st_idle;
  wire       st_div;
  wire       st_round;
  wire       st_out;
  wire       cnt_last;
  wire       load;
  wire       step;
  wire       rnd_ok;
  reg  [1:0] state_d;
  reg        d_valid_d;
  wire       sat_err_d;

  assign st_idle  = (state_q == ST_IDLE);
  assign st_div   = (state_q == ST_DIV);
  assign st_round = (state_q == ST_ROUND);
  assign st_out   = (state_q == ST_OUT);
  assign cnt_last = (cnt_q == 5'd25);
  assign load     = st_idle & start & ~z_sat & ~clr;
  assign step     = st_div & ~clr;
  assign rnd_ok   = st_round & ~d_sat & ~clr;

  always @(*) begin
    state_d = state_q;
    if (clr) begin
      state_d = ST_IDLE;
    end
    else begin
      case (state_q)
        ST_IDLE: begin
          if (start & ~z_sat) begin
            state_d = ST_DIV;
          end
        end
        ST_DIV: begin
          if (cnt_last) begin
            state_d = ST_ROUND;
          end
        end
        ST_ROUND: begin
          state_d = d_sat ? ST_IDLE : ST_OUT;
        end
        ST_OUT: begin
          if (d_ready) begin
            state_d = ST_IDLE;
          end
        end
        default: begin
          state_d = ST_IDLE;
        end
      endcase
    end
  end

  always @(*) begin
    d_valid_d = d_valid_q;
    if (clr) begin
      d_valid_d = 1'b0;
    end
    else if (rnd_ok) begin
      d_valid_d = 1'b1;
    end
    else if (st_out & d_ready) begin
      d_valid_d = 1'b0;
    end
  end

  assign sat_err_d = ~clr & ((st_idle & start & z_sat) | (st_round & d_sat));

  // ---------------- sequential ----------------
  always @(posedge clk) begin
    if (!rst_n) begin
      state_q   <= ST_IDLE;
      cnt_q     <= 5'd0;
      a_i_q     <= 26'd0;
      a_q_q     <= 26'd0;
      rem_i_q   <= 8'd0;
      rem_q_q   <= 8'd0;
      quo_i_q   <= 26'd0;
      quo_q_q   <= 26'd0;
      z_neg_i_q <= 1'b0;
      z_neg_q_q <= 1'b0;
      d_i_q     <= 26'd0;
      d_q_q     <= 26'd0;
      d_valid_q <= 1'b0;
      sat_err_q <= 1'b0;
    end
    else begin
      state_q   <= state_d;
      d_valid_q <= d_valid_d;
      sat_err_q <= sat_err_d;

      // Iteration counter
      if (load) begin
        cnt_q <= 5'd0;
      end
      else if (st_div) begin
        cnt_q <= cnt_q + 5'd1;
      end

      // Dividers
      if (load) begin
        a_i_q     <= zv_i[25:0];
        a_q_q     <= zv_q[25:0];
        z_neg_i_q <= p_i[56];
        z_neg_q_q <= p_q[56];
        rem_i_q   <= 8'd0;
        rem_q_q   <= 8'd0;
        quo_i_q   <= 26'd0;
        quo_q_q   <= 26'd0;
      end
      else if (step) begin
        rem_i_q <= ge_i ? rs_i - {1'b0, n_re} : rs_i;
        rem_q_q <= ge_q ? rs_q - {1'b0, n_re} : rs_q;
        quo_i_q <= {quo_i_q[24:0], ge_i};
        quo_q_q <= {quo_q_q[24:0], ge_q};
        a_i_q   <= {a_i_q[24:0], 1'b0};
        a_q_q   <= {a_q_q[24:0], 1'b0};
      end

      // Output register
      if (rnd_ok) begin
        d_i_q <= d_new_i;
        d_q_q <= d_new_q;
      end
    end
  end

  assign d_valid = d_valid_q;
  assign d_i     = d_i_q;
  assign d_q     = d_q_q;
  assign sat_err = sat_err_q;

endmodule

`default_nettype wire
