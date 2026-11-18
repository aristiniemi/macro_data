function results = compare_with_smets_wouters_2007(data, varargin)
% COMPARE_WITH_SMETS_WOUTERS_2007  Compare the dataset with the original SW (2007) data.
%
%   results = compare_with_smets_wouters_2007(data)
%   results = compare_with_smets_wouters_2007(data, 'file', 'usmodel_data.mat')
%   results = compare_with_smets_wouters_2007(data, 'url', '<address of usmodel_data.mat>')
%
%   data is the struct from build_us_quarterly (or loaded from <name>.mat).
%   The reference is the file usmodel_data.mat distributed with Smets and
%   Wouters (2007), "Shocks and Frictions in US Business Cycles", American
%   Economic Review 97(3). It holds dc, dinve, dy, dw, pinfobs, labobs and
%   robs for 1947Q3 to 2004Q4 (230 quarters). By default it is downloaded to
%   the temporary folder from the copy in Johannes Pfeifer's DSGE_mod
%   repository (GitHub), so that nothing is stored in this repository.
%
%   For each variable the function reports, on the quarters where both
%   series exist: the number of quarters, the correlation, the mean
%   difference, the root mean square difference and the largest absolute
%   difference (ours minus SW). labobs is compared after removing each
%   series' mean over the common sample, because SW demeaned hours over their
%   own sample. Differences in the growth rates and inflation come from data
%   revisions since 2005 (new base years of the chain-weighted accounts, and
%   benchmark revisions); robs should agree to the rounding of the federal
%   funds rate from 1954Q3 on, when the series starts (SW used another short
%   rate before). The results are returned as a struct array and printed.

p = struct('file', '', ...
    'url', 'https://raw.githubusercontent.com/JohannesPfeifer/DSGE_mod/master/Smets_Wouters_2007/usmodel_data.mat', ...
    'quiet', false);
for k = 1:2:numel(varargin)
    p.(varargin{k}) = varargin{k + 1};
end

if isempty(p.file)
    p.file = fullfile(tempdir, 'usmodel_data_sw2007.mat');
    if ~exist(p.file, 'file')
        fprintf('Downloading the Smets-Wouters (2007) data to %s\n', p.file);
        fetch_url(p.url, p.file);
    end
end
sw = load(p.file);
needed = {'dc', 'dinve', 'dy', 'dw', 'pinfobs', 'labobs', 'robs'};
for k = 1:numel(needed)
    if ~isfield(sw, needed{k})
        error('macrodata:sw2007', 'Reference file lacks %s.', needed{k});
    end
end
n_sw = numel(sw.dy);
if n_sw ~= 230
    warning('macrodata:sw2007', 'Reference has %d quarters; 230 (1947Q3 to 2004Q4) expected.', n_sw);
end
sw_q = (quarter_index(1947, 3) + (0:n_sw - 1))';
our_q = quarter_index(data.date);

[tf, loc] = ismember(sw_q, our_q);
results = struct('variable', {}, 'n', {}, 'first', {}, 'last', {}, 'correlation', {}, ...
    'mean_difference', {}, 'rms_difference', {}, 'max_abs_difference', {}, 'note', {});
for k = 1:numel(needed)
    v = needed{k};
    ref = sw.(v)(:);
    ours = nan(n_sw, 1);
    ours(tf) = data.(v)(loc(tf));
    note = '';
    if strcmp(v, 'robs')
        % The federal funds rate starts in 1954Q3; SW used another rate before.
        ok = sw_q >= quarter_index(1954, 3);
        ours(~ok) = NaN;
        note = 'from 1954Q3, start of the federal funds rate';
    end
    both = ~isnan(ours) & ~isnan(ref);
    a = ours(both);
    b = ref(both);
    if strcmp(v, 'labobs')
        a = a - mean(a);
        b = b - mean(b);
        note = 'both demeaned over the common sample';
    end
    d = a - b;
    r = struct('variable', v, 'n', numel(d), ...
        'first', qlabel(sw_q(find(both, 1, 'first'))), 'last', qlabel(sw_q(find(both, 1, 'last'))), ...
        'correlation', corr_(a, b), 'mean_difference', mean(d), ...
        'rms_difference', sqrt(mean(d .^ 2)), 'max_abs_difference', max(abs(d)), 'note', note);
    results(end + 1) = r; %#ok<AGROW>
end

if ~p.quiet
    fprintf('\nComparison with Smets and Wouters (2007), ours minus SW:\n');
    fprintf('%-8s %4s  %-7s %-7s %6s %9s %9s %9s  %s\n', 'variable', 'n', 'first', 'last', 'corr', 'mean', 'rms', 'max abs', 'note');
    for k = 1:numel(results)
        r = results(k);
        fprintf('%-8s %4d  %-7s %-7s %6.3f %9.4f %9.4f %9.4f  %s\n', r.variable, r.n, r.first, r.last, ...
            r.correlation, r.mean_difference, r.rms_difference, r.max_abs_difference, r.note);
    end
    fprintf('\n');
end
end

function c = corr_(a, b)
a = a - mean(a);
b = b - mean(b);
c = (a' * b) / sqrt((a' * a) * (b' * b));
end

function s = qlabel(q)
c = quarter_string(q);
s = c{1};
end
