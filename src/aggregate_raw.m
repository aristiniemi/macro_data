function Q = aggregate_raw(raw)
% AGGREGATE_RAW  Aggregate every raw series to quarters with the rule in the list.
%
%   Q = aggregate_raw(raw)
%
%   Returns a struct with one field per series name, each holding q (quarter
%   indices) and x (quarterly values), from to_quarterly.

Q = struct();
for i = 1:numel(raw)
    fprintf('Aggregating %-16s (%s, %s)\n', raw(i).name, raw(i).frequency, raw(i).aggregation);
    [q, x] = to_quarterly(raw(i).dates, raw(i).values, raw(i).frequency, raw(i).aggregation);
    Q.(raw(i).name) = struct('q', q, 'x', x);
end
end
