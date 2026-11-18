function list = read_series_list(file, country)
% READ_SERIES_LIST  Read the series list (CSV) into a struct array.
%
%   list = read_series_list(file, country)
%
%   Returns one struct per row of the series list whose country field equals
%   COUNTRY (case-insensitive). Every column of the CSV becomes a field with the
%   same name. The function checks that the required columns exist, that names
%   are valid identifiers and unique within the country, and that the
%   frequency and aggregation fields hold allowed values.
%
%   Columns:
%     country       country code, e.g. US or EA
%     name          short name used for files, output columns and in the build
%                   functions; must be a valid MATLAB identifier
%     code          series code at the source (FRED code, ECB series key, ...)
%     description, units, citation
%     source        FRED, ECB, or any label for another source
%     url           full download address; may be empty for FRED and ECB,
%                   where it follows from the code; a local file path is
%                   copied instead of downloaded
%     format        csv or xlsx
%     sheet         sheet name for xlsx
%     date_column, date_format, value_column
%                   where the dates and values are in the file; may be empty
%                   for FRED and ECB
%     native_frequency      daily, monthly, quarterly or annual
%     quarterly_aggregation none (quarterly), average, last, sum (daily and
%                           monthly) or interpolate (annual)
%     expected_start        the series must start no later than this date
%     required              yes: a failure stops the run; no: skipped with a warning
%     allow_gaps            yes: missing values inside the sample are permitted

required_columns = {'country', 'name', 'code', 'description', 'units', 'source', 'url', ...
    'format', 'sheet', 'date_column', 'date_format', 'value_column', ...
    'native_frequency', 'quarterly_aggregation', 'expected_start', 'required', 'allow_gaps', 'citation'};

[header, cells] = read_csv_cells(file);
header = lower(header);
missing = setdiff(required_columns, header);
if ~isempty(missing)
    error('macrodata:seriesList', 'Series list %s lacks column(s): %s', ...
        file, strjoin(missing, ', '));
end

rows = strcmpi(cells(:, strcmp(header, 'country')), country);
if ~any(rows)
    error('macrodata:seriesList', 'No series for country "%s" in %s.', country, file);
end
cells = cells(rows, :);

list = struct();
for i = 1:size(cells, 1)
    for k = 1:numel(header)
        list(i).(header{k}) = cells{i, k};
    end
    if ~isvarname(list(i).name)
        error('macrodata:seriesList', 'Series name "%s" is not a valid identifier.', list(i).name);
    end
    list(i).native_frequency = lower(list(i).native_frequency);
    list(i).quarterly_aggregation = lower(list(i).quarterly_aggregation);
    list(i).format = lower(list(i).format);
    list(i).required = strcmpi(list(i).required, 'yes') || strcmpi(list(i).required, 'true');
    list(i).allow_gaps = strcmpi(list(i).allow_gaps, 'yes') || strcmpi(list(i).allow_gaps, 'true');

    % FRED and ECB Data Portal series need no URL, date column or value
    % column in the list: they follow from the code.
    if strcmpi(list(i).source, 'FRED')
        if isempty(list(i).url)
            list(i).url = sprintf('https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s', list(i).code);
        end
        if isempty(list(i).date_column), list(i).date_column = 'observation_date'; end
        if isempty(list(i).date_format), list(i).date_format = 'yyyy-mm-dd'; end
        if isempty(list(i).value_column), list(i).value_column = list(i).code; end
    elseif strcmpi(list(i).source, 'ECB')
        % The code is the full series key, e.g. MNA.Q.Y.I9.W2.S1.S1.B.B1GQ._Z._Z._Z.EUR.LR.N;
        % the dataflow is its first element.
        if isempty(list(i).url)
            dot = find(list(i).code == '.', 1);
            if isempty(dot)
                error('macrodata:seriesList', 'ECB code %s must be a full series key (FLOW.KEY).', list(i).code);
            end
            list(i).url = sprintf('https://data-api.ecb.europa.eu/service/data/%s/%s?format=csvdata', ...
                list(i).code(1:dot - 1), list(i).code(dot + 1:end));
        end
        if isempty(list(i).date_column), list(i).date_column = 'TIME_PERIOD'; end
        if isempty(list(i).value_column), list(i).value_column = 'OBS_VALUE'; end
        if isempty(list(i).date_format)
            switch list(i).native_frequency
                case 'annual', list(i).date_format = 'yyyy';
                case 'quarterly', list(i).date_format = 'yyyyQq';
                case 'monthly', list(i).date_format = 'yyyy-mm';
                otherwise, list(i).date_format = 'yyyy-mm-dd';
            end
        end
    end

    f = list(i).native_frequency;
    a = list(i).quarterly_aggregation;
    if ~any(strcmp(f, {'daily', 'monthly', 'quarterly', 'annual'}))
        error('macrodata:seriesList', 'Series %s: unknown native_frequency "%s".', list(i).name, f);
    end
    if ~any(strcmp(a, {'none', 'average', 'last', 'sum', 'interpolate'}))
        error('macrodata:seriesList', 'Series %s: unknown quarterly_aggregation "%s".', list(i).name, a);
    end
    if strcmp(f, 'quarterly') && ~strcmp(a, 'none')
        error('macrodata:seriesList', 'Series %s is quarterly; its aggregation must be "none".', list(i).name);
    end
    if strcmp(f, 'annual') && ~strcmp(a, 'interpolate')
        error('macrodata:seriesList', 'Series %s is annual; its aggregation must be "interpolate".', list(i).name);
    end
    if any(strcmp(f, {'daily', 'monthly'})) && ~any(strcmp(a, {'average', 'last', 'sum'}))
        error('macrodata:seriesList', 'Series %s is %s; it needs average, last or sum.', list(i).name, f);
    end
    if ~any(strcmp(list(i).format, {'csv', 'xlsx'}))
        error('macrodata:seriesList', 'Series %s: unknown format "%s".', list(i).name, list(i).format);
    end
    if isempty(list(i).url)
        error('macrodata:seriesList', 'Series %s has no URL.', list(i).name);
    end
    if isempty(list(i).date_column) || isempty(list(i).value_column) || isempty(list(i).date_format)
        error('macrodata:seriesList', 'Series %s needs date_column, date_format and value_column.', list(i).name);
    end
end

names = {list.name};
if numel(unique(names)) ~= numel(names)
    error('macrodata:seriesList', 'Duplicate names in the series list for %s.', country);
end
end
