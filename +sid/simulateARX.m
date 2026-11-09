function ys = simulateARX(varargin)
%SIMULATEARX Free-run (recursive) simulation of an ARX model.
%
%   Syntax 1 (used by GUI & evaluation):
%       ys = sid.simulateARX(model, u, y, kValStart)
%       Uses y(1:kValStart-1) as initial history, then recursively simulates
%       for k >= kValStart using only the model's own past predictions.
%
%   Syntax 2 (classic):
%       ys = sid.simulateARX(y_init, u, a_coeffs, b_coeffs, nk)

    if nargin >= 3 && isstruct(varargin{1})
        model = varargin{1};
        u = varargin{2}(:);
        y = varargin{3}(:);
        a = model.a(:)';
        b = model.b(:)';
        na = model.na;
        nb = model.nb;
        nk = model.nk;
        k1 = model.k1;

        if nargin >= 4 && ~isempty(varargin{4})
            kValStart = varargin{4};
        else
            kValStart = k1;
        end
    elseif nargin >= 5
        y_init = varargin{1}(:);
        u = varargin{2}(:);
        a = varargin{3}(:)';
        b = varargin{4}(:)';
        nk = varargin{5};
        na = numel(a);
        nb = numel(b);
        k1 = max(na, nk + nb - 1) + 1;
        y = zeros(numel(u), 1);
        y(1:min(numel(y_init), numel(u))) = y_init(1:min(numel(y_init), numel(u)));
        kValStart = numel(y_init) + 1;
    else
        error('sid:simulateARX:nargin', 'Invalid arguments for simulateARX.');
    end

    N = numel(u);
    ys = y;

    % Recursive simulation from kValStart to N
    for k = kValStart:N
        if k - na < 1 || (k - nk - nb + 1) < 1
            continue;
        end
        pastY = ys(k - (1:na));
        pastU = u(k - nk - (0:nb-1));
        ys(k) = -sum(a .* pastY') + sum(b .* pastU');
    end
end
