function [varargout] = simulatePlant(sysType, params, varargin)
%SIMULATEPLANT Simulate continuous-time first or second order dynamic systems.
%
%   Calling syntax 1 (used by GUI):
%       [t, y, x_history] = sid.simulatePlant(sysType, params, u, Ts)
%
%   Calling syntax 2 (used by unit tests & script analysis):
%       s = sid.simulatePlant(sysType, params, Ts, duration, signalType, signalParams)
%       returns struct s with fields: s.t, s.y, s.u, s.x
%
%   Inputs:
%       sysType: 1, 'first', '1st Order' for first-order G(s) = K / (tau*s + 1)
%                2, 'second', '2nd Order' for second-order G(s) = K*wn^2 / (s^2 + 2*zeta*wn*s + wn^2)
%       params:  struct containing:
%                First-order:  params.K, params.tau (tau > 0)
%                Second-order: params.K, params.wn (wn > 0), params.zeta (zeta >= 0)
%
%   Zero-Order Hold (ZOH) discretization is performed via augmented matrix exponential:
%       M = expm([A, B; zeros(1, n+1)] * Ts)
%       Ad = M(1:n, 1:n),  Bd = M(1:n, n+1)

    % ---- Validate sysType ----
    if ischar(sysType) || isstring(sysType)
        stStr = lower(char(sysType));
        if contains(stStr, 'first') || contains(stStr, '1')
            isFirst = true;
        elseif contains(stStr, 'second') || contains(stStr, '2')
            isFirst = false;
        else
            error('sid:simulatePlant:invalidType', 'Unknown sysType: %s', sysType);
        end
    elseif isnumeric(sysType) && isscalar(sysType)
        if sysType == 1
            isFirst = true;
        elseif sysType == 2
            isFirst = false;
        else
            error('sid:simulatePlant:invalidType', 'sysType numeric must be 1 or 2');
        end
    else
        error('sid:simulatePlant:invalidType', 'Invalid sysType');
    end

    % ---- Validate params ----
    if ~isstruct(params)
        error('sid:simulatePlant:invalidParams', 'params must be a struct');
    end
    if isFirst
        if ~isfield(params, 'K') || ~isfield(params, 'tau')
            error('sid:simulatePlant:missingParam', 'First-order requires params.K and params.tau');
        end
        K = params.K;
        tau = params.tau;
        if ~isscalar(tau) || ~isnumeric(tau) || tau <= 0
            error('sid:simulatePlant:invalidTau', 'Time constant tau must be positive (tau > 0)');
        end
        % Continuous state space: x_dot = (-1/tau)*x + (K/tau)*u, y = x
        A = -1 / tau;
        B = K / tau;
        C = 1;
        D = 0;
        nStates = 1;
    else
        if ~isfield(params, 'K') || ~isfield(params, 'wn') || ~isfield(params, 'zeta')
            error('sid:simulatePlant:missingParam', 'Second-order requires K, wn, and zeta');
        end
        K = params.K;
        wn = params.wn;
        zeta = params.zeta;
        if ~isscalar(wn) || ~isnumeric(wn) || wn <= 0
            error('sid:simulatePlant:invalidWn', 'Natural frequency wn must be positive (wn > 0)');
        end
        if ~isscalar(zeta) || ~isnumeric(zeta) || zeta < 0
            error('sid:simulatePlant:invalidZeta', 'Damping ratio zeta must be non-negative (zeta >= 0)');
        end
        % Continuous state space:
        % x1_dot = x2, x2_dot = -wn^2*x1 - 2*zeta*wn*x2 + K*wn^2*u, y = x1
        A = [0, 1; -wn^2, -2*zeta*wn];
        B = [0; K*wn^2];
        C = [1, 0];
        D = 0;
        nStates = 2;
    end

    % ---- Distinguish Calling Syntaxes ----
    if numel(varargin) >= 4 && isnumeric(varargin{1}) && isscalar(varargin{1}) && ...
       isnumeric(varargin{2}) && isscalar(varargin{2}) && (ischar(varargin{3}) || isstring(varargin{3}))
        % Syntax 2: (sysType, params, Ts, duration, signalType, signalParams)
        Ts = varargin{1};
        duration = varargin{2};
        signalType = varargin{3};
        if numel(varargin) >= 4
            sigParams = varargin{4};
        else
            sigParams = struct();
        end
        if ~isscalar(Ts) || ~isnumeric(Ts) || Ts <= 0
            error('sid:simulatePlant:invalidTs', 'Ts must be positive (Ts > 0)');
        end
        if ~isscalar(duration) || ~isnumeric(duration) || duration <= 0
            error('sid:simulatePlant:invalidDuration', 'Duration must be positive');
        end
        [u, t] = sid.generateInput(signalType, Ts, duration, sigParams);
        isStructReturn = true;
    else
        % Syntax 1: (sysType, params, u, Ts)
        if numel(varargin) < 2
            error('sid:simulatePlant:nargin', 'Requires u and Ts');
        end
        u = varargin{1};
        Ts = varargin{2};
        if ~isscalar(Ts) || ~isnumeric(Ts) || Ts <= 0
            error('sid:simulatePlant:invalidTs', 'Ts must be positive (Ts > 0)');
        end
        if ~isnumeric(u) || ~isvector(u) || isempty(u)
            error('sid:simulatePlant:invalidU', 'u must be a non-empty numeric vector');
        end
        u = u(:);
        N = numel(u);
        t = (0:N-1)' * Ts;
        isStructReturn = (nargout <= 1 && numel(varargin) >= 4);
    end

    % ---- Discretize using Zero-Order Hold (ZOH) via augmented matrix exponential ----
    % M = expm([A, B; 0, 0] * Ts)
    M = expm([A, B; zeros(1, nStates + 1)] * Ts);
    Ad = M(1:nStates, 1:nStates);
    Bd = M(1:nStates, nStates + 1);

    % ---- Time-domain simulation ----
    N = numel(u);
    x = zeros(nStates, 1);
    x_history = zeros(N, nStates);
    y = zeros(N, 1);

    for k = 1:N
        x_history(k, :) = x';
        y(k) = C * x + D * u(k);
        x = Ad * x + Bd * u(k);
    end

    % ---- Return values based on calling pattern ----
    if isStructReturn || (nargout <= 1 && numel(varargin) > 2)
        s = struct('t', t, 'y', y, 'u', u, 'x', x_history);
        varargout{1} = s;
    else
        varargout{1} = t;
        if nargout >= 2
            varargout{2} = y;
        end
        if nargout >= 3
            varargout{3} = x_history;
        end
    end
end
