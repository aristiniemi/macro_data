function [dates, values] = parse_series_file(file, item)
% PARSE_SERIES_FILE  Read one downloaded file into dates and values.
%
%   [dates, values] = parse_series_file(file, item)
%
%   item is one row of the series list (see read_series_list). The file
%   format, sheet, date column, date format and value column come from it.
%   Dates are returned as date numbers, values as doubles; a missing value
%   in the file ('.', empty, 'NA', or a non-numeric cell) becomes NaN here and
%   is checked by the caller. Rows are sorted by date. Duplicate dates raise
%   an error.
%
%   Supported formats:
%     csv   text file with a header row (FRED, Federal Reserve Board files)
%     xlsx  Excel workbook, one sheet, header in the first row (needs
%           readcell, MATLAB R2019a or later)

switch item.format
    case 'csv'
        [header, cells] = read_csv_cells(file);
        dcol = find_column(header, item.date_column, file);
        vcol = find_column(header, item.value_column, file);
        datestrs = cells(:, dcol);
        valstrs = cells(:, vcol);
        values = to_numbers(valstrs);
    case 'xlsx'
        if ~(exist('readcell', 'file') == 2 || exist('readcell', 'builtin') == 5)
            error('macrodata:xlsx', ...
                'Reading %s needs readcell (MATLAB R2019a or later).', file);
        end
        if isempty(item.sheet)
            C = readcell(file);
        else
            C = readcell(file, 'Sheet', item.sheet);
        end
        header = cellfun(@(c) to_string(c), C(1, :), 'UniformOutput', false);
        dcol = find_column(header, item.date_column, file);
        vcol = find_column(header, item.value_column, file);
        body = C(2:end, :);
        datestrs = cellfun(@(c) to_string(c), body(:, dcol), 'UniformOutput', false);
        values = cellfun(@(c) to_number_cell(c), body(:, vcol));
    otherwise
        error('macrodata:format', 'Unknown file format "%s".', item.format);
end

% Drop rows without a date (blank trailing rows in spreadsheets).
keep = ~cellfun(@isempty, datestrs);
datestrs = datestrs(keep);
values = values(keep);

dates = parse_dates(datestrs, item.date_format);
[dates, order] = sort(dates);
values = values(order);
if any(diff(dates) == 0)
    error('macrodata:duplicateDates', 'Duplicate dates in %s.', file);
end
end

function k = find_column(header, name, file)
k = find(strcmpi(strtrim(header), strtrim(name)));
if numel(k) ~= 1
    error('macrodata:column', 'Column "%s" not found (or not unique) in %s. Columns: %s', ...
        name, file, strjoin(header, ' | '));
end
end

function v = to_numbers(strs)
v = nan(numel(strs), 1);
for i = 1:numel(strs)
    s = strtrim(strs{i});
    if isempty(s) || strcmp(s, '.') || strcmpi(s, 'NA') || strcmpi(s, 'NaN')
        continue
    end
    x = str2double(s);
    if isnan(x)
        error('macrodata:value', 'Cannot read "%s" as a number.', s);
    end
    v(i) = x;
end
end

function s = to_string(c)
if ischar(c)
    s = c;
elseif isnumeric(c) && isscalar(c)
    s = sprintf('%.15g', c);
elseif isa(c, 'datetime')
    s = datestr(c, 'yyyy-mm-dd');
else
    s = '';
end
end

function v = to_number_cell(c)
if isnumeric(c) && isscalar(c)
    v = double(c);
elseif ischar(c)
    v = str2double(c);
else
    v = NaN;
end
end
