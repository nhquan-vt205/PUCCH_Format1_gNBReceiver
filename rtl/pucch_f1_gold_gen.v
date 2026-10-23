// ============================================================================
// Module : pucch_f1_gold_gen
// Length-31 Gold sequence generator (TS 38.211 5.2.1). On start: x1 = 1,
// x2 = c_init, 1600 warm-up shifts, then c(t) one bit per clock with index t.
// Spec    : doc/spec/architecture/pucch_f1_gold_gen_spec.md
// Diagram : doc/diagram/pucch_f1_gold_gen/pucch_f1_gold_gen.svg (L2)
// Revision: 2.0 - regenerated from the S2 SVG model
// ============================================================================
`default_nettype none

module pucch_f1_gold_gen (
  input  wire        clk,      // clock, rising edge
  input  wire        rst_n,    // synchronous active-low reset
  input  wire        start,    // load init, begin warm-up
  input  wire        clr,      // stop and clear (priority over start)
  input  wire [30:0] c_init,   // initial value of x2
  output wire        c_valid,  // c_bit valid
  output wire        c_bit,    // c(t)
  output wire [11:0] c_idx     // t
);

  // State registers
  reg  [30:0] x1_q;        // bit k = x1(t+k)
  reg  [30:0] x2_q;        // bit k = x2(t+k)
  reg  [10:0] warm_cnt_q;  // warm-up shifts done
  reg  [11:0] c_idx_q;     // output index t
  reg         run_q;       // running
  reg         out_q;       // output phase

  // Next-value signals
  wire        x1_fb;
  wire        x2_fb;
  wire [30:0] x1_d;
  wire [30:0] x2_d;
  wire [10:0] warm_cnt_d;
  wire [11:0] c_idx_d;
  wire        warm_en;
  wire        warm_done;
  wire        idx_last;
  wire        set_out;
  wire        stop;
  wire        out_d;
  wire        run_d;

  // LFSR feedback and shift
  assign x1_fb = x1_q[3] ^ x1_q[0];
  assign x2_fb = x2_q[3] ^ x2_q[2] ^ x2_q[1] ^ x2_q[0];
  assign x1_d  = start ? 31'd1  : (run_q ? {x1_fb, x1_q[30:1]} : x1_q);
  assign x2_d  = start ? c_init : (run_q ? {x2_fb, x2_q[30:1]} : x2_q);

  // Warm-up and output counters
  assign warm_en    = run_q & ~out_q;
  assign c_valid    = run_q & out_q;
  assign warm_done  = (warm_cnt_q == 11'd1599);
  assign idx_last   = (c_idx_q == 12'd4095);
  assign warm_cnt_d = start ? 11'd0 : (warm_en ? warm_cnt_q + 11'd1 : warm_cnt_q);
  assign c_idx_d    = start ? 12'd0 : (c_valid ? c_idx_q + 12'd1 : c_idx_q);

  // Run / output phase control
  assign set_out = warm_en & warm_done;
  assign stop    = c_valid & idx_last;
  assign out_d   = (out_q | set_out) & ~(clr | start | stop);
  assign run_d   = (start | (run_q & ~stop)) & ~clr;

  always @(posedge clk) begin
    if (!rst_n) begin
      x1_q       <= 31'd0;
      x2_q       <= 31'd0;
      warm_cnt_q <= 11'd0;
      c_idx_q    <= 12'd0;
      run_q      <= 1'b0;
      out_q      <= 1'b0;
    end
    else begin
      x1_q       <= x1_d;
      x2_q       <= x2_d;
      warm_cnt_q <= warm_cnt_d;
      c_idx_q    <= c_idx_d;
      run_q      <= run_d;
      out_q      <= out_d;
    end
  end

  assign c_bit = x1_q[0] ^ x2_q[0];
  assign c_idx = c_idx_q;

endmodule

`default_nettype wire
