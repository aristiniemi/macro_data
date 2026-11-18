function x = place_on_grid(S, grid)
% PLACE_ON_GRID  Put a quarterly series onto the output grid by quarter index.
%
%   x = place_on_grid(S, grid)
%
%   S has fields q (quarter indices) and x (values). The result has the size
%   of grid and is NaN at quarters where S has no value. Alignment is by
%   quarter, never by position.

x = nan(size(grid));
[tf, loc] = ismember(grid, S.q);
x(tf) = S.x(loc(tf));
end
