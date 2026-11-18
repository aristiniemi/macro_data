function [data, meta] = build_us_quarterly(raw, opts)
% BUILD_US_QUARTERLY  Quarterly US dataset in the Smets and Wouters (2007) form.
%
%   [data, meta] = build_us_quarterly(raw, opts)
%
%   raw is the struct array from download_series or load_raw. opts holds the
%   options set in the preamble of build_dataset.m; the values 'auto' are
%   replaced by the US defaults: sample_start 1947Q1, index_base 1992Q3,
%   hours_mean_start 1964Q1, population_series CNP16OV.
%
%   Every series is aggregated to quarters with its own rule and placed on
%   the output grid by quarter, never by position. Quarters at which a series
%   is not available are missing (NaN), not filled.
%
%   Levels, with popidx and empidx the population and employment indices:
%     consumption  100 * log((PCEC / GDPDEF) / popidx)
%     investment   100 * log((FPI / GDPDEF) / popidx)
%     output       100 * log(GDPC1 / popidx)
%     hours        100 * log((PRS85006023 * empidx / 100) / popidx)
%                  (the hours index covers the non-farm business sector; it is
%                  scaled by civilian employment as in Smets and Wouters)
%     realwage     100 * log(COMPNFB / GDPDEF)
%   The model variables, the output struct and the metadata are made by
%   sw_finish, shared with the other countries.

o = resolve_options(opts, struct('sample_start', '1947Q1', 'index_base', '1992Q3', ...
    'hours_mean_start', '1964Q1', 'population_series', 'CNP16OV'));

names = {raw.name};
needed = {'GDPC1', 'GDPDEF', 'PCEC', 'FPI', 'CE16OV', 'UNRATE', 'FEDFUNDS', ...
    o.population_series, 'PRS85006023', 'COMPNFB', 'EBP'};
missing = setdiff(needed, names);
if ~isempty(missing)
    error('macrodata:build', 'Raw data lack series: %s', strjoin(missing, ', '));
end

Q = aggregate_raw(raw);
R = rate_group(raw, Q, o.rate_aggregation, {'FEDFUNDS', 'EBP', 'SHADOWRATE'});
grid = make_grid(o, Q.GDPC1.q(end));
on = @(name) place_on_grid(Q.(name), grid);

[popidx, population, pop_gaps] = population_index(Q.(o.population_series), o, grid);
jbase = find(Q.CE16OV.q == quarter_index(o.index_base));
if isempty(jbase)
    error('macrodata:build', 'Index base %s is outside the employment sample.', o.index_base);
end
empidx = place_on_grid(struct('q', Q.CE16OV.q, 'x', 100 * Q.CE16OV.x / Q.CE16OV.x(jbase)), grid);

GDPDEF = on('GDPDEF');
S = struct();
S.country = 'US';
S.grid = grid;
S.popidx = popidx;
S.empidx = empidx;
S.population = population;
S.population_name = o.population_series;
S.pop_gaps_bridged = pop_gaps;
S.consumption = 100 * log((on('PCEC') ./ GDPDEF) ./ popidx);
S.investment = 100 * log((on('FPI') ./ GDPDEF) ./ popidx);
S.output = 100 * log(on('GDPC1') ./ popidx);
S.hours = 100 * log((on('PRS85006023') .* empidx / 100) ./ popidx);
S.realwage = 100 * log(on('COMPNFB') ./ GDPDEF);
S.deflator = GDPDEF;
S.deflator_name = 'GDPDEF';
S.rate = place_on_grid(R.FEDFUNDS, grid);
S.rate_name = 'FEDFUNDS';
if isfield(R, 'SHADOWRATE')
    S.shadow = place_on_grid(R.SHADOWRATE, grid);
else
    S.shadow = [];
end
S.ebp = place_on_grid(R.EBP, grid);
S.ebp_name = 'EBP';
S.Q = Q;
S.R = R;
S.raw = raw;

def = struct();
def.popidx = sprintf('population / population(%s); population is %s averaged over the quarter%s', ...
    o.index_base, o.population_series, smoothing_text(o));
def.empidx = sprintf('100 * CE16OV / CE16OV(%s), CE16OV averaged over the quarter', o.index_base);
def.consumption = '100 * log((PCEC / GDPDEF) / popidx)';
def.investment = '100 * log((FPI / GDPDEF) / popidx)';
def.output = '100 * log(GDPC1 / popidx)';
def.hours = '100 * log((PRS85006023 * empidx / 100) / popidx)';
def.realwage = '100 * log(COMPNFB / GDPDEF)';
def.population = sprintf('%s averaged over the quarter%s', o.population_series, smoothing_text(o));
S.definitions = def;

[data, meta] = sw_finish(S, o);
end

function s = smoothing_text(o)
if strcmpi(o.population, 'smoothed')
    s = sprintf(', then exp(HP trend of log population, lambda %g)', o.hp_lambda);
else
    s = ', not smoothed';
end
end
