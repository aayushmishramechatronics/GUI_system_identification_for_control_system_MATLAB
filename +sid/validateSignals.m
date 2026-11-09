function varargout = validateSignals(time, input, output, Ts, options)
%VALIDATESIGNALS Validate and preprocess imported time, input, and output data.
%
%   r = sid.validateSignals(time, input, output, Ts, options)
%   [isValid, messages] = sid.validateSignals(...)
%
%   Checks:
%       - Numeric real vectors
%       - Equal lengths
%       - Sufficient length (>= 10 samples)
%       - Monotonically increasing time
%       - Regular vs irregular sampling detection
%       - Missing / NaN / Inf handling (rejection or linear interpolation)

    if nargin < 4, Ts = []; end
    if nargin < 5 || isempty(options), options = struct(); end

    r = struct();
    r.ok = true;
    r.irregular = false;
    r.nInterpolated = 0;
    r.warnings = {};
    r.errors = {};
    r.t = [];
    r.u = [];
    r.y = [];
    r.Ts = NaN;

    % ---- Validate input & output vectors ----
    if isempty(input) || ~isnumeric(input) || ~isvector(input) || ~isreal(input)
        r.ok = false;
        r.errors{end+1} = 'Input must be a non-empty numeric real vector.';
    end
    if isempty(output) || ~isnumeric(output) || ~isvector(output) || ~isreal(output)
        r.ok = false;
        r.errors{end+1} = 'Output must be a non-empty numeric real vector.';
    end

    if ~r.ok
        varargout = formatReturn(r, nargout);
        return;
    end

    u = input(:);
    y = output(:);
    N = numel(u);

    if numel(y) ~= N
        r.ok = false;
        r.errors{end+1} = sprintf('Input length (%d) does not match output length (%d).', N, numel(y));
        varargout = formatReturn(r, nargout);
        return;
    end

    if N < 10
        r.ok = false;
        r.errors{end+1} = sprintf('Too few samples (%d). Minimum required is 10.', N);
        varargout = formatReturn(r, nargout);
        return;
    end

    % ---- Time vector or Ts validation ----
    if isempty(time)
        if isempty(Ts) || ~isnumeric(Ts) || ~isscalar(Ts) || Ts <= 0
            r.ok = false;
            r.errors{end+1} = 'Missing or invalid sampling time Ts (must be a positive scalar).';
            varargout = formatReturn(r, nargout);
            return;
        end
        t = (0:N-1)' * Ts;
        r.Ts = Ts;
        r.irregular = false;
    else
        if ~isnumeric(time) || ~isvector(time) || ~isreal(time)
            r.ok = false;
            r.errors{end+1} = 'Time vector must be a numeric real vector.';
            varargout = formatReturn(r, nargout);
            return;
        end
        t = time(:);
        if numel(t) ~= N
            r.ok = false;
            r.errors{end+1} = sprintf('Time length (%d) does not match signal length (%d).', numel(t), N);
            varargout = formatReturn(r, nargout);
            return;
        end

        dt = diff(t);
        if any(dt <= 0)
            r.ok = false;
            r.errors{end+1} = 'Time vector must be strictly monotonically increasing.';
            varargout = formatReturn(r, nargout);
            return;
        end

        medianTs = median(dt);
        r.Ts = medianTs;
        % Check sampling regularity
        if any(abs(dt - medianTs) > 1e-4 * medianTs)
            r.irregular = true;
            r.warnings{end+1} = sprintf('Irregular sampling detected. Median Ts = %.6g s.', medianTs);
        end
    end

    % ---- Handle NaN / Inf values ----
    badMask = isnan(u) | isinf(u) | isnan(y) | isinf(y) | isnan(t) | isinf(t);
    nBad = sum(badMask);
    if nBad > 0
        doInterp = isfield(options, 'missing') && strcmpi(options.missing, 'interpolate');
        if doInterp
            if nBad >= N - 2
                r.ok = false;
                r.errors{end+1} = 'Too many missing/infinite values to interpolate.';
                varargout = formatReturn(r, nargout);
                return;
            end
            goodIdx = find(~badMask);
            badIdx = find(badMask);
            u(badIdx) = interp1(t(goodIdx), u(goodIdx), t(badIdx), 'linear', 'extrap');
            y(badIdx) = interp1(t(goodIdx), y(goodIdx), t(badIdx), 'linear', 'extrap');
            r.nInterpolated = nBad;
            r.warnings{end+1} = sprintf('Interpolated %d missing or infinite sample(s).', nBad);
        else
            r.ok = false;
            r.errors{end+1} = sprintf('Dataset contains %d NaN or Inf values.', nBad);
            varargout = formatReturn(r, nargout);
            return;
        end
    end

    % ---- Excitation Check ----
    if std(u) < 1e-8 * max(abs(u), 1)
        r.warnings{end+1} = 'Input signal lacks excitation (constant or near-constant).';
    end

    r.t = t;
    r.u = u;
    r.y = y;

    varargout = formatReturn(r, nargout);
end

function out = formatReturn(r, nOut)
    if nOut >= 2
        out = cell(1, 2);
        out{1} = r.ok;
        out{2} = [r.errors(:); r.warnings(:)];
    else
        out = {r};
    end
end
