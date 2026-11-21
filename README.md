# Cascaded H-Bridge Multilevel Inverter with SPWM

This repository contains the MATLAB/Simulink implementation and customizable simulation script for a **Sinusoidal Pulse Width Modulation (SPWM) based Cascaded H-Bridge (CHB) Multilevel Inverter**, developed as part of the **EE348 – Design and Development Task in Power Electronics and Drives** course at **NITK Surathkal**.

The project focuses on analyzing **power quality improvement** using multilevel inverter topologies and **LC output filtering**.

---

## 📋 Project Overview

Conventional two-level inverters suffer from high harmonic distortion, making them unsuitable for power-quality-sensitive applications.  
This project addresses the issue by implementing and comparing **3-level and 5-level cascaded H-bridge inverters** using SPWM control.

The performance is evaluated in terms of:
- Output voltage and current waveforms  
- RMS values  
- Total Harmonic Distortion (THD)  
- Effect of LC output filtering  

---

## ⚙️ System Configuration

- **Inverter Topology:** Cascaded H-Bridge (3-level & 5-level)
- **Modulation Technique:** Sinusoidal PWM (SPWM) with Multi-Carrier Level Shifted / Phase Shifted schemes
- **Fundamental Frequency:** 50 Hz
- **DC Input Voltage:** 100 V per cell
- **Load Type:** Resistive (10 Ω) & Inductive (RL)
- **Filter:** LC Low-Pass Output Filter ($L = 70\text{ mH}, C = 33\ \mu\text{F}$)

---

## 📁 Repository Structure

- **`MLI_MODEL.slx`**: Simulink model of the Cascaded H-Bridge Multilevel Inverter with SPWM control and LC filter.
- **`CHB_Multilevel_Inverter_SPWM.m`**: Fully customizable MATLAB script & simulation engine.
  - Interactive parameter customization dialog (GUI/CLI).
  - Standalone high-fidelity simulation engine with IEEE 519 FFT/THD analyzer (up to 50th harmonic).
  - Automatically exports configured parameters (`Vdc`, `fm`, `fc`, `ma`, `R_load`, `Lf`, `Cf`, etc.) to the MATLAB Base Workspace for Simulink.
  - Generates 5-panel publication-grade figures (Modulation, Switched Voltage, Load Voltage, Load Current, and Harmonic Spectrum).
- **`compare_inverter_cases.m`**: Automated batch runner that executes the 4 core cases (3-Level Unfiltered, 3-Level Filtered, 5-Level Unfiltered, 5-Level Filtered) and displays a side-by-side performance comparison table.
- **`Mini Project Final Report.pdf`**: Complete project end-semester technical report.

---

## 🚀 How to Run

### Method 1: Interactive Parameter Customization
Open MATLAB in this directory and run:
```matlab
CHB_Multilevel_Inverter_SPWM
```
A popup dialog will appear allowing you to customize:
- **Number of Inverter Levels**: `3`, `5`, `7`, `9`, ...
- **DC Voltage per H-Bridge Cell**: e.g., `100` V
- **Fundamental Frequency ($f_m$)**: e.g., `50` Hz
- **Carrier Frequency ($f_c$)**: e.g., `2500` Hz
- **Modulation Index ($m_a$)**: e.g., `0.9` (range: `0.1` to `1.2`)
- **SPWM Scheme**: `'PD'` (Phase Disposition), `'POD'`, `'APOD'`, or `'PS'` (Phase-Shifted)
- **Load Resistance ($R$)**: e.g., `10` $\Omega$
- **Enable LC Filter?**: `1` (Yes) or `0` (No)
- **Filter Inductance ($L_f$)**: e.g., `70` mH
- **Filter Capacitance ($C_f$)**: e.g., `33` $\mu\text{F}$

Click **OK** to run. The script calculates electrical metrics, displays summary tables in the console, and generates detailed waveform plots.

### Method 2: Programmatic Script Call
```matlab
cfg = struct();
cfg.InteractiveMode = false;
cfg.num_levels      = 5;          % 5-Level Inverter
cfg.Vdc_per_cell    = 100;        % 100 V per cell
cfg.fm              = 50;         % 50 Hz fundamental
cfg.fc              = 2500;       % 2.5 kHz carrier
cfg.ma              = 0.90;       % Modulation index
cfg.modulation_type = 'PD';       % Phase Disposition SPWM
cfg.R_load          = 10;         % 10 Ohm load
cfg.use_filter      = true;       % LC Filter enabled
cfg.L_filter        = 70e-3;      % 70 mH
cfg.C_filter        = 33e-6;      % 33 uF

results = CHB_Multilevel_Inverter_SPWM(cfg);
```

### Method 3: Run the 4-Case Comparison Suite
To reproduce the comparative study from Chapter 6 of the project report:
```matlab
compare_inverter_cases
```

### Method 4: Running with Simulink (`MLI_MODEL.slx`)
Running `CHB_Multilevel_Inverter_SPWM` automatically populates the MATLAB Base Workspace with all block parameters (`Vdc`, `fm`, `fc`, `ma`, `R_load`, `Lf`, `Cf`, etc.). You can then open and run `MLI_MODEL.slx` directly.

---

## 📊 Results Summary

- Unfiltered inverter outputs exhibited high harmonic distortion (~30–35%).
- LC output filtering significantly improved waveform quality, reducing THD below 10%.
- Minimum achieved **THD ≈ 4.3%** for the 3-level inverter with filter.
- Filtered system demonstrated a clear trade-off between harmonic reduction and fundamental voltage utilization.

---

## 🛠️ Tools & Software

- MATLAB (R2018a or newer)
- Simulink
- Simscape Electrical (Specialized Power Systems)
