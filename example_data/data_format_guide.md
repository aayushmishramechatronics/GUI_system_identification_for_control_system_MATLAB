# Dataset Format & Import Guide

This guide describes the dataset requirements and guidelines for importing experimental or simulation time-series data into the **System Identification GUI (SysIdGUI)**.

---

## 1. Supported File Formats

The GUI imports data using MATLAB's built-in table readers (`readtable` / `readmatrix`):

- **CSV (`.csv`)**: Comma-Separated Values (recommended).
- **Excel (`.xlsx`, `.xls`)**: Microsoft Excel spreadsheets.
- **Text (`.txt`)**: Delimited text files (tab, space, or comma separated).

---

## 2. Expected Dataset Layouts

### Format A: Time, Input, Output (Standard 3-Column)

Columns can appear in any order and with any header names. The GUI allows interactive mapping via dropdown menus.

```csv
Time_s,Input_Voltage,Output_Speed
0.0000,1.0000,0.0035
0.0500,1.0000,0.0893
0.1000,1.0000,0.2925
0.1500,1.0000,0.5624
...
```

- **Time column**: Monotonically increasing time stamps in seconds.
- **Input column**: Actuator/excitation signal $u(k)$.
- **Output column**: Sensor/measurement signal $y(k)$.

### Format B: Input, Output Only (2-Column)

When physical time stamps were not recorded by the acquisition hardware:

```csv
ControlSignal,SensorResponse
1.0000,0.0035
1.0000,0.0893
1.0000,0.2925
...
```

- In the GUI, select **"(none - specify Ts)"** for the Time column.
- Enter the constant sampling interval $T_s$ manually into the provided numeric field.
- The GUI will automatically synthesize a uniform time vector $t = [0, T_s, 2T_s, \dots, (N-1)T_s]^T$.

---

## 3. Data Integrity & Validation Rules

Before parameter estimation, the GUI enforces rigorous engineering data checks:

1. **Numerical Data**: Input and output must contain real finite numbers.
2. **Length Consistency**: The input and output vectors must have exactly the same number of samples ($N \ge 10$, preferably $N \ge 100$).
3. **Monotonic Time**: If a time vector is supplied, time differences $\Delta t_k = t_{k+1} - t_k$ must be strictly positive.
4. **Sampling Uniformity**:
   - If sampling intervals vary by more than $0.01\%$, the GUI flags the dataset as **Irregular Sampling**.
   - A warning dialog will notify the user with an option to resample to a uniform grid via linear interpolation.
5. **Missing / NaN Values**:
   - By default, missing samples are detected and reported.
   - The user can select **Interpolate linearly** to reconstruct isolated missing points before ARX identification.
6. **Input Excitation**:
   - The application checks whether the input has non-zero variation. A constant input is flagged because persistent excitation is necessary to identify dynamic poles and zeros.

---

## 4. Provided Example Datasets

The `example_data/` directory includes 4 ready-to-use sample datasets:

1. **`example_first_order.csv`**:
   - True plant: $G(s) = \frac{2}{1.5s + 1}$, $T_s = 0.05\text{ s}$
   - Excitation: PRBS (amplitude 1.0, hold 6 samples) with 2% measurement noise.
2. **`example_second_order.csv`**:
   - True plant: $G(s) = \frac{1.5 \cdot 2.5^2}{s^2 + 2(0.4)(2.5)s + 2.5^2}$, $T_s = 0.05\text{ s}$
   - Excitation: PRBS (amplitude 2.0, hold 8 samples) with 3% measurement noise.
3. **`example_input_output_only.csv`**:
   - 2-column dataset demonstrating manual $T_s$ entry ($T_s = 0.05\text{ s}$).
4. **`example_irregular_sampling.csv`**:
   - Timestamped dataset with variable sampling intervals, used to test the irregular-sampling detector and uniform resampling module.
