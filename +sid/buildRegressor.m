function [Phi, Y] = buildRegressor(u, y, na, nb, nk, k1, k2)
%BUILDREGRESSOR  Rows k1..k2 of Phi = [-y(k-1..k-na), u(k-nk .. k-nk-nb+1)], Y = y(k).
k = (k1:k2)';  Phi = zeros(numel(k), na+nb);
for i = 1:na,  Phi(:, i)    = -y(k - i);          end
for j = 1:nb,  Phi(:, na+j) =  u(k - nk - j + 1); end
Y = y(k);
end
