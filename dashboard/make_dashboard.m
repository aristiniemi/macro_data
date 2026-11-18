function htmlfile = make_dashboard(output_folder, name, raw_folder)
% MAKE_DASHBOARD  Build a self-contained HTML page to look at the dataset.
%
%   htmlfile = make_dashboard(output_folder, name, raw_folder)
%
%   Reads <name>.csv and <name>_metadata.json from output_folder and the raw
%   series saved by download_series in raw_folder, and writes
%   <name>_dashboard.html next to them. The page is the template
%   dashboard/template.html with the data embedded as JSON; it needs no
%   network connection and no external library. Open it in any browser.
%
%   The page shows sample coverage and last observation per series, the model
%   variables, the levels and indices, and every raw series at its native
%   frequency together with its quarterly aggregate.

here = fileparts(mfilename('fullpath'));
template = fileread(fullfile(here, 'template.html'));

% ---- Output dataset from the CSV file (the file is the source, not memory) ----
[header, cells] = read_csv_cells(fullfile(output_folder, [name '.csv']));
T = size(cells, 1);
P = struct();
P.dates = cells(:, strcmp(header, 'date'));
q = quarter_index(P.dates);
P.t = floor(q / 4) + (mod(q, 4) + 0.5) / 4;   % decimal year, middle of the quarter
values = struct();
for k = 1:numel(header)
    if any(strcmp(header{k}, {'date', 'year', 'quarter'}))
        continue
    end
    col = cells(:, k);
    v = nan(T, 1);
    filled = ~cellfun(@isempty, col);
    v(filled) = str2double(col(filled));
    values.(header{k}) = v;
end
P.values = values;

% ---- Metadata ----
meta = jsondecode(fileread(fullfile(output_folder, [name '_metadata.json'])));
P.meta = meta;
labels = struct('US', 'US', 'EA', 'Euro Area');
if isfield(labels, meta.country)
    P.title = sprintf('%s Macro Dataset', labels.(meta.country));
else
    P.title = sprintf('%s Macro Dataset', meta.country);
end
P.built = meta.built;

% Column descriptions by group.
units = struct('dc', 'percent per quarter', 'dinve', 'percent per quarter', ...
    'dy', 'percent per quarter', 'dw', 'percent per quarter', ...
    'pinfobs', 'percent per quarter', 'labobs', 'percent deviation from mean', ...
    'robs', 'percent per quarter', 'ebpobs', 'percentage points', ...
    'consumption', '100 x log', 'investment', '100 x log', 'output', '100 x log', ...
    'hours', '100 x log', 'realwage', '100 x log', ...
    'COMP', 'euro per hour', ...
    'popidx', sprintf('ratio, %s = 1', meta.index_base), ...
    'empidx', sprintf('index, %s = 100', meta.index_base), ...
    'population', 'thousands of persons');
columns = struct('name', {}, 'group', {}, 'definition', {}, 'units', {});
groups = {'model', meta.model_variables; 'level', meta.levels; 'raw', meta.raw_columns};
for g = 1:size(groups, 1)
    keys = groups{g, 2};
    if ischar(keys)
        keys = {keys};
    end
    for k = 1:numel(keys)
        c = struct('name', keys{k}, 'group', groups{g, 1}, 'definition', '', 'units', '');
        if isfield(meta.definitions, keys{k})
            c.definition = meta.definitions.(keys{k});
        elseif strcmp(keys{k}, 'population')
            c.definition = 'population series used for popidx';
        end
        if isfield(units, keys{k})
            c.units = units.(keys{k});
        else
            [s, rule] = series_info(meta, keys{k});
            if ~isempty(s)
                c.units = s.units;
                c.definition = sprintf('%s, quarterly %s', s.description, aggregation_text(rule, s));
            elseif strcmp(groups{g, 1}, 'level') && isfield(meta.definitions, keys{k})
                c.units = 'see definition';
            end
        end
        columns(end + 1) = c; %#ok<AGROW>
    end
end
P.columns = columns;

% ---- Raw series at native frequency ----
S = load(fullfile(raw_folder, sprintf('raw_%s.mat', meta.country)));
raw = S.raw;
R = struct('name', {}, 'code', {}, 'description', {}, 'units', {}, 'source', {}, 'url', {}, ...
    'frequency', {}, 'aggregation', {}, 'downloaded', {}, 'first', {}, 'last', {}, ...
    'n', {}, 'gaps', {}, 't', {}, 'v', {}, 'citation', {});
for i = 1:numel(raw)
    r = raw(i);
    [y, ~, ~] = datevec(r.dates);
    t = y + (r.dates - datenum(y, 1, 1)) ./ (datenum(y + 1, 1, 1) - datenum(y, 1, 1));
    gaps = r.gaps;
    if isempty(gaps)
        gaps = {};
    end
    R(end + 1) = struct('name', r.name, 'code', r.code, 'description', r.description, 'units', r.units, ...
        'source', r.source, 'url', r.url, 'frequency', r.frequency, 'aggregation', r.aggregation, ...
        'downloaded', r.downloaded, 'first', datestr(r.dates(1), 'yyyy-mm-dd'), ...
        'last', datestr(r.dates(end), 'yyyy-mm-dd'), 'n', sum(~isnan(r.values)), ...
        'gaps', {gaps}, 't', t(:)', 'v', r.values(:)', 'citation', r.citation); %#ok<AGROW>
end
P.raw = R;

json = jsonencode(P);
% Keep the JSON safe inside a <script> element.
json = strrep(json, '</', '<\/');
html = strrep(template, '__PAYLOAD__', json);

htmlfile = fullfile(output_folder, [name '_dashboard.html']);
fid = fopen(htmlfile, 'w');
if fid < 0
    error('macrodata:write', 'Cannot write %s.', htmlfile);
end
fprintf(fid, '%s', html);
fclose(fid);
fprintf('Wrote %s\n', htmlfile);
end

function [s, rule] = series_info(meta, column)
% The column is a series name, or a series name followed by _<rule> for the
% interest rate option.
s = [];
rule = '';
names = {meta.series.name};
i = find(strcmp(names, column), 1);
if isempty(i)
    for r = {'average', 'last', 'sum'}
        suffix = ['_' r{1}];
        if numel(column) > numel(suffix) && strcmp(column(end - numel(suffix) + 1:end), suffix)
            i = find(strcmp(names, column(1:end - numel(suffix))), 1);
            if ~isempty(i)
                rule = r{1};
                break
            end
        end
    end
end
if ~isempty(i)
    s = meta.series(i);
    if isempty(rule)
        rule = s.quarterly_aggregation;
    end
end
end

function txt = aggregation_text(rule, s) %#ok<INUSD>
switch rule
    case 'none'
        txt = 'as published';
    case 'average'
        txt = 'average';
    case 'last'
        txt = 'last observation of the quarter';
    case 'sum'
        txt = 'sum';
    case 'interpolate'
        txt = 'interpolated from annual values';
    otherwise
        txt = rule;
end
end
