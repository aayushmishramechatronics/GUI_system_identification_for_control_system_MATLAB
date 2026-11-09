function [tn, un, yn] = resampleUniform(t, u, y, Tsn)
%RESAMPLEUNIFORM  Linear-interpolation resampling onto a uniform grid with step Tsn.
%   Note: no anti-alias filter is applied when down-sampling (documented limitation).
t = t(:); u = u(:); y = y(:);
if ~(isscalar(Tsn) && isfinite(Tsn) && Tsn > 0)
    error('sid:resampleUniform:Ts', 'New sampling time must be a positive number.');
end
if Tsn >= (t(end) - t(1))
    error('sid:resampleUniform:Ts', 'New sampling time exceeds the data duration.');
end
tn = (t(1):Tsn:t(end))';
un = interp1(t, u, tn, 'linear');  yn = interp1(t, y, tn, 'linear');
keep = ~(isnan(un) | isnan(yn));
tn = tn(keep); un = un(keep); yn = yn(keep);
end
