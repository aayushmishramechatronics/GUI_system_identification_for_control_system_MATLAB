function varargout = calculateResiduals(y_actual, y_predicted, maxLag)
%CALCULATERESIDUALS Calculate prediction errors, ACF, and confidence bounds.
%
%   r = sid.calculateResiduals(y_actual, y_predicted, maxLag)
%   [residuals, acf, lags, confBound] = sid.calculateResiduals(...)
%
%   Outputs in struct r:
%       r.e     - valid residual vector e(k) = y_actual(k) - y_pred(k)
%       r.acf   - autocorrelation values for lags 0..maxLag (acf(0) = 1)
%       r.lags  - column vector of lag values (0:maxLag)'
%       r.bound - 95% confidence bound 1.96 / sqrt(N)
%       r.N     - number of valid samples
%       r.idx   - indices of valid samples
%       r.mean  - mean of residuals
%       r.std   - standard deviation of residuals

    if nargin < 2
        error('sid:calculateResiduals:nargin', 'Requires y_actual and y_predicted.');
    end

    y_actual = y_actual(:);
    y_predicted = y_predicted(:);

    if numel(y_actual) ~= numel(y_predicted)
        error('sid:calculateResiduals:lengthMismatch', 'Lengths of actual and predicted outputs must match.');
    end

    rawE = y_actual - y_predicted;
    validIdx = find(~isnan(rawE) & ~isinf(rawE));
    e = rawE(validIdx);
    N = numel(e);

    if nargin < 3 || isempty(maxLag)
        maxLag = min(20, max(0, N - 1));
    else
        maxLag = min(round(maxLag), max(0, N - 1));
    end

    lags = (0:maxLag)';
    acf = zeros(maxLag + 1, 1);

    if N > 0
        denom = sum(e.^2);
        if denom < 1e-14
            acf(1) = 1;
        else
            for k = 0:maxLag
                acf(k + 1) = sum(e(1:N-k) .* e(1+k:N)) / denom;
            end
        end
        bound = 1.96 / sqrt(N);
        meanVal = mean(e);
        stdVal = std(e);
    else
        bound = NaN;
        meanVal = NaN;
        stdVal = NaN;
    end

    r = struct();
    r.e = e;
    r.acf = acf;
    r.lags = lags;
    r.bound = bound;
    r.N = N;
    r.idx = validIdx;
    r.mean = meanVal;
    r.std = stdVal;

    if nargout <= 1
        varargout{1} = r;
    else
        varargout{1} = e;
        if nargout >= 2, varargout{2} = acf; end
        if nargout >= 3, varargout{3} = lags; end
        if nargout >= 4, varargout{4} = bound; end
    end
end
