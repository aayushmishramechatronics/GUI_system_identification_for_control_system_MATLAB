function [u, t] = generateInput(signalType, varargin)
%GENERATEINPUT Generate standard test and identification input waveforms.
%
%   Calling syntax 1:
%       [u, t] = sid.generateInput(signalType, Ts, duration, params)
%
%   Calling syntax 2:
%       u = sid.generateInput(signalType, t, params)
%
%   Signal types:
%       'step', 'impulse' / 'pulse', 'ramp', 'sine', 'square', 'prbs'
%
%   Params:
%       'step':    amp/amplitude (1), t0/stepTime (0)
%       'pulse':   amp/amplitude (1), t0/stepTime (0)
%       'ramp':    slope (1), t0/startTime (0)
%       'sine':    amp/amplitude (1), freq/frequency (1 Hz)
%       'square':  amp/amplitude (1), freq/frequency (1 Hz)
%       'prbs':    amp/amplitude (1), hold/numBits (10)

    if nargin < 2
        error('sid:generateInput:nargin', 'At least 2 arguments required.');
    end

    % Determine calling syntax
    arg2 = varargin{1};
    if isnumeric(arg2) && isvector(arg2) && numel(arg2) > 1
        % Syntax 2: (signalType, t, params)
        t = arg2(:);
        if numel(varargin) >= 2 && isstruct(varargin{2})
            params = varargin{2};
        else
            params = struct();
        end
    else
        % Syntax 1: (signalType, Ts, duration, params)
        Ts = arg2;
        if ~isscalar(Ts) || ~isnumeric(Ts) || Ts <= 0
            error('sid:generateInput:invalidTs', 'Sampling period Ts must be a positive scalar.');
        end
        if numel(varargin) < 2
            error('sid:generateInput:missingDuration', 'Duration is required.');
        end
        duration = varargin{2};
        if ~isscalar(duration) || ~isnumeric(duration) || duration <= 0
            error('sid:generateInput:invalidDuration', 'Duration must be a positive scalar.');
        end
        if numel(varargin) >= 3 && isstruct(varargin{3})
            params = varargin{3};
        else
            params = struct();
        end
        t = (0:Ts:duration)';
    end

    N = numel(t);
    st = lower(char(signalType));

    % Helper to extract parameter with multiple alias names
    function val = getParam(p, aliases, defaultVal)
        val = defaultVal;
        for a = aliases
            if isfield(p, a{1})
                val = p.(a{1});
                return;
            end
        end
    end

    amp   = getParam(params, {'amp', 'amplitude'}, 1);
    t0    = getParam(params, {'t0', 'stepTime', 'startTime'}, 0);
    freq  = getParam(params, {'freq', 'frequency'}, 1);
    slope = getParam(params, {'slope', 'rampSlope'}, 1);
    holdVal = getParam(params, {'hold', 'numBits', 'bits'}, 10);

    switch st
        case 'step'
            u = zeros(N, 1);
            u(t >= t0) = amp;

        case {'impulse', 'pulse'}
            u = zeros(N, 1);
            idx = find(t >= t0, 1, 'first');
            if isempty(idx)
                idx = 1;
            end
            u(idx) = amp;

        case 'ramp'
            u = slope * max(t - t0, 0);

        case 'sine'
            u = amp * sin(2 * pi * freq * t);

        case 'square'
            s = sin(2 * pi * freq * t);
            u = amp * sign(s);
            u(u == 0) = amp;

        case 'prbs'
            holdSamples = max(1, round(holdVal));
            nBlocks = ceil(N / holdSamples);
            % Deterministic PRBS generation using LFSR (order 9 maximal length)
            % polynomial: x^9 + x^5 + 1
            lfsr = uint16(255); % non-zero initial state
            bits = zeros(nBlocks, 1);
            for b = 1:nBlocks
                % feedback bit = bit 9 xor bit 5
                fb = bitxor(bitget(lfsr, 9), bitget(lfsr, 5));
                lfsr = bitset(bitshift(lfsr, 1), 1, fb);
                lfsr = bitand(lfsr, uint16(511));
                if bitget(lfsr, 1) == 1
                    bits(b) = 1;
                else
                    bits(b) = -1;
                end
            end
            extended = repelem(bits, holdSamples);
            u = amp * extended(1:N);

        otherwise
            error('sid:generateInput:unknownType', 'Unknown signal type: %s', signalType);
    end

    u = u(:);
end
