# 01 — Requirements

**Version:** 1.0-vi · **Authority:** baseline mới trong README.

## 1. Phạm vi

| Thuộc phạm vi | Bên ngoài core |
|---|---|
| PUCCH Format 1, một PRB, một receive stream đã equalize | RF, FFT, channel estimation, equalization, antenna combining |
| Nhận data RE `Y_hat` từ RE Extraction bên ngoài, trích xuất từ RG đã estimation/equalization | RG RAM, RE extraction, PRB/address generation, DM-RS processing |
| 1 hoặc 2 UCI bits; 4..14 PUCCH symbols | Format 0/2/3/4, UCI coding pipeline, SR/DTX policy và diễn giải HARQ/SR |
| No hopping hoặc intra-slot hopping; OCC và cyclic shift | Multi-slot repetition/combining, nhiều transaction đồng thời |
| Config field input ports | Config RAM, AXI/CSR, packed field decode |
| FR1, Normal CP, μ=1 (30 kHz), 20 slots/frame | Numerology/CP khác, CDC bên trong core |

Clock tham chiếu triển khai 122.88 MHz; không phải bằng chứng timing closure. Carrier bandwidth không ảnh hưởng arithmetic core sau extraction.

## 2. Yêu cầu chức năng

| ID | Yêu cầu bắt buộc | Kiểm chứng |
|---|---|---|
| R-F01 | RG đầu vào RE Extraction bên ngoài đã qua channel estimation/equalization; core nhận trực tiếp các data RE `Y_hat` trích xuất từ RG đó; DM-RS không được trộn vào transaction | V01, V02 |
| R-F02 | Dùng `M_bit=1` cho 2 candidate và `M_bit=2` cho 4 candidate | V03 |
| R-F03 | Nhánh thu loại base phase, cyclic shift và OCC bằng liên hợp pha | V04, V05 |
| R-F04 | Cộng base/CS/OCC phase rồi quay mỗi RE đúng một lần | V05 |
| R-F05 | Tổng coherent trên tất cả RE và cả hai hop; xuất một `d_rx(0)` | V06 |
| R-F06 | Bù gain CORDIC và chia đúng tổng số RE trước port `d_rx(0)` | V06, V07 |
| R-F07 | Nhánh xuôi chỉ modulation mọi tổ hợp bit thành `d_k(0)` | V03 |
| R-F08 | MLE dùng `d_rx(0)` và candidate table, chọn correlation lớn nhất | V08 |
| R-F09 | Tie chọn candidate index nhỏ hơn; trả đúng `b(0)`, `b(1)` | V08 |
| R-F10 | Low-PAPR generator xuất phase `r(n)`; không cần sinh I/Q sequence ROM | V04 |
| R-F11 | Nhánh modulation không dùng OCC, `u`, cyclic shift hay RE count để thay constellation | V03 |
| R-F12 | Không modulo hoặc unit-normalize biên độ `Y_hat`; giữ thông tin I/Q cho coherent sum | V06 |

OCC là chính block-wise spreading của Format 1. “Despreading” trong thiết kế này gồm conjugate OCC và phép cộng các RE đã quay; không thêm một lớp spreading hay scrambling độc lập không có trong phương trình phát.

## 3. Input và statistical contract

**Điều kiện upstream mặc định:** channel estimation/equalization đã hoàn tất trên RG trước khi RE Extraction bên ngoài đọc/trích xuất. RE Extraction chỉ chọn, sắp thứ tự và xuất các PUCCH data RE dưới dạng `Y_hat`, giữ convention I/Q của RG. Không đặt equalizer sau RE Extraction hoặc bên trong inverse phase core.

Với data RE thứ `q`, đặt `a_q=w_i(m)r_u^{alpha_l}(n)`, `|a_q|=1`:

$$
\hat Y_q=d_{true}a_q+e_q.
$$

Equalizer upstream tạo RG phải đưa channel phase và scaling về convention này trước extraction. `Y_hat` thừa hưởng convention đó từ RG; low-PAPR, cyclic-shift và OCC phase của waveform vẫn còn để core xử lý chiều ngược. Noiseless expected amplitude của symbol là 1; signed Q1.15 có thể clip tại sát +1 và phải được golden model mô phỏng. Core không tự ước lượng channel phase, CFO hay phase offset giữa hai hop.

**R-S01:** baseline MLE giả định `e_q` độc lập circular complex Gaussian với cùng variance và channel gain đã equalize. Under this model, unweighted coherent sum là sufficient statistic cho bit decision. Với variance khác nhau, thiết kế vẫn chạy nhưng không được gọi là exact weighted ML cho kênh đó; mở rộng cần weight ports và sum of weights.

**R-S02:** không suy luận “không có UCI” từ `d_rx=0`; giá trị zero vẫn chọn candidate 0 theo tie. Không có DTX threshold hay confidence threshold baseline.

## 4. Config và transaction

| ID | Yêu cầu |
|---|---|
| R-I01 | Tất cả field cần tính toán đi qua port, capture cùng một `cfg_valid && cfg_ready` |
| R-I02 | Không đọc config live trong transaction; chỉ một context active |
| R-I03 | `cfg_n_id` đã chọn hoppingId hoặc cell ID bên ngoài; core không decode RRC |
| R-I04 | Generator tự tính Gold, `u` và `n_cs` từ field ports; không bắt caller nạp per-RE phase |
| R-I05 | Input stream có ready/valid và `sample_q`, `first`, `last`; tiến state khi handshake |
| R-I06 | `q=0..N_RE-1` đúng thứ tự; subcarrier chạy nhanh nhất; bỏ DM-RS |
| R-I07 | `busy` giữ đến khi result/error đã được consumer nhận |
| R-I08 | Result giữ ổn định trong stall; một result record cho mỗi config được nhận |
| R-I09 | Reset hủy transaction và mọi pending token; không phát result cũ |
| R-I10 | Invalid config, sai thứ tự/marker RE hoặc numerical overflow phát error record, không valid UCI |

Độ dài PUCCH, hopping và OCC phải configurable. Cùng chỉ số OCC dùng cho hai hop; cần `i<N_SF` ở mỗi hop active. Hopping flag quyết định split ngay cả khi hai PRB vật lý trùng nhau; core không cần biết PRB.

## 5. Numeric requirements

| ID | Freeze |
|---|---|
| R-N01 | Input I/Q signed 16 bit, F=15; candidate I/Q cùng representation |
| R-N02 | Pha ngoài unsigned 16 bit, một vòng = 65536; cộng modulo 65536 |
| R-N03 | Base phase `phi*pi/4`, không đổi thành `phi*pi/2` |
| R-N04 | CS dùng remainder accumulator modulo 12 rồi LUT, tránh sai lệch do lặp bước pha đã lượng tử |
| R-N05 | OCC dùng bảng theo `N_SF`, đặc biệt `N_SF=4` dùng bảng Walsh |
| R-N06 | CORDIC 16 iterations; I/Q nội bộ 24 bit F21, góc nội bộ 24 bit |
| R-N07 | CORDIC output 18 bit F15; coherent sum 26 bit F15 |
| R-N08 | `d_rx` 26 bit F15; normalization một lần cuối; không clip về Q1.15 |
| R-N09 | MLE products 42-bit signed, sum/metric 43-bit signed; gap 44-bit unsigned |
| R-N10 | Phase LUT dùng floor cho phân số không âm; I/Q chuyển precision dùng RNE rồi saturation |
| R-N11 | Saturation/overflow là numerical error, không wrap signed I/Q hay metric |

RNE = round-to-nearest-even; các bước shift-add trong CORDIC dùng arithmetic right shift, không RNE mỗi iteration. Gain compensation và divider phải đúng quy tắc trong Document 03.

## 6. Hiệu năng và tiêu chí chấp nhận

Maximum input count = 84 complex RE/transaction. Input cho phép gap và backpressure bất kỳ; producer phải cuối cùng cung cấp đủ RE, consumer phải cuối cùng nhận result. Không cam kết thời gian hoàn thành khi environment stall vô hạn.

Baseline pipeline có thể nhận 1 RE/clock sau PREPARE, nếu downstream không stall. Không buffer toàn bộ 84 RE để lặp lại cho 4 candidates. Latency của Gold prep và normalization phải được báo cáo khi chốt microarchitecture; mục tiêu tương ứng ≤3904 và ≤64 clocks, không tính external stall.

Chấp nhận functional model khi mọi legal config/candidate trong ma trận V01..V12 ở Document 06 được bao phủ, và noiseless I/Q đã quantize được decode đúng. RTL sign-off yêu cầu bit-exact CORDIC/normalization, stall/reset/error tests và synthesis/timing riêng. Script kiểm tra đi kèm chỉ kiểm tra phần được ghi trong báo cáo; không thay thế RTL verification.
