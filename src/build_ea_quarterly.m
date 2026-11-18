function [data, meta] = build_ea_quarterly(raw, opts)
% BUILD_EA_QUARTERLY  Quarterly euro-area dataset in the Smets and Wouters (2007) form.
%
%   [data, meta] = build_ea_quarterly(raw, opts)
%
%   raw is the struct array from download_series or load_raw. opts holds the
%   options set in the preamble of build_dataset.m; the values 'auto' are
%   replaced by the euro-area defaults: sample_start 1995Q1 (start of the
%   quarterly national accounts in the ECB Data Portal), index_base 1999Q1
%   (start of the euro), hours_mean_start 'start' (first observation),
%   population_series POP (annual total population interpolated to quarters;
%   the alternative POP1574 is the quarterly population aged 15 to 74 from
%   the Labour Force Survey, available from 2009).
%
%   The construction follows the US one, series for series:
%     popidx       population / population(index_base), smoothed by default
%     empidx       100 * EMP / EMP(index_base)
%     consumption  100 * log((CONS / GDPDEF) / popidx)
%     investment   100 * log((INV / GDPDEF) / popidx)
%     output       100 * log(GDP / popidx)
%     hours        100 * log(HOURS / popidx)
%                  HOURS is total hours worked in the whole economy, so no
%                  scaling by employment is needed (the US hours index covers
%                  the non-farm business sector only and is scaled by
%                  civilian employment)
%     COMP         WAGES / HOURS_EMPLOYEES, wages and salaries per hour
%                  worked by employees, in euro per hour (the counterpart of
%                  the US compensation per hour)
%     realwage     100 * log(COMP / GDPDEF)
%   robs uses the 3-month Euribor (EURIBOR3M). There is no excess bond
%   premium series for the euro area in the ECB Data Portal, so ebpobs is
%   all missing unless a series named EBP is added to the list.

o = resolve_options(opts, struct('sample_start', '1995Q1', 'index_base', '1999Q1', ...
    'hours_mean_start', 'start', 'population_series', 'POP'));

names = {raw.name};
needed = {'GDP', 'GDPDEF', 'CONS', 'INV', 'EMP', 'EURIBOR3M', o.population_series, ...
    'HOURS', 'HOURS_EMPLOYEES', 'WAGES'};
missing = setdiff(needed, names);
if ~isempty(missing)
    error('macrodata:build', 'Raw data lack series: %s', strjoin(missing, ', '));
end

Q = aggregate_raw(raw);
R = rate_group(raw, Q, o.rate_aggregation, {'EURIBOR3M', 'EBP', 'SHADOWRATE'});
grid = make_grid(o, Q.GDP.q(end));
on = @(name) place_on_grid(Q.(name), grid);

[popidx, population, pop_gaps] = population_index(Q.(o.population_series), o, grid);
jbase = find(Q.EMP.q == quarter_index(o.index_base));
if isempty(jbase)
    error('macrodata:build', 'Index base %s is outside the employment sample.', o.index_base);
end
empidx = place_on_grid(struct('q', Q.EMP.q, 'x', 100 * Q.EMP.x / Q.EMP.x(jbase)), grid);

GDPDEF = on('GDPDEF');
% Wages and salaries are in millions of euro, hours in thousands: the ratio
% times 1000 is euro per hour.
COMP = 1000 * on('WAGES') ./ on('HOURS_EMPLOYEES');

S = struct();
S.country = 'EA';
S.grid = grid;
S.popidx = popidx;
S.empidx = empidx;
S.population = population;
S.population_name = o.population_series;
S.pop_gaps_bridged = pop_gaps;
S.consumption = 100 * log((on('CONS') ./ GDPDEF) ./ popidx);
S.investment = 100 * log((on('INV') ./ GDPDEF) ./ popidx);
S.output = 100 * log(on('GDP') ./ popidx);
S.hours = 100 * log(on('HOURS') ./ popidx);
S.realwage = 100 * log(COMP ./ GDPDEF);
S.extra_levels = struct('COMP', COMP);
S.deflator = GDPDEF;
S.deflator_name = 'GDPDEF';
S.rate = place_on_grid(R.EURIBOR3M, grid);
S.rate_name = 'EURIBOR3M';
if isfield(R, 'SHADOWRATE')
    S.shadow = place_on_grid(R.SHADOWRATE, grid);
else
    S.shadow = [];
end
if isfield(R, 'EBP')
    S.ebp = place_on_grid(R.EBP, grid);
    S.ebp_name = 'EBP';
else
    S.ebp = [];
    S.ebp_name = '';
end
S.Q = Q;
S.R = R;
S.raw = raw;

def = struct();
def.popidx = sprintf('population / population(%s); population is %s%s', ...
    o.index_base, population_text(o), smoothing_text(o));
def.empidx = sprintf('100 * EMP / EMP(%s)', o.index_base);
def.consumption = '100 * log((CONS / GDPDEF) / popidx)';
def.investment = '100 * log((INV / GDPDEF) / popidx)';
def.output = '100 * log(GDP / popidx)';
def.hours = '100 * log(HOURS / popidx)';
def.COMP = '1000 * WAGES / HOURS_EMPLOYEES, euro per hour worked by employees';
def.realwage = '100 * log(COMP / GDPDEF)';
def.population = sprintf('%s%s', population_text(o), smoothing_text(o));
S.definitions = def;

[data, meta] = sw_finish(S, o);
end

function s = population_text(o)
if strcmp(o.population_series, 'POP')
    s = 'POP, annual total population interpolated to quarters (mid-year values, straight lines between them)';
else
    s = sprintf('%s as published', o.population_series);
end
end

function s = smoothing_text(o)
if strcmpi(o.population, 'smoothed')
    s = sprintf(', then exp(HP trend of log population, lambda %g)', o.hp_lambda);
else
    s = ', not smoothed';
end
end
