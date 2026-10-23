# 04 — Interface specification

**Version:** 1.0-vi. Input/output đều cùng `clk`; không AXI, CSR hay RAM interface trong compute core.

## 1. Clock và transaction start

```systemverilog
input  logic clk;
input  logic rst_n;
input  logic cfg_valid;
output logic cfg_ready;
output logic busy;
```

Reset active-low, synchronous tại rising edge trong core này. Wrapper xử lý asynchronous reset synchronization nếu cần. Transfer = `valid && ready` tại rising edge. Producer giữ valid và toàn bộ payload khi valid=1, ready=0. Cùng quy tắc áp dụng config, data, result và mọi internal stream.

`cfg_ready=1` chỉ IDLE. `busy` lên sau config handshake và xuống sau result handshake hoặc reset. Các latch snapshot phục vụ transaction hiện tại, không tạo control plane lưu cấu hình cho software.

## 2. Config ports

| Port | Width | Legal value | Consumer / ý nghĩa |
|---|---:|---|---|
| `cfg_m_bit` | 2 | 1,2 | Modulation/MLE; số UCI bits |
| `cfg_nsymb` | 4 | 4..14 | Controller/RX; PUCCH duration |
| `cfg_start_symbol` | 4 | 0..10, đồng thời start+nsymb≤14 | Low-PAPR/tag derivation |
| `cfg_intra_slot_hopping` | 1 | 0,1 | Controller/Gen/RX |
| `cfg_group_hopping_mode` | 2 | 0=neither,1=enable,2=disable; 3 invalid | Low-PAPR Gen |
| `cfg_n_id` | 10 | 0..1023 | Effective hoppingId/cell-ID input |
| `cfg_m0` | 4 | 0..11 | Low-PAPR Gen, initial cyclic shift |
| `cfg_occ_i` | 3 | 0..min(N_SF active)-1 | RX inverse, time-domain OCC index |
| `cfg_slot_idx` | 5 | 0..19 | Low-PAPR Gen; slot trong frame, μ=1 |

Mọi field được sample cùng config handshake. `start+nsymb` tính với ít nhất 5 bits tránh overflow4. `cfg_n_id` không phân biệt có/không hoppingId; lựa chọn nguồn được thực hiện ngoài core. Không nhận `uci_bits` thực tế làm config: generator tự enumerate toàn bộ tổ hợp.

Không cần frame_idx cho Gold của baseline: mỗi transaction reinitialize PRBS, bit offset dựa slot trong frame. Không có live symbol_idx; absolute symbol derive từ snapshot và q. PRB, second-hop PRB và antenna index là ownership upstream extraction.

## 3. Y_hat stream input

Producer của interface là **RE Extraction bên ngoài**. RG mà producer đọc mặc định đã qua channel estimation và equalization; producer xuất trực tiếp các PUCCH data RE từ RG đó dưới dạng `Y_hat`, giữ convention I/Q sau equalization. Không yêu cầu khối estimation/equalization ở sau RE Extraction hoặc trong core.

```systemverilog
input  logic               y_valid;
output logic               y_ready;
input  logic signed [15:0] y_i;
input  logic signed [15:0] y_q;
input  logic        [6:0]  y_sample_q;
input  logic               y_first;
input  logic               y_last;
```

I/Q F15, một complex RE/transfer. Không mang DM-RS. `y_sample_q` là counter 0..83, **khác** `y_q` là thành phần quadrature. Không pack I/Q implicit; nếu wrapper pack word thì `{I[15:0],Q[15:0]}`.

Canonical order: global data symbol tăng, trong đó hop0 trước hop1 nếu hopping; mỗi data symbol n=0..11. Input `y_first` chỉ tại q=0, `y_last` chỉ tại q=N_RE-1. Markers đều phải đúng; core derive expected values và kiểm tra khi handshake.

`y_ready=0` trong IDLE, VALIDATE, PREPARE, DRAIN, NORMALIZE, DETECT, REPORT và khi phase join không có chỗ. Producer có thể giữ first RE từ PREPARE đến RECEIVE. Không yêu cầu data stream liên tục; valid gap không tiến counters. Sau accepted last, không nhận extra RE cho transaction cũ. Một sample extra được producer giữ đến config tiếp theo sẽ bị kiểm tra theo q/first của transaction mới; core không thể biết ý định producer khi chưa handshake.

## 4. Result output

```systemverilog
output logic               res_valid;
input  logic               res_ready;
output logic               res_error;
output logic        [3:0]  res_error_code;
output logic        [1:0]  res_m_bit;
output logic        [1:0]  res_candidate_idx;
output logic        [1:0]  res_uci_bits;
output logic signed [25:0] res_d_rx_i;
output logic signed [25:0] res_d_rx_q;
output logic signed [42:0] res_metric_best;
output logic signed [42:0] res_metric_second;
output logic        [43:0] res_metric_gap;
```

`res_valid` nghĩa record hợp lệ, bao gồm success **hoặc error**. `res_error=0` mới được diễn giải UCI và metrics. Success: error_code=0, d_rx F15, metrics F30. `res_uci_bits[0]=b0`, `[1]=b1`; one-bit mode `[1]=0`. `candidate_idx` theo bảng algorithm, không cùng packing với `uci_bits`.

Error record: `res_error=1`, error_code nonzero; tất cả payload numeric/uci/candidate bằng 0; `res_m_bit` giữ config đã nhận kể cả invalid value. Result/payload giữ nguyên đến handshake. Result data không được dùng khi `res_valid=0`.

| Code | Tên | Điều kiện |
|---:|---|---|
| 0 | NONE | Success |
| 1 | CFG_RANGE | Invalid ranges/start+length/mode |
| 2 | CFG_OCC | OCC index không hợp lệ ở một hop active |
| 3 | SAMPLE_ORDER | `y_sample_q != q_expected` |
| 4 | SAMPLE_MARKER | first/last khác expected |
| 5 | NUMERIC | CORDIC, sum, normalize hoặc metric overflow/saturation |
| 6 | INTERNAL_ALIGN | phase/data tags khác nhau hoặc LUT address invalid |

Trong cùng edge, priority config range → config OCC → alignment → sample order → sample marker → numeric. Lỗi đầu tiên đã latch giữ đến REPORT. Khi error phát hiện, `y_ready` xuống, in-flight valid tokens bị flush; chưa có transaction mới cho đến error record được nhận. Source upstream phải bỏ phần stream còn lại của transaction bị lỗi và bắt đầu lại với config mới.

Không timeout cho missing RE hay consumer stall trong baseline. Nếu cần watchdog thì thêm rõ timeout config và error code trong revision sau.

## 5. Controller fan-out

Snapshot ports nội bộ giữ toàn bộ transaction. `txn_start` pulse một enabled edge sau validation cho bốn khối; controller phát K/N_RE/N_SF derived, không yêu cầu consumer đọc live top config. Không có independent starts từ software cho từng module.

| Derived field | Width | Range |
|---|---:|---|
| `n_re` | 7 | 24,36,48,60,72,84 |
| `n_sf0`, `n_sf1` | 3 mỗi field | 1..7; n_sf1=0 nếu no hop |
| `candidate_count` | 3 | 2 hoặc 4 |
| `q_expected` | 7 | 0..N_RE-1 |
| `hop` | 1 | 0/1 |
| `m` | 3 | 0..N_SF[hop]-1 |
| `n` | 4 | 0..11 |
| `l_abs` | 4 | 0..13 |

## 6. Low-PAPR → RX phase stream

```systemverilog
output logic        phase_valid;
input  logic        phase_ready;
output logic [15:0] r_phase;
output logic [6:0]  phase_sample_q;
output logic        phase_hop;
output logic [2:0]  phase_m;
output logic [3:0]  phase_n;
output logic [3:0]  phase_l_abs;
output logic        phase_first;
output logic        phase_last;
```

`r_phase` gồm base+CS; chưa có OCC/modulation. Response được giữ khi stall. Controller join phase tag với data tag. Baseline transfer hai stream đồng thời: `y_ready=RECEIVE && phase_valid && join_ready`, `phase_ready=RECEIVE && y_valid && join_ready`. Không consume phase trước khi consume data; producer phase phải tạo valid độc lập ready để tránh deadlock. `phase_first/last` theo cùng q boundaries với data stream.

RX inverse có input phase bằng các tên tương ứng và config `occ_i`, `n_sf0/1`, `n_re`. Low-PAPR Gen có input snapshot `n_id`, mode, slot, start_symbol, nsymb, hopping, m0. Generator output `gen_ready` sau PREPARE và controller chỉ nhận data khi phase path sẵn sàng.

## 7. Modulation → MLE candidate table

Logical contract dùng parallel table một transfer cho toàn bộ K symbols:

```systemverilog
output logic               cand_valid;
input  logic               cand_ready;
output logic        [3:0]  cand_mask;
output logic        [1:0]  cand_m_bit;
output logic signed [15:0] cand_i [0:3];
output logic signed [15:0] cand_q [0:3];
output logic        [15:0] cand_phase [0:3];
output logic        [1:0]  cand_bits [0:3];
```

Array index = k. One-bit mask `4'b0011`, two-bit `4'b1111`. Inactive entries bằng 0. `cand_bits` là packed output UCI convention, không binary k. MLE capture toàn table một lần/transaction; giữ table đến scalar detection. Có thể flatten arrays thành buses khi integration nhưng giữ array-order contract.

`cand_m_bit` phải bằng snapshot M_bit; mismatch là INTERNAL_ALIGN. MLE không được compare với candidate table của transaction trước.

## 8. RX inverse → MLE scalar stream

```systemverilog
output logic               d_valid;
input  logic               d_ready;
output logic signed [25:0] d_i;
output logic signed [25:0] d_q;
output logic        [6:0]  d_n_re;
```

Một transfer/transaction, F15, đã bù gain và count. `d_n_re` debug/checking, không scale candidate lại. MLE chỉ assert d_ready khi đã có table và đủ chỗ result. Controller bảo đảm error không forward d_valid. Một context nên không cần transaction_id; extension multi-context bắt buộc bổ sung ID trên mọi stream.

## 9. Internal CORDIC/accumulator

Input CORDIC: signed16 F15 I/Q, phase16, valid/ready, q7/first/last. Output: signed18 F15 I/Q có A16 gain, valid/ready, cùng tag. Pipeline qua quadrant/iterations/output như Architecture.

Accumulator nhận output khi `valid && ready`; output sum signed26 F15 được publish đúng một lần sau accepted last. `first` không được dùng để clear accumulator ở chu kỳ valid=0 hoặc ready=0.

## 10. Ví dụ timing handshake

```text
edge C0: cfg_valid=cfg_ready=1 -> capture context
after C0: busy=1, cfg_ready=0, y_ready=0
PREPARE complete -> RECEIVE
edge Y0: y_valid=y_ready=1, q=0, first=1
gap/stall: mọi accepted counters và token bị giữ đúng contract
edge YL: accept q=N_RE-1, last=1
DRAIN -> NORMALIZE -> DETECT -> REPORT
REPORT: res_valid=1; nếu res_ready=0 thì giữ payload, busy=1
edge R0: res_valid=res_ready=1
after R0: IDLE, busy=0, cfg_ready=1, res_valid=0
```

Không nhận config mới trong edge R0 theo baseline, vì cfg_ready vẫn 0 trước edge đó; có thể nhận từ edge tiếp theo. Reset ở bất kỳ state flush snapshot valid, joins, pipeline valids, sums, table valid, result và error; ROM constant không reset.
