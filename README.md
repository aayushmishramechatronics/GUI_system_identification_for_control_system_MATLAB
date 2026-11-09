# System Identification GUI (SysIdGUI)

## 1. Project Overview

A MATLAB-based interactive application for dynamic system identification using the ARX (AutoRegressive with eXogenous input) method. Developed as an academic engineering project demonstrating system simulation, data import, model identification, validation, and sensitivity analysis. Built entirely with programmatic MATLAB GUI (uifigure) without reliance on any MATLAB toolboxes.

## 2. Software Requirements

- MATLAB R2020b or newer
- No additional toolboxes required
- Standard MATLAB installation is sufficient
- The application uses only built-in MATLAB functions

## 3. Folder Structure

```
SysIdGUI/
├── SystemIdentificationGUI.m      # Main application entry point
├── runSelfTests.m                  # Self-testing and verification script
├── README.md                       # This file
├── Technical_Report_Template.md    # Academic report template
├── +sid/                           # Computational functions package
│   ├── simulatePlant.m            # System simulation (1st/2nd order)
│   ├── generateInput.m            # Input signal generation
│   ├── validateSignals.m          # Data validation & resampling
│   ├── estimateARX.m              # ARX parameter estimation (Least Squares)
│   ├── predictARX.m               # One-step-ahead prediction
│   ├── simulateARX.m              # Free-run recursive simulation
│   ├── calculateFit.m             # Fit metrics calculation
│   ├── calculateResiduals.m       # Residual analysis & ACF
│   └── runSensitivityStudy.m      # Sensitivity experiments
└── example_data/                   # Example datasets
    ├── example_first_order.csv
    ├── example_second_order.csv
    └── data_format_guide.md
```

## 4. How to Launch the Application

```matlab
% Navigate to the project folder
cd('path/to/SysIdGUI')

% Launch the GUI
SystemIdentificationGUI
```

The application window opens with four tabs: System Simulation, Data Import & Identification, Model Validation, and Interactive Analysis.

## 5. How to Import a Dataset

1. Navigate to the **Data Import & Identification** tab
2. Click the **Import Data** button
3. Select a CSV, XLSX, or TXT file
4. The application displays a preview of the data and populates column-mapping dropdowns
5. Select which columns correspond to **Time**, **Input**, and **Output**
   - If no time column exists, select "None" and enter the sampling time manually
6. Click **Apply Column Mapping**
7. The application validates the data and displays the imported signals

### Supported Data Formats

- **CSV files** (.csv): Comma-separated values
- **Excel files** (.xlsx, .xls): Microsoft Excel format
- **Text files** (.txt): Tab or comma delimited

### Data Requirements

- Input and output columns must be numeric
- Minimum 20 samples recommended
- If a time column is provided, it must be monotonically increasing
- Missing values (NaN) and infinite values are detected and reported

## 6. How to Configure ARX Model Orders

In the **Data Import & Identification** tab:

- **na** (denominator order): Number of past output terms (1–10, default: 2)
- **nb** (numerator order): Number of past input terms (1–10, default: 2)
- **nk** (input delay): Number of sample delays (0–10, default: 1)
- **Estimation %**: Percentage of data for estimation (50–90%, default: 70%)

### Guidelines for Order Selection

- Start with na=2, nb=2, nk=1 as a baseline
- Use the Interactive Analysis tab's Model Order Sensitivity study to find optimal orders
- Higher orders increase model flexibility but risk overfitting
- nk=1 is typical for systems with one-sample transport delay

## 7. How to Perform Identification

1. Import and validate your dataset (Section 5)
2. Set the desired model orders (Section 6)
3. Click **Identify Model**
4. The application:
   - Splits data chronologically (estimation + validation)
   - Constructs the regression matrix
   - Estimates ARX parameters using Least Squares
   - Displays the estimated coefficients and transfer function
5. Review the displayed transfer function G(z)
6. Check for any condition number warnings

## 8. How to Validate the Model

1. After identification, switch to the **Model Validation** tab
2. Click **Run Validation**
3. The application displays:
   - Measured output vs. one-step prediction vs. free-run simulation
   - Fit percentages (estimation, validation one-step, validation free-run)
   - RMSE and residual statistics
   - Residual time plot, histogram, and autocorrelation function
4. Examine the residual ACF — values within the confidence bounds suggest adequate modelling

### Interpreting Results

- **High one-step fit, low free-run fit**: Model captures short-term dynamics but not long-term behaviour
- **Both fits high**: Good model for both prediction and simulation
- **Significant residual autocorrelation**: Unmodelled dynamics may be present
- **Large residuals**: Model may need different orders or the data may need preprocessing

## 9. How to Conduct Sensitivity Experiments

Navigate to the **Interactive Analysis** tab:

### Model Order Sensitivity

1. Select "Model Order Sensitivity" from the dropdown
2. Set the maximum order to evaluate
3. Click **Run Model Order Study**
4. Examine the heatmap — brighter values indicate better fit
5. The best (na, nb) combination is highlighted

### Noise Sensitivity

1. Select "Noise Sensitivity" from the dropdown
2. Click **Run Noise Study**
3. The application tests multiple noise levels (0% to 100% of output std)
4. View how identification accuracy degrades with increasing noise

### Input Signal Analysis

- Educational panel explaining input excitation requirements
- Use the System Simulation tab to experiment with different signals

### Sampling Time Analysis

- Shows current dataset sampling time
- Explains how sampling time affects discrete-time models

## 10. How to Export Results

1. After identification, click **Export Results** in the Data Import & Identification tab
2. Choose a save location
3. The application exports:
   - Model coefficients (a and b vectors)
   - Model orders (na, nb, nk)
   - Sampling time
   - Fit percentages and RMSE
   - Actual and predicted output arrays
   - Residual arrays

Export formats: MAT file (MATLAB native) or CSV

## 11. Explanation of the ARX Method

### Mathematical Foundation

The ARX (AutoRegressive with eXogenous input) model relates the current output y(k) to past outputs and inputs:

```
y(k) = -a₁·y(k-1) - ... - aₙₐ·y(k-na) + b₁·u(k-nk) - ... + bₙᵦ·u(k-nk-nb+1) + e(k)
```

In polynomial form:

```
A(q)·y(k) = B(q)·u(k) + e(k)
```

where:
- A(q) = 1 + a₁·q⁻¹ + ... + aₙₐ·q⁻ⁿᵃ
- B(q) = b₁·q⁻ⁿᵏ + ... + bₙᵦ·q⁻⁽ⁿᵏ⁺ⁿᵇ⁻¹⁾

### Least Squares Estimation

The model is rewritten as a linear regression:

```
Y = Φ · θ + E
```

The parameter vector θ = [a₁, ..., aₙₐ, b₁, ..., bₙᵦ]ᵀ is estimated by:

```
θ̂ = Φ \ Y  (MATLAB backslash operator)
```

This is numerically superior to explicitly computing (ΦᵀΦ)⁻¹Φᵀ Y.

### Discrete Transfer Function

The identified model yields the discrete-time transfer function:

```
G(z) = B(z⁻¹) / A(z⁻¹)
```

## 12. Troubleshooting

| Issue | Solution |
|-------|----------|
| GUI doesn't launch | Ensure you're in the SysIdGUI folder and MATLAB's current directory contains SystemIdentificationGUI.m |
| "Undefined function 'sid.xxx'" | Ensure the +sid folder is in the same directory as SystemIdentificationGUI.m |
| Import fails | Check file format (CSV, XLSX, TXT). Ensure data is numeric. |
| Poor identification fit | Try different model orders. Ensure input signal has sufficient excitation. |
| Condition number warning | The estimation problem may be poorly conditioned. Try lower model orders or check data quality. |
| Negative fit percentage | The model prediction is worse than a constant mean prediction. Try different orders. |
| GUI is slow | Large datasets (>10000 samples) may take longer. Consider downsampling. |
| Plots don't update | Click the relevant "Simulate", "Identify", or "Validate" button to refresh. |
