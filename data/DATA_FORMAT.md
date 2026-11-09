# Example data format

Preferred CSV/XLSX/TXT layout (header row, one sample per row):

    time,input,output
    0.0,1,0.0000
    0.1,1,0.0123

* `data/example_time_input_output.csv`: time + input + output (Ts = 0.1 s).
* `data/example_input_output_only.csv`: input + output only. Choose "(none - use Ts)" for the time column and enter Ts = 0.1.

These two files were produced OUTSIDE the application (a 2nd-order plant, PRBS input, small noise) purely to demonstrate the format. The GUI itself has no data-generation feature. Column order and names are free: map them with the dropdowns. Columns must be numeric; time must be strictly increasing. NaN/Inf values are rejected unless you pick "Interpolate linearly" (reported in the status bar).
