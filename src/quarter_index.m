function q = quarter_index(arg1, arg2)
% QUARTER_INDEX  Integer index of a quarter: 4*year + quarter - 1.
%
%   q = quarter_index(datenums)        from date numbers
%   q = quarter_index(year, quarter)   from year and quarter (1 to 4)
%   q = quarter_index('1992Q3')        from a string or cell array of strings
%
%   Consecutive quarters have consecutive indices, so differences of indices
%   count quarters. Use quarter_string to go back to 'YYYYQn'.

if nargin == 2
    q = 4 * arg1(:) + arg2(:) - 1;
elseif ischar(arg1) || iscell(arg1)
    q = quarter_index(parse_dates(arg1, 'yyyyQq'));
else
    [y, m] = datevec(arg1(:));
    q = 4 * y + floor((m - 1) / 3);
end
end
