function varargout = calculateFit(y_actual, y_predicted)
%CALCULATEFIT Calculate normalized model-fit percentage and error metrics.
%
%   f = sid.calculateFit(y_actual, y_predicted)
%       returns struct with fields: .fit, .rmse, .resMean, .residualMean, .resStd, .residualStd
%
%   [fitPct, rmse, resMean, resStd] = sid.calculateFit(...)
%
%   Normalized fit definition:
%       Fit (%) = 100 * [1 - norm(y_actual - y_pred) / norm(y_actual - mean(y_actual))]
%       RMSE    = sqrt(mean((y_actual - y_pred).^2))

    if nargin < 2
        error('sid:calculateFit:nargin', 'calculateFit requires 2 inputs: y_actual and y_predicted.');
    end

    y_actual = y_actual(:);
    y_predicted = y_predicted(:);

    if numel(y_actual) ~= numel(y_predicted)
        error('sid:calculateFit:lengthMismatch', 'Actual and predicted vectors must have equal length.');
    end

    % Check divergence (-Inf fit)
    hasInf = any(isinf(y_predicted));

    valid = ~isnan(y_actual) & ~isnan(y_predicted) & ~isinf(y_actual);
    if hasInf
        fitPct = -Inf;
        rmse = Inf;
        resMean = NaN;
        resStd = NaN;
    else
        ya = y_actual(valid);
        yp = y_predicted(valid);

        if isempty(ya)
            fitPct = NaN;
            rmse = NaN;
            resMean = NaN;
            resStd = NaN;
        else
            res = ya - yp;
            rmse = sqrt(mean(res.^2));
            resMean = mean(res);
            resStd = std(res);

            denom = norm(ya - mean(ya));
            num   = norm(res);

            if denom < 1e-12
                if num < 1e-12
                    fitPct = 100;
                else
                    fitPct = NaN;
                end
            else
                fitPct = 100 * (1 - num / denom);
            end
        end
    end

    f = struct();
    f.fit = fitPct;
    f.rmse = rmse;
    f.resMean = resMean;
    f.residualMean = resMean;
    f.resStd = resStd;
    f.residualStd = resStd;

    if nargout <= 1
        varargout{1} = f;
    else
        varargout{1} = fitPct;
        if nargout >= 2, varargout{2} = rmse; end
        if nargout >= 3, varargout{3} = resMean; end
        if nargout >= 4, varargout{4} = resStd; end
    end
end
