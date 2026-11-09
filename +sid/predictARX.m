function yh = predictARX(varargin)
%PREDICTARX One-step-ahead prediction using measured past outputs and inputs.
%
%   Syntax 1: yh = sid.predictARX(model, u, y)
%   Syntax 2: yh = sid.predictARX(y_actual, u, a_coeffs, b_coeffs, nk)

    if nargin == 3 && isstruct(varargin{1})
        model = varargin{1};
        u = varargin{2}(:);
        y = varargin{3}(:);
        a = model.a(:)';
        b = model.b(:)';
        na = model.na;
        nb = model.nb;
        nk = model.nk;
        k1 = model.k1;
    elseif nargin >= 5
        y = varargin{1}(:);
        u = varargin{2}(:);
        a = varargin{3}(:)';
        b = varargin{4}(:)';
        nk = varargin{5};
        na = numel(a);
        nb = numel(b);
        k1 = max(na, nk + nb - 1) + 1;
    else
        error('sid:predictARX:nargin', 'Invalid arguments for predictARX.');
    end

    N = numel(u);
    yh = nan(N, 1);

    for k = k1:N
        pastY = y(k - (1:na));
        pastU = u(k - nk - (0:nb-1));
        yh(k) = -sum(a .* pastY') + sum(b .* pastU');
    end
end
