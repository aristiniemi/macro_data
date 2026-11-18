function s = quarter_string(q)
% QUARTER_STRING  'YYYYQn' labels for quarter indices from quarter_index.
%
%   s = quarter_string(q)   returns a cell array of strings the size of q.
s = arrayfun(@(v) sprintf('%dQ%d', floor(v / 4), mod(v, 4) + 1), q(:), 'UniformOutput', false);
end
