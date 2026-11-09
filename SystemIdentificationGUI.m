function figHandle = SystemIdentificationGUI()
%SYSTEMIDENTIFICATIONGUI  Interactive ARX system identification GUI.
%   SystemIdentificationGUI() launches a four-tab application:
%     Tab 1 - System Simulation  (demo / learning)
%     Tab 2 - Data Import & Identification
%     Tab 3 - Model Validation
%     Tab 4 - Interactive Analysis (sensitivity studies)
%
%   All numerical algorithms live in the +sid package (no toolboxes).
%   State is shared via nested-function closures over a single struct S.
%
%   Usage:
%       SystemIdentificationGUI          % launch the GUI
%       h = SystemIdentificationGUI();   % return figure handle

% ---- Ensure +sid package is on the path -----------------------------------
rootDir = fileparts(mfilename('fullpath'));
if ~contains(path, rootDir)
    addpath(rootDir);
end

% =========================================================================
%  SHARED APPLICATION STATE
% =========================================================================
S = struct( ...
    'raw',     [], ...      % imported raw table + metadata
    'orig',    [], ...      % validated original dataset (struct with t,u,y,Ts,...)
    'work',    [], ...      % working dataset (may be resampled)
    'model',   [], ...      % ARX model struct from sid.estimateARX
    'ev',      [], ...      % evaluation struct from sid.evaluateModel
    'Ne',      0,  ...      % number of estimation samples used
    'study',   [], ...      % model-order sensitivity study results
    'noise',   [], ...      % noise sensitivity study results
    'samp',    [], ...      % sampling-time study results
    'obs', struct('order','','noise','','samp','') ...
);

% =========================================================================
%  MAIN FIGURE
% =========================================================================
fig = uifigure('Name', 'System Identification GUI — SysIdGUI', ...
    'Position', [50 50 1400 850], ...
    'CloseRequestFcn', @(~,~) onClose());
rootGrid = uigridlayout(fig, [2 1]);
rootGrid.RowHeight = {'1x', 25};
rootGrid.Padding = [6 6 6 6];
rootGrid.RowSpacing = 4;

% Tab group
tabs = uitabgroup(rootGrid);

% Status bar
statusBar = uilabel(rootGrid, 'Text', 'Ready', ...
    'FontSize', 11, 'FontColor', [0.2 0.2 0.2], ...
    'BackgroundColor', [0.94 0.94 0.94]);

% =========================================================================
%  TAB 1: SYSTEM SIMULATION
% =========================================================================
tab1 = uitab(tabs, 'Title', '1. System Simulation');
g1 = uigridlayout(tab1, [1 2]);
g1.ColumnWidth = {300, '1x'};

% ---- Left panel: parameters ----
pan1 = uipanel(g1, 'Title', 'Simulation Parameters');
c1 = uigridlayout(pan1, [22 2]);
c1.ColumnWidth = {140, '1x'};
c1.RowHeight = [repmat({26}, 1, 21), {'1x'}];
c1.Scrollable = 'on';

% System Type
mkSectionLabel(c1, 1, 'System Type');
ddSysType = mkDropdown(c1, 2, 'Type', ...
    {'1st Order', '2nd Order'}, {'first', 'second'}, 'first');

% System Parameters
mkSectionLabel(c1, 3, 'System Parameters');
efK    = mkNumericField(c1, 4, 'K (Gain)', 1, [-1e6, 1e6]);
efTau  = mkNumericField(c1, 5, 'tau (Time Const.)', 1, [1e-6, 1e6]);
efWn   = mkNumericField(c1, 6, 'wn (Nat. Freq.)', 5, [1e-6, 1e6]);
efZeta = mkNumericField(c1, 7, 'zeta (Damping)', 0.7, [0, 100]);
% Initial visibility: first order selected
efWn.Enable = 'off';
efZeta.Enable = 'off';

% Simulation Settings
mkSectionLabel(c1, 8, 'Simulation Settings');
efTsSim = mkNumericField(c1, 9,  'Ts (Sample Time)', 0.01, [1e-6, 100]);
efDur   = mkNumericField(c1, 10, 'Duration (s)', 10, [0.01, 1e6]);

% Input Signal
mkSectionLabel(c1, 11, 'Input Signal');
ddInputType = mkDropdown(c1, 12, 'Signal Type', ...
    {'Step', 'Impulse', 'Ramp', 'Sine', 'Square', 'PRBS'}, ...
    {'step', 'impulse', 'ramp', 'sine', 'square', 'prbs'}, 'step');
efAmp      = mkNumericField(c1, 13, 'Amplitude', 1, [-1e6, 1e6]);
efFreqSim  = mkNumericField(c1, 14, 'Frequency (Hz)', 1, [1e-6, 1e6]);
efStepTime = mkNumericField(c1, 15, 'Step Time (s)', 1, [0, 1e6]);
efRampSlope = mkNumericField(c1, 16, 'Ramp Slope', 1, [-1e6, 1e6]);
efPRBSBits  = mkNumericField(c1, 17, 'PRBS Bits', 5, [1, 100]);
efPRBSBits.RoundFractionalValues = 'on';

% Initial input param visibility
efFreqSim.Enable = 'off';
efRampSlope.Enable = 'off';
efPRBSBits.Enable = 'off';

% Simulate button
btnSimulate = uibutton(c1, 'Text', 'Simulate', ...
    'FontWeight', 'bold', 'FontSize', 13, ...
    'BackgroundColor', [0.3 0.6 0.9]);
btnSimulate.Layout.Row = 18;
btnSimulate.Layout.Column = [1 2];
btnSimulate.ButtonPushedFcn = @(~,~) onSimulate();

% Observations
mkSectionLabel(c1, 19, 'Observations');
txtObs1 = uitextarea(c1, 'Editable', 'off');
txtObs1.Layout.Row = [20 22];
txtObs1.Layout.Column = [1 2];
txtObs1.Value = {'Click "Simulate" to see observations.'};

% Set callbacks for dynamic visibility
ddSysType.ValueChangedFcn   = @(~,~) updateSimVisibility();
ddInputType.ValueChangedFcn = @(~,~) updateSimVisibility();

% ---- Right panel: plots ----
plotGrid1 = uigridlayout(g1, [2 1]);
plotGrid1.RowHeight = {'1x', '1x'};
axInput1  = uiaxes(plotGrid1);
axOutput1 = uiaxes(plotGrid1);
formatAxes(axInput1,  'Input Signal', 'Time (s)', 'Input');
formatAxes(axOutput1, 'System Response', 'Time (s)', 'Output');

% =========================================================================
%  TAB 2: DATA IMPORT & IDENTIFICATION
% =========================================================================
tab2 = uitab(tabs, 'Title', '2. Data Import & Identification');
g2 = uigridlayout(tab2, [1 2]);
g2.ColumnWidth = {350, '1x'};

% ---- Left panel ----
pan2 = uipanel(g2, 'Title', 'Data & Model Settings');
c2 = uigridlayout(pan2, [22 2]);
c2.ColumnWidth = {150, '1x'};
c2.RowHeight = [repmat({26}, 1, 21), {'1x'}];
c2.Scrollable = 'on';

% Data Import
mkSectionLabel(c2, 1, 'Data Import');
btnImport = uibutton(c2, 'Text', 'Import Data...');
btnImport.Layout.Row = 2;
btnImport.Layout.Column = [1 2];
btnImport.ButtonPushedFcn = @(~,~) onImportData();

lblFileName = uilabel(c2, 'Text', 'No file loaded', 'WordWrap', 'on');
lblFileName.Layout.Row = 3;
lblFileName.Layout.Column = [1 2];

lblDataInfo = uilabel(c2, 'Text', '', 'FontSize', 10);
lblDataInfo.Layout.Row = 4;
lblDataInfo.Layout.Column = [1 2];

% Column Mapping
mkSectionLabel(c2, 5, 'Column Mapping');
ddTimeCol = mkDropdown(c2, 6, 'Time Column', {'None'}, {0}, 0);
ddInputCol  = mkDropdown(c2, 7, 'Input Column', {'-'}, {1}, 1);
ddOutputCol = mkDropdown(c2, 8, 'Output Column', {'-'}, {1}, 1);
efTsManual  = mkNumericField(c2, 9, 'Manual Ts (s)', 0.1, [1e-9, 1e6]);

btnApplyMapping = uibutton(c2, 'Text', 'Apply Column Mapping');
btnApplyMapping.Layout.Row = 10;
btnApplyMapping.Layout.Column = [1 2];
btnApplyMapping.ButtonPushedFcn = @(~,~) onApplyMapping();

% Data Preview
mkSectionLabel(c2, 11, 'Data Preview');
txtPreview = uitextarea(c2, 'Editable', 'off', 'FontName', 'Courier New', ...
    'FontSize', 10);
txtPreview.Layout.Row = [12 13];
txtPreview.Layout.Column = [1 2];

% ARX Model Orders
mkSectionLabel(c2, 14, 'ARX Model Orders');
spNa = mkSpinner(c2, 15, 'na', 2, 1, 10);
spNb = mkSpinner(c2, 16, 'nb', 2, 1, 10);
spNk = mkSpinner(c2, 17, 'nk', 1, 0, 10);

% Estimation/Validation Split
mkSectionLabel(c2, 18, 'Estimation / Validation Split');
efSplitPct = mkNumericField(c2, 19, 'Estimation %', 70, [50, 90]);
lblSplitInfo = uilabel(c2, 'Text', '', 'FontSize', 10);
lblSplitInfo.Layout.Row = 20;
lblSplitInfo.Layout.Column = [1 2];

% Identify button
btnIdentify = uibutton(c2, 'Text', 'Identify Model', ...
    'FontWeight', 'bold', 'FontSize', 13, ...
    'BackgroundColor', [0.2 0.7 0.3]);
btnIdentify.Layout.Row = 21;
btnIdentify.Layout.Column = [1 2];
btnIdentify.ButtonPushedFcn = @(~,~) onIdentifyModel();

% ---- Right panel ----
rightGrid2 = uigridlayout(g2, [3 2]);
rightGrid2.RowHeight = {'1x', 210, 30};
rightGrid2.ColumnWidth = {'1x', '1x'};

% Top row: input and output plots side by side
axInput2  = uiaxes(rightGrid2);
axInput2.Layout.Row = 1;
axInput2.Layout.Column = 1;
formatAxes(axInput2, 'Imported Input Signal', 'Time (s)', 'Input');

axOutput2 = uiaxes(rightGrid2);
axOutput2.Layout.Row = 1;
axOutput2.Layout.Column = 2;
formatAxes(axOutput2, 'Imported Output Signal', 'Time (s)', 'Output');

% Middle row: Results panel spanning both columns
txtResults = uitextarea(rightGrid2, 'Editable', 'off', ...
    'FontName', 'Courier New', 'FontSize', 11);
txtResults.Layout.Row = 2;
txtResults.Layout.Column = [1 2];
txtResults.Value = {'Import data and run identification to see results here.'};

% Bottom row: Export button
btnExport = uibutton(rightGrid2, 'Text', 'Export Results...');
btnExport.Layout.Row = 3;
btnExport.Layout.Column = [1 2];
btnExport.ButtonPushedFcn = @(~,~) onExportResults();

% =========================================================================
%  TAB 3: MODEL VALIDATION
% =========================================================================
tab3 = uitab(tabs, 'Title', '3. Model Validation');
g3 = uigridlayout(tab3, [2 1]);
g3.RowHeight = {'1.3x', '1x'};

% ---- Top section: validation plot with run button ----
topGrid3 = uigridlayout(g3, [1 1]);
topGrid3.Padding = [5 5 5 5];
axValidation = uiaxes(topGrid3);
formatAxes(axValidation, 'Measured vs Predicted Output', 'Time (s)', 'Output');

% ---- Bottom section: 3 columns ----
bottomGrid3 = uigridlayout(g3, [1 3]);
bottomGrid3.ColumnWidth = {'1x', '1.5x', '1x'};

% Column 1: Metrics panel
metricsPanel = uipanel(bottomGrid3, 'Title', 'Fit Metrics');
metricsGrid = uigridlayout(metricsPanel, [2 1]);
metricsGrid.RowHeight = {30, '1x'};
btnRunValidation = uibutton(metricsGrid, 'Text', 'Run Validation', ...
    'FontWeight', 'bold', 'BackgroundColor', [0.9 0.6 0.2]);
btnRunValidation.ButtonPushedFcn = @(~,~) onRunValidation();
txtMetrics = uitextarea(metricsGrid, 'Editable', 'off', 'FontName', 'Courier New', ...
    'FontSize', 10);
txtMetrics.Value = {'Identify a model first (Tab 2).'};

% Column 2: Residual plots (2 axes stacked)
resPlotGrid = uigridlayout(bottomGrid3, [2 1]);
resPlotGrid.RowHeight = {'1x', '1x'};
axResiduals = uiaxes(resPlotGrid);
formatAxes(axResiduals, 'Residuals vs Time', 'Time (s)', 'Residual');
axHistogram = uiaxes(resPlotGrid);
formatAxes(axHistogram, 'Residual Histogram', 'Residual', 'Count');

% Column 3: ACF plot and interpretation
acfGrid = uigridlayout(bottomGrid3, [2 1]);
acfGrid.RowHeight = {'1x', '1x'};
axACF = uiaxes(acfGrid);
formatAxes(axACF, 'Autocorrelation', 'Lag', 'ACF');
txtInterpretation = uitextarea(acfGrid, 'Editable', 'off', 'FontSize', 10);
txtInterpretation.Value = {'Run validation to see interpretation.'};

% =========================================================================
%  TAB 4: INTERACTIVE ANALYSIS
% =========================================================================
tab4 = uitab(tabs, 'Title', '4. Interactive Analysis');
g4 = uigridlayout(tab4, [1 2]);
g4.ColumnWidth = {350, '1x'};

% ---- Left panel: controls ----
pan4 = uipanel(g4, 'Title', 'Sensitivity Studies');
c4 = uigridlayout(pan4, [20 2]);
c4.ColumnWidth = {150, '1x'};
c4.RowHeight = [repmat({26}, 1, 19), {'1x'}];
c4.Scrollable = 'on';

% Study type dropdown
mkSectionLabel(c4, 1, 'Analysis Type');
ddAnalysis = mkDropdown(c4, 2, 'Study', ...
    {'Model Order Sensitivity', 'Noise Sensitivity', 'Input Signal Analysis', 'Sampling Time Analysis'}, ...
    {'order', 'noise', 'input', 'sampling'}, 'order');
ddAnalysis.ValueChangedFcn = @(~,~) updateAnalysisVisibility();

% --- Model Order Sensitivity controls ---
mkSectionLabel(c4, 3, 'Model Order Study');
lbl4OrderMax = uilabel(c4, 'Text', 'Max Order');
lbl4OrderMax.Layout.Row = 4; lbl4OrderMax.Layout.Column = 1;
spMaxOrder = uispinner(c4, 'Value', 5, 'Limits', [2 10], 'Step', 1, ...
    'RoundFractionalValues', 'on');
spMaxOrder.Layout.Row = 4; spMaxOrder.Layout.Column = 2;
ddHeatMetric = mkDropdown(c4, 5, 'Heatmap Metric', ...
    {'Val Free-Run Fit', 'Val One-Step Fit'}, {'fr', 'os'}, 'fr');
ddHeatMetric.ValueChangedFcn = @(~,~) drawOrderStudy();

btnRunOrder = uibutton(c4, 'Text', 'Run Model Order Study', ...
    'FontWeight', 'bold', 'BackgroundColor', [0.3 0.6 0.9]);
btnRunOrder.Layout.Row = 6; btnRunOrder.Layout.Column = [1 2];
btnRunOrder.ButtonPushedFcn = @(~,~) onRunOrderStudy();

% --- Noise Sensitivity controls ---
mkSectionLabel(c4, 7, 'Noise Sensitivity');
lbl4Noise = uilabel(c4, 'Text', 'Noise Level');
lbl4Noise.Layout.Row = 8; lbl4Noise.Layout.Column = 1;
lblNoiseVal = uilabel(c4, 'Text', '10 %', 'FontWeight', 'bold');
lblNoiseVal.Layout.Row = 8; lblNoiseVal.Layout.Column = 2;
sldNoise = uislider(c4, 'Limits', [0 100], 'Value', 10, ...
    'MajorTicks', 0:25:100, 'MinorTicks', []);
sldNoise.Layout.Row = 9; sldNoise.Layout.Column = [1 2];
sldNoise.ValueChangingFcn = @(~,e) set(lblNoiseVal, 'Text', sprintf('%.0f %%', e.Value));
sldNoise.ValueChangedFcn  = @(s,~) set(lblNoiseVal, 'Text', sprintf('%.0f %%', s.Value));

efSeed = mkNumericField(c4, 10, 'Random Seed', 1, [0 1e6]);
efSeed.RoundFractionalValues = 'on';

btnRunNoise = uibutton(c4, 'Text', 'Run Noise Study', ...
    'FontWeight', 'bold', 'BackgroundColor', [0.3 0.6 0.9]);
btnRunNoise.Layout.Row = 11; btnRunNoise.Layout.Column = [1 2];
btnRunNoise.ButtonPushedFcn = @(~,~) onRunNoiseStudy();

% --- Input Signal Analysis controls ---
mkSectionLabel(c4, 12, 'Input Signal Analysis');
txtInputAnalysis = uitextarea(c4, 'Editable', 'off', 'FontSize', 10);
txtInputAnalysis.Layout.Row = [13 15]; txtInputAnalysis.Layout.Column = [1 2];
txtInputAnalysis.Value = { ...
    'Input excitation is critical for identification.', ...
    '', ...
    'Step: excites mainly DC/low freq. Good for gain estimation.', ...
    'Sine: excites a single frequency. Limited information.', ...
    'PRBS: broadband excitation. Ideal for identification.', ...
    'Square: odd harmonics only.', ...
    'Impulse: low energy, poor SNR.', ...
    '', ...
    'Use Tab 1 to experiment with different input signals.'};

% --- Sampling Time Analysis controls ---
mkSectionLabel(c4, 16, 'Sampling Time Analysis');
lbl4SampInfo = uilabel(c4, 'Text', 'Current Ts: N/A', 'FontSize', 10);
lbl4SampInfo.Layout.Row = 17; lbl4SampInfo.Layout.Column = [1 2];

efTsFactors = uieditfield(c4, 'text', 'Value', '1 2 3 4 6 8');
efTsFactors.Layout.Row = 18; efTsFactors.Layout.Column = 2;
lbl4Factors = uilabel(c4, 'Text', 'Ts Multipliers');
lbl4Factors.Layout.Row = 18; lbl4Factors.Layout.Column = 1;

btnRunSampling = uibutton(c4, 'Text', 'Run Sampling Study', ...
    'FontWeight', 'bold', 'BackgroundColor', [0.3 0.6 0.9]);
btnRunSampling.Layout.Row = 19; btnRunSampling.Layout.Column = [1 2];
btnRunSampling.ButtonPushedFcn = @(~,~) onRunSamplingStudy();

txtSampNote = uitextarea(c4, 'Editable', 'off', 'FontSize', 10);
txtSampNote.Layout.Row = 20; txtSampNote.Layout.Column = [1 2];
txtSampNote.Value = { ...
    'Nyquist: Ts < 1/(2*fmax).', ...
    'Rule of thumb: 5-10 samples per fastest time constant.', ...
    'Too fast => poles near z=1, ill-conditioned.', ...
    'Too slow => lose dynamics, fewer samples.'};

% ---- Right panel: analysis results ----
rightGrid4 = uigridlayout(g4, [3 2]);
rightGrid4.RowHeight = {'1x', '1x', '1x'};
rightGrid4.ColumnWidth = {'1x', '1x'};

% Row 1: Heatmap + table (model order study)
axHeatmap = uiaxes(rightGrid4);
axHeatmap.Layout.Row = 1; axHeatmap.Layout.Column = 1;
formatAxes(axHeatmap, 'Fit % Heatmap (na vs nb)', 'nb', 'na');

tblOrderResults = uitable(rightGrid4);
tblOrderResults.Layout.Row = 1; tblOrderResults.Layout.Column = 2;
tblOrderResults.ColumnName = {'na', 'nb', 'Est %', 'Val 1-step %', 'Val FR %', 'Notes'};

% Row 2: Noise comparison + sweep
axNoiseCompare = uiaxes(rightGrid4);
axNoiseCompare.Layout.Row = 2; axNoiseCompare.Layout.Column = 1;
formatAxes(axNoiseCompare, 'Noise Experiment', 'Time (s)', 'Output');

axNoiseSweep = uiaxes(rightGrid4);
axNoiseSweep.Layout.Row = 2; axNoiseSweep.Layout.Column = 2;
formatAxes(axNoiseSweep, 'Fit vs Noise Level', 'Noise (% of std)', 'Fit (%)');

% Row 3: Sampling plot + observations text
axSampling = uiaxes(rightGrid4);
axSampling.Layout.Row = 3; axSampling.Layout.Column = 1;
formatAxes(axSampling, 'Fit vs Sampling Time', 'Ts (s)', 'Fit (%)');

txtObsTab4 = uitextarea(rightGrid4, 'Editable', 'off', 'FontSize', 10);
txtObsTab4.Layout.Row = 3; txtObsTab4.Layout.Column = 2;
txtObsTab4.Value = {'Run an experiment to see observations.'};

% ---- Initial analysis panel visibility ----
updateAnalysisVisibility();

% =========================================================================
%  INITIALIZATION
% =========================================================================
updateSimVisibility();
if nargout > 0
    figHandle = fig;
end

% =========================================================================
%  UI HELPER FUNCTIONS (nested)
% =========================================================================

    function lbl = mkSectionLabel(parent, row, txt)
        lbl = uilabel(parent, 'Text', txt, 'FontWeight', 'bold', ...
            'FontSize', 12);
        lbl.Layout.Row = row;
        lbl.Layout.Column = [1 2];
    end

    function ef = mkNumericField(parent, row, labelText, defaultVal, limits)
        lbl = uilabel(parent, 'Text', labelText);
        lbl.Layout.Row = row;
        lbl.Layout.Column = 1;
        ef = uieditfield(parent, 'numeric', 'Value', defaultVal, ...
            'Limits', limits);
        ef.Layout.Row = row;
        ef.Layout.Column = 2;
    end

    function dd = mkDropdown(parent, row, labelText, items, itemsData, defaultVal)
        lbl = uilabel(parent, 'Text', labelText);
        lbl.Layout.Row = row;
        lbl.Layout.Column = 1;
        dd = uidropdown(parent, 'Items', items, 'ItemsData', itemsData, ...
            'Value', defaultVal);
        dd.Layout.Row = row;
        dd.Layout.Column = 2;
    end

    function sp = mkSpinner(parent, row, labelText, defaultVal, minVal, maxVal)
        lbl = uilabel(parent, 'Text', labelText);
        lbl.Layout.Row = row;
        lbl.Layout.Column = 1;
        sp = uispinner(parent, 'Value', defaultVal, ...
            'Limits', [minVal maxVal], 'Step', 1, ...
            'RoundFractionalValues', 'on');
        sp.Layout.Row = row;
        sp.Layout.Column = 2;
    end

    function formatAxes(ax, titleStr, xlabelStr, ylabelStr)
        title(ax, titleStr);
        xlabel(ax, xlabelStr);
        ylabel(ax, ylabelStr);
        grid(ax, 'on');
    end

    function setStatus(msg, level)
        % Update the status bar label with coloured text.
        if nargin < 2, level = 'info'; end
        switch level
            case 'error', clr = [0.75 0 0];
            case 'warn',  clr = [0.8 0.45 0];
            case 'ok',    clr = [0 0.5 0.1];
            otherwise,    clr = [0.2 0.2 0.2];
        end
        try
            stamp = datestr(now, 'HH:MM:SS'); %#ok<TNOW1,DATST>
            statusBar.Text = sprintf('[%s] %s', stamp, msg);
            statusBar.FontColor = clr;
        catch
            % Figure may have been deleted
        end
    end

    function alertUser(msg, ttl)
        try
            uialert(fig, msg, ttl, 'Icon', 'error');
        catch
            % Figure may have been deleted
        end
    end

    function warnUser(msg, ttl)
        try
            uialert(fig, msg, ttl, 'Icon', 'warning');
        catch
        end
    end

    function onClose()
        delete(fig);
    end

    function s = fmtFit(v)
        % Format a fit percentage for display.
        if isnan(v)
            s = 'N/A';
        elseif isinf(v) && v < 0
            s = '-Inf (diverged)';
        else
            s = sprintf('%.2f', v);
        end
    end

    function s = fmtFit0(v)
        % Short format for heatmap annotations.
        if isnan(v), s = 'N/A';
        elseif v < -999, s = '<-999';
        else, s = sprintf('%.1f', v);
        end
    end

% =========================================================================
%  TAB 1 CALLBACKS: SYSTEM SIMULATION
% =========================================================================

    function updateSimVisibility()
        % Show/hide parameter fields based on system type and input type.
        sysType = ddSysType.Value;
        inType  = ddInputType.Value;

        isFirst = strcmp(sysType, 'first');
        efTau.Enable  = boolToOnOff(isFirst);
        efWn.Enable   = boolToOnOff(~isFirst);
        efZeta.Enable = boolToOnOff(~isFirst);

        efFreqSim.Enable  = boolToOnOff(ismember(inType, {'sine', 'square'}));
        efStepTime.Enable = boolToOnOff(strcmp(inType, 'step'));
        efRampSlope.Enable = boolToOnOff(strcmp(inType, 'ramp'));
        efPRBSBits.Enable  = boolToOnOff(strcmp(inType, 'prbs'));
    end

    function s = boolToOnOff(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end

    function onSimulate()
        try
            % --- Gather parameters ---
            sysType = ddSysType.Value;
            inType  = ddInputType.Value;
            Ts      = efTsSim.Value;
            dur     = efDur.Value;

            % Build system params struct
            if strcmp(sysType, 'first')
                sysNum = 1;
                sysParams = struct('K', efK.Value, 'tau', efTau.Value);
            else
                sysNum = 2;
                sysParams = struct('K', efK.Value, 'wn', efWn.Value, ...
                    'zeta', efZeta.Value);
            end

            % Build input signal params struct
            inputParams = struct();
            inputParams.amplitude = efAmp.Value;
            switch inType
                case 'step'
                    inputParams.stepTime = efStepTime.Value;
                case 'impulse'
                    % amplitude only
                case 'ramp'
                    inputParams.slope = efRampSlope.Value;
                    inputParams.startTime = 0;
                case 'sine'
                    inputParams.frequency = efFreqSim.Value;
                case 'square'
                    inputParams.frequency = efFreqSim.Value;
                case 'prbs'
                    inputParams.numBits = efPRBSBits.Value;
            end

            % Generate input signal
            [u, t_in] = sid.generateInput(inType, Ts, dur, inputParams);

            % Simulate plant
            [t, y, ~] = sid.simulatePlant(sysNum, sysParams, u, Ts);

            % --- Plot input signal ---
            cla(axInput1);
            stairs(axInput1, t_in, u, 'b', 'LineWidth', 1.5);
            formatAxes(axInput1, 'Input Signal', 'Time (s)', 'Input');

            % --- Plot system response ---
            cla(axOutput1);
            plot(axOutput1, t, y, 'r', 'LineWidth', 1.5);
            formatAxes(axOutput1, 'System Response', 'Time (s)', 'Output');

            % --- Generate observations ---
            obs = generateObservations(sysType, sysParams, inType, ...
                inputParams, t, y, u, Ts);
            txtObs1.Value = obs;

            setStatus(sprintf('Simulation complete: %s system, %s input, %d samples', ...
                sysType, inType, length(t)));

        catch ME
            setStatus(['Simulation error: ' ME.message], 'error');
            txtObs1.Value = {['Error: ' ME.message]};
        end
    end

    function obs = generateObservations(sysType, sysParams, inType, inputParams, t, y, u, Ts)
        % Generate descriptive observations about the simulated response.
        obs = {};

        if strcmp(sysType, 'first')
            K   = sysParams.K;
            tau = sysParams.tau;
            obs{end+1} = sprintf('1st Order System: G(s) = %.4g / (%.4g*s + 1)', K, tau);
            obs{end+1} = sprintf('Time constant tau = %.4g s', tau);
            obs{end+1} = sprintf('Settling time (~4*tau) = %.4g s', 4*tau);
            obs{end+1} = sprintf('DC gain K = %.4g', K);
            obs{end+1} = sprintf('Discrete pole: z = exp(-Ts/tau) = %.4f', exp(-Ts/tau));
            if tau/Ts < 5
                obs{end+1} = 'WARNING: Sampling too coarse relative to tau (< 5 samples/tau).';
            end
        else
            K    = sysParams.K;
            wn   = sysParams.wn;
            zeta = sysParams.zeta;
            obs{end+1} = sprintf('2nd Order System: G(s) = %.4g*%.4g^2 / (s^2 + 2*%.4g*%.4g*s + %.4g^2)', ...
                K, wn, zeta, wn, wn);

            if zeta < 1
                dampStr = 'Underdamped';
                overshoot = 100 * exp(-pi * zeta / sqrt(1 - zeta^2));
                obs{end+1} = sprintf('Damping: %s (zeta = %.4g)', dampStr, zeta);
                obs{end+1} = sprintf('Predicted overshoot: %.1f%%', overshoot);
                wd = wn * sqrt(1 - zeta^2);
                obs{end+1} = sprintf('Damped natural freq: %.4g rad/s', wd);
                obs{end+1} = sprintf('Peak time: %.4g s', pi / wd);
            elseif zeta == 1
                obs{end+1} = sprintf('Damping: Critically Damped (zeta = %.4g)', zeta);
            else
                obs{end+1} = sprintf('Damping: Overdamped (zeta = %.4g)', zeta);
            end
            obs{end+1} = sprintf('Natural frequency wn = %.4g rad/s', wn);
        end

        % Input-specific observations
        switch inType
            case 'step'
                ampVal = inputParams.amplitude;
                if strcmp(sysType, 'first')
                    ssVal = sysParams.K * ampVal;
                else
                    ssVal = sysParams.K * ampVal;
                end
                obs{end+1} = '';
                obs{end+1} = sprintf('Step input: amplitude = %.4g', ampVal);
                obs{end+1} = sprintf('Expected steady-state: K*A = %.4g', ssVal);
                obs{end+1} = sprintf('Actual final value: %.4g', y(end));
            case 'sine'
                obs{end+1} = '';
                obs{end+1} = sprintf('Sine input: freq = %.4g Hz, amplitude = %.4g', ...
                    inputParams.frequency, inputParams.amplitude);
                obs{end+1} = 'Transient dies out, leaving steady-state sinusoidal response.';
            case 'prbs'
                obs{end+1} = '';
                obs{end+1} = 'PRBS input: broadband excitation, ideal for system identification.';
            case 'impulse'
                obs{end+1} = '';
                obs{end+1} = 'Impulse response: shows natural dynamics but low energy (poor SNR).';
            case 'ramp'
                obs{end+1} = '';
                obs{end+1} = 'Ramp input: unbounded, mainly excites very low frequencies.';
            case 'square'
                obs{end+1} = '';
                obs{end+1} = 'Square wave: periodic excitation at odd harmonics only.';
        end
    end

% =========================================================================
%  TAB 2 CALLBACKS: DATA IMPORT & IDENTIFICATION
% =========================================================================

    function onImportData()
        try
            [fname, fpath] = uigetfile( ...
                {'*.csv;*.xlsx;*.xls;*.txt', 'Data files (*.csv, *.xlsx, *.xls, *.txt)'}, ...
                'Select Data File');
            try, figure(fig); catch, end
            if isequal(fname, 0)
                return;  % User cancelled
            end
            fullPath = fullfile(fpath, fname);

            % Read file
            [~, ~, ext] = fileparts(fullPath);
            if strcmpi(ext, '.txt')
                T = readtable(fullPath, 'FileType', 'text');
            else
                T = readtable(fullPath);
            end

            if width(T) < 2 || height(T) < 1
                setStatus('Import failed: file needs at least 2 columns and 1 row.', 'error');
                alertUser('File needs at least 2 columns (input, output) and 1 data row.', ...
                    'Import Failed');
                return;
            end

            % Store raw data
            colNames = T.Properties.VariableNames;
            nCols = numel(colNames);
            S.raw = struct('T', T, 'file', fname, 'path', fpath, ...
                'names', {colNames});

            % Reset downstream state
            S.orig = [];  S.work = [];  S.model = [];
            S.ev = [];    S.study = [];  S.noise = [];  S.samp = [];

            % Populate column dropdowns
            ddTimeCol.Items = [{'None'}, colNames];
            ddTimeCol.ItemsData = [0, 1:nCols];
            ddInputCol.Items = colNames;
            ddInputCol.ItemsData = 1:nCols;
            ddOutputCol.Items = colNames;
            ddOutputCol.ItemsData = 1:nCols;

            % Auto-detect column assignments
            if nCols >= 3
                defTime = 1; defIn = 2; defOut = 3;
            else
                defTime = 0; defIn = 1; defOut = 2;
            end
            ddTimeCol.Value   = findColByName(colNames, {'time','t','timestamp','time_s'}, defTime);
            ddInputCol.Value  = findColByName(colNames, {'input','u','in','u_k'}, defIn);
            ddOutputCol.Value = findColByName(colNames, {'output','y','out','y_k'}, defOut);

            % Update file info label
            lblFileName.Text = sprintf('%s  (%d rows x %d columns)', ...
                fname, height(T), nCols);

            % Show preview
            showDataPreview(T);

            % Update data info label
            lblDataInfo.Text = sprintf('Rows: %d | Columns: %d', height(T), nCols);

            setStatus(sprintf('Imported "%s". Select columns and click "Apply Column Mapping".', fname), 'ok');

            % Clear plots
            cla(axInput2);  formatAxes(axInput2, 'Imported Input Signal', 'Time (s)', 'Input');
            cla(axOutput2); formatAxes(axOutput2, 'Imported Output Signal', 'Time (s)', 'Output');
            txtResults.Value = {'Data imported. Apply column mapping to validate.'};

        catch ME
            setStatus(['Import error: ' ME.message], 'error');
            alertUser(ME.message, 'Import Failed');
        end
    end

    function idx = findColByName(names, candidates, defaultIdx)
        % Try to match column names to known patterns.
        idx = defaultIdx;
        for i = 1:numel(candidates)
            k = find(strcmpi(names, candidates{i}), 1);
            if ~isempty(k)
                idx = k;
                return;
            end
        end
    end

    function showDataPreview(T)
        % Show first 5-10 rows as formatted text in the preview area.
        nShow = min(8, height(T));
        names = T.Properties.VariableNames;

        lines = {};
        % Header
        hdr = '';
        for j = 1:numel(names)
            hdr = [hdr, sprintf('%-14s', names{j})]; %#ok<AGROW>
        end
        lines{end+1} = hdr;
        lines{end+1} = repmat('-', 1, 14*numel(names));

        % Data rows
        for i = 1:nShow
            row = '';
            for j = 1:numel(names)
                val = T{i, j};
                if isnumeric(val)
                    row = [row, sprintf('%-14.6g', val)]; %#ok<AGROW>
                elseif iscell(val)
                    row = [row, sprintf('%-14s', char(val))]; %#ok<AGROW>
                else
                    row = [row, sprintf('%-14s', char(string(val)))]; %#ok<AGROW>
                end
            end
            lines{end+1} = row; %#ok<AGROW>
        end
        if nShow < height(T)
            lines{end+1} = sprintf('... (%d more rows)', height(T) - nShow);
        end
        txtPreview.Value = lines;
    end

    function onApplyMapping()
        try
            if isempty(S.raw)
                warnUser('Import a file first.', 'No Data');
                return;
            end

            T = S.raw.T;
            names = S.raw.names;
            timeIdx   = ddTimeCol.Value;
            inputIdx  = ddInputCol.Value;
            outputIdx = ddOutputCol.Value;

            % Validate column selections
            if inputIdx == outputIdx
                alertUser('Input and output must be different columns.', 'Column Mapping');
                return;
            end
            if timeIdx > 0 && (timeIdx == inputIdx || timeIdx == outputIdx)
                alertUser('Time column must differ from input/output.', 'Column Mapping');
                return;
            end

            % Extract data vectors
            if timeIdx > 0
                tVec = T.(names{timeIdx});
            else
                tVec = [];
            end
            uVec = T.(names{inputIdx});
            yVec = T.(names{outputIdx});

            % Validate using sid.validateSignals
            TsVal = efTsManual.Value;
            opts = struct('missing', 'interpolate');
            rep = sid.validateSignals(tVec, uVec, yVec, TsVal, opts);

            if ~rep.ok
                msg = strjoin(rep.errors, '\n');
                setStatus(['Validation failed: ' strjoin(rep.errors, ' | ')], 'error');
                alertUser(msg, 'Validation Failed');
                return;
            end

            % Store validated data
            S.orig = struct('t', rep.t, 'u', rep.u, 'y', rep.y, ...
                'Ts', rep.Ts, 'irregular', rep.irregular, ...
                'file', S.raw.file, 'hasTime', timeIdx > 0, ...
                'warnings', {rep.warnings}, 'note', '');
            S.work = S.orig;
            S.model = [];  S.ev = [];
            S.study = [];  S.noise = [];  S.samp = [];

            % Update data info
            N = numel(rep.t);
            lblDataInfo.Text = sprintf('Samples: %d | Ts: %.6g s | Duration: %.4g s', ...
                N, rep.Ts, rep.t(end) - rep.t(1));

            % Update split info
            updateSplitInfo();

            % Plot the data
            plotImportedData();

            % Handle warnings
            lvl = 'ok';
            msg = sprintf('Data validated: %d samples, Ts = %.6g s.', N, rep.Ts);
            if ~isempty(rep.warnings)
                lvl = 'warn';
                msg = [msg ' Warnings: ' strjoin(rep.warnings, ' | ')];
            end

            if rep.irregular
                warnUser(['Sampling is irregular. Resample to a uniform grid before ' ...
                    'identification. Median interval: ' sprintf('%.6g s.', rep.Ts)], ...
                    'Irregular Sampling');
            end

            setStatus(msg, lvl);

            % Update tab 4 sampling info
            lbl4SampInfo.Text = sprintf('Current Ts: %.6g s', rep.Ts);

        catch ME
            setStatus(['Mapping error: ' ME.message], 'error');
            alertUser(ME.message, 'Mapping Error');
        end
    end

    function updateSplitInfo()
        if isempty(S.work), return; end
        N = numel(S.work.y);
        pct = efSplitPct.Value / 100;
        Ne = floor(pct * N);
        Nv = N - Ne;
        lblSplitInfo.Text = sprintf('Est: %d samples | Val: %d samples', Ne, Nv);
    end

    function plotImportedData()
        if isempty(S.work), return; end
        w = S.work;
        N = numel(w.y);
        pct = efSplitPct.Value / 100;
        Ne = floor(pct * N);

        % Input plot
        cla(axInput2);
        plot(axInput2, w.t, w.u, 'b', 'LineWidth', 1.2);
        formatAxes(axInput2, 'Imported Input Signal', 'Time (s)', 'Input');

        % Output plot with est/val split indication
        cla(axOutput2);
        plot(axOutput2, w.t(1:Ne), w.y(1:Ne), 'b', 'LineWidth', 1.2, ...
            'DisplayName', 'Estimation');
        hold(axOutput2, 'on');
        if Ne < N
            plot(axOutput2, w.t(Ne+1:N), w.y(Ne+1:N), 'Color', [0.8 0.4 0], ...
                'LineWidth', 1.2, 'DisplayName', 'Validation');
            yl = ylim(axOutput2);
            plot(axOutput2, [w.t(Ne) w.t(Ne)], yl, 'k--', 'LineWidth', 1, ...
                'HandleVisibility', 'off');
        end
        hold(axOutput2, 'off');
        legend(axOutput2, 'show', 'Location', 'best');
        formatAxes(axOutput2, 'Imported Output (Est|Val Split)', 'Time (s)', 'Output');
    end

    function onIdentifyModel()
        try
            if isempty(S.work)
                warnUser('Import and validate data first (use "Apply Column Mapping").', 'No Data');
                return;
            end
            if S.work.irregular
                warnUser('Data is irregularly sampled. Resample first.', 'Irregular Sampling');
                return;
            end

            u = S.work.u;
            y = S.work.y;
            Ts = S.work.Ts;
            N = numel(y);

            na = spNa.Value;
            nb = spNb.Value;
            nk = spNk.Value;
            pct = efSplitPct.Value / 100;
            Ne = floor(pct * N);

            if N - Ne < 5
                warnUser('Validation segment too small (< 5 samples). Reduce estimation %.', ...
                    'Split Error');
                return;
            end

            % Estimate ARX model
            model = sid.estimateARX(u, y, na, nb, nk, Ne);
            model.Ts = Ts;

            % Evaluate model (predictions + fit metrics)
            ev = sid.evaluateModel(model, u, y, Ne);

            % Store results
            S.model = model;
            S.ev = ev;
            S.Ne = Ne;

            % Display results
            displayModelResults();

            % Update plots
            plotImportedData();

            % Build status message
            lvl = 'ok';
            msg = sprintf('ARX(%d,%d,%d) identified. Val fit: 1-step %.2f%%, free-run %s%%', ...
                na, nb, nk, ev.valOS.fit, fmtFit(ev.valFR.fit));
            if ~isempty(model.warnings)
                lvl = 'warn';
                msg = [msg ' | WARN: ' strjoin(model.warnings, ' | ')];
            end
            setStatus(msg, lvl);

        catch ME
            setStatus(['Identification error: ' ME.message], 'error');
            alertUser(ME.message, 'Identification Failed');
        end
    end

    function displayModelResults()
        if isempty(S.model)
            txtResults.Value = {'No model identified yet.'};
            return;
        end

        m  = S.model;
        ev = S.ev;
        Ne = S.Ne;
        N  = numel(S.work.y);

        lines = {};
        lines{end+1} = '========== ESTIMATED ARX MODEL ==========';
        lines{end+1} = sprintf('Model: ARX(%d, %d, %d)  |  Ts = %.6g s', m.na, m.nb, m.nk, m.Ts);
        lines{end+1} = sprintf('Estimation: %d samples  |  Validation: %d samples', Ne, N - Ne);
        lines{end+1} = '';

        % A coefficients
        lines{end+1} = 'A Coefficients (denominator):';
        for i = 1:m.na
            lines{end+1} = sprintf('  a%d = %+.6g', i, m.a(i)); %#ok<AGROW>
        end

        % B coefficients
        lines{end+1} = '';
        lines{end+1} = 'B Coefficients (numerator):';
        for i = 1:m.nb
            lines{end+1} = sprintf('  b%d = %+.6g', i, m.b(i)); %#ok<AGROW>
        end

        % Transfer function
        lines{end+1} = '';
        tfLines = sid.tfString(m, m.Ts);
        for i = 1:numel(tfLines)
            lines{end+1} = tfLines{i}; %#ok<AGROW>
        end

        % Conditioning info
        lines{end+1} = '';
        lines{end+1} = sprintf('Condition number: %.3g', m.condPhi);
        lines{end+1} = sprintf('Rank(Phi): %d / %d', m.rankPhi, m.na + m.nb);
        lines{end+1} = sprintf('Regression rows used: %d', m.nEst);

        % Fit metrics
        lines{end+1} = '';
        lines{end+1} = '========== FIT METRICS ==========';
        lines{end+1} = sprintf('Estimation Fit (1-step):       %s %%', fmtFit(ev.est.fit));
        lines{end+1} = sprintf('Validation Fit (1-step):       %s %%', fmtFit(ev.valOS.fit));
        lines{end+1} = sprintf('Validation Fit (free-run):     %s %%', fmtFit(ev.valFR.fit));

        % Warnings
        if ~isempty(m.warnings)
            lines{end+1} = '';
            lines{end+1} = '========== WARNINGS ==========';
            for i = 1:numel(m.warnings)
                lines{end+1} = ['  * ' m.warnings{i}]; %#ok<AGROW>
            end
        end

        txtResults.Value = lines;
    end

    function onExportResults()
        try
            if isempty(S.model)
                warnUser('Identify a model first.', 'Nothing to Export');
                return;
            end

            [fname, fpath] = uiputfile( ...
                {'*.mat', 'MAT file (*.mat)'; '*.csv', 'CSV file (*.csv)'}, ...
                'Export Results', 'arx_results');
            try, figure(fig); catch, end
            if isequal(fname, 0), return; end

            [~, base, ext] = fileparts(fname);
            outBase = fullfile(fpath, base);

            m  = S.model;
            ev = S.ev;
            w  = S.work;
            N  = numel(w.y);
            Ne = S.Ne;

            results = struct( ...
                'a', m.a, 'b', m.b, 'na', m.na, 'nb', m.nb, 'nk', m.nk, ...
                'Ts', m.Ts, ...
                'theta', m.theta, ...
                'transferFunction', {sid.tfString(m, m.Ts)}, ...
                'fitEstimation', ev.est.fit, ...
                'fitValidationOneStep', ev.valOS.fit, ...
                'fitValidationFreeRun', ev.valFR.fit, ...
                'rmseValOneStep', ev.valOS.rmse, ...
                'resMeanValOneStep', ev.valOS.resMean, ...
                'resStdValOneStep', ev.valOS.resStd, ...
                't', w.t, 'u', w.u, ...
                'yActual', w.y, ...
                'yOneStep', ev.yhat, ...
                'yFreeRun', ev.ysim, ...
                'residualOneStep', w.y - ev.yhat, ...
                'estimationSamples', Ne);

            if strcmpi(ext, '.mat')
                save([outBase '.mat'], 'results');
                setStatus(['Results exported to ' outBase '.mat'], 'ok');
            else
                % CSV export: summary + signals
                fid = fopen([outBase '_summary.csv'], 'w');
                fprintf(fid, 'quantity,value\n');
                fprintf(fid, 'na,%d\nnb,%d\nnk,%d\n', m.na, m.nb, m.nk);
                fprintf(fid, 'Ts_s,%.10g\n', m.Ts);
                fprintf(fid, 'estimation_samples,%d\nvalidation_samples,%d\n', Ne, N - Ne);
                for i = 1:m.na
                    fprintf(fid, 'a%d,%.12g\n', i, m.a(i));
                end
                for i = 1:m.nb
                    fprintf(fid, 'b%d,%.12g\n', i, m.b(i));
                end
                fprintf(fid, 'fit_estimation_pct,%.6g\n', results.fitEstimation);
                fprintf(fid, 'fit_validation_onestep_pct,%.6g\n', results.fitValidationOneStep);
                fprintf(fid, 'fit_validation_freerun_pct,%.6g\n', results.fitValidationFreeRun);
                fprintf(fid, 'rmse_validation_onestep,%.6g\n', results.rmseValOneStep);
                fclose(fid);

                % Signals CSV
                Tsig = array2table([w.t, w.u, w.y, ev.yhat, ev.ysim, w.y - ev.yhat], ...
                    'VariableNames', {'time', 'input', 'y_actual', 'y_onestep', ...
                    'y_freerun', 'residual_onestep'});
                writetable(Tsig, [outBase '_signals.csv']);
                setStatus(['Results exported to ' outBase '_summary.csv and _signals.csv'], 'ok');
            end

        catch ME
            setStatus(['Export error: ' ME.message], 'error');
            alertUser(ME.message, 'Export Failed');
        end
    end

% =========================================================================
%  TAB 3 CALLBACKS: MODEL VALIDATION
% =========================================================================

    function onRunValidation()
        try
            if isempty(S.model) || isempty(S.work)
                warnUser('Identify a model first (Tab 2).', 'No Model');
                return;
            end

            w  = S.work;
            m  = S.model;
            ev = S.ev;
            Ne = S.Ne;
            N  = numel(w.y);
            t  = w.t;
            y  = w.y;

            % ---- Main validation plot ----
            cla(axValidation);
            plot(axValidation, t, y, 'k', 'LineWidth', 1.2, ...
                'DisplayName', 'Measured');
            hold(axValidation, 'on');
            plot(axValidation, t, ev.yhat, 'b--', 'LineWidth', 1.2, ...
                'DisplayName', 'One-Step Prediction');
            plot(axValidation, t, ev.ysim, 'g:', 'LineWidth', 1.5, ...
                'DisplayName', 'Free-Run Simulation');
            % Vertical line at est/val boundary
            yl = ylim(axValidation);
            plot(axValidation, [t(Ne) t(Ne)], yl, '--', ...
                'Color', [0.5 0.5 0.5], 'LineWidth', 1.2, ...
                'HandleVisibility', 'off');
            text(axValidation, t(Ne), yl(2)*0.95, ' Est|Val', ...
                'FontSize', 9, 'Color', [0.5 0.5 0.5]);
            hold(axValidation, 'off');
            legend(axValidation, 'show', 'Location', 'best');
            formatAxes(axValidation, ...
                sprintf('Measured vs Predicted (split at t=%.3g s)', t(Ne)), ...
                'Time (s)', 'Output');

            % ---- Metrics display ----
            metricsLines = {};
            metricsLines{end+1} = sprintf('ARX(%d,%d,%d)  Ts=%.5g s', m.na, m.nb, m.nk, m.Ts);
            metricsLines{end+1} = sprintf('Est: %d  Val: %d samples', Ne, N - Ne);
            metricsLines{end+1} = '';
            metricsLines{end+1} = sprintf('Estimation Fit:       %s %%', fmtFit(ev.est.fit));
            metricsLines{end+1} = sprintf('Val 1-Step Fit:       %s %%', fmtFit(ev.valOS.fit));
            metricsLines{end+1} = sprintf('Val Free-Run Fit:     %s %%', fmtFit(ev.valFR.fit));
            metricsLines{end+1} = '';
            metricsLines{end+1} = sprintf('RMSE (1-step):  %.4g', ev.valOS.rmse);
            metricsLines{end+1} = sprintf('RMSE (free-run): %.4g', ev.valFR.rmse);
            metricsLines{end+1} = sprintf('Res. Mean:       %.4g', ev.valOS.resMean);
            metricsLines{end+1} = sprintf('Res. Std:        %.4g', ev.valOS.resStd);
            txtMetrics.Value = metricsLines;

            % ---- Residual analysis (validation one-step) ----
            valSeg = (Ne+1):N;
            yp_val = ev.yhat(valSeg);
            y_val  = y(valSeg);
            t_val  = t(valSeg);

            resInfo = sid.calculateResiduals(y_val, yp_val, 30);

            if resInfo.N < 3
                cla(axResiduals);  cla(axHistogram);  cla(axACF);
                txtInterpretation.Value = {'Insufficient data for residual analysis.'};
            else
                % Residuals vs Time
                cla(axResiduals);
                tt = t_val(resInfo.idx);
                plot(axResiduals, tt, resInfo.e, 'b', 'LineWidth', 1);
                hold(axResiduals, 'on');
                plot(axResiduals, [tt(1) tt(end)], [0 0], 'k-', ...
                    'LineWidth', 0.8, 'HandleVisibility', 'off');
                hold(axResiduals, 'off');
                formatAxes(axResiduals, 'Residuals (Val 1-Step)', 'Time (s)', 'Residual');

                % Residual Histogram
                cla(axHistogram);
                histogram(axHistogram, resInfo.e);
                formatAxes(axHistogram, 'Residual Histogram', 'Residual', 'Count');

                % ACF
                cla(axACF);
                stem(axACF, resInfo.lags, resInfo.acf, 'filled', 'MarkerSize', 4);
                hold(axACF, 'on');
                plot(axACF, [0 resInfo.lags(end)], [resInfo.bound resInfo.bound], ...
                    'r--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
                plot(axACF, [0 resInfo.lags(end)], [-resInfo.bound -resInfo.bound], ...
                    'r--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
                hold(axACF, 'off');
                ylim(axACF, [-1 1]);
                formatAxes(axACF, ...
                    sprintf('Residual ACF (95%% bounds: +/-%.3f)', resInfo.bound), ...
                    'Lag', 'ACF');

                % Interpretation text
                interpLines = generateResidualInterpretation(resInfo, ev);
                txtInterpretation.Value = interpLines;
            end

            setStatus('Validation complete.', 'ok');

        catch ME
            setStatus(['Validation error: ' ME.message], 'error');
            alertUser(ME.message, 'Validation Error');
        end
    end

    function lines = generateResidualInterpretation(rInfo, ev)
        lines = {};
        lines{end+1} = sprintf('Residual mean: %.4g', rInfo.mean);
        lines{end+1} = sprintf('Residual std:  %.4g', rInfo.std);
        lines{end+1} = '';

        if rInfo.std > 0 && abs(rInfo.mean) > 0.2 * rInfo.std
            lines{end+1} = 'Bias detected: residual mean is not ~0. This suggests DC offset or unmodelled static gain.';
            lines{end+1} = '';
        end

        if ~isnan(rInfo.fracOutside)
            if rInfo.fracOutside > 0.05
                lines{end+1} = sprintf('%.0f%% of ACF lags exceed the 95%% bounds.', ...
                    100 * rInfo.fracOutside);
                lines{end+1} = 'Residuals are NOT white noise.';
                lines{end+1} = 'Unmodelled dynamics or coloured noise present.';
                lines{end+1} = 'Try different model orders or nk.';
            else
                lines{end+1} = 'ACF mostly within 95% bounds.';
                lines{end+1} = 'Residuals appear approximately white.';
                lines{end+1} = 'Model captures the main dynamics.';
            end
        end

        lines{end+1} = '';
        if ev.valFR.fit < ev.valOS.fit - 20
            lines{end+1} = 'Free-run fit is much lower than 1-step fit.';
            lines{end+1} = '1-step prediction may be flattering.';
            lines{end+1} = 'Judge model quality by free-run fit.';
        end

        lines{end+1} = '';
        lines{end+1} = 'Good model: small, zero-mean, patternless residuals.';
        lines{end+1} = 'Poor model: systematic patterns in residuals.';
    end

% =========================================================================
%  TAB 4 CALLBACKS: INTERACTIVE ANALYSIS
% =========================================================================

    function updateAnalysisVisibility()
        % Show/hide analysis-type specific controls.
        % All controls remain in the grid but we can use visual cues.
        % The right-side plots always show results of the last run study.
        % This is mainly for the UI controls enable/disable.
        sel = ddAnalysis.Value;

        % Model order controls
        orderEn = boolToOnOff(strcmp(sel, 'order'));
        spMaxOrder.Enable = orderEn;
        ddHeatMetric.Enable = orderEn;
        btnRunOrder.Enable = orderEn;

        % Noise controls
        noiseEn = boolToOnOff(strcmp(sel, 'noise'));
        sldNoise.Enable = noiseEn;
        efSeed.Enable = noiseEn;
        btnRunNoise.Enable = noiseEn;

        % Sampling controls
        sampEn = boolToOnOff(strcmp(sel, 'sampling'));
        efTsFactors.Enable = sampEn;
        btnRunSampling.Enable = sampEn;
    end

    function [u, y, Ts, frac, ok] = getWorkingData()
        % Get working data and validate readiness for analysis.
        u = []; y = []; Ts = []; frac = []; ok = false;
        if isempty(S.work)
            warnUser('Import and validate a dataset first (Tab 2).', 'No Data');
            return;
        end
        if S.work.irregular
            warnUser('Data is irregularly sampled. Resample first (Tab 2).', 'Irregular Sampling');
            return;
        end
        u = S.work.u;
        y = S.work.y;
        Ts = S.work.Ts;
        frac = efSplitPct.Value / 100;
        ok = true;
    end

    function onRunOrderStudy()
        try
            [u, y, Ts, frac, ok] = getWorkingData();
            if ~ok, return; end

            maxOrd = spMaxOrder.Value;
            nk = spNk.Value;

            setStatus('Running model order study...', 'info');
            drawnow;

            opts = struct('nk', nk, 'split', frac, 'maxOrder', maxOrd);
            S.study = sid.runSensitivityStudy('order', u, y, Ts, opts);

            s = S.study;

            % Build observation text
            L = sprintf(['MODEL ORDER (nk=%d): best free-run fit %.2f%% at na=%d, nb=%d; ' ...
                'best 1-step %.2f%% at na=%d, nb=%d.'], ...
                s.nk, s.bestFR, s.bestFRna, s.bestFRnb, ...
                s.bestOS, s.bestOSna, s.bestOSnb);
            if s.bestEstna * s.bestEstnb > s.bestFRna * s.bestFRnb && ...
                    (s.bestEstna ~= s.bestFRna || s.bestEstnb ~= s.bestFRnb)
                L = [L ' The most complex model fits estimation data best but not ' ...
                    'validation data: possible overfitting.'];
            end
            L = [L ' Higher orders fit more estimation noise but may degrade ' ...
                'free-run validation accuracy.'];
            S.obs.order = L;

            drawOrderStudy();
            updateTab4Obs();
            setStatus(sprintf('Order study done (%dx%d models).', maxOrd, maxOrd), 'ok');

        catch ME
            setStatus(['Order study error: ' ME.message], 'error');
            alertUser(ME.message, 'Order Study Failed');
        end
    end

    function drawOrderStudy()
        cla(axHeatmap);
        if isempty(S.study)
            formatAxes(axHeatmap, 'Fit % Heatmap (na vs nb)', 'nb', 'na');
            tblOrderResults.Data = {};
            return;
        end

        s = S.study;
        mo = s.maxOrder;

        % Select metric to display
        if strcmp(ddHeatMetric.Value, 'fr')
            F = s.FitFR;  metricName = 'Free-Run';
        else
            F = s.FitOS;  metricName = 'One-Step';
        end

        % Clip for colour mapping
        Fc = max(F, -50);
        Fc(isnan(Fc)) = -50;

        imagesc(axHeatmap, 1:mo, 1:mo, Fc);
        colormap(axHeatmap, 'parula');
        try, colorbar(axHeatmap); catch, end
        axHeatmap.XTick = 1:mo;
        axHeatmap.YTick = 1:mo;
        axHeatmap.YDir = 'normal';

        % Annotate cells with fit values
        hold(axHeatmap, 'on');
        for i = 1:mo
            for j = 1:mo
                text(axHeatmap, j, i, fmtFit0(F(i,j)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 9, ...
                    'Color', 'k');
            end
        end

        % Mark best
        if strcmp(ddHeatMetric.Value, 'fr')
            bn = s.bestFRna;  bb = s.bestFRnb;
        else
            bn = s.bestOSna;  bb = s.bestOSnb;
        end
        plot(axHeatmap, bb, bn, 'rs', 'MarkerSize', 22, 'LineWidth', 2.5);
        hold(axHeatmap, 'off');
        formatAxes(axHeatmap, ...
            sprintf('Val %s Fit [%%] (best = red square)', metricName), ...
            'nb (numerator)', 'na (denominator)');

        % Populate table sorted by free-run fit
        D = cell(mo*mo, 6);
        keys = zeros(mo*mo, 1);
        k = 0;
        for i = 1:mo
            for j = 1:mo
                k = k + 1;
                D(k,:) = {i, j, ...
                    roundFit(s.FitEst(i,j)), ...
                    roundFit(s.FitOS(i,j)), ...
                    roundFit(s.FitFR(i,j)), ...
                    s.Note{i,j}};
                keys(k) = s.FitFR(i,j);
                if isnan(keys(k)), keys(k) = -Inf; end
            end
        end
        [~, sortIdx] = sort(keys, 'descend');
        tblOrderResults.Data = D(sortIdx, :);
    end

    function v = roundFit(x)
        if isnan(x), v = NaN; else, v = round(x, 2); end
    end

    function onRunNoiseStudy()
        try
            [u, y, Ts, frac, ok] = getWorkingData();
            if ~ok, return; end

            setStatus('Running noise sensitivity study...', 'info');
            drawnow;

            noiseLevel = sldNoise.Value;
            seedVal = efSeed.Value;
            na = spNa.Value;
            nb = spNb.Value;
            nk = spNk.Value;

            opts = struct('na', na, 'nb', nb, 'nk', nk, 'split', frac, ...
                'noisePct', noiseLevel, 'seed', seedVal, ...
                'levels', [0 2 5 10 20 30 50 75 100]);

            S.noise = sid.runSensitivityStudy('noise', u, y, Ts, opts);

            n = S.noise;
            L = sprintf(['NOISE (%.0f%% of std(y), seed %d): val 1-step fit %.2f%% -> %.2f%%; ' ...
                'free-run %s%% -> %s%%.'], ...
                n.pct, n.seed, ...
                n.evBase.valOS.fit, n.evNoisy.valOS.fit, ...
                fmtFit(n.evBase.valFR.fit), fmtFit(n.evNoisy.valFR.fit));
            L = [L ' Noise on estimation outputs biases ARX (errors-in-variables effect).'];
            S.obs.noise = L;

            drawNoiseStudy();
            updateTab4Obs();
            setStatus(sprintf('Noise study done (%.0f%%).', noiseLevel), 'ok');

        catch ME
            setStatus(['Noise study error: ' ME.message], 'error');
            alertUser(ME.message, 'Noise Study Failed');
        end
    end

    function drawNoiseStudy()
        cla(axNoiseCompare);  cla(axNoiseSweep);
        if isempty(S.noise) || isempty(S.work)
            formatAxes(axNoiseCompare, 'Noise Experiment', 'Time (s)', 'Output');
            formatAxes(axNoiseSweep, 'Fit vs Noise Level', 'Noise (% std)', 'Fit (%)');
            return;
        end

        n = S.noise;
        w = S.work;
        Ne = n.Ne;
        N = numel(w.y);
        seg = (Ne+1):N;

        % Comparison plot: measured vs baseline vs noisy model
        plot(axNoiseCompare, w.t(seg), w.y(seg), 'k', 'LineWidth', 1.2, ...
            'DisplayName', 'Measured (val)');
        hold(axNoiseCompare, 'on');
        plot(axNoiseCompare, w.t(seg), n.evBase.ysim(seg), 'b', 'LineWidth', 1.3, ...
            'DisplayName', 'Baseline model');
        plot(axNoiseCompare, w.t(seg), n.evNoisy.ysim(seg), 'r--', 'LineWidth', 1.3, ...
            'DisplayName', sprintf('%.0f%% noise model', n.pct));
        hold(axNoiseCompare, 'off');
        legend(axNoiseCompare, 'show', 'Location', 'best');
        formatAxes(axNoiseCompare, 'Noise Experiment (Validation Segment)', 'Time (s)', 'Output');

        % Sweep plot: fit vs noise level
        plot(axNoiseSweep, n.levels, max(n.sweepOS, -100), 'bo-', 'LineWidth', 1.3, ...
            'DisplayName', 'Val 1-step');
        hold(axNoiseSweep, 'on');
        plot(axNoiseSweep, n.levels, max(n.sweepFR, -100), 'rs-', 'LineWidth', 1.3, ...
            'DisplayName', 'Val free-run');
        hold(axNoiseSweep, 'off');
        legend(axNoiseSweep, 'show', 'Location', 'best');
        formatAxes(axNoiseSweep, 'Fit vs Noise Level', 'Noise (% of std)', 'Fit (%)');
    end

    function onRunSamplingStudy()
        try
            [u, y, Ts, frac, ok] = getWorkingData();
            if ~ok, return; end

            setStatus('Running sampling time study...', 'info');
            drawnow;

            % Parse factors from text field
            factors = sscanf(efTsFactors.Value, '%f')';
            if isempty(factors) || any(~isfinite(factors)) || any(factors <= 0)
                alertUser('Enter positive multipliers (e.g. "1 2 4 8").', 'Invalid Input');
                return;
            end

            na = spNa.Value;
            nb = spNb.Value;
            nk = spNk.Value;

            opts = struct('na', na, 'nb', nb, 'nk', nk, 'split', frac, ...
                'factors', factors, 't', S.work.t);

            S.samp = sid.runSensitivityStudy('sampling', u, y, Ts, opts);

            s = S.samp;
            L = 'SAMPLING TIME STUDY: ';
            for i = 1:numel(s.Ts)
                if isnan(s.FitFR(i)) && isnan(s.FitOS(i))
                    L = [L sprintf('Ts=%.4g: failed (%s). ', s.Ts(i), s.Note{i})]; %#ok<AGROW>
                else
                    L = [L sprintf('Ts=%.4g s (N=%d): 1-step %.1f%%, FR %s%%. ', ...
                        s.Ts(i), s.N(i), s.FitOS(i), fmtFit(s.FitFR(i)))]; %#ok<AGROW>
                end
            end
            L = [L 'Poles map as z=exp(s*Ts); fast sampling pushes poles toward z=1 (ill-conditioned).'];
            S.obs.samp = L;

            drawSamplingStudy();
            updateTab4Obs();
            setStatus('Sampling time study done.', 'ok');

        catch ME
            setStatus(['Sampling study error: ' ME.message], 'error');
            alertUser(ME.message, 'Sampling Study Failed');
        end
    end

    function drawSamplingStudy()
        cla(axSampling);
        if isempty(S.samp)
            formatAxes(axSampling, 'Fit vs Sampling Time', 'Ts (s)', 'Fit (%)');
            return;
        end

        s = S.samp;
        plot(axSampling, s.Ts, max(s.FitOS, -100), 'bo-', 'LineWidth', 1.3, ...
            'DisplayName', 'Val 1-step');
        hold(axSampling, 'on');
        plot(axSampling, s.Ts, max(s.FitFR, -100), 'rs-', 'LineWidth', 1.3, ...
            'DisplayName', 'Val free-run');
        hold(axSampling, 'off');
        legend(axSampling, 'show', 'Location', 'best');
        formatAxes(axSampling, 'Fit vs Sampling Time (Resampled)', 'Ts (s)', 'Fit (%)');
    end

    function updateTab4Obs()
        % Consolidate all observation strings into the text area.
        parts = {S.obs.order, S.obs.noise, S.obs.samp};
        parts = parts(~cellfun(@isempty, parts));
        if isempty(parts)
            txtObsTab4.Value = {'Run an experiment to see observations.'};
        else
            txtObsTab4.Value = parts;
        end
    end

end  % SystemIdentificationGUI
