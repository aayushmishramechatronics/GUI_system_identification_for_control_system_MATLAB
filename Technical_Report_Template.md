# Technical Report: Development of a GUI for System Identification

**Course:** Control Systems & System Identification / Dynamic Systems Modelling  
**Academic Assignment:** 10-Mark Practical Engineering Project  
**Student Name:** `[Insert Full Name]`  
**Roll / Matriculation Number:** `[Insert Student ID]`  
**Date of Submission:** `[Insert Date]`  
**MATLAB Version:** MATLAB R2020b or newer (Verified on MATLAB R2024b)  

---

## 1. Title

**Interactive MATLAB Application for Dynamic System Simulation, ARX Model Identification, and Statistical Model Validation**

---

## 2. Objective

The primary objective of this project is to design, implement, and validate a standalone, modular, programmatic MATLAB graphical user interface (`SysIdGUI`) that:
1. Simulates continuous-time first-order and second-order dynamic systems under diverse test excitations via Zero-Order Hold (ZOH) augmented matrix-exponential discretization without toolboxes.
2. Imports arbitrary experimental or numerical time-series datasets from CSV, XLSX, and TXT files, providing dynamic column mapping, validation, sampling-rate recovery, and missing-data handling.
3. Performs parameter estimation for discrete-time AutoRegressive with eXogenous input (ARX) models using an independently implemented Ordinary Least Squares (OLS) algorithm.
4. Validates model quality by comparing actual outputs with one-step-ahead predictions and multi-step recursive free-run simulations, calculating normalized fit percentages, RMSE, and residual statistics.
5. Conducts residual diagnostic analysis (residuals vs. time, distribution histograms, and Autocorrelation Function [ACF] with 95% confidence intervals).
6. Provides an interactive sensitivity suite exploring the effects of model order ($n_a, n_b$), additive measurement noise, and sampling period ($T_s$) on estimation accuracy and parameter stability.

---

## 3. Introduction to System Identification

System identification is the scientific discipline of constructing mathematical models of dynamic systems from measured input-output observations. In modern engineering—ranging from aerospace and industrial robotics to chemical process automation and biomedical devices—deriving accurate physical models purely from first principles (white-box modelling) is often intractable due to unmodelled dynamics, parametric uncertainties, distributed effects, and environmental noise.

System identification bridges this gap through data-driven methodologies:
- **Black-box modelling**: The internal physical structure is unknown; a mathematical model (such as an ARX or ARMAX transfer function) is fitted to describe the input-output mapping.
- **Grey-box modelling**: The model structure is known from physical laws, but key physical parameters (e.g., damping coefficients, thermal resistances) are estimated from data.

A complete system identification cycle encompasses five interconnected phases:
$$\text{Experiment Design \& Excitation} \longrightarrow \text{Data Preprocessing} \longrightarrow \text{Model Structure Selection} \longrightarrow \text{Parameter Estimation} \longrightarrow \text{Model Validation}$$

If validation reveals unacceptable prediction residuals or unmodelled dynamic modes, the engineer must iterate back to revisit model orders, data filtering, or excitation conditions.

---

## 4. Methodology & Workflow

The developed application follows a strict chronological engineering workflow:

```
[Import Raw Data (CSV/Excel/TXT)] 
               │
               ▼
   [Column Mapping & Validation]
  (Monotonic time, NaN/Inf checks, excitation)
               │
               ▼
[Chronological Data Partitioning]
  (70% Estimation / 30% Validation)
               │
               ▼
   [ARX Least Squares Estimation] ──► [Parameter Vector θ & G(z)]
               │
               ▼
   [Model Validation & Metrics] 
  ├── One-Step-Ahead Prediction y_hat(k)
  ├── Free-Run Recursive Simulation y_sim(k)
  └── Normalized Fit %, RMSE, Residual Stats
               │
               ▼
     [Residual Diagnostics]
  ├── Time series e(k) = y(k) - y_hat(k)
  ├── Probability Distribution Histogram
  └── Autocorrelation Function (ACF) with ±1.96/√N bounds
               │
               ▼
[Interactive Sensitivity Experiments]
  ├── Order Grid Search (na vs. nb heatmap)
  ├── Measurement Noise Robustness Sweep
  └── Sampling Rate / Resampling Study
```

---

## 5. System Simulation

### 5.1 Continuous-Time Plant Models

1. **First-Order Linear System:**
   $$G_1(s) = \frac{Y(s)}{U(s)} = \frac{K}{\tau s + 1}$$
   where $K$ is the steady-state gain and $\tau > 0$ is the time constant.
   The state-space representation is:
   $$\dot{x}(t) = -\frac{1}{\tau}x(t) + \frac{K}{\tau}u(t), \quad y(t) = x(t)$$

2. **Second-Order Linear System:**
   $$G_2(s) = \frac{Y(s)}{U(s)} = \frac{K \omega_n^2}{s^2 + 2\zeta\omega_n s + \omega_n^2}$$
   where $K$ is the static gain, $\omega_n > 0$ is the undamped natural frequency, and $\zeta \ge 0$ is the damping ratio.
   In controllable canonical state-space form:
   $$\begin{bmatrix} \dot{x}_1(t) \\ \dot{x}_2(t) \end{bmatrix} = \begin{bmatrix} 0 & 1 \\ -\omega_n^2 & -2\zeta\omega_n \end{bmatrix} \begin{bmatrix} x_1(t) \\ x_2(t) \end{bmatrix} + \begin{bmatrix} 0 \\ K \omega_n^2 \end{bmatrix} u(t), \quad y(t) = \begin{bmatrix} 1 & 0 \end{bmatrix} \begin{bmatrix} x_1(t) \\ x_2(t) \end{bmatrix}$$

### 5.2 Zero-Order Hold (ZOH) Discretization

To simulate the continuous systems without relying on the Control System Toolbox, the exact Zero-Order Hold discretization is computed using the augmented matrix exponential method:
$$\mathbf{M} = \exp\left( \begin{bmatrix} \mathbf{A} & \mathbf{B} \\ \mathbf{0}_{1 \times n} & 0 \end{bmatrix} T_s \right) = \begin{bmatrix} \mathbf{A}_d & \mathbf{B}_d \\ \mathbf{0}_{1 \times n} & 1 \end{bmatrix}$$
where:
$$\mathbf{A}_d = \mathbf{M}(1:n, 1:n) = e^{\mathbf{A} T_s}, \quad \mathbf{B}_d = \mathbf{M}(1:n, n+1) = \int_0^{T_s} e^{\mathbf{A}\eta} \mathbf{B} \, d\eta$$
This formulation is numerically stable and holds identically even when $\mathbf{A}$ is singular or ill-conditioned. The discrete state update is:
$$\mathbf{x}_{k+1} = \mathbf{A}_d \mathbf{x}_k + \mathbf{B}_d u_k, \quad y_k = \mathbf{C} \mathbf{x}_k + \mathbf{D} u_k$$

### 5.3 Simulation Observations

`[Insert observations regarding the effects of K, tau, wn, and zeta. Attach simulation response screenshots from Tab 1 below.]`

- **Effect of Time Constant $\tau$:** `[Describe response speed and rise time]`
- **Effect of Damping Ratio $\zeta$:** `[Describe underdamped oscillations, critical damping, and overdamped lag]`
- **Input Signal Comparison:** `[Compare Step, Ramp, Sinusoid, and PRBS excitations]`

---

## 6. ARX Model Structure

The AutoRegressive with eXogenous input (ARX) model is formulated as:
$$A(q) y(k) = B(q) u(k) + e(k)$$
where $q^{-1}$ is the backward shift operator ($q^{-1} x(k) = x(k-1)$), and the polynomials are:
$$A(q) = 1 + a_1 q^{-1} + a_2 q^{-2} + \dots + a_{n_a} q^{-n_a}$$
$$B(q) = b_1 q^{-n_k} + b_2 q^{-(n_k+1)} + \dots + b_{n_b} q^{-(n_k+n_b-1)}$$
where:
- $n_a$: Denominator polynomial order (number of poles).
- $n_b$: Numerator polynomial order (number of zeros plus one).
- $n_k$: Input transport dead-time in integer samples ($n_k \ge 0$).
- $e(k)$: White noise equation error sequence.

In time-domain difference equation form:
$$y(k) = -\sum_{i=1}^{n_a} a_i y(k-i) + \sum_{j=1}^{n_b} b_j u(k - n_k - j + 1) + e(k)$$

---

## 7. Ordinary Least Squares (OLS) Estimation

Rewriting the difference equation in linear regression matrix form:
$$Y = \Phi \theta + E$$
The unknown parameter vector is:
$$\theta = \begin{bmatrix} a_1 & a_2 & \dots & a_{n_a} & b_1 & b_2 & \dots & b_{n_b} \end{bmatrix}^T \in \mathbb{R}^{(n_a + n_b) \times 1}$$
For sample index $k$ starting at $k_1 = \max(n_a, n_k + n_b - 1) + 1$ up to estimation length $N_e$:
$$\phi(k) = \begin{bmatrix} -y(k-1) & \dots & -y(k-n_a) & u(k-n_k) & \dots & u(k-n_k-n_b+1) \end{bmatrix}$$
The full regression matrix and target vector are:
$$\Phi = \begin{bmatrix} \phi(k_1) \\ \phi(k_1+1) \\ \vdots \\ \phi(N_e) \end{bmatrix} \in \mathbb{R}^{(N_e - k_1 + 1) \times (n_a + n_b)}, \quad Y = \begin{bmatrix} y(k_1) \\ y(k_1+1) \\ \vdots \\ y(N_e) \end{bmatrix}$$

The least-squares objective minimizes the sum of squared prediction errors:
$$V(\theta) = \frac{1}{2} \| Y - \Phi \theta \|_2^2$$
Setting the gradient $\nabla_\theta V = -\Phi^T (Y - \Phi \theta) = 0$ yields the normal equations:
$$(\Phi^T \Phi) \hat{\theta} = \Phi^T Y$$
In our implementation, rather than explicitly computing the matrix inverse $(\Phi^T \Phi)^{-1}$ (which squares the condition number), the parameter estimate is computed directly via MATLAB's backslash operator:
$$\hat{\theta} = \Phi \backslash Y$$
which uses QR decomposition with column pivoting for high numerical stability.

### 7.1 Dataset & Estimated Model Coefficients

- **Selected Dataset:** `[e.g., example_second_order.csv]`
- **Total Samples $N$:** `[e.g., 601]` | **Sampling Time $T_s$:** `[e.g., 0.05 s]`
- **Chronological Split:** `[70% Estimation / 30% Validation]`
- **Selected Orders:** $n_a =$ `[ ]`, $n_b =$ `[ ]`, $n_k =$ `[ ]`

**Identified Parameter Vector $\hat{\theta}$:**

| Parameter | Estimated Value | True Value (if known) | Relative Error (%) |
|:---:|:---:|:---:|:---:|
| $a_1$ | `[Insert]` | `[Insert]` | `[Insert]` |
| $a_2$ | `[Insert]` | `[Insert]` | `[Insert]` |
| $b_1$ | `[Insert]` | `[Insert]` | `[Insert]` |
| $b_2$ | `[Insert]` | `[Insert]` | `[Insert]` |

**Resulting Discrete-Time Transfer Function:**
$$G(z) = \frac{B(z^{-1})}{A(z^{-1})} = \frac{[ \quad ] z^{-1} + [ \quad ] z^{-2}}{1 + [ \quad ] z^{-1} + [ \quad ] z^{-2}}$$
- **Condition Number of $\Phi$:** `[Insert]`
- **Rank of $\Phi$:** `[Insert]` / `[n_a + n_b]`
- **Discrete Poles:** $z_p =$ `[Insert]`, Stability Check: $|z_p| < 1$ `[Stable / Unstable]`

---

## 8. Model Validation

Model validation evaluates the predictive capability of the estimated ARX model on unseen data reserved during the chronological split.

### 8.1 One-Step-Ahead Prediction vs. Free-Run Simulation

Two distinct validation paradigms are implemented:

1. **One-Step-Ahead Prediction ($\hat{y}_{1\text{-step}}(k)$):**
   $$\hat{y}(k) = -\sum_{i=1}^{n_a} \hat{a}_i y_{\text{actual}}(k-i) + \sum_{j=1}^{n_b} \hat{b}_j u(k - n_k - j + 1)$$
   Uses *actual past measured outputs* as feedback at every time step. Evaluates immediate one-step tracking capability.
2. **Free-Run Recursive Simulation ($\hat{y}_{\text{free-run}}(k)$):**
   $$\hat{y}_{\text{sim}}(k) = -\sum_{i=1}^{n_a} \hat{a}_i \hat{y}_{\text{sim}}(k-i) + \sum_{j=1}^{n_b} \hat{b}_j u(k - n_k - j + 1)$$
   The model is seeded only by initial history prior to the validation segment ($k < N_e+1$). Throughout the entire validation horizon, the model feeds back its *own previous simulated outputs*. This is a much more stringent test of true autonomous dynamic fidelity.

### 8.2 Normalized Model-Fit Metric

The normalized model-fit percentage is computed as:
$$\text{Fit} (\%) = 100 \times \left( 1 - \frac{\| \mathbf{y}_{\text{actual}} - \mathbf{y}_{\text{pred}} \|_2}{\| \mathbf{y}_{\text{actual}} - \bar{y}_{\text{actual}} \|_2} \right)$$
where $\bar{y}_{\text{actual}}$ is the sample mean of the actual output signal.
- $\text{Fit} = 100\%$: Perfect prediction.
- $\text{Fit} = 0\%$: Prediction performs no better than the constant mean output $\bar{y}$.
- $\text{Fit} < 0\%$: Prediction is worse than predicting the mean.

### 8.3 Validation Metrics Summary Table

| Metric | Estimation Data ($1 \dots N_e$) | Validation Data ($N_e+1 \dots N$) |
|:---|:---:|:---:|
| **One-Step Fit (%)** | `[Insert]` | `[Insert]` |
| **Free-Run Simulation Fit (%)** | `[N/A or Insert]` | `[Insert]` |
| **Root Mean Squared Error (RMSE)** | `[Insert]` | `[Insert]` |
| **Residual Mean** | `[Insert]` | `[Insert]` |
| **Residual Standard Deviation** | `[Insert]` | `[Insert]` |

`[Insert screenshot of Model Validation Tab 3 comparing actual vs. predicted vs. simulated output curves.]`

---

## 9. Residual Diagnostic Analysis

The prediction residuals are defined as:
$$e(k) = y_{\text{actual}}(k) - \hat{y}_{1\text{-step}}(k)$$

### 9.1 Autocorrelation Function (ACF)

The sample autocorrelation function for lag $l = 0, 1, \dots, L_{\max}$ is computed directly:
$$r_{ee}(l) = \frac{\sum_{k=1}^{N-l} (e(k) - \bar{e})(e(k+l) - \bar{e})}{\sum_{k=1}^N (e(k) - \bar{e})^2}$$
normalized such that $r_{ee}(0) = 1$. Under the null hypothesis that $e(k)$ is a white Gaussian noise sequence:
$$\sqrt{N} r_{ee}(l) \sim \mathcal{N}(0, 1) \quad \text{for } l \ge 1$$
The approximate 95% confidence bounds are:
$$\text{Bound}_{95\%} = \pm \frac{1.96}{\sqrt{N_{\text{val}}}}$$

### 9.2 Residual Diagnostic Plots & Analysis

`[Insert plots of: (1) Residuals vs. Time, (2) Residual Histogram, (3) ACF stem plot with bounds.]`

- **Whiteness of Residuals:** `[Do the ACF stems stay within the ±1.96/√N bounds?]`
- **Bias / Zero-Mean Property:** `[Is the residual mean close to zero?]`
- **Model Inadequacy Indications:** `[Explain whether unmodelled dynamics or non-linearities are visible in the residual patterns.]`

---

## 10. Interactive Analysis and Sensitivity Studies

### 10.1 Model-Order Sensitivity ($n_a$ vs. $n_b$ Grid)

`[Insert heatmap image from Tab 4 and populate the table below for varying na, nb with fixed nk=1.]`

| $n_a \backslash n_b$ | $n_b = 1$ | $n_b = 2$ | $n_b = 3$ | $n_b = 4$ | $n_b = 5$ |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **$n_a = 1$** | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` |
| **$n_a = 2$** | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` |
| **$n_a = 3$** | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` |
| **$n_a = 4$** | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` |
| **$n_a = 5$** | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` | `[Fit %]` |

- **Optimal Model Order:** $n_a^* =$ `[ ]`, $n_b^* =$ `[ ]`
- **Overfitting Analysis:** `[Discuss why higher model orders increase estimation fit while potentially degrading free-run validation fit.]`

### 10.2 Noise Sensitivity Study

`[Insert noise study curve from Tab 4 displaying Fit % vs. Noise Level (% of output std).]`

- **Seed Used:** `[e.g., 42]`
- **Baseline Fit (0% Noise):** `[Insert %]`
- **Fit at 20% Noise:** `[Insert %]`
- **Fit at 50% Noise:** `[Insert %]`
- **Parameter Drift Observation:** `[Explain how measurement noise on output y induces errors-in-variables bias in least squares estimates.]`

### 10.3 Sampling-Time ($T_s$) Analysis

- **Nominal $T_s$:** `[Insert s]`
- **Resampling Multipliers Tested:** `[1x, 2x, 4x]`
- **Observations on Pole Migration:** `[Explain how rapid sampling Ts -> 0 pushes discrete poles to z -> 1, increasing condition number.]`

---

## 11. Conclusions

`[Summarize the main engineering findings from the project, the accuracy of ARX identification on the selected dataset, and the effectiveness of the interactive GUI application.]`

---

## 12. Limitations & Future Work

1. **White Equation Error Assumption:** The classical ARX structure assumes the error term $e(k)$ is strictly white noise. If physical measurement noise enters after plant dynamics, ARX least-squares estimates are asymptotically biased; an ARMAX or Output-Error (OE) model with instrumental variables or prediction error methods (PEM) would be required.
2. **Linear System Restriction:** The software models linear time-invariant (LTI) systems; severe actuator saturation or non-linear friction are not captured.
3. **Resampling Filter:** Resampling is implemented via linear interpolation without an anti-aliasing low-pass decimation filter.
