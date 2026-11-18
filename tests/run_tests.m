function results = run_tests(varargin)
% RUN_TESTS  Check a generated dataset against its own definitions and outside sources.
%
%   run_tests()                      the US dataset in the default folders
%   run_tests('country', 'EA')       the euro-area dataset
%   run_tests('network', false)      skip the checks that download data
%   run_tests('output_folder', f, 'raw_folder', g, 'name', n)
%
%   Checks:
%     1. Raw series: dates strictly increasing and regularly spaced for the
%        native frequency; permitted gaps reported.
%     2. Output grid: consecutive quarters, no duplicates, year and quarter
%        columns consistent with the date label; CSV and .mat agree.
%     3. Index base: popidx equals 1 and empidx equals 100 in the base quarter.
%     4. Definitions: every constructed column recomputed from the other
%        columns of the CSV file, so that a misaligned or mislabelled column
%        would show up.
%     5. Population: US, the raw population grows by more than 0.8 percent in
%        2000Q1 (new population controls) and the smoothed index by less
%        than 0.4 percent; EA, no quarter-to-quarter change of the index
%        above 1 percent.
%     6. Second source (network): US, the quarterly averages of the monthly
%        FRED series equal FRED's own quarterly aggregation to FRED's
%        rounding, and the last-month federal funds rate equals FRED's
%        end-of-period aggregation; EA, the quarterly average of the monthly
%        3-month Euribor is within 0.05 of the ECB's own quarterly series
%        (average of daily observations).
%     7. Reference dataset (network, US only): comparison with Smets and
%        Wouters (2007); robs must agree to 0.01 from 1954Q3, inflation and
%        hours must correlate above 0.95 and 0.9, the growth rates of output,
%        consumption and investment above 0.9 and the real wage above 0.7
%        (differences are data revisions since 2005).
%   Each check prints PASS or FAIL with the numbers; the function errors at
%   the end if any check failed, so it can be used as a gate.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root, 'src'));
addpath(here);

p = struct('country', 'US', 'output_folder', fullfile(root, 'data', 'output'), ...
    'raw_folder', '', 'name', '', 'network', true);
for k = 1:2:numel(varargin)
    p.(varargin{k}) = varargin{k + 1};
end
p.country = upper(p.country);
if isempty(p.raw_folder)
    p.raw_folder = fullfile(root, 'data', 'raw', p.country);
end
if isempty(p.name)
    p.name = sprintf('%s_quarterly', lower(p.country));
end

S = load(fullfile(p.output_folder, [p.name '.mat']));
data = S.data;
meta = S.meta;
raw = load_raw(p.raw_folder, p.country);
[header, cells] = read_csv_cells(fullfile(p.output_folder, [p.name '.csv']));
csv = struct();
for k = 1:numel(header)
    col = cells(:, k);
    if strcmp(header{k}, 'date')
        csv.date = col;
    else
        v = nan(numel(col), 1);
        filled = ~cellfun(@isempty, col);
        v(filled) = str2double(col(filled));
        csv.(header{k}) = v;
    end
end

results = struct('name', {}, 'passed', {}, 'message', {});

% ---- 1. Raw series regularity ----
for i = 1:numel(raw)
    d = raw(i).dates;
    ok = all(diff(d) > 0);
    msg = sprintf('%d obs, %s to %s', sum(~isnan(raw(i).values)), ...
        datestr(d(1), 'yyyy-mm-dd'), datestr(d(end), 'yyyy-mm-dd'));
    [y, m] = datevec(d);
    switch raw(i).frequency
        case 'monthly'
            ok = ok && all(diff(12 * y + m) == 1);
        case 'quarterly'
            ok = ok && all(diff(quarter_index(d)) == 1);
        case 'annual'
            ok = ok && all(diff(y) == 1) && all(m == 1);
        case 'daily'
            ok = ok && all(diff(d) <= 7);  % business days with holidays
    end
    if ~isempty(raw(i).gaps)
        msg = sprintf('%s, permitted gaps: %s', msg, strjoin(raw(i).gaps, ' '));
    end
    results = add(results, sprintf('raw %s regular dates', raw(i).name), ok, msg);
end

% ---- 2. Output grid ----
q = quarter_index(data.date);
ok = all(diff(q) == 1) && numel(unique(q)) == numel(q);
results = add(results, 'grid consecutive quarters', ok, sprintf('%s to %s, %d quarters', ...
    data.date{1}, data.date{end}, numel(q)));
ok = isequal(data.year, floor(q / 4)) && isequal(data.quarter, mod(q, 4) + 1);
results = add(results, 'grid year/quarter columns', ok, 'match the date label');
ok = isequal(csv.date, data.date) && numel(fieldnames(csv)) == numel(fieldnames(data));
results = add(results, 'csv and mat agree', ok, sprintf('%d columns', numel(fieldnames(csv))));

% ---- 3. Index base ----
ib = find(strcmp(data.date, meta.index_base));
ok = ~isempty(ib) && abs(csv.popidx(ib) - 1) < 1e-12 && abs(csv.empidx(ib) - 100) < 1e-10;
results = add(results, 'index base', ok, sprintf('%s: popidx %.12f, empidx %.10f', ...
    meta.index_base, csv.popidx(ib), csv.empidx(ib)));

% ---- 4. Definitions recomputed from the CSV columns ----
tol = 1e-8;
chk = @(a, b) max([abs(a(~isnan(a) & ~isnan(b)) - b(~isnan(a) & ~isnan(b))); 0]);
switch p.country
    case 'US'
        defs = {'consumption', 100 * log((csv.PCEC ./ csv.GDPDEF) ./ csv.popidx); ...
            'investment', 100 * log((csv.FPI ./ csv.GDPDEF) ./ csv.popidx); ...
            'output', 100 * log(csv.GDPC1 ./ csv.popidx); ...
            'hours', 100 * log((csv.PRS85006023 .* csv.empidx / 100) ./ csv.popidx); ...
            'realwage', 100 * log(csv.COMPNFB ./ csv.GDPDEF)};
    case 'EA'
        defs = {'consumption', 100 * log((csv.CONS ./ csv.GDPDEF) ./ csv.popidx); ...
            'investment', 100 * log((csv.INV ./ csv.GDPDEF) ./ csv.popidx); ...
            'output', 100 * log(csv.GDP ./ csv.popidx); ...
            'hours', 100 * log(csv.HOURS ./ csv.popidx); ...
            'COMP', 1000 * csv.WAGES ./ csv.HOURS_EMPLOYEES; ...
            'realwage', 100 * log(csv.COMP ./ csv.GDPDEF)};
    otherwise
        error('macrodata:tests', 'No definition checks for country %s.', p.country);
end
defs = [defs; {'dc', [NaN; diff(csv.consumption)]; 'dinve', [NaN; diff(csv.investment)]; ...
    'dy', [NaN; diff(csv.output)]; 'dw', [NaN; diff(csv.realwage)]; ...
    'pinfobs', [NaN; 100 * diff(log(csv.GDPDEF))]; ...
    'labobs', csv.hours - meta.hours_mean}];
for k = 1:size(defs, 1)
    e = chk(csv.(defs{k, 1}), defs{k, 2});
    ok = e < tol && sum(~isnan(csv.(defs{k, 1}))) == sum(~isnan(defs{k, 2}));
    results = add(results, sprintf('definition %s', defs{k, 1}), ok, sprintf('max abs error %.2e', e));
end
% robs: policy rate or shadow rate divided by 4, by quarter.
rate = rate_column(csv, meta, meta.rate_series);
if meta.shadow_rate_used
    sh = rate_column(csv, meta, 'SHADOWRATE');
    use = strcmp(meta.robs_source, 'SHADOWRATE');
    rate(use) = sh(use);
end
e = chk(csv.robs, rate / 4);
results = add(results, 'definition robs', e < tol, sprintf('max abs error %.2e (%s)', e, meta.definitions.robs));
if isfield(csv, 'EBP')
    e = chk(csv.ebpobs, rate_column(csv, meta, 'EBP'));
    results = add(results, 'definition ebpobs', e < tol, sprintf('max abs error %.2e', e));
else
    results = add(results, 'definition ebpobs', all(isnan(csv.ebpobs)), 'no EBP series: all missing');
end
% Hours mean recorded in the metadata equals the mean over the recorded range.
rng = regexp(meta.hours_mean_range_used, '(\d{4}Q\d) to (\d{4}Q\d)', 'tokens');
r1 = find(strcmp(data.date, rng{1}{1}));
r2 = find(strcmp(data.date, rng{1}{2}));
h = csv.hours(r1:r2);
e = abs(mean(h(~isnan(h))) - meta.hours_mean);
results = add(results, 'hours mean matches metadata', e < 1e-9, ...
    sprintf('%s, mean %.4f, %d quarters', meta.hours_mean_range_used, meta.hours_mean, meta.hours_mean_n));

% ---- 5. Population ----
g_idx = 100 * diff(log(csv.popidx));
switch p.country
    case 'US'
        i2000 = find(strcmp(data.date, '2000Q1'));
        g_raw = 100 * log(csv.CNP16OV(i2000) / csv.CNP16OV(i2000 - 1));
        results = add(results, 'population controls 2000Q1', g_raw > 0.8 && abs(g_idx(i2000 - 1)) < 0.4, ...
            sprintf('raw population growth %.2f%%, smoothed index growth %.2f%%', g_raw, g_idx(i2000 - 1)));
    otherwise
        results = add(results, 'population index smooth', max(abs(g_idx)) < 1, ...
            sprintf('largest quarterly change of popidx %.3f%%', max(abs(g_idx))));
end

% ---- 6. Second source ----
if p.network
    switch p.country
        case 'US'
            codes = {'CE16OV', 'UNRATE', 'CNP16OV', 'FEDFUNDS'};
            for k = 1:numel(codes)
                c = codes{k};
                [fq, fx, dec] = fred_quarterly(c, 'avg');
                ours = csv.(c);
                [tf, loc] = ismember(quarter_index(csv.date), fq);
                both = tf & ~isnan(ours);
                d = abs(ours(both) - fx(loc(both)));
                tolr = 0.5 * 10 ^ (-dec) + 1e-9;
                results = add(results, sprintf('FRED quarterly average %s', c), max(d) <= tolr, ...
                    sprintf('%d quarters, max abs diff %.4g, tolerance %.4g (FRED rounds to %d decimals)', ...
                    sum(both), max(d), tolr, dec));
            end
            r = raw(strcmp({raw.name}, 'FEDFUNDS'));
            [lq, lx] = to_quarterly(r.dates, r.values, 'monthly', 'last');
            [fq, fx, dec] = fred_quarterly('FEDFUNDS', 'eop');
            [tf, loc] = ismember(lq, fq);
            d = abs(lx(tf) - fx(loc(tf)));
            results = add(results, 'FRED end-of-period FEDFUNDS', max(d) <= 0.5 * 10 ^ (-dec) + 1e-9, ...
                sprintf('%d quarters, max abs diff %.4g', sum(tf), max(d)));
        case 'EA'
            % The ECB publishes the quarterly Euribor as the average of daily
            % observations; the average of monthly averages differs slightly
            % because months have different numbers of trading days.
            [eq, ex] = ecb_series('FM.Q.U2.EUR.RT.MM.EURIBOR3MD_.HSTA', 'yyyyQq');
            ours = csv.EURIBOR3M;
            [tf, loc] = ismember(quarter_index(csv.date), eq);
            both = tf & ~isnan(ours);
            d = abs(ours(both) - ex(loc(both)));
            results = add(results, 'ECB quarterly Euribor', max(d) <= 0.05, ...
                sprintf('%d quarters, max abs diff %.4f, tolerance 0.05', sum(both), max(d)));
    end
end

% ---- 7. Reference dataset ----
if p.network && strcmp(p.country, 'US')
    sw = compare_with_smets_wouters_2007(data);
    g = @(v) sw(strcmp({sw.variable}, v));
    results = add(results, 'SW2007 robs', g('robs').max_abs_difference < 0.01, ...
        sprintf('max abs diff %.4f over %d quarters from %s', g('robs').max_abs_difference, g('robs').n, g('robs').first));
    results = add(results, 'SW2007 pinfobs', g('pinfobs').correlation > 0.95, ...
        sprintf('correlation %.3f, rms diff %.3f', g('pinfobs').correlation, g('pinfobs').rms_difference));
    % The real wage uses the compensation index, which has been revised the
    % most since 2005, so its threshold is lower.
    thresholds = struct('dy', 0.9, 'dc', 0.9, 'dinve', 0.9, 'dw', 0.7);
    for v = {'dy', 'dc', 'dinve', 'dw'}
        results = add(results, sprintf('SW2007 %s', v{1}), g(v{1}).correlation > thresholds.(v{1}), ...
            sprintf('correlation %.3f (threshold %.2f), rms diff %.3f (data revisions)', ...
            g(v{1}).correlation, thresholds.(v{1}), g(v{1}).rms_difference));
    end
    results = add(results, 'SW2007 labobs', g('labobs').correlation > 0.9, ...
        sprintf('correlation %.3f after demeaning both', g('labobs').correlation));
elseif p.network
    fprintf('INFO  no published reference dataset for %s\n', p.country);
end

% ---- Summary ----
n_fail = sum(~[results.passed]);
fprintf('\n%s: %d checks, %d failed.\n', p.country, numel(results), n_fail);
if n_fail > 0
    error('macrodata:tests', '%d check(s) failed.', n_fail);
end
end

% ---------------------------------------------------------------------------
function results = add(results, name, ok, msg)
if ok
    tag = 'PASS';
else
    tag = 'FAIL';
end
fprintf('%s  %-36s %s\n', tag, name, msg);
results(end + 1) = struct('name', name, 'passed', logical(ok), 'message', msg);
end

function x = rate_column(csv, meta, name)
alt = sprintf('%s_%s', name, meta.rate_aggregation);
if isfield(csv, alt)
    x = csv.(alt);
else
    x = csv.(name);
end
end

function [q, x, dec] = fred_quarterly(code, method)
% FRED's own quarterly aggregation of a monthly series (avg or eop).
url = sprintf('https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s&fq=Quarterly&fam=%s', code, method);
file = fullfile(tempdir, sprintf('fred_%s_q_%s.csv', code, method));
fetch_url(url, file);
[header, cells] = read_csv_cells(file);
vals = cells(:, strcmp(header, code));
dates = parse_dates(cells(:, 1), 'yyyy-mm-dd');
x = nan(numel(vals), 1);
dec = 0;
for i = 1:numel(vals)
    s = vals{i};
    if isempty(s) || strcmp(s, '.')
        continue
    end
    x(i) = str2double(s);
    dot = find(s == '.', 1);
    if ~isempty(dot)
        dec = max(dec, numel(s) - dot);
    end
end
q = quarter_index(dates);
keep = ~isnan(x);
q = q(keep);
x = x(keep);
end

function [q, x] = ecb_series(key, date_format)
% A quarterly series from the ECB Data Portal, as quarter indices and values.
dot = find(key == '.', 1);
url = sprintf('https://data-api.ecb.europa.eu/service/data/%s/%s?format=csvdata', key(1:dot - 1), key(dot + 1:end));
file = fullfile(tempdir, sprintf('ecb_%s.csv', strrep(key, '.', '_')));
fetch_url(url, file);
[header, cells] = read_csv_cells(file);
q = quarter_index(parse_dates(cells(:, strcmp(header, 'TIME_PERIOD')), date_format));
x = str2double(cells(:, strcmp(header, 'OBS_VALUE')));
keep = ~isnan(x);
q = q(keep);
x = x(keep);
end
