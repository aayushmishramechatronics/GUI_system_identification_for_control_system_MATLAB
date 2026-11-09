function lines = tfString(model, Ts)
%TFSTRING  Readable G(z) = B(z^-1)/A(z^-1) built from the estimated coefficients.
num = polyStr(model.b, model.nk + (0:model.nb-1), '');
den = polyStr(model.a, 1:model.na, '1');
A1 = 1 + sum(model.a);
if abs(A1) < 1e-12, dc = 'infinite (pole at z = 1)'; else, dc = sprintf('%.5g', sum(model.b)/A1); end
p = roots([1, model.a]);
ps = '';
for i = 1:numel(p)
    if abs(imag(p(i))) < 1e-12, ps = [ps sprintf('%.4f  ', real(p(i)))];                 %#ok<AGROW>
    else, ps = [ps sprintf('%.4f%+.4fi  ', real(p(i)), imag(p(i)))];                      %#ok<AGROW>
    end
end
lines = {'G(z) = B(z^-1) / A(z^-1)', ['B(z^-1) = ' num], ['A(z^-1) = ' den], ...
         ['DC gain B(1)/A(1) = ' dc], ['Poles (|p|<1 stable): ' strtrim(ps)]};
if nargin > 1 && isfinite(Ts), lines{end+1} = sprintf('Sampling time Ts = %.6g s', Ts); end
end

function s = polyStr(c, e, s)
for i = 1:numel(c)
    if e(i) == 0, term = sprintf('%.5g', abs(c(i)));
    else,         term = sprintf('%.5g*z^(-%d)', abs(c(i)), e(i)); end
    if isempty(s)
        if c(i) < 0, s = ['-' term]; else, s = term; end
    elseif c(i) < 0, s = [s ' - ' term];
    else,            s = [s ' + ' term];
    end
end
end
