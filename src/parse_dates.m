function d = parse_dates(x, fmt)
% PARSE_DATES  Convert date strings or numbers into MATLAB date numbers.
%
%   d = parse_dates(x, fmt)
%
%   x is a cell array of strings (or a numeric vector for numeric formats).
%   fmt is one of
%     'yyyy-mm-dd'  ISO date, e.g. 1992-07-01 (also accepts 1992/07/01)
%     'yyyy-mm'     year and month, taken as the first day of the month
%     'yyyymmdd'    integer such as 19920701, as text or as a number
%     'yyyyQq'      quarter such as 1992Q3 or 1992-Q3 (ECB Data Portal), taken
%                   as the first day of the quarter
%     'yyyy'        year, taken as the first day of the year
%   The result is a column vector of date numbers. Dates that cannot be parsed
%   raise an error; nothing is guessed.

if ischar(x)
    x = {x};
end
if isnumeric(x)
    x = arrayfun(@(v) sprintf('%d', v), x(:), 'UniformOutput', false);
end
x = x(:);
n = numel(x);
d = zeros(n, 1);
switch lower(fmt)
    case 'yyyy-mm-dd'
        for i = 1:n
            v = sscanf(strrep(x{i}, '/', '-'), '%d-%d-%d');
            check(numel(v) == 3, x{i}, fmt);
            d(i) = datenum(v(1), v(2), v(3));
        end
    case 'yyyy-mm'
        for i = 1:n
            v = sscanf(strrep(x{i}, '/', '-'), '%d-%d');
            check(numel(v) == 2, x{i}, fmt);
            d(i) = datenum(v(1), v(2), 1);
        end
    case 'yyyymmdd'
        for i = 1:n
            v = sscanf(x{i}, '%d');
            check(numel(v) == 1 && v >= 10000101, x{i}, fmt);
            d(i) = datenum(floor(v / 10000), floor(mod(v, 10000) / 100), mod(v, 100));
        end
    case 'yyyyqq'
        for i = 1:n
            v = sscanf(strrep(upper(x{i}), '-Q', 'Q'), '%dQ%d');
            check(numel(v) == 2 && v(2) >= 1 && v(2) <= 4, x{i}, fmt);
            d(i) = datenum(v(1), 3 * (v(2) - 1) + 1, 1);
        end
    case 'yyyy'
        for i = 1:n
            v = sscanf(x{i}, '%d');
            check(numel(v) == 1 && v >= 1000 && v <= 9999, x{i}, fmt);
            d(i) = datenum(v, 1, 1);
        end
    otherwise
        error('macrodata:dateFormat', 'Unknown date format "%s".', fmt);
end
end

function check(ok, s, fmt)
if ~ok
    error('macrodata:dateParse', 'Cannot read "%s" as a date in format %s.', s, fmt);
end
end
