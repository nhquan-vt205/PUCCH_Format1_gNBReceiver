// ============================================================================
// tb_pucch_f1_rx_core - self-checking data-driven testbench for pucch_f1_rx_core
// Test data (format: doc/report/pucch_f1_rx_core_tb_data_format.md):
//   +IN=<file>  input file  : CFG + RE lines per CASE (everything driven into the DUT)
//               default ../doc/database/input/pucch_f1_rx_core_input.txt (relative to sim/)
//   +OUT=<file> output file : SRC / TX / MATLAB / EXP lines per CASE (reference)
//               default ../doc/database/output/pucch_f1_rx_core_output.txt (relative to sim/)
// Both files are streamed one CASE at a time, so the case count is unbounded.
// Test cases: testcases/<TESTNAME>.v, copied to sim/run_test.v by "make build"
// and included at the end of this module (section 9).
//   TC_PUCCH_F1_RX_CORE_001 - MATLAB decoded bits (continuous stream, no stall)
//   TC_PUCCH_F1_RX_CORE_002 - bit-exact golden record (input gaps + result stall)
// ============================================================================
`timescale 1ns/1ps

module tb_pucch_f1_rx_core;

  // ============================================================
  // 1. Declaration
  // ============================================================
  parameter      CLK_PERIOD   = 20;
  parameter      RESET_CYCLES = 5;
  parameter real TIMEOUT_NS   = 1.0e10;
  parameter      WAIT_MAX     = 10000;  // max cycles waiting for one handshake
  parameter      RE_MAX       = 128;    // RE lines kept per case (y_sample_q is 7 bits)

  reg          clk;
  reg          rst_n;
  reg          cfg_valid;
  wire         cfg_ready;
  wire         busy;
  reg  [1:0]   cfg_m_bit;
  reg  [3:0]   cfg_nsymb;
  reg  [3:0]   cfg_start_symbol;
  reg          cfg_intra_slot_hopping;
  reg  [1:0]   cfg_group_hopping_mode;
  reg  [9:0]   cfg_n_id;
  reg  [3:0]   cfg_m0;
  reg  [2:0]   cfg_occ_i;
  reg  [4:0]   cfg_slot_idx;
  reg          y_valid;
  wire         y_ready;
  reg  [15:0]  y_i;
  reg  [15:0]  y_q;
  reg  [6:0]   y_sample_q;
  reg          y_first;
  reg          y_last;
  wire         res_valid;
  reg          res_ready;
  wire         res_error;
  wire [3:0]   res_error_code;
  wire [1:0]   res_m_bit;
  wire [1:0]   res_candidate_idx;
  wire [1:0]   res_uci_bits;
  wire [25:0]  res_d_rx_i;
  wire [25:0]  res_d_rx_q;
  wire [42:0]  res_metric_best;
  wire [42:0]  res_metric_second;
  wire [43:0]  res_metric_gap;

  // File reading
  reg  [8*256-1:0]   in_path;
  reg  [8*256-1:0]   out_path;
  integer            fd_in;
  integer            fd_out;
  reg  [8*1024-1:0]  line;
  reg  [8*16-1:0]    key;
  reg                eof;
  integer            nf;
  integer            v0, v1, v2, v3, v4, v5, v6, v7, v8;
  reg  signed [63:0] x_di, x_dq, x_best, x_second, x_gap;

  // Current case: input side (stimulus)
  reg                case_valid;
  integer            cur_id;
  integer            out_id;
  reg  [35:0]        c_cfg;              // {m_bit, nsymb, start, hop, gh, n_id, m0, occ, slot}
  reg  [6:0]         re_sq    [0:RE_MAX-1];
  reg                re_first [0:RE_MAX-1];
  reg                re_last  [0:RE_MAX-1];
  reg  [15:0]        re_i     [0:RE_MAX-1];
  reg  [15:0]        re_q     [0:RE_MAX-1];
  integer            n_re_in;

  // Current case: output side (reference)
  integer            src_frame;
  real               src_snr;
  integer            tx_b0, tx_b1;
  integer            mat_valid, mat_b0, mat_b1;
  reg                has_exp;
  reg  [192:0]       ref_record;         // {err, code, m_bit, k, bits, di, dq, best, second, gap}
  reg  [2:0]         ref_matlab;         // {err = 0, b1, b0}

  // Captured DUT result record
  reg  [192:0]       act_record;
  reg  [2:0]         act_bits;

  integer            pass_count;
  integer            fail_count;
  integer            tx_cases;
  integer            tx_errors;
  integer            wait_cnt;
  integer            re_idx;
  integer            gap;
  reg                aborted;
  reg  [8*96-1:0]    cfg_tag;
  reg  [8*160-1:0]   case_name;
  reg  [8*200-1:0]   exp_str;
  reg  [8*200-1:0]   act_str;

  // ============================================================
  // 2. DUT Instance
  // ============================================================
  pucch_f1_rx_core u_dut (
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
    .y_i                    (y_i),
    .y_q                    (y_q),
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
    .res_metric_gap         (res_metric_gap)
  );

  // ============================================================
  // 3. Clock Generation
  // ============================================================
  initial begin
    clk = 1'b0;
  end

  always #(CLK_PERIOD / 2) clk = ~clk;

  // ============================================================
  // 4. Init Reset
  // ============================================================
  // Synchronous active-low reset: assert and release at posedge + #1
  task reset_dut;
    begin
      @(posedge clk);
      #1;
      rst_n                  = 1'b0;
      cfg_valid              = 1'b0;
      cfg_m_bit              = 2'd0;
      cfg_nsymb              = 4'd0;
      cfg_start_symbol       = 4'd0;
      cfg_intra_slot_hopping = 1'b0;
      cfg_group_hopping_mode = 2'd0;
      cfg_n_id               = 10'd0;
      cfg_m0                 = 4'd0;
      cfg_occ_i              = 3'd0;
      cfg_slot_idx           = 5'd0;
      y_valid                = 1'b0;
      y_i                    = 16'd0;
      y_q                    = 16'd0;
      y_sample_q             = 7'd0;
      y_first                = 1'b0;
      y_last                 = 1'b0;
      res_ready              = 1'b0;
      ref_reset;
      repeat (RESET_CYCLES) @(posedge clk);
      #1;
      rst_n = 1'b1;
    end
  endtask

  // ============================================================
  // 5. Golden Reference Model
  // ============================================================
  // Reference values come from the output file: MATLAB decoded bits (MATLAB
  // line) and the bit-exact model record of source 03 (EXP line, written by
  // gen_vectors.py or by the MATLAB export).
  task ref_reset;
    begin
      src_frame  = -1;
      src_snr    = 0.0;
      tx_b0      = -1;
      tx_b1      = -1;
      mat_valid  = -1;
      mat_b0     = -1;
      mat_b1     = -1;
      has_exp    = 1'b0;
      ref_record = 193'd0;
      ref_matlab = 3'd0;
    end
  endtask

  // Read the next line of fd into line / key (key = first token, 0 if empty)
  task next_line;
    input integer fd;
    begin
      line = 0;
      key  = 0;
      if ($fgets(line, fd) == 0) begin
        eof = 1'b1;
      end
      else begin
        eof = 1'b0;
        nf  = $sscanf(line, "%s", key);
      end
    end
  endtask

  // Load the next CASE of both files; case_valid = 0 at end of file
  task load_case;
    begin
      case_valid = 1'b0;
      ref_reset;
      // input file: CASE, CFG, RE..., END
      eof = 1'b0;
      key = 0;
      while (!eof && key != "CASE") next_line(fd_in);
      if (!eof) begin
        nf      = $sscanf(line, "%s %d", key, cur_id);
        n_re_in = 0;
        c_cfg   = 36'd0;
        next_line(fd_in);
        while (!eof && key != "END") begin
          if (key == "CFG") begin
            nf    = $sscanf(line, "%s %d %d %d %d %d %d %d %d %d", key, v0, v1, v2, v3, v4, v5, v6, v7, v8);
            c_cfg = {v0[1:0], v1[3:0], v2[3:0], v3[0], v4[1:0], v5[9:0], v6[3:0], v7[2:0], v8[4:0]};
          end
          else if (key == "RE") begin
            nf = $sscanf(line, "%s %d %d %d %d %d", key, v0, v1, v2, v3, v4);
            if (n_re_in < RE_MAX) begin
              re_sq[n_re_in]    = v0[6:0];
              re_first[n_re_in] = v1[0];
              re_last[n_re_in]  = v2[0];
              re_i[n_re_in]     = v3[15:0];
              re_q[n_re_in]     = v4[15:0];
            end
            n_re_in = n_re_in + 1;
          end
          next_line(fd_in);
        end
        // output file: CASE, SRC, TX, MATLAB, [EXP], [INFO...], END
        key = 0;
        while (!eof && key != "CASE") next_line(fd_out);
        nf = $sscanf(line, "%s %d", key, out_id);
        next_line(fd_out);
        while (!eof && key != "END") begin
          if (key == "SRC") begin
            nf = $sscanf(line, "%s %d %f", key, src_frame, src_snr);
          end
          else if (key == "TX") begin
            nf = $sscanf(line, "%s %d %d", key, tx_b0, tx_b1);
          end
          else if (key == "MATLAB") begin
            nf = $sscanf(line, "%s %d %d %d", key, mat_valid, mat_b0, mat_b1);
          end
          else if (key == "EXP") begin
            nf = $sscanf(line, "%s %d %d %d %d %d %d %d %d %d %d", key, v0, v1, v2, v3, v4,
                         x_di, x_dq, x_best, x_second, x_gap);
            has_exp    = (nf == 11);
            ref_record = {v0[0], v1[3:0], v2[1:0], v3[1:0], v4[1:0], x_di[25:0], x_dq[25:0],
                          x_best[42:0], x_second[42:0], x_gap[43:0]};
          end
          next_line(fd_out);
        end
        ref_matlab = {1'b0, (mat_b1 < 0) ? 1'b0 : mat_b1[0], mat_b0[0]};
        if (out_id != cur_id) begin
          fail_count = fail_count + 1;
          $display("[ERROR] CASE id mismatch: input %0d, output %0d", cur_id, out_id);
        end
        else begin
          case_valid = 1'b1;
        end
      end
    end
  endtask

  // ============================================================
  // 6. Checker
  // ============================================================
  task check_bits;
    input [8*160-1:0] name;
    input [2:0]       exp;
    input [2:0]       act;
    begin
      if (act === exp) begin
        pass_count = pass_count + 1;
        $display("[%0d] %0s PASS | expected: err=%0d bits=%b | actual: err=%0d bits=%b",
                 $time, name, exp[2], exp[1:0], act[2], act[1:0]);
      end
      else begin
        fail_count = fail_count + 1;
        $display("[%0d] %0s FAIL | expected: err=%0d bits=%b | actual: err=%0d bits=%b",
                 $time, name, exp[2], exp[1:0], act[2], act[1:0]);
      end
    end
  endtask

  task check_record;
    input [8*160-1:0] name;
    input [192:0]     exp;
    input [192:0]     act;
    begin
      fmt_record(exp, exp_str);
      fmt_record(act, act_str);
      if (act === exp) begin
        pass_count = pass_count + 1;
        $display("[%0d] %0s PASS | expected: %0s | actual: %0s", $time, name, exp_str, act_str);
      end
      else begin
        fail_count = fail_count + 1;
        $display("[%0d] %0s FAIL | expected: %0s | actual: %0s", $time, name, exp_str, act_str);
      end
    end
  endtask

  // ============================================================
  // 7. Helper Functions
  // ============================================================
  // Readable form of a 193-bit result record
  task fmt_record;
    input  [192:0]     r;
    output [8*200-1:0] s;
    begin
      $sformat(s, "err=%0d code=%0d mbit=%0d k=%0d bits=%b di=%0d dq=%0d best=%0d second=%0d gap=%0d",
               r[192], r[191:188], r[187:186], r[185:184], r[183:182], $signed(r[181:156]),
               $signed(r[155:130]), $signed(r[129:87]), $signed(r[86:44]), r[43:0]);
    end
  endtask

  // ============================================================
  // 8. Tasks
  // ============================================================
  // Open both data files and load the first case
  task open_data;
    begin
      fd_in  = $fopen(in_path, "r");
      fd_out = $fopen(out_path, "r");
      if (fd_in == 0 || fd_out == 0) begin
        $display("[FATAL] cannot open %0s or %0s", in_path, out_path);
        fail_count = fail_count + 1;
        end_test;
      end
      load_case;
    end
  endtask

  task close_data;
    begin
      $fclose(fd_in);
      $fclose(fd_out);
    end
  endtask

  // Config handshake with the CFG line of the current case
  task send_cfg;
    begin
      @(posedge clk);
      #1;
      cfg_valid = 1'b1;
      {cfg_m_bit, cfg_nsymb, cfg_start_symbol, cfg_intra_slot_hopping, cfg_group_hopping_mode,
       cfg_n_id, cfg_m0, cfg_occ_i, cfg_slot_idx} = c_cfg;
      wait_cnt = 0;
      while (!cfg_ready && wait_cnt < WAIT_MAX) begin
        @(posedge clk);
        #1;
        wait_cnt = wait_cnt + 1;
      end
      @(posedge clk);
      #1;
      cfg_valid = 1'b0;
    end
  endtask

  // Stream the RE lines of the current case exactly as written (q, first,
  // last, I, Q); with_gap inserts idle cycles. Stops early when the DUT
  // already reports a result (error record).
  task send_res;
    input with_gap;
    begin
      re_idx  = 0;
      aborted = 1'b0;
      while (re_idx < n_re_in && re_idx < RE_MAX && !aborted) begin
        gap = with_gap ? ((re_idx * 7 + cur_id) % 3) : 0;
        if (gap > 0) begin
          @(posedge clk);
          #1;
          y_valid = 1'b0;
          repeat (gap - 1) @(posedge clk);
        end
        @(posedge clk);
        #1;
        y_valid    = 1'b1;
        y_i        = re_i[re_idx];
        y_q        = re_q[re_idx];
        y_sample_q = re_sq[re_idx];
        y_first    = re_first[re_idx];
        y_last     = re_last[re_idx];
        wait_cnt   = 0;
        while (!y_ready && !res_valid && wait_cnt < WAIT_MAX) begin
          @(posedge clk);
          #1;
          wait_cnt = wait_cnt + 1;
        end
        if (!y_ready) begin
          aborted = 1'b1;
          y_valid = 1'b0;
        end
        re_idx = re_idx + 1;
      end
      @(posedge clk);
      #1;
      y_valid = 1'b0;
      y_first = 1'b0;
      y_last  = 1'b0;
    end
  endtask

  // Wait for the result record, optionally stall res_ready, capture it
  task get_result;
    input integer stall;
    begin
      @(posedge clk);
      #1;
      res_ready = (stall == 0);
      wait_cnt  = 0;
      while (!res_valid && wait_cnt < WAIT_MAX) begin
        @(posedge clk);
        #1;
        wait_cnt = wait_cnt + 1;
      end
      if (stall > 0) begin
        repeat (stall) @(posedge clk);
        #1;
        res_ready = 1'b1;
      end
      act_bits   = {res_error, res_uci_bits};
      act_record = {res_error, res_error_code, res_m_bit, res_candidate_idx, res_uci_bits, res_d_rx_i,
                    res_d_rx_q, res_metric_best, res_metric_second, res_metric_gap};
      @(posedge clk);
      #1;
      res_ready = 1'b0;
    end
  endtask

  // One full transaction for the current case
  task run_case;
    input         with_gap;
    input integer stall;
    begin
      send_cfg;
      send_res(with_gap);
      get_result(stall);
      $sformat(cfg_tag, "m%0d_L%0d_s%0d_h%0d_g%0d_nid%0d_cs%0d_occ%0d_slot%0d",
               cfg_m_bit, cfg_nsymb, cfg_start_symbol, cfg_intra_slot_hopping, cfg_group_hopping_mode,
               cfg_n_id, cfg_m0, cfg_occ_i, cfg_slot_idx);
    end
  endtask

  // Counters and data file paths; call first in every test case
  task init_test;
    begin
      pass_count = 0;
      fail_count = 0;
      if (!$value$plusargs("IN=%s", in_path)) begin
        in_path = "../doc/database/input/pucch_f1_rx_core_input.txt";
      end
      if (!$value$plusargs("OUT=%s", out_path)) begin
        out_path = "../doc/database/output/pucch_f1_rx_core_output.txt";
      end
    end
  endtask

  // Summary and overall result (read by sim/report.csh); ends the simulation
  task end_test;
    begin
      $display("[SUMMARY] PASS=%0d FAIL=%0d", pass_count, fail_count);
      if (fail_count == 0 && pass_count > 0) begin
        $display("Test_result: PASSED");
      end
      else begin
        $display("Test_result: FAILED");
      end
      $finish;
    end
  endtask

  // ============================================================
  // 9. Main Program Body
  // ============================================================
  // Test sequence of the selected test case (testcases/<TESTNAME>.v)
`include "run_test.v"

  initial begin
    #(TIMEOUT_NS);
    $display("[TIMEOUT] simulation exceeded %0g ns", TIMEOUT_NS);
    fail_count = fail_count + 1;
    end_test;
  end

endmodule
