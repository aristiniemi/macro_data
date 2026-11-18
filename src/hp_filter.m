function trend = hp_filter(y, lambda)
% HP_FILTER  Hodrick-Prescott trend of a series.
%
%   trend = hp_filter(y, lambda)
%
%   y is a column vector without missing values, lambda the smoothing
%   parameter (1600 for quarterly data). The trend solves
%       min sum (y - trend)^2 + lambda * sum (second difference of trend)^2,
%   computed exactly with a sparse linear system.

y = y(:);
T = numel(y);
if T < 3
    error('macrodata:hp', 'The HP filter needs at least 3 observations.');
end
if any(isnan(y))
    error('macrodata:hp', 'The HP filter does not accept missing values.');
end
e = ones(T, 1);
D = spdiags([e -2 * e e], 0:2, T - 2, T);
trend = (speye(T) + lambda * (D' * D)) \ y;
end
