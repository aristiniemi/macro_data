function [q, x] = to_quarterly(dates, values, frequency, rule)
% TO_QUARTERLY  Aggregate a daily, monthly or quarterly series to quarters.
%
%   [q, x] = to_quarterly(dates, values, frequency, rule)
%
%   dates are date numbers, values the observations, frequency one of
%   'daily', 'monthly', 'quarterly', and rule one of 'none' (quarterly input
%   only), 'average', 'last', 'sum'. The result is a column of quarter indices
%   q (see quarter_index), consecutive without gaps, and the quarterly values x.
%
%   Alignment is by date, never by position: each observation is assigned to
%   the quarter that contains its date. Rules:
%     quarterly  dates must be the first month of a quarter and consecutive;
%                values are returned unchanged (a NaN stays NaN).
%     monthly    the months must be consecutive. A quarter is complete when all
%                three months are present with a value; an incomplete quarter
%                is missing (NaN) and printed as a message. An incomplete
%                quarter at the end of the series is dropped instead.
%     daily      observations with a NaN value are ignored. Every quarter needs
%                at least one observation. The final quarter is kept only if
%                the last observation falls within the last 7 days of the
%                quarter; otherwise it is dropped.
%     annual     rule 'interpolate' only. The annual value is taken as the
%                value at the middle of the year and quarterly values are
%                read off the straight line between consecutive mid-years
%                (quarter k of year y sits at y + (k - 0.5)/4). Quarters before
%                the first mid-year and after the last are not extrapolated:
%                the result starts in Q3 of the first year and ends in Q2 of
%                the last. The years must be consecutive without missing
%                values.
%   Apart from that documented interpolation of annual series, nothing is
%   interpolated or filled.

dates = dates(:);
values = values(:);
if numel(dates) ~= numel(values)
    error('macrodata:toQuarterly', 'dates and values differ in length.');
end
if any(diff(dates) <= 0)
    error('macrodata:toQuarterly', 'Dates must be strictly increasing.');
end
qi = quarter_index(dates);

switch frequency
    case 'quarterly'
        if ~strcmp(rule, 'none')
            error('macrodata:toQuarterly', 'A quarterly series takes rule "none", not "%s".', rule);
        end
        [~, m] = datevec(dates);
        if any(~ismember(m, [1 4 7 10]))
            error('macrodata:toQuarterly', 'Quarterly dates must be the first month of a quarter.');
        end
        if any(diff(qi) ~= 1)
            error('macrodata:toQuarterly', 'Quarterly series has a gap or a duplicate quarter.');
        end
        q = qi;
        x = values;
        return
    case 'monthly'
        [~, m] = datevec(dates);
        months = 12 * floor(qi / 4) + m;  % absolute month index
        if any(diff(months) ~= 1)
            error('macrodata:toQuarterly', 'Monthly series has a gap or a duplicate month.');
        end
        q = (qi(1):qi(end))';
        x = nan(size(q));
        for k = 1:numel(q)
            v = values(qi == q(k));
            v = v(~isnan(v));
            if numel(v) == 3
                x(k) = aggregate(v, rule);
            elseif k == numel(q)
                fprintf('   incomplete final quarter %s (%d month(s)) dropped\n', qlabel(q(k)), numel(v));
                q(k) = [];
                x(k) = [];
            else
                fprintf('   quarter %s has only %d month(s) with data: left missing\n', qlabel(q(k)), numel(v));
            end
        end
        % A series starting mid-quarter: drop the leading missing quarter.
        while ~isempty(x) && isnan(x(1))
            q(1) = [];
            x(1) = [];
        end
    case 'daily'
        keep = ~isnan(values);
        dates = dates(keep);
        values = values(keep);
        qi = qi(keep);
        q = (qi(1):qi(end))';
        x = nan(size(q));
        for k = 1:numel(q)
            v = values(qi == q(k));
            if isempty(v)
                error('macrodata:toQuarterly', 'Quarter %s has no observations.', qlabel(q(k)));
            end
            x(k) = aggregate(v, rule);
        end
        % Drop the final quarter if it is not (nearly) complete.
        qend = datenum(floor(q(end) / 4), 3 * (mod(q(end), 4) + 1) + 1, 1) - 1;
        if dates(end) < qend - 7
            fprintf('   incomplete final quarter %s (last observation %s) dropped\n', ...
                qlabel(q(end)), datestr(dates(end), 'yyyy-mm-dd'));
            q(end) = [];
            x(end) = [];
        end
    case 'annual'
        if ~strcmp(rule, 'interpolate')
            error('macrodata:toQuarterly', 'An annual series takes rule "interpolate", not "%s".', rule);
        end
        [y, m] = datevec(dates);
        if any(m ~= 1) || any(diff(y) ~= 1)
            error('macrodata:toQuarterly', 'Annual dates must be 1 January of consecutive years.');
        end
        if any(isnan(values))
            error('macrodata:toQuarterly', 'Annual series has missing values; cannot interpolate across them.');
        end
        if numel(y) < 2
            error('macrodata:toQuarterly', 'At least two years are needed to interpolate.');
        end
        q = (quarter_index(y(1), 3):quarter_index(y(end), 2))';
        tq = floor(q / 4) + (mod(q, 4) + 0.5) / 4;   % position of each quarter in years
        ty = y + 0.5;                                 % mid-year position of annual values
        x = interp1(ty, values, tq, 'linear');
    otherwise
        error('macrodata:toQuarterly', 'Unknown frequency "%s".', frequency);
end
end

function s = qlabel(q)
c = quarter_string(q);
s = c{1};
end

function a = aggregate(v, rule)
switch rule
    case 'average'
        a = mean(v);
    case 'last'
        a = v(end);
    case 'sum'
        a = sum(v);
    otherwise
        error('macrodata:toQuarterly', 'Unknown aggregation rule "%s".', rule);
end
end
