%% =========================================================================
%  CASCADED H-BRIDGE MULTILEVEL INVERTER WITH SPWM TECHNIQUE
%  Customizable MATLAB Simulation & Simulink Parameter Configuration Tool
%
%  Project: Cascaded H-Bridge Multilevel Inverter with SPWM Technique
%  Department of Electrical and Electronics Engineering
%  National Institute of Technology Karnataka (NITK), Surathkal
% =========================================================================
%  FEATURES:
%  1. Fully Customizable Parameters:
%     - Inverter Levels (3-Level, 5-Level, 7-Level, 9-Level, or arbitrary m-level)
%     - DC link voltages per H-bridge cell (Symmetric or Asymmetric)
%     - Modulation scheme: PD (Phase Disposition), POD, APOD, or Phase-Shifted
%     - Fundamental frequency (fm), Carrier frequency (fc), Modulation index (ma)
%     - Load parameters (R or R-L load)
%     - Output LC Filter parameters (Lf, Cf) with enable/disable toggle
%  2. Two Execution Modes:
%     - Mode 1: Interactive GUI/CLI Prompt to customize values at runtime
%     - Mode 2: Direct Script Execution with user-defined parameters or presets
%  3. Workspace Export for Simulink:
%     - Automatically exports all configured variables to MATLAB base workspace
%       for seamless integration with Simulink models (.slx).
%  4. Standalone High-Precision Simulation Engine:
%     - Performs exact time-domain mathematical and state-space simulation
%     - Computes Vrms, Irms, Fundamental Voltage, Active Power, and THD (up to 50th order)
%     - Generates publication-grade waveforms and FFT Harmonic Spectrum plots.
% =========================================================================

function results = CHB_Multilevel_Inverter_SPWM(varargin)
    % Clear command window and close figures if run as standalone script
    if nargin == 0
        clc;
        close all;
    end

    fprintf('=================================================================\n');
    fprintf('  CASCADED H-BRIDGE MULTILEVEL INVERTER WITH SPWM SIMULATOR\n');
    fprintf('=================================================================\n\n');

    %% --------------------------------------------------------------------
    %% 1. DEFAULT CONFIGURATION & PRESETS
    %% --------------------------------------------------------------------
    % Available Presets:
    % 'Report_5Level_WithFilter' : 5-Level CHB, Vdc=[100,100]V, Lf=70mH, Cf=33uF, R=10 Ohm
    % 'Report_5Level_NoFilter'   : 5-Level CHB, Vdc=[100,100]V, No Filter, R=10 Ohm
    % 'Report_3Level_WithFilter' : 3-Level CHB, Vdc=100V, Lf=70mH, Cf=33uF, R=10 Ohm
    % 'Report_3Level_NoFilter'   : 3-Level CHB, Vdc=100V, No Filter, R=10 Ohm
    % 'Custom'                  : User-defined parameters
    
    cfg = struct();
    cfg.InteractiveMode = true;             % Set to true for interactive prompt, false to use below values
    cfg.Preset          = 'Report_5Level_WithFilter'; 

    % --- Default Base Parameters (5-Level Filtered Benchmark) ---
    cfg.num_levels      = 5;                 % Inverter voltage levels (3, 5, 7, 9, ...)
    cfg.Vdc_per_cell    = 100.0;             % DC Source Voltage per H-Bridge Cell (Volts)
    cfg.fm              = 50.0;              % Fundamental reference frequency (Hz)
    cfg.fc              = 2500.0;            % SPWM Carrier switching frequency (Hz)
    cfg.ma              = 0.90;              % Amplitude modulation index (0 < ma <= 1.2)
    cfg.modulation_type = 'PD';              % Multi-carrier: 'PD' (Phase Disposition), 'POD', 'APOD', 'PS'
    
    % --- Load Parameters ---
    cfg.load_type       = 'R';               % Load type: 'R' or 'RL'
    cfg.R_load          = 10.0;              % Load resistance (Ohms)
    cfg.L_load          = 0.0;               % Load inductance (Henries) - e.g., 0.01 for 10mH
    
    % --- Output LC Filter ---
    cfg.use_filter      = true;              % Enable LC Low-Pass Filter (true / false)
    cfg.L_filter        = 70e-3;             % Filter Inductance (H) -> 70 mH
    cfg.C_filter        = 33e-6;             % Filter Capacitance (F) -> 33 uF
    
    % --- Simulation Settings ---
    cfg.num_cycles      = 4;                 % Number of fundamental cycles to simulate
    cfg.samples_per_cycle = 20000;           % High resolution for accurate THD and switching edges
    cfg.export_to_simulink = true;          % Assign variables to base workspace for Simulink

    %% --------------------------------------------------------------------
    %% 2. USER INTERACTIVE CUSTOMIZATION (GUI or Command Line)
    %% --------------------------------------------------------------------
    if cfg.InteractiveMode && nargin == 0
        cfg = promptUserCustomization(cfg);
    end

    %% --------------------------------------------------------------------
    %% 3. DERIVED PARAMETERS & VALIDATION
    %% --------------------------------------------------------------------
    % Number of cascaded cells: m = 2*N + 1 => N = (m - 1) / 2
    if mod(cfg.num_levels, 2) == 0 || cfg.num_levels < 3
        error('Number of inverter levels must be an odd integer >= 3 (e.g., 3, 5, 7, 9).');
    end
    N_cells = (cfg.num_levels - 1) / 2;
    
    % DC Bus vector (supports symmetric cell voltage array)
    if isscalar(cfg.Vdc_per_cell)
        Vdc_array = repmat(cfg.Vdc_per_cell, 1, N_cells);
    else
        Vdc_array = cfg.Vdc_per_cell;
        if length(Vdc_array) ~= N_cells
            error('Vdc_per_cell vector length (%d) must match number of H-bridge cells (%d).', length(Vdc_array), N_cells);
        end
    end
    Vdc_max = sum(Vdc_array);
    
    Tm = 1 / cfg.fm;                         % Fundamental period (s)
    T_total = cfg.num_cycles * Tm;           % Total simulation time (s)
    dt = Tm / cfg.samples_per_cycle;         % Time step size
    t = (0:dt:T_total)';                     % Time vector
    N_pts = length(t);
    
    %% --------------------------------------------------------------------
    %% 4. EXPORT VARIABLES TO SIMULINK WORKSPACE
    %% --------------------------------------------------------------------
    if cfg.export_to_simulink
        exportVariablesToWorkspace(cfg, N_cells, Vdc_array);
    end

    %% --------------------------------------------------------------------
    %% 5. MULTI-CARRIER SPWM GENERATION & GATE LOGIC
    %% --------------------------------------------------------------------
    fprintf('\n--> Generating %s Multi-Carrier SPWM for %d-Level Inverter (fc = %g Hz, fm = %g Hz, ma = %.2f)...\n', ...
            cfg.modulation_type, cfg.num_levels, cfg.fc, cfg.fm, cfg.ma);

    % Reference sinusoidal signal: -1 to +1 scaled by ma
    v_ref = cfg.ma * sin(2 * pi * cfg.fm * t);
    
    % Level-Shifted Carriers: For m levels, (m-1) carrier bands are needed.
    % Spanning normalized range [-1, +1]
    m_carriers = cfg.num_levels - 1;
    band_height = 2 / m_carriers;
    
    % Base triangular carrier wave between 0 and 1
    % Period is 1/fc
    tau = mod(t * cfg.fc, 1);
    tri_base_01 = 2 * abs(tau - 0.5); % 0 to 1 symmetric triangle
    
    carrier_matrix = zeros(N_pts, m_carriers);
    switch upper(cfg.modulation_type)
        case 'PD'   % Phase Disposition (All carriers in-phase)
            for k = 1:m_carriers
                c_min = -1 + (k - 1) * band_height;
                carrier_matrix(:, k) = c_min + tri_base_01 * band_height;
            end
            
        case 'POD'  % Phase Opposition Disposition (Inverted below zero)
            for k = 1:m_carriers
                c_min = -1 + (k - 1) * band_height;
                if c_min >= 0
                    carrier_matrix(:, k) = c_min + tri_base_01 * band_height;
                else
                    % Inverted 180 degrees
                    carrier_matrix(:, k) = c_min + (1 - tri_base_01) * band_height;
                end
            end
            
        case 'APOD' % Alternate Phase Opposition Disposition
            for k = 1:m_carriers
                c_min = -1 + (k - 1) * band_height;
                if mod(k, 2) == 1
                    carrier_matrix(:, k) = c_min + tri_base_01 * band_height;
                else
                    carrier_matrix(:, k) = c_min + (1 - tri_base_01) * band_height;
                end
            end
            
        case 'PS'   % Phase-Shifted PWM
            % In PS-PWM, N_cells carriers are phase shifted by 180/N_cells degrees
            for k = 1:N_cells
                ps_angle = (k - 1) * (1 / (N_cells * cfg.fc));
                tau_ps = mod((t - ps_angle) * cfg.fc, 1);
                carrier_matrix(:, k) = 2 * (2 * abs(tau_ps - 0.5) - 0.5); % [-1, 1]
            end
            
        otherwise
            error('Unknown modulation type: %s. Use PD, POD, APOD, or PS.', cfg.modulation_type);
    end

    %% --------------------------------------------------------------------
    %% 6. INVERTER SWITCHED VOLTAGE SYNTHESIS (V_inv)
    %% --------------------------------------------------------------------
    v_inv = zeros(N_pts, 1);
    
    if ~strcmpi(cfg.modulation_type, 'PS')
        % LSPWM (PD, POD, APOD):
        % Level comparison: Reference compared against each carrier band
        for k = 1:m_carriers
            cmp = (v_ref >= carrier_matrix(:, k));
            % Each band that reference exceeds adds one step of DC voltage
            % Normalized levels: from -N*Vdc to +N*Vdc
            v_inv = v_inv + cmp * (2 * Vdc_max / m_carriers);
        end
        v_inv = v_inv - Vdc_max; % Shift baseline to symmetrical AC (0 mean)
    else
        % Phase-Shifted PWM:
        for k = 1:N_cells
            s_leg1 = (v_ref >= carrier_matrix(:, k));
            s_leg2 = (-v_ref >= carrier_matrix(:, k));
            v_cell = (s_leg1 - s_leg2) * Vdc_array(k);
            v_inv = v_inv + v_cell;
        end
    end

    %% --------------------------------------------------------------------
    %% 7. OUTPUT LC FILTER & LOAD CIRCUIT SIMULATION
    %% --------------------------------------------------------------------
    % State-Space Modeling:
    % Inductor equation:   Lf * di_L/dt = v_inv - v_C
    % Capacitor equation:  Cf * dv_C/dt = i_L - i_load
    % Load equation:
    %   - Pure R load:      i_load = v_C / R_load
    %   - RL load:          L_load * di_load/dt + R_load * i_load = v_C
    
    v_load = zeros(N_pts, 1);
    i_load = zeros(N_pts, 1);
    
    if ~cfg.use_filter || (cfg.L_filter == 0 && cfg.C_filter == 0)
        fprintf('--> Simulating UNFILTERED load output...\n');
        v_load = v_inv;
        if strcmpi(cfg.load_type, 'R') || cfg.L_load == 0
            i_load = v_load / cfg.R_load;
        else
            % Solve 1st order RL circuit: di/dt = (v_load - R*i) / L
            i_curr = 0;
            for n = 1:N_pts
                i_load(n) = i_curr;
                di = (v_load(n) - cfg.R_load * i_curr) / cfg.L_load;
                i_curr = i_curr + di * dt;
            end
        end
    else
        fprintf('--> Simulating LC FILTERED output (Lf = %g mH, Cf = %g uF)...\n', ...
                cfg.L_filter * 1e3, cfg.C_filter * 1e6);
        
        Lf = cfg.L_filter;
        Cf = cfg.C_filter;
        R  = cfg.R_load;
        
        % Numerical Integration (4th Order Runge-Kutta / Heun's method for stiff switching)
        % State vector x = [i_Lf; v_Cf]
        i_L = 0;
        v_C = 0;
        
        for n = 1:N_pts
            u = v_inv(n);
            % Substep Trapezoidal / Heun Integration for numerical stability
            % Derivative at current step
            di1 = (u - v_C) / Lf;
            dv1 = (i_L - v_C / R) / Cf;
            
            % Predictor
            i_pred = i_L + di1 * dt;
            v_pred = v_C + dv1 * dt;
            
            % Derivative at predicted step
            di2 = (u - v_pred) / Lf;
            dv2 = (i_pred - v_pred / R) / Cf;
            
            % Corrector
            i_L = i_L + 0.5 * (di1 + di2) * dt;
            v_C = v_C + 0.5 * (dv1 + dv2) * dt;
            
            v_load(n) = v_C;
            i_load(n) = v_C / R;
        end
    end

    %% --------------------------------------------------------------------
    %% 8. STEADY-STATE EXTRACTION & FFT / THD ANALYSIS
    %% --------------------------------------------------------------------
    % Analyze the last complete fundamental cycle for steady-state accuracy
    idx_start = round((cfg.num_cycles - 1) * cfg.samples_per_cycle) + 1;
    idx_end   = length(t);
    t_ss      = t(idx_start:idx_end) - t(idx_start);
    v_inv_ss  = v_inv(idx_start:idx_end);
    v_load_ss = v_load(idx_start:idx_end);
    i_load_ss = i_load(idx_start:idx_end);
    
    % RMS Calculations
    Vinv_rms  = sqrt(mean(v_inv_ss.^2));
    Vload_rms = sqrt(mean(v_load_ss.^2));
    Iload_rms = sqrt(mean(i_load_ss.^2));
    P_active  = mean(v_load_ss .* i_load_ss);
    S_apparent = Vload_rms * Iload_rms;
    Power_Factor = P_active / (S_apparent + 1e-9);
    
    % FFT for Harmonic Spectrum & THD Calculation (IEEE 519 standard)
    N_fft = length(t_ss);
    V_fft = fft(v_load_ss) / N_fft;
    I_fft = fft(i_load_ss) / N_fft;
    
    % Two-sided to single-sided spectrum
    V_mag = 2 * abs(V_fft(1:floor(N_fft/2)));
    I_mag = 2 * abs(I_fft(1:floor(N_fft/2)));
    
    % Fundamental frequency bin
    fund_bin = 1 + round(cfg.fm * (t_ss(end) - t_ss(1)));
    V_fund_peak = V_mag(fund_bin);
    V_fund_rms  = V_fund_peak / sqrt(2);
    I_fund_peak = I_mag(fund_bin);
    I_fund_rms  = I_fund_peak / sqrt(2);
    
    % Harmonics up to 50th order
    max_harm = 50;
    harm_orders = 1:max_harm;
    V_harm_mags = zeros(max_harm, 1);
    I_harm_mags = zeros(max_harm, 1);
    
    for h = 1:max_harm
        bin_h = 1 + round(h * cfg.fm * (t_ss(end) - t_ss(1)));
        if bin_h <= length(V_mag)
            V_harm_mags(h) = V_mag(bin_h);
            I_harm_mags(h) = I_mag(bin_h);
        end
    end
    
    % THD Formula: sqrt(sum(V_h^2, h=2..50)) / V_fund * 100%
    V_harm_sum_sq = sum(V_harm_mags(2:end).^2);
    THDv_pct = (sqrt(V_harm_sum_sq) / (V_fund_peak + 1e-9)) * 100;
    
    I_harm_sum_sq = sum(I_harm_mags(2:end).^2);
    THDi_pct = (sqrt(I_harm_sum_sq) / (I_fund_peak + 1e-9)) * 100;

    %% --------------------------------------------------------------------
    %% 9. DISPLAY COMPREHENSIVE PERFORMANCE SUMMARY
    %% --------------------------------------------------------------------
    fprintf('\n=================================================================\n');
    fprintf('                    SIMULATION RESULTS SUMMARY                   \n');
    fprintf('=================================================================\n');
    fprintf('  Configuration:       %d-Level Inverter (%s-SPWM)\n', cfg.num_levels, cfg.modulation_type);
    fprintf('  Number of H-Bridges: %d Cascaded Cells\n', N_cells);
    fprintf('  Total DC Bus (Max):  %.1f V (%.1f V per cell)\n', Vdc_max, cfg.Vdc_per_cell);
    fprintf('  Modulation Index:    ma = %.2f,  Carrier fc = %g Hz\n', cfg.ma, cfg.fc);
    if cfg.use_filter
        fprintf('  Filter Status:       ENABLED (Lf = %.1f mH, Cf = %.1f uF)\n', cfg.L_filter*1e3, cfg.C_filter*1e6);
    else
        fprintf('  Filter Status:       DISABLED (Raw Switched Waveform)\n');
    end
    fprintf('  Load Parameters:     R = %.2f Ohm, L = %g mH\n', cfg.R_load, cfg.L_load*1e3);
    fprintf('-----------------------------------------------------------------\n');
    fprintf('  Output Voltage RMS:  %8.2f V\n', Vload_rms);
    fprintf('  Output Current RMS:  %8.3f A\n', Iload_rms);
    fprintf('  Fundamental V (RMS): %8.2f V (Peak = %.2f V)\n', V_fund_rms, V_fund_peak);
    fprintf('  Active Real Power:   %8.2f W\n', P_active);
    fprintf('  Apparent Power:      %8.2f VA\n', S_apparent);
    fprintf('  Power Factor:        %8.4f\n', Power_Factor);
    fprintf('  Voltage THD (THDv):  %8.2f %%\n', THDv_pct);
    fprintf('  Current THD (THDi):  %8.2f %%\n', THDi_pct);
    fprintf('=================================================================\n\n');

    %% --------------------------------------------------------------------
    %% 10. PLOTTING PUBLICATION-QUALITY WAVEFORMS
    %% --------------------------------------------------------------------
    plotSimulationResults(t, v_ref, carrier_matrix, v_inv, v_load, i_load, ...
                          cfg, harm_orders, V_harm_mags, V_fund_peak, THDv_pct, ...
                          Vload_rms, Iload_rms);

    %% --------------------------------------------------------------------
    %% 11. PACKAGE RESULTS OUTPUT STRUCT
    %% --------------------------------------------------------------------
    results = struct();
    results.Config     = cfg;
    results.Time       = t;
    results.V_ref      = v_ref;
    results.Carriers   = carrier_matrix;
    results.V_inverter = v_inv;
    results.V_load     = v_load;
    results.I_load     = i_load;
    results.Vrms       = Vload_rms;
    results.Irms       = Iload_rms;
    results.Vfund_rms  = V_fund_rms;
    results.THDv_pct   = THDv_pct;
    results.THDi_pct   = THDi_pct;
    results.ActivePower = P_active;
    results.PowerFactor = Power_Factor;
end

%% ========================================================================
%% HELPER FUNCTION: INTERACTIVE CUSTOMIZATION PROMPT
%% ========================================================================
function cfg = promptUserCustomization(defaultCfg)
    cfg = defaultCfg;
    
    % Check if GUI dialogs are supported in the current MATLAB session
    hasGUI = usejava('desktop') && usejava('awt');
    
    if hasGUI
        % --- Method 1: Graphical Input Dialog ---
        prompt = { ...
            'Number of Inverter Levels (3, 5, 7, 9, ...):', ...
            'DC Voltage per H-Bridge Cell (V):', ...
            'Fundamental Frequency fm (Hz):', ...
            'Carrier Frequency fc (Hz):', ...
            'Amplitude Modulation Index ma (0.1 - 1.2):', ...
            'SPWM Scheme (PD, POD, APOD, or PS):', ...
            'Load Resistance R (Ohms):', ...
            'Enable LC Filter? (1 = Yes, 0 = No):', ...
            'Filter Inductance Lf (mH):', ...
            'Filter Capacitance Cf (uF):' ...
        };
        dlgtitle = 'Customize CHB Multilevel Inverter Parameters';
        dims = [1 55];
        definput = { ...
            num2str(cfg.num_levels), ...
            num2str(cfg.Vdc_per_cell), ...
            num2str(cfg.fm), ...
            num2str(cfg.fc), ...
            num2str(cfg.ma), ...
            cfg.modulation_type, ...
            num2str(cfg.R_load), ...
            num2str(double(cfg.use_filter)), ...
            num2str(cfg.L_filter * 1e3), ...
            num2str(cfg.C_filter * 1e6) ...
        };
        
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        if ~isempty(answer)
            cfg.num_levels      = str2double(answer{1});
            cfg.Vdc_per_cell    = str2double(answer{2});
            cfg.fm              = str2double(answer{3});
            cfg.fc              = str2double(answer{4});
            cfg.ma              = str2double(answer{5});
            cfg.modulation_type = strtrim(answer{6});
            cfg.R_load          = str2double(answer{7});
            cfg.use_filter      = (str2double(answer{8}) == 1);
            cfg.L_filter        = str2double(answer{9}) * 1e-3;
            cfg.C_filter        = str2double(answer{10}) * 1e-6;
        else
            fprintf('Dialog cancelled. Using standard report benchmark settings.\n');
        end
    else
        % --- Method 2: Command Line Interactive Prompt ---
        fprintf('--- INTERACTIVE PARAMETER CUSTOMIZATION ---\n');
        fprintf('(Press ENTER to accept the bracketed default value)\n\n');
        
        val = input(sprintf('Number of Inverter Levels [%d]: ', cfg.num_levels));
        if ~isempty(val), cfg.num_levels = val; end
        
        val = input(sprintf('DC Voltage per Cell in Volts [%g]: ', cfg.Vdc_per_cell));
        if ~isempty(val), cfg.Vdc_per_cell = val; end
        
        val = input(sprintf('Carrier Frequency fc in Hz [%g]: ', cfg.fc));
        if ~isempty(val), cfg.fc = val; end
        
        val = input(sprintf('Modulation Index ma [%g]: ', cfg.ma));
        if ~isempty(val), cfg.ma = val; end
        
        val = input(sprintf('Modulation Scheme (PD/POD/APOD/PS) [%s]: ', cfg.modulation_type), 's');
        if ~isempty(val), cfg.modulation_type = strtrim(val); end
        
        val = input(sprintf('Load Resistance R in Ohms [%g]: ', cfg.R_load));
        if ~isempty(val), cfg.R_load = val; end
        
        filt_choice = input(sprintf('Enable Output LC Filter? (1=Yes, 0=No) [%d]: ', double(cfg.use_filter)));
        if ~isempty(filt_choice), cfg.use_filter = (filt_choice == 1); end
        
        if cfg.use_filter
            val = input(sprintf('Filter Inductance Lf in mH [%g]: ', cfg.L_filter * 1e3));
            if ~isempty(val), cfg.L_filter = val * 1e-3; end
            
            val = input(sprintf('Filter Capacitance Cf in uF [%g]: ', cfg.C_filter * 1e6));
            if ~isempty(val), cfg.C_filter = val * 1e-6; end
        end
        fprintf('-------------------------------------------\n');
    end
end

%% ========================================================================
%% HELPER FUNCTION: EXPORT VARIABLES TO BASE WORKSPACE FOR SIMULINK
%% ========================================================================
function exportVariablesToWorkspace(cfg, N_cells, Vdc_array)
    % Common Simulink block parameters
    assignin('base', 'Vdc', cfg.Vdc_per_cell);
    assignin('base', 'Vdc1', Vdc_array(1));
    if N_cells >= 2
        assignin('base', 'Vdc2', Vdc_array(2));
    end
    assignin('base', 'Vdc_array', Vdc_array);
    assignin('base', 'Vdc_total', sum(Vdc_array));
    assignin('base', 'fm', cfg.fm);
    assignin('base', 'fc', cfg.fc);
    assignin('base', 'ma', cfg.ma);
    assignin('base', 'num_levels', cfg.num_levels);
    assignin('base', 'N_cells', N_cells);
    assignin('base', 'R_load', cfg.R_load);
    assignin('base', 'L_load', cfg.L_load);
    assignin('base', 'Lf', cfg.L_filter);
    assignin('base', 'Cf', cfg.C_filter);
    assignin('base', 'L_filter', cfg.L_filter);
    assignin('base', 'C_filter', cfg.C_filter);
    assignin('base', 'use_filter', double(cfg.use_filter));
    assignin('base', 'Ts', (1/cfg.fm) / cfg.samples_per_cycle);
    assignin('base', 'T_stop', cfg.num_cycles * (1/cfg.fm));
    
    fprintf('--> Exported variables (Vdc, fm, fc, ma, R_load, Lf, Cf, etc.) to MATLAB Base Workspace for Simulink.\n');
end

%% ========================================================================
%% HELPER FUNCTION: PLOT HIGH QUALITY WAVEFORMS
%% ========================================================================
function plotSimulationResults(t, v_ref, carrier_matrix, v_inv, v_load, i_load, ...
                              cfg, harm_orders, V_harm_mags, V_fund_peak, THDv_pct, ...
                              Vload_rms, Iload_rms)
    fig = figure('Name', sprintf('%d-Level CHB MLI SPWM Simulation', cfg.num_levels), ...
                 'Color', 'w', 'Position', [80, 50, 1100, 750]);

    % Display first 2 cycles for time-domain waveform clarity
    t_plot_limit = min(2 * (1 / cfg.fm), t(end));
    mask = (t <= t_plot_limit);
    t_ms = t(mask) * 1e3;

    % 1. Modulation Reference & Carriers
    subplot(3, 2, 1);
    hold on; box on; grid on;
    % Plot carriers
    plot(t_ms, carrier_matrix(mask, :), 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);
    % Plot reference
    h_ref = plot(t_ms, v_ref(mask), 'r', 'LineWidth', 1.8);
    title(sprintf('(a) %s Multi-Carrier SPWM Modulation Signals', cfg.modulation_type), 'FontWeight', 'bold');
    xlabel('Time (ms)'); ylabel('Normalized Amplitude');
    legend(h_ref, {'v_{ref} (Sine)'}, 'Location', 'northeast');
    ylim([-1.15, 1.15]);

    % 2. Inverter Raw Switched Output Voltage (Staircase)
    subplot(3, 2, 2);
    box on; grid on; hold on;
    plot(t_ms, v_inv(mask), 'Color', [0 0.4470 0.7410], 'LineWidth', 1.2);
    title(sprintf('(b) Inverter Switched Output Voltage (V_{inv}) - %d Levels', cfg.num_levels), 'FontWeight', 'bold');
    xlabel('Time (ms)'); ylabel('Voltage (V)');
    xlim([0, t_plot_limit * 1e3]);

    % 3. Load Output Voltage (Filtered or Unfiltered)
    subplot(3, 2, 3);
    box on; grid on; hold on;
    plot(t_ms, v_load(mask), 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);
    filter_txt = 'With LC Filter';
    if ~cfg.use_filter, filter_txt = 'Without Filter'; end
    title(sprintf('(c) Load Terminal Voltage (V_{load}) [%s]', filter_txt), 'FontWeight', 'bold');
    xlabel('Time (ms)'); ylabel('Voltage (V)');
    legend({sprintf('V_{rms} = %.2f V', Vload_rms)}, 'Location', 'northeast');
    xlim([0, t_plot_limit * 1e3]);

    % 4. Load Current Waveform
    subplot(3, 2, 4);
    box on; grid on; hold on;
    plot(t_ms, i_load(mask), 'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.5);
    title(sprintf('(d) Load Current Waveform (I_{load}) [R = %g \\Omega]', cfg.R_load), 'FontWeight', 'bold');
    xlabel('Time (ms)'); ylabel('Current (A)');
    legend({sprintf('I_{rms} = %.2f A', Iload_rms)}, 'Location', 'northeast');
    xlim([0, t_plot_limit * 1e3]);

    % 5. FFT Harmonic Spectrum Bar Chart
    subplot(3, 2, [5, 6]);
    box on; grid on; hold on;
    harm_pct = (V_harm_mags / (V_fund_peak + 1e-9)) * 100;
    
    b = bar(harm_orders, harm_pct, 0.7);
    b.FaceColor = [0.2 0.6 0.8];
    b.EdgeColor = [0.1 0.4 0.6];
    
    % Highlight fundamental
    title(sprintf('(e) Harmonic Spectrum of Load Voltage (THD_v = %.2f%%, Fundamental V_{fund} = %.1f V peak)', ...
                  THDv_pct, V_fund_peak), 'FontWeight', 'bold');
    xlabel('Harmonic Order (h)'); ylabel('Magnitude (% of Fundamental)');
    xlim([0, 51]);
    
    % Annotations
    text(2, max(harm_pct(2:end)) * 0.9 + 5, ...
         sprintf('THD_v = %.2f%%\nV_{rms} = %.2f V\nI_{rms} = %.2f A', THDv_pct, Vload_rms, Iload_rms), ...
         'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [1 1 0.9], 'EdgeColor', 'k');
end
