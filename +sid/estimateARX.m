function varargout = estimateARX(u, y, na, nb, nk, Ne)
%ESTIMATEARX Estimate ARX parameters using the Least Squares method.
%
%   model = sid.estimateARX(u, y, na, nb, nk, Ne)
%   [model, a_coeffs, b_coeffs, Phi, Y, info] = sid.estimateARX(...)
%
%   Model equation:
%       A(q) y(k) = B(q) u(k) + e(k)
%       y(k) = -a1*y(k-1) - ... - ana*y(k-na)
%              + b1*u(k-nk) + ... + bnb*u(k-nk-nb+1) + e(k)
%
%   Regression form:
%       Y = Phi * theta + E
%       theta = [a1, ..., ana, b1, ..., bnb]'
%       theta_hat = Phi \ Y

    if nargin < 5
        error('sid:estimateARX:nargin', 'At least 5 arguments required: u, y, na, nb, nk.');
    end

    % ---- Validate signals ----
    if ~isnumeric(u) || ~isvector(u) || isempty(u)
        error('sid:estimateARX:invalidU', 'Input u must be a non-empty numeric vector.');
    end
    if ~isnumeric(y) || ~isvector(y) || isempty(y)
        error('sid:estimateARX:invalidY', 'Output y must be a non-empty numeric vector.');
    end
    u = u(:);
    y = y(:);
    N = numel(u);
    if numel(y) ~= N
        error('sid:estimateARX:lengthMismatch', 'u and y must have equal lengths.');
    end

    if nargin < 6 || isempty(Ne)
        Ne = N;
    else
        if ~isscalar(Ne) || ~isnumeric(Ne) || Ne < 1 || Ne > N || Ne ~= round(Ne)
            error('sid:estimateARX:invalidNe', 'Ne must be an integer between 1 and %d.', N);
        end
    end

    % ---- Validate model orders ----
    if ~isscalar(na) || ~isnumeric(na) || na < 1 || na ~= round(na)
        error('sid:estimateARX:invalidNA', 'na must be an integer >= 1.');
    end
    if ~isscalar(nb) || ~isnumeric(nb) || nb < 1 || nb ~= round(nb)
        error('sid:estimateARX:invalidNB', 'nb must be an integer >= 1.');
    end
    if ~isscalar(nk) || ~isnumeric(nk) || nk < 0 || nk ~= round(nk)
        error('sid:estimateARX:invalidNK', 'nk must be an integer >= 0.');
    end

    % First valid sample index
    k1 = max(na, nk + nb - 1) + 1;
    numParams = na + nb;

    if k1 > Ne
        error('sid:estimateARX:insufficientData', ...
            'Insufficient data: sample index %d exceeds estimation length %d.', k1, Ne);
    end

    nEst = Ne - k1 + 1;
    if nEst < 2 * numParams || Ne < 10
        error('sid:estimateARX:insufficientData', ...
            'Insufficient estimation data: need at least %d samples (got Ne = %d, nEst = %d for %d parameters).', ...
            max(10, k1 + 2 * numParams - 1), Ne, nEst, numParams);
    end

    % ---- Build Regressor Matrix Phi and Target Vector Y ----
    [Phi, Y] = sid.buildRegressor(u, y, na, nb, nk, k1, Ne);

    % ---- Parameter Estimation via Matrix Left-Division ----
    theta = Phi \ Y;

    a = theta(1:na)';           % 1 x na
    b = theta(na+1:end)';       % 1 x nb

    % Diagnostics
    rankPhi = rank(Phi);
    condPhi = cond(Phi);
    rankDef = (rankPhi < numParams);

    warnings = {};
    if rankDef
        warnings{end+1} = sprintf('Regression matrix Phi is rank deficient (rank %d of %d).', rankPhi, numParams);
    end
    if condPhi > 1e10
        warnings{end+1} = sprintf('Regression matrix Phi is poorly conditioned (cond = %.2e).', condPhi);
    end
    if std(u(1:Ne)) < 1e-6 * max(abs(u(1:Ne)), 1)
        warnings{end+1} = 'Input excitation is insufficient (constant or low variation).';
    end

    % Construct model struct
    model = struct();
    model.a = a;
    model.b = b;
    model.theta = theta;
    model.na = na;
    model.nb = nb;
    model.nk = nk;
    model.Ne = Ne;
    model.k1 = k1;
    model.nEst = nEst;
    model.rankPhi = rankPhi;
    model.condPhi = condPhi;
    model.condNumber = condPhi;
    model.rankDef = rankDef;
    model.rankDeficient = rankDef;
    model.warnings = {warnings};
    model.warnings = warnings;
    model.Ts = 1;
    model.Phi = Phi;
    model.Y = Y;

    varargout{1} = model;
    if nargout >= 2, varargout{2} = a(:); end
    if nargout >= 3, varargout{3} = b(:); end
    if nargout >= 4, varargout{4} = Phi; end
    if nargout >= 5, varargout{5} = Y; end
    if nargout >= 6
        varargout{6} = struct('numSamples', nEst, 'condNumber', condPhi, ...
            'rankPhi', rankPhi, 'rankDeficient', rankDef, 'warning', strjoin(warnings, ' '));
    end
end
