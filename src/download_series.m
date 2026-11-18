function raw = download_series(list, raw_folder)
% DOWNLOAD_SERIES  Download every series in the list and save the raw data.
%
%   raw = download_series(list, raw_folder)
%
%   list is the struct array from read_series_list. For each series the file
%   is downloaded unchanged to raw_folder/<code>.<format>, parsed, and checked:
%     - the file must exist and contain at least one observation,
%     - the first observation must be no later than expected_start in the list,
%     - there must be no missing value between the first and the last
%       observation, unless allow_gaps is "yes" in the list. A permitted gap
%       is printed as a warning, listed in the field gaps, and kept as NaN in
%       values; it is never filled.
%   A series that fails a check stops the run with an error, unless its
%   required field is "no": then a warning is printed and the series is left
%   out of the result.
%
%   The parsed series are returned as a struct array with fields
%     name, code, country, description, units, source, url, frequency,
%     aggregation, citation, file, downloaded (local time of download),
%     dates (date numbers), values, gaps (cell array of dates of missing
%     values). Files are named after the series name.
%   and saved to raw_folder/raw_<country>.mat together with a download log,
%   raw_folder/download_log.csv (code, url, downloaded, first date, last
%   date, number of observations, file).

if ~exist(raw_folder, 'dir')
    mkdir(raw_folder);
end

raw = struct('name', {}, 'code', {}, 'country', {}, 'description', {}, 'units', {}, ...
    'source', {}, 'url', {}, 'frequency', {}, 'aggregation', {}, 'citation', {}, ...
    'file', {}, 'downloaded', {}, 'dates', {}, 'values', {}, 'gaps', {});

for i = 1:numel(list)
    item = list(i);
    file = fullfile(raw_folder, sprintf('%s.%s', item.name, item.format));
    fprintf('Downloading %-16s from %s\n', item.name, shorten(item.url));
    try
        fetch_url(item.url, file);
        stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        [dates, values] = parse_series_file(file, item);
        gaps = check_series(dates, values, item);
    catch err
        if item.required
            rethrow(err);
        else
            warning('macrodata:optionalSeries', ...
                'Optional series %s skipped: %s', item.name, err.message);
            continue
        end
    end
    % Drop missing values at the ends only; permitted interior gaps stay NaN.
    first = find(~isnan(values), 1, 'first');
    last = find(~isnan(values), 1, 'last');
    dates = dates(first:last);
    values = values(first:last);

    s = struct('name', item.name, 'code', item.code, 'country', item.country, ...
        'description', item.description, 'units', item.units, ...
        'source', item.source, 'url', item.url, 'frequency', item.native_frequency, ...
        'aggregation', item.quarterly_aggregation, 'citation', item.citation, ...
        'file', file, 'downloaded', stamp, 'dates', dates, 'values', values, 'gaps', {gaps});
    raw(end + 1) = s; %#ok<AGROW>
    fprintf('   %d observations, %s to %s\n', sum(~isnan(values)), ...
        datestr(dates(1), 'yyyy-mm-dd'), datestr(dates(end), 'yyyy-mm-dd'));
end

if isempty(raw)
    error('macrodata:download', 'No series were downloaded.');
end

country = raw(1).country;
save(fullfile(raw_folder, sprintf('raw_%s.mat', country)), '-v7', 'raw');
write_download_log(raw, fullfile(raw_folder, 'download_log.csv'));
end

function gaps = check_series(dates, values, item)
gaps = {};
if isempty(values) || all(isnan(values))
    error('macrodata:emptySeries', 'Series %s has no observations.', item.name);
end
first = find(~isnan(values), 1, 'first');
last = find(~isnan(values), 1, 'last');
interior = values(first:last);
if any(isnan(interior))
    gapdates = dates(first - 1 + find(isnan(interior)));
    gaps = cellstr(datestr(gapdates, 'yyyy-mm-dd'))';
    if ~item.allow_gaps
        error('macrodata:gap', ['Series %s has %d missing value(s) inside its sample, first at %s. ' ...
            'Set allow_gaps to yes in the series list if the gap is genuine.'], ...
            item.name, numel(gaps), gaps{1});
    end
    warning('macrodata:gap', 'Series %s has %d missing value(s) inside its sample (%s). %s', ...
        item.name, numel(gaps), strjoin(gaps, ', '), ...
        'Quarters containing a gap will be missing in the output.');
end
if ~isempty(item.expected_start)
    expected = parse_dates(item.expected_start, 'yyyy-mm-dd');
    if dates(first) > expected
        error('macrodata:shortSeries', 'Series %s starts %s, expected no later than %s.', ...
            item.name, datestr(dates(first), 'yyyy-mm-dd'), item.expected_start);
    end
end
end

function write_download_log(raw, file)
fid = fopen(file, 'w');
if fid < 0
    error('macrodata:write', 'Cannot write %s.', file);
end
fprintf(fid, 'name,code,url,downloaded,first_date,last_date,n_obs,gaps,file\n');
for i = 1:numel(raw)
    fprintf(fid, '%s,%s,"%s",%s,%s,%s,%d,"%s",%s\n', raw(i).name, raw(i).code, raw(i).url, raw(i).downloaded, ...
        datestr(raw(i).dates(1), 'yyyy-mm-dd'), datestr(raw(i).dates(end), 'yyyy-mm-dd'), ...
        sum(~isnan(raw(i).values)), strjoin(raw(i).gaps, ' '), raw(i).file);
end
fclose(fid);
end

function s = shorten(url)
if numel(url) > 80
    s = [url(1:77) '...'];
else
    s = url;
end
end
