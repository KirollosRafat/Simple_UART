# Simple UART Project (SystemVerilog)

## 📌 Overview
This project implements a **simple UART communication system** in SystemVerilog, featuring:
- Baud rate generation
- UART transmission
- UART reception
- A top-level integration module

It is designed for FPGA or ASIC designs that require basic serial communication.  

---

## ✨ Features
- **Configurable baud rate** using a dedicated generator module
- **8-bit UART transmission and reception**
- **Start and stop bit framing**
- Works in **full-duplex** mode (simultaneous TX and RX)
- Modular design for easy integration into larger systems

---

## 📂 Module Descriptions

### 1. `BAUDRATE_GEN.sv`
Generates a `baud_clk_en` pulse from a high-frequency system clock to match the desired baud rate.

**Key Parameters:**
- `CLK_FREQ` — system clock frequency (Hz)
- `BAUD_RATE` — UART baud rate (bps)

**Ports:**
- **Input:** `clk`, `reset`
- **Output:** `baud_clk_en`

---

### 2. `UART_Tx.sv`
Transmits data over a UART serial line.

**Operation:**
- Waits for `tx_start`
- Sends **start bit**, **8 data bits (LSB first)**, and **stop bit**
- Uses `baud_clk_en` for timing

**Ports:**
- **Input:** `clk`, `reset`, `tx_start`, `data_in[7:0]`, `baud_clk_en`
- **Output:** `tx`, `tx_busy`

---

### 3. `UART_Rx.sv`
Receives serial data and reconstructs bytes.

**Operation:**
- Detects **start bit**
- Samples incoming bits at correct intervals
- Outputs received byte with `rx_ready` flag

**Ports:**
- **Input:** `clk`, `reset`, `rx`, `baud_clk_en`
- **Output:** `data_out[7:0]`, `rx_ready`

---

### 4. `Simple_UART.sv` (Top Level)
Integrates:
- `BAUDRATE_GEN`
- `UART_Tx`
- `UART_Rx`

Provides a simple interface for full-duplex UART communication.

**Ports:**
- **Input:** `clk`, `reset`, `tx_start`, `data_in[7:0]`, `rx`
- **Output:** `tx`, `tx_busy`, `data_out[7:0]`, `rx_ready`

---

## ⚙️ Simulation
1. Write a **testbench** to:
   - Generate a clock and reset
   - Provide stimulus for `tx_start` and `data_in`
   - Loop back `tx` to `rx` for self-test
2. Use your preferred simulator (e.g., ModelSim, Vivado, Verilator):
   ```bash
   vlog BAUDRATE_GEN.sv UART_Tx.sv UART_Rx.sv Simple_UART.sv tb_uart.sv
   vsim tb_uart
   ```
3. Observe `tx`, `rx`, `rx_ready`, and `data_out` signals in the waveform viewer.

---

## 🚀 Synthesis
- The design is FPGA-friendly and uses synchronous logic.
- For Xilinx/Intel FPGAs:
  - Create a new project
  - Add all `.sv` files
  - Assign I/O pins for `tx` and `rx`
  - Configure `CLK_FREQ` and `BAUD_RATE` parameters

---

## 🧪 Example Usage
- Connect FPGA UART TX/RX pins to a USB-to-UART adapter.
- Open a serial terminal on your PC (PuTTY, Tera Term, minicom, etc.).
- Match baud rate settings.
- Send and receive data via FPGA.

---
