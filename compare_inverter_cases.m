%% =========================================================================
%  COMPARE INVERTER CASES (3-LEVEL vs 5-LEVEL, FILTERED vs UNFILTERED)
%  Automated Comparison and Validation Script for CHB Inverter with SPWM
%
%  Validates against findings in the EE348 Project Report:
%  "Cascaded H-Bridge Multilevel Inverter with SPWM Technique"
% =========================================================================

clc;
clear;
close all;

fprintf('=================================================================\n');
fprintf('  RUNNING BATCH COMPARISON FOR 3-LEVEL & 5-LEVEL CHB INVERTER    \n');
fprintf('=================================================================\n\n');

% Base parameters common across cases
Vdc = 100;      % 100V per cell
R   = 10;       % 10 Ohm load
Lf  = 70e-3;    % 70 mH
Cf  = 33e-6;    % 33 uF
fc  = 2500;     % 2.5 kHz carrier
fm  = 50;       % 50 Hz fundamental
ma  = 0.90;     % Modulation index

% Define test cases
cases = {
    struct('Name', '3-Level Unfiltered', 'levels', 3, 'filter', false), ...
    struct('Name', '3-Level With LC Filter', 'levels', 3, 'filter', true), ...
    struct('Name', '5-Level Unfiltered', 'levels', 5, 'filter', false), ...
    struct('Name', '5-Level With LC Filter', 'levels', 5, 'filter', true)
};

summary_data = cell(length(cases), 5);

for i = 1:length(cases)
    c = cases{i};
    fprintf('Running Case %d: %s ...\n', i, c.Name);
    
    cfg = struct();
    cfg.InteractiveMode = false;
    cfg.num_levels      = c.levels;
    cfg.Vdc_per_cell    = Vdc;
    cfg.fm              = fm;
    cfg.fc              = fc;
    cfg.ma              = ma;
    cfg.modulation_type = 'PD';
    cfg.load_type       = 'R';
    cfg.R_load          = R;
    cfg.L_load          = 0;
    cfg.use_filter      = c.filter;
    cfg.L_filter        = Lf;
    cfg.C_filter        = Cf;
    cfg.num_cycles      = 4;
    cfg.samples_per_cycle = 20000;
    cfg.export_to_simulink = false;
    
    res = CHB_Multilevel_Inverter_SPWM(cfg);
    
    summary_data{i, 1} = c.Name;
    summary_data{i, 2} = res.Vrms;
    summary_data{i, 3} = res.Irms;
    summary_data{i, 4} = res.THDv_pct;
    summary_data{i, 5} = res.ActivePower;
end

% Display Comparison Table
fprintf('\n===============================================================================\n');
fprintf('                      SUMMARY PERFORMANCE COMPARISON TABLE                     \n');
fprintf('===============================================================================\n');
fprintf('%-26s | %10s | %10s | %10s | %12s\n', 'Configuration', 'Vrms (V)', 'Irms (A)', 'THD_v (%)', 'P_real (W)');
fprintf('-------------------------------------------------------------------------------\n');
for i = 1:size(summary_data, 1)
    fprintf('%-26s | %10.2f | %10.3f | %9.2f%% | %12.2f\n', ...
            summary_data{i,1}, summary_data{i,2}, summary_data{i,3}, summary_data{i,4}, summary_data{i,5});
end
fprintf('===============================================================================\n');
fprintf('Key Observations from Report:\n');
fprintf('1. LC output filtering drastically reduces THD (from ~30-35%% down to below 10%%).\n');
fprintf('2. The 3-level inverter delivers higher fundamental voltage and RMS power to the load.\n');
fprintf('3. The 5-level inverter provides higher voltage resolution and smaller dv/dt switching steps.\n');
fprintf('===============================================================================\n');
