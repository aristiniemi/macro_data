function R = rate_group(raw, Q, rule, names)
% RATE_GROUP  Quarterly values of the interest-rate group under the rate option.
%
%   R = rate_group(raw, Q, rule, names)
%
%   For each series in names that exists in raw, returns the quarterly
%   series aggregated with RULE ('average' or 'last'): the one already in Q
%   when the list rule is the same, otherwise a fresh aggregation.

R = struct();
all_names = {raw.name};
for k = 1:numel(names)
    c = names{k};
    i = find(strcmp(all_names, c), 1);
    if isempty(i)
        continue
    end
    if strcmp(raw(i).aggregation, rule)
        R.(c) = Q.(c);
    else
        fprintf('Aggregating %-16s (%s, %s) for the interest rate option\n', c, raw(i).frequency, rule);
        [q, x] = to_quarterly(raw(i).dates, raw(i).values, raw(i).frequency, rule);
        R.(c) = struct('q', q, 'x', x);
    end
end
end
