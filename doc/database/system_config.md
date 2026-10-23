# Cấu hình hệ thống mô phỏng PUCCH Format 1

## 1. Tổng quan hệ thống

Hệ thống mô phỏng đường lên **5G NR PUCCH Format 1** với cấu hình **SISO 1×1**, truyền qua kênh **TDL-A**.

Luồng xử lý chính:

```text
UCI bits
   ↓
PUCCH Format 1 Modulation
   ↓
Resource Grid Mapping
   ↓
OFDM Modulation
   ↓
TDL-A Channel
   ↓
AWGN
   ↓
OFDM Demodulation
   ↓
DM-RS Channel Estimation
   ↓
MMSE Equalization
   ↓
PUCCH Decode
   ↓
Decoded UCI bits
```

---

## 2. Simulation Configuration

| Tham số | Giá trị | Ý nghĩa |
|---|---:|---|
| Random Seed | 42 | Seed cho quá trình sinh dữ liệu ngẫu nhiên |
| SNR Range | -30:2:20 dB | Dải SNR khảo sát |
| Minimum Frames / SNR | 50 | Số frame tối thiểu cho mỗi mức SNR |
| Maximum Frames / SNR | 100 | Số frame tối đa cho mỗi mức SNR |
| Target Bit Errors | 25 | Ngưỡng lỗi bit dùng cho early stopping |
| Number of UCI Bits | 2 | Số bit UCI truyền trong mỗi frame |

---

## 3. Carrier Configuration

| Tham số | Giá trị |
|---|---:|
| NCellID | 1 |
| Subcarrier Spacing | 30 kHz |
| Cyclic Prefix | Normal |
| NStartGrid | 0 |
| NSlot | 0 |
| NSizeGrid | 273 PRB |

Cấu hình `273 PRB` với `30 kHz SCS` tương ứng cấu hình carrier danh định khoảng **100 MHz**.

---

## 4. PUCCH Format 1 Configuration

| Tham số | Giá trị |
|---|---|
| PUCCH Format | 1 |
| NSizeBWP | Toàn bộ BWP |
| NStartBWP | Mặc định |
| PRB Set | 10 |
| Symbol Allocation | [0 14] |
| Frequency Hopping | Neither |
| Group Hopping | Neither |
| Hopping ID | 1 |
| Initial Cyclic Shift | 0 |
| OCCI | 0 |

PUCCH được ánh xạ vào **PRB 10** và sử dụng toàn bộ **14 OFDM symbols** trong slot.

---

## 5. Channel Configuration

Kênh truyền sử dụng mô hình **3GPP TDL-A**.

| Tham số | Giá trị |
|---|---:|
| Channel Type | TDL |
| Delay Profile | TDL-A |
| Delay Spread | 100 ns |
| Maximum Doppler Shift | 100 Hz |
| Tx Antennas | 1 |
| Rx Antennas | 1 |
| Random Stream | mt19937ar with seed |
| Channel Seed | 100 |

Cấu hình anten:

```text
1 Tx antenna → TDL-A Channel → 1 Rx antenna
```

Do đó đây là hệ thống **SISO (Single Input Single Output)**.

---

## 6. Receiver Configuration

### 6.1 Timing Synchronization

Sử dụng:

```matlab
nrPerfectTimingEstimate
```

Perfect timing chỉ được dùng để loại bỏ độ trễ do kênh TDL gây ra.

Không sử dụng perfect channel estimation.

---

### 6.2 OFDM Demodulation

Tín hiệu thu miền thời gian được chuyển về resource grid bằng:

```matlab
frameRxGrid = nrOFDMDemodulate( ...
    carrier, ...
    frameRxWaveform);
```

`frameRxGrid` chính là **resource grid phía thu** sau OFDM demodulation.

---

### 6.3 Channel Estimation

Channel estimation sử dụng **PUCCH DM-RS**:

```matlab
[estimatedChannelGrid,noiseEstimate] = ...
    nrChannelEstimate( ...
        carrier, ...
        frameRxGrid, ...
        dmrsIndices, ...
        txDMRSSymbols);
```

Do đó bộ thu không biết trước channel thực mà phải ước lượng channel từ DM-RS.

---

### 6.4 Resource Extraction

Các resource element thuộc PUCCH được lấy từ resource grid:

```matlab
[rxPUCCHSymbols,estimatedPUCCHChannel] = ...
    nrExtractResources( ...
        pucchIndices, ...
        frameRxGrid, ...
        estimatedChannelGrid);
```

---

### 6.5 Equalization

Sử dụng **MMSE Equalization**:

```matlab
equalizedPUCCHSymbols = ...
    nrEqualizeMMSE( ...
        rxPUCCHSymbols, ...
        estimatedPUCCHChannel, ...
        noiseEstimate);
```

---

### 6.6 PUCCH Decoding

Bit UCI được giải mã bằng:

```matlab
[decodedUCI,constellationAfter] = ...
    nrPUCCHDecode( ...
        carrier, ...
        pucch, ...
        numUCIBits, ...
        equalizedPUCCHSymbols, ...
        noiseEstimate);
```

Sau đó bit được lấy từ:

```matlab
frameRxBit = decodedUCI{1};
```

---

## 7. AWGN Configuration

Noise được tạo trong miền thời gian:

```matlab
unitNoise = complex( ...
    randn(size(frameChannelWaveform)), ...
    randn(size(frameChannelWaveform)));
```

Sau đó được scale theo từng mức SNR.

Noise amplitude:

```matlab
noiseAmplitude = 1 ./ sqrt( ...
    2 ...
    * numReceiveAntennas ...
    * double(ofdmInfo.Nfft) ...
    .* snrLinear);
```

---

## 8. Output Metrics

Hệ thống hiện tại tính ba metric chính:

### BER

```text
BER = Number of bit errors / Number of transmitted bits
```

### BLER

```text
BLER = Number of erroneous frames / Number of transmitted frames
```

### RMS EVM

```text
RMS EVM (%) =
100 × sqrt(
    Error Signal Energy /
    Reference Signal Energy
)
```

EVM được tính sau:

```text
Channel Estimation
       ↓
MMSE Equalization
       ↓
PUCCH Despreading
       ↓
Constellation
```

---

## 9. CSV Export Configuration

Hệ thống được cấu hình xuất dữ liệu ở:

```text
SNR = 20 dB
```

Có thể thay đổi mức SNR này trong config.

Thư mục output:

```text
csv_export/
```

---

### 9.1 Rx Grid CSV

File:

```text
rx_grid_SNR_20dB.csv
```

Rx grid được lưu **ngay sau OFDM demodulation**.

Cấu trúc:

| Column | Ý nghĩa |
|---|---|
| FrameIndex | Frame hiện tại |
| SNR_dB | Mức SNR |
| SubcarrierIndex | Chỉ số subcarrier |
| OFDMSymbolIndex | Chỉ số OFDM symbol |
| RxAntennaIndex | Chỉ số anten thu |
| RxReal | Phần thực của resource element |
| RxImag | Phần ảo của resource element |

Mỗi resource element phức:

```text
RxGrid(k,l) = RxReal + j × RxImag
```

---

### 9.2 Decoded Bit CSV

File:

```text
decoded_bits_SNR_20dB.csv
```

Bit được lưu trực tiếp từ output của:

```matlab
nrPUCCHDecode
```

và được lưu **trước bước fallback khi decode lỗi hoặc DTX**.

Cấu trúc:

| Column | Ý nghĩa |
|---|---|
| SequenceIndex | Thứ tự bit toàn bộ chuỗi |
| FrameIndex | Frame chứa bit |
| BitPositionInFrame | Vị trí bit trong frame |
| SNR_dB | Mức SNR |
| DecodedBit | Bit sau giải mã |
| ValidDecode | Decode hợp lệ hay không |

Thứ tự lưu:

```text
Frame 1 - Bit 1
Frame 1 - Bit 2
Frame 2 - Bit 1
Frame 2 - Bit 2
Frame 3 - Bit 1
Frame 3 - Bit 2
...
```

Nếu decode không hợp lệ:

```text
DecodedBit = NaN
ValidDecode = false
```

---

## 10. Tóm tắt cấu hình hệ thống

```text
System             : 5G NR Uplink
Physical Channel   : PUCCH Format 1
UCI bits/frame     : 2

Carrier Bandwidth  : ~100 MHz
Subcarrier Spacing : 30 kHz
Number of PRBs     : 273
Cyclic Prefix      : Normal

Tx Antennas        : 1
Rx Antennas        : 1
MIMO Mode          : SISO

Channel            : TDL-A
Delay Spread       : 100 ns
Maximum Doppler    : 100 Hz

Timing             : Perfect Timing Estimate
Channel Estimation : PUCCH DM-RS
Equalizer          : MMSE
Decoder            : nrPUCCHDecode

SNR Range          : -30 to 20 dB
SNR Step           : 2 dB

Metrics            : BER / BLER / RMS EVM

CSV Output:
    - Rx resource grid
    - Decoded UCI bit sequence
```
