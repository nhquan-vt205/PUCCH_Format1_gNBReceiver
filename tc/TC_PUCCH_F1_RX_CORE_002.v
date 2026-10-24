// ============================================================================
// TC_PUCCH_F1_RX_CORE_002 - bit-exact golden record (input gaps + result stall)
// Every case with an EXP line, with input gaps and a result stall; the full
// result record must equal the bit-exact reference model.
// Copied to sim/run_test.v and included inside tb_pucch_f1_rx_core.
// ============================================================================
  initial begin
    init_test;
    reset_dut;
    $display("-- Bit-exact golden record with stall test --");
    open_data;
    while (case_valid) begin
      if (has_exp) begin
        run_case(1'b1, cur_id % 4);
        $sformat(case_name, "case_%0d_frame_%0d_%0s_stall%0d_vs_golden", cur_id, src_frame, cfg_tag, cur_id % 4);
        check_record(case_name, ref_record, act_record);
      end
      else begin
        $display("[INFO] case_%0d skipped: no EXP line", cur_id);
      end
      load_case;
    end
    close_data;
    end_test;
  end
