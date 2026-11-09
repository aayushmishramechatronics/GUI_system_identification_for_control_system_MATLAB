function ev = evaluateModel(model, u, y, Ne)
%EVALUATEMODEL  One-step and free-run predictions plus fit metrics.
%   Estimation segment = 1..Ne (one-step fit); validation = Ne+1..N (one-step and free-run).
u = u(:); y = y(:); N = numel(y);
if Ne+1 > N, error('sid:evaluateModel:split', 'No validation samples.'); end
ev.yhat  = sid.predictARX(model, u, y);
ev.ysim  = sid.simulateARX(model, u, y, Ne+1);
ev.est   = sid.calculateFit(y(1:Ne),     ev.yhat(1:Ne));
ev.valOS = sid.calculateFit(y(Ne+1:N),   ev.yhat(Ne+1:N));
ev.valFR = sid.calculateFit(y(Ne+1:N),   ev.ysim(Ne+1:N));
end
