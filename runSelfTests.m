function runSelfTests()
%RUNSELFTESTS  Numerical self-tests for the +sid package (synthetic signals are used ONLY here).
addpath(fileparts(mfilename('fullpath')));
tests = {@t01_first_order, @t02_second_order, @t03_inputs, @t04_validation, @t05_arx_known, ...
         @t06_one_step, @t07_free_run, @t08_fit, @t09_residuals, @t10_invalid, ...
         @t11_noise, @t12_order, @t13_sampling};
nFail = 0;
for i = 1:numel(tests)
    nm = func2str(tests{i});
    try
        tests{i}();  fprintf('PASS  %s\n', nm);
    catch ME
        nFail = nFail + 1;  fprintf('FAIL  %s : %s\n', nm, ME.message);
    end
end
fprintf('\n%d of %d tests passed.\n', numel(tests)-nFail, numel(tests));
if nFail > 0, error('runSelfTests:failed', '%d test(s) failed.', nFail); end
end

% ------------------------------------------------------------------ helpers
function check(c, msg), if ~c, error('%s', msg); end, end
function checkClose(a, b, tol, msg)
if ~all(abs(a(:) - b(:)) <= tol), error('%s (max err %.3g)', msg, max(abs(a(:)-b(:)))); end
end
function expectError(f, name)
try, f(); catch, return; end
error('Expected an error but none was raised: %s', name);
end
function [u, y] = genARX(N, noiseStd)
u = sid.generateInput('prbs', (0:N-1)', struct('amp',1,'hold',3));
e = noiseStd * seededRandn(N);
y = zeros(N,1);
for k = 3:N
    y(k) = 1.5*y(k-1) - 0.7*y(k-2) + 0.5*u(k-1) + 0.3*u(k-2) + e(k);
end
end
function z = seededRandn(n)
try, s = rng; rng(1,'twister'); z = randn(n,1); rng(s);
catch, randn('state',1); z = randn(n,1); end %#ok<RAND>
end
function o = studyOpts(), o = struct('na',2,'nb',2,'nk',1,'split',0.7,'noisePct',0,'seed',1, ...
        'levels',[0 20 50],'maxOrder',3,'factors',[1 2]); end

% -------------------------------------------------------------------- tests
function t01_first_order()
K = 2; tau = 0.5; Ts = 0.01;
s = sid.simulatePlant('first', struct('K',K,'tau',tau), Ts, 3, 'step', struct('amp',1,'t0',0));
checkClose(s.y, K*(1 - exp(-s.t/tau)), 1e-9, 'First-order step response differs from analytic ZOH result');
check(all(diff(s.y) >= 0), 'Response must be monotonic');
check(abs(s.y(end) - K*(1-exp(-6))) < 1e-9, 'Final value wrong');
end

function t02_second_order()
K = 1.5; wn = 4; z = 0.3;
s = sid.simulatePlant('second', struct('K',K,'wn',wn,'zeta',z), 0.001, 10, 'step', struct('amp',1,'t0',0));
check(abs(s.y(end) - K) < 1e-3, 'Steady state should equal K');
os = max(s.y)/K - 1;
check(abs(os - exp(-pi*z/sqrt(1-z^2))) < 0.01, 'Overshoot differs from theory');
o = sid.simulatePlant('second', struct('K',1,'wn',4,'zeta',1.5), 0.001, 10, 'step', struct('amp',1,'t0',0));
check(max(o.y) <= 1 + 1e-6, 'Overdamped response must not overshoot');
expectError(@() sid.simulatePlant('first', struct('K',1,'tau',-1), 0.1, 1, 'step', struct()), 'tau<0');
expectError(@() sid.simulatePlant('first', struct('K',1,'tau',1), 0, 1, 'step', struct()), 'Ts=0');
end

function t03_inputs()
t = (0:0.1:20)'; N = numel(t); types = {'step','pulse','ramp','sine','square','prbs'};
for i = 1:numel(types)
    u = sid.generateInput(types{i}, t, struct('amp',2,'freq',0.5,'t0',1,'slope',3,'hold',4));
    check(isequal(size(u), [N 1]), ['Wrong size: ' types{i}]);
end
check(nnz(sid.generateInput('pulse', t, struct('amp',2,'t0',1))) == 1, 'Pulse must be one sample');
u = sid.generateInput('prbs', t, struct('amp',2,'hold',4));
check(all(abs(u) == 2), 'PRBS must be +/-amp');
checkClose(sid.generateInput('ramp', t, struct('slope',3,'t0',1)), 3*max(t-1,0), 1e-12, 'Ramp wrong');
end

function t04_validation()
N = 100; t = (0:N-1)'*0.1; u = sin(t); y = cos(t);
r = sid.validateSignals(t, u, y, [], struct()); check(r.ok && ~r.irregular && abs(r.Ts-0.1) < 1e-12, 'Good data rejected');
r = sid.validateSignals([], u, y, 0.2, struct()); check(r.ok && abs(r.t(end) - 19.8) < 1e-9, 'Ts-only construction failed');
r = sid.validateSignals([], u, y, [], struct()); check(~r.ok, 'Missing Ts must be an error');
yb = y; yb(10) = NaN;
r = sid.validateSignals(t, u, yb, [], struct()); check(~r.ok, 'NaN must be rejected by default');
r = sid.validateSignals(t, u, yb, [], struct('missing','interpolate')); check(r.ok && r.nInterpolated == 1 && ~isempty(r.warnings), 'Interpolation must succeed and be reported');
tb = t; tb(20) = tb(19); r = sid.validateSignals(tb, u, y, [], struct()); check(~r.ok, 'Non-monotonic time must be rejected');
ti = t; ti(50:end) = ti(50:end) + 0.05; r = sid.validateSignals(ti, u, y, [], struct()); check(r.ok && r.irregular, 'Irregular sampling must be flagged');
r = sid.validateSignals(t, u(1:50), y, [], struct()); check(~r.ok, 'Length mismatch must be rejected');
r = sid.validateSignals(t(1:5), u(1:5), y(1:5), [], struct()); check(~r.ok, 'Too few samples must be rejected');
r = sid.validateSignals(t, u, y*1i, [], struct()); %#ok<NASGU>
[tn, un, yn] = sid.resampleUniform(ti, ti, 2*ti, 0.1);
checkClose(un, tn, 1e-9, 'Resampling a linear signal must be exact'); checkClose(yn, 2*tn, 1e-9, 'Resampling (y) wrong');
end

function t05_arx_known()
[u, y] = genARX(400, 0);
m = sid.estimateARX(u, y, 2, 2, 1, 280);
checkClose(m.a, [-1.5 0.7], 1e-8, 'a coefficients not recovered');
checkClose(m.b, [0.5 0.3], 1e-8, 'b coefficients not recovered');
[u, y] = genARX(2000, 0.05);
m = sid.estimateARX(u, y, 2, 2, 1, 1400);
checkClose(m.theta', [-1.5 0.7 0.5 0.3], 0.05, 'Noisy estimate too far from truth');
tf = sid.tfString(m, 1); check(iscell(tf) && numel(tf) >= 5, 'tfString output malformed');
end

function t06_one_step()
[u, y] = genARX(200, 0);
m = sid.estimateARX(u, y, 2, 2, 1, 140);
yh = sid.predictARX(m, u, y);
check(all(isnan(yh(1:m.k1-1))), 'History samples must be NaN');
k = 50; manual = 1.5*y(k-1) - 0.7*y(k-2) + 0.5*u(k-1) + 0.3*u(k-2);
check(abs(yh(k) - manual) < 1e-7, 'One-step value differs from manual calculation');
checkClose(yh(m.k1:end), y(m.k1:end), 1e-7, 'Noise-free one-step prediction should be exact');
end

function t07_free_run()
[u, y] = genARX(200, 0);
m = sid.estimateARX(u, y, 2, 2, 1, 140);
ys = sid.simulateARX(m, u, y, 141);
checkClose(ys(141:end), y(141:end), 1e-6, 'Free-run should reproduce noise-free output');
y2 = y; y2(141:end) = 1e3;                      % corrupt validation outputs
ys2 = sid.simulateARX(m, u, y2, 141);
checkClose(ys2(141:end), ys(141:end), 1e-12, 'Free-run must not use validation outputs as feedback');
end

function t08_fit()
f = sid.calculateFit([1;2;3], [1;2;4]);
check(abs(f.fit - 100*(1 - 1/sqrt(2))) < 1e-10, 'Fit formula wrong');
f = sid.calculateFit([1;2;3], [1;2;3]);   check(abs(f.fit - 100) < 1e-12, 'Perfect fit must be 100');
f = sid.calculateFit([1;2;3], [2;2;2]);   check(abs(f.fit) < 1e-12, 'Mean predictor must give 0');
f = sid.calculateFit([2;2;2], [1;2;3]);   check(isnan(f.fit), 'Zero-variance output must give NaN');
f = sid.calculateFit([1;2;3], [1;Inf;3]); check(f.fit == -Inf, 'Divergence must give -Inf');
f = sid.calculateFit([1;2;3], [1;2;4]);   check(abs(f.rmse - sqrt(1/3)) < 1e-12, 'RMSE wrong');
end

function t09_residuals()
y = sin(0.3*(1:200)'); yp = y + 0.1*cos(1.7*(1:200)');
r = sid.calculateResiduals(y, yp, 20);
checkClose(r.e, -0.1*cos(1.7*(1:200)'), 1e-12, 'Residuals wrong');
check(abs(r.acf(1) - 1) < 1e-12 && numel(r.lags) == 21, 'ACF lag 0 must be 1');
check(abs(r.bound - 1.96/sqrt(200)) < 1e-12, 'Confidence bound wrong');
end

function t10_invalid()
[u, y] = genARX(200, 0);
expectError(@() sid.estimateARX(u, y, 0, 2, 1, 140), 'na=0');
expectError(@() sid.estimateARX(u, y, 2, 0, 1, 140), 'nb=0');
expectError(@() sid.estimateARX(u, y, 2, 2, -1, 140), 'nk<0');
expectError(@() sid.estimateARX(u, y, 2.5, 2, 1, 140), 'non-integer');
expectError(@() sid.estimateARX(u, y, 2, 2, 1, 8), 'insufficient data');
m = sid.estimateARX(ones(200,1), y, 2, 2, 1, 140);
check(~isempty(m.warnings), 'Constant input must raise warnings');
end

function t11_noise()
[u, y] = genARX(1000, 0.02); o = studyOpts();
r0 = sid.runSensitivityStudy('noise', u, y, 1, o);
checkClose(r0.base.theta, r0.noisy.theta, 1e-12, '0% noise must equal baseline');
o.noisePct = 80; r1 = sid.runSensitivityStudy('noise', u, y, 1, o); r2 = sid.runSensitivityStudy('noise', u, y, 1, o);
check(norm(r1.noisy.theta - r1.base.theta) > 1e-3, 'Noise must change the parameters');
checkClose(r1.noisy.theta, r2.noisy.theta, 1e-12, 'Seeded experiment must be reproducible');
check(isequal(r1.yNoisy(r1.Ne+1:end), y(r1.Ne+1:end)), 'Validation data must stay untouched');
check(numel(r1.sweepOS) == 3 && ~any(isnan(r1.sweepOS)), 'Sweep failed');
end

function t12_order()
[u, y] = genARX(600, 0); o = studyOpts();
r = sid.runSensitivityStudy('order', u, y, 1, o);
check(isequal(size(r.FitOS), [3 3]), 'Comparison matrix wrong size');
check(r.FitOS(2,2) > 99.99, 'True order (2,2) must fit almost perfectly');
check(r.FitOS(1,1) < r.FitOS(2,2), 'Too-low order must fit worse');
end

function t13_sampling()
[u, y] = genARX(800, 0.01); o = studyOpts(); o.factors = [1 2 3];
r = sid.runSensitivityStudy('sampling', u, y, 1, o);
check(numel(r.Ts) == 3 && abs(r.Ts(2) - 2) < 1e-12 && r.N(2) < r.N(1), 'Resampling study malformed');
end
