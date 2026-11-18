function [data, meta] = sw_finish(S, o)
% SW_FINISH  Model variables, output struct and metadata from the levels.
%
%   [data, meta] = sw_finish(S, o)
%
%   Shared by the country build functions. S holds, all on the output grid:
%     country, grid
%     consumption, investment, output, hours, realwage   levels (100 x log)
%     popidx, empidx, population
%     deflator           price index used for pinfobs
%     rate, rate_name    interest rate in percent per year and its series name
%     shadow             shadow rate on the grid, or [] if not available
%     ebp, ebp_name      excess bond premium on the grid, or [] if none
%     Q, R, raw          quarterly aggregates (list rule and rate option) and
%                        the raw series, for the raw columns of the output
%     definitions        struct with the text definitions of the levels
%     pop_gaps_bridged   from population_index
%   o is the resolved option struct (see resolve_options).
%
%   Model variables:
%     dc, dinve, dy, dw  change from the previous quarter of consumption,
%                        investment, output and the real wage
%     pinfobs            100 * (log deflator - log deflator of the previous quarter)
%     labobs             hours minus their mean over o.hours_mean_start to
%                        o.hours_mean_end ('start' and 'last' mean the first
%                        and last available observation)
%     robs               rate / 4, with the shadow rate in place of the rate
%                        from o.shadow_rate_start to o.shadow_rate_end
%     ebpobs             excess bond premium; all missing when there is none

grid = S.grid;
T = numel(grid);

dc = lag_diff(S.consumption);
dinve = lag_diff(S.investment);
dy = lag_diff(S.output);
dw = lag_diff(S.realwage);
pinfobs = 100 * lag_diff(log(S.deflator));

% Hours demeaned over the chosen range.
avail = find(~isnan(S.hours));
if isempty(avail)
    error('macrodata:build', 'Hours have no observations on the grid.');
end
if strcmpi(o.hours_mean_start, 'start')
    m_start = grid(avail(1));
else
    m_start = quarter_index(o.hours_mean_start);
end
if strcmpi(o.hours_mean_end, 'last')
    m_end = grid(avail(end));
else
    m_end = quarter_index(o.hours_mean_end);
end
in_range = grid >= m_start & grid <= m_end & ~isnan(S.hours);
if ~any(in_range)
    error('macrodata:build', 'No hours observations in the demeaning range.');
end
hours_mean = mean(S.hours(in_range));
used = grid(in_range);
labobs = S.hours - hours_mean;

% Interest rate, optionally replaced by the shadow rate.
rate = S.rate;
rate_source = repmat({S.rate_name}, T, 1);
shadow_used = false;
if ~isempty(o.shadow_rate_start) || ~isempty(o.shadow_rate_end)
    if isempty(o.shadow_rate_start) || isempty(o.shadow_rate_end)
        error('macrodata:build', 'Set both shadow_rate_start and shadow_rate_end, or neither.');
    end
    if isempty(S.shadow)
        error('macrodata:build', 'A shadow rate range is set but the series SHADOWRATE was not downloaded.');
    end
    idx = grid >= quarter_index(o.shadow_rate_start) & grid <= quarter_index(o.shadow_rate_end);
    if any(isnan(S.shadow(idx)))
        first_nan = grid(idx & isnan(S.shadow));
        error('macrodata:build', 'The shadow rate is missing in %s, inside the replacement range.', ...
            qlabel(first_nan(1)));
    end
    rate(idx) = S.shadow(idx);
    rate_source(idx) = {'SHADOWRATE'};
    shadow_used = true;
end
robs = rate / 4;

if isempty(S.ebp)
    fprintf('No excess bond premium series for %s: ebpobs is all missing\n', S.country);
    ebpobs = nan(T, 1);
else
    ebpobs = S.ebp;
end

% ---- Output ----
data = struct();
data.date = quarter_string(grid);
data.year = floor(grid / 4);
data.quarter = mod(grid, 4) + 1;
data.dc = dc;
data.dinve = dinve;
data.dy = dy;
data.dw = dw;
data.pinfobs = pinfobs;
data.labobs = labobs;
data.robs = robs;
data.ebpobs = ebpobs;
data.consumption = S.consumption;
data.investment = S.investment;
data.output = S.output;
data.hours = S.hours;
data.realwage = S.realwage;
data.popidx = S.popidx;
data.empidx = S.empidx;
data.population = S.population;
levels = {'consumption', 'investment', 'output', 'hours', 'realwage', 'popidx', 'empidx', 'population'};
if isfield(S, 'extra_levels')
    extra = fieldnames(S.extra_levels);
    for k = 1:numel(extra)
        data.(extra{k}) = S.extra_levels.(extra{k});
        levels{end + 1} = extra{k}; %#ok<AGROW>
    end
end
raw_columns = {};
for i = 1:numel(S.raw)
    c = S.raw(i).name;
    data.(c) = place_on_grid(S.Q.(c), grid);
    raw_columns{end + 1} = c; %#ok<AGROW>
    if isfield(S.R, c) && ~strcmp(S.raw(i).aggregation, o.rate_aggregation)
        alt = sprintf('%s_%s', c, o.rate_aggregation);
        data.(alt) = place_on_grid(S.R.(c), grid);
        raw_columns{end + 1} = alt; %#ok<AGROW>
    end
end

% ---- Metadata ----
meta = struct();
meta.country = S.country;
meta.built = datestr(now, 'yyyy-mm-dd HH:MM:SS');
meta.sample_start = qlabel(grid(1));
meta.sample_end = qlabel(grid(end));
meta.sample_end_option = o.sample_end;
meta.index_base = o.index_base;
meta.population = lower(o.population);
meta.population_series = S.population_name;
meta.hp_lambda = o.hp_lambda;
meta.population_gaps_bridged_for_hp = S.pop_gaps_bridged;
meta.hours_mean_start_option = o.hours_mean_start;
meta.hours_mean_end_option = o.hours_mean_end;
meta.hours_mean_range_used = sprintf('%s to %s', qlabel(used(1)), qlabel(used(end)));
meta.hours_mean_n = numel(used);
meta.hours_mean = hours_mean;
meta.rate_series = S.rate_name;
meta.rate_aggregation = o.rate_aggregation;
meta.shadow_rate_used = shadow_used;
meta.shadow_rate_start = o.shadow_rate_start;
meta.shadow_rate_end = o.shadow_rate_end;
meta.robs_source = rate_source;
meta.options_resolved_from_auto = o.auto_resolved;
meta.model_variables = {'dc', 'dinve', 'dy', 'dw', 'pinfobs', 'labobs', 'robs', 'ebpobs'};
meta.levels = levels;
meta.raw_columns = raw_columns;

def = S.definitions;
def.dc = 'consumption minus its value in the previous quarter';
def.dinve = 'investment minus its value in the previous quarter';
def.dy = 'output minus its value in the previous quarter';
def.dw = 'realwage minus its value in the previous quarter';
def.pinfobs = sprintf('100 * (log(%s) - log(%s of the previous quarter))', S.deflator_name, S.deflator_name);
def.labobs = sprintf('hours minus their mean over %s to %s', o.hours_mean_start, o.hours_mean_end);
if shadow_used
    def.robs = sprintf('%s (%s of the quarter) / 4, replaced by SHADOWRATE / 4 from %s to %s', ...
        S.rate_name, rate_text(o), o.shadow_rate_start, o.shadow_rate_end);
else
    def.robs = sprintf('%s (%s of the quarter) / 4', S.rate_name, rate_text(o));
end
if isempty(S.ebp)
    def.ebpobs = 'no excess bond premium series for this country; all missing';
else
    def.ebpobs = sprintf('%s, %s of the quarter', S.ebp_name, rate_text(o));
end
meta.definitions = def;

meta.series = struct('name', {S.raw.name}, 'code', {S.raw.code}, 'description', {S.raw.description}, ...
    'units', {S.raw.units}, 'source', {S.raw.source}, 'url', {S.raw.url}, ...
    'native_frequency', {S.raw.frequency}, 'quarterly_aggregation', {S.raw.aggregation}, ...
    'downloaded', {S.raw.downloaded}, 'citation', {S.raw.citation});
for i = 1:numel(S.raw)
    meta.series(i).first_observation = datestr(S.raw(i).dates(1), 'yyyy-mm-dd');
    meta.series(i).last_observation = datestr(S.raw(i).dates(end), 'yyyy-mm-dd');
    meta.series(i).n_observations = sum(~isnan(S.raw(i).values));
    meta.series(i).gaps = S.raw(i).gaps;
end
end

% ---------------------------------------------------------------------------
function d = lag_diff(x)
d = [NaN; x(2:end) - x(1:end - 1)];
end

function s = qlabel(q)
c = quarter_string(q);
s = c{1};
end

function s = rate_text(o)
if strcmp(o.rate_aggregation, 'average')
    s = 'average of the months';
else
    s = 'last month';
end
end
