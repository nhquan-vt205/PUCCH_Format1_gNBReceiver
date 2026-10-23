# PUCCH Format 1 gNB Receiver — Inverse Phase Spec Set

**Phiên bản:** 1.0-vi · **Ngày:** 2026-10-08  
**Trạng thái:** baseline đặc tả mới theo yêu cầu người thiết kế; chưa phải RTL đã kiểm chứng hoặc sign-off synthesis.

## Thiết kế được đặc tả

```text
                        config field ports
                      /         |         \
              Low-PAPR Gen    RX inverse   Modulation candidates
              r_base + CS       ^          bits -> d_k(0)
                  |             |                 |
                  +-- phase --->|                 |
  Y_hat từ RE Extraction ------+                 |
                      RX inverse: + OCC phase      |
                      -> một lần derotation        |
                      -> coherent sum              |
                      -> gain/count normalization  |
                      -> d_rx(0), một số phức ------+--> scalar MLE -> UCI
```

Có đúng bốn khối tính toán chức năng: `pucch_f1_rx_inverse`, `pucch_f1_mod_candidates`, `pucch_f1_scalar_mle`, `pucch_f1_lowpapr_phase_gen`. Controller, LUT, thanh ghi và CORDIC là thành phần hỗ trợ hoặc submodule. Nhánh modulation chỉ sinh 2/4 **symbol** `d_k(0)`, không sinh chuỗi phát đầy đủ.

**Upstream contract:** Resource Grid (RG) mà RE Extraction bên ngoài đọc mặc định đã qua channel estimation và equalization. RE Extraction chọn các PUCCH data RE từ RG đó và xuất trực tiếp `Y_hat` vào core:

```text
channel estimation/equalization -> RG đã equalize -> RE Extraction bên ngoài
    -> Y_hat data RE stream -> inverse phase core
```

RE Extraction giữ convention I/Q của RG khi trích xuất; không có bước estimation/equalization bổ sung giữa RE Extraction và core. Core bắt đầu tại port `Y_hat`; RG và các khối xử lý upstream nằm ngoài phạm vi.

`d_rx(0)` là ước lượng phức liên tục có I và Q, chưa quyết định cứng; `d_k(0)` là điểm constellation chuẩn; `Z` là tổng chưa chuẩn hóa. Ba tên này có ý nghĩa khác nhau. Một số phức có hai thành phần I/Q; không ép giá trị thu thành một góc pha hay một số thực.

## Bộ tài liệu

| File | Nội dung |
|---|---|
| [01_Requirements.md](01_Requirements.md) | Phạm vi, yêu cầu đánh số, điều kiện MLE và tiêu chí chấp nhận |
| [02_Architecture.md](02_Architecture.md) | Bốn khối, ownership, scheduling, datapath, bộ nhớ và performance |
| [03_Algorithm.md](03_Algorithm.md) | Chiều xuôi tham chiếu, chiều ngược, cộng pha, CORDIC, chuẩn hóa, MLE |
| [04_Interface.md](04_Interface.md) | Port config, handshake, thứ tự RE, port nội bộ, reset/error/result |
| [05_LUT.md](05_LUT.md) | Định dạng pha, địa chỉ ROM, bảng đầy đủ, artifact và cách tái sinh |
| [06_Freeze_and_Verification.md](06_Freeze_and_Verification.md) | Thay đổi freeze cũ, quyết định mới, ma trận verification, việc còn lại trước RTL sign-off |
| [07_LUT_Consolidated.md](07_LUT_Consolidated.md) | Một file tổng hợp đầy đủ phi, phase16 r(n), OCC, CS, N_SF, modulation và CORDIC từ CSV/MEM |

`lut/` chứa ROM `.mem`, bảng `.csv`, hằng số và checksum. `tools/build_luts.py` tái sinh LUT; `tools/check_spec.py` kiểm tra artifact và các tính chất thuật toán được liệt kê trong báo cáo kiểm tra.

## Nguồn và thứ tự authority

1. Yêu cầu hiện tại của người thiết kế: receiver chiều ngược, scalar MLE, cấu hình bằng input port.
2. Bộ spec mới này: hợp đồng chức năng và số học cho kiến trúc đó.
3. Hai bộ nguồn trong workspace: giữ các định nghĩa phù hợp; thay các freeze mâu thuẫn theo Document 06.

Nguồn cục bộ:

- `../PUCCH_F1_Receiver_Design_Combined_v1.5_vi/`: nền thuật toán chiều ngược.
- `../PUCCH_F1_Design_Ready_Spec_Set_v1.3_VI/`: nền interface, kiểm chứng và dữ liệu LUT; kiến trúc direct sequence của bộ này không áp dụng cho core mới.

Đã đối chiếu các điểm xung đột tại §6.3.2.2.1 và Table 6.3.2.4.1-2 với [ETSI TS 138 211 V15.10.0](https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/15.10.00_60/ts_138211v151000p.pdf). Chi tiết sửa lỗi ở Document 06. Bảng base/OCC/N_SF trong bộ mới được chuyển đổi từ dữ liệu có trong tài liệu người dùng cung cấp.

## Đọc và triển khai

Đọc 01 → 02 → 03 → 04 → 05 → 06. Nếu đổi numeric width, quantization hoặc metric thì cập nhật đồng thời algorithm, interface, LUT và verification. Config RAM, CSR, AXI, decode/extract field và RE extractor sẽ được bọc bên ngoài sau; core hiện tại nhận trực tiếp các field đã tách.
