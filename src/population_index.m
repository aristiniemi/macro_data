function [popidx, population, gaps_bridged] = population_index(P, o, grid)
% POPULATION_INDEX  Population index on the output grid, smoothed or raw.
%
%   [popidx, population, gaps_bridged] = population_index(P, o, grid)
%
%   P has fields q and x: the quarterly population series. With
%   o.population = 'smoothed', the population used is exp(HP trend of log
%   population) with o.hp_lambda, computed over the whole available series;
%   with 'raw' it is the series as it is. popidx is population divided by its
%   value in o.index_base.
%
%   The HP filter needs a complete series. A quarter in which the population
%   is missing (for example 2025Q4 in the US, when the October 2025 household
%   survey was not collected) is bridged, for the filter input only, by linear
%   interpolation of log population between the neighbouring quarters. This
%   is printed and returned in gaps_bridged; the raw population column of
%   the output keeps the quarter missing.

gaps_bridged = {};
switch lower(o.population)
    case 'smoothed'
        logpop = log(P.x);
        gap = isnan(logpop);
        if any(gap)
            gaps_bridged = quarter_string(P.q(gap))';
            fprintf('Population missing in %s: bridged by linear interpolation of log population for the HP trend only\n', ...
                strjoin(gaps_bridged, ', '));
            logpop(gap) = interp1(find(~gap), logpop(~gap), find(gap), 'linear');
        end
        used = exp(hp_filter(logpop, o.hp_lambda));
    case 'raw'
        used = P.x;
    otherwise
        error('macrodata:build', 'opts.population must be "smoothed" or "raw".');
end
ibase = find(P.q == quarter_index(o.index_base));
if isempty(ibase) || isnan(used(ibase))
    error('macrodata:build', 'Index base %s is outside the population sample.', o.index_base);
end
popidx = place_on_grid(struct('q', P.q, 'x', used / used(ibase)), grid);
population = place_on_grid(struct('q', P.q, 'x', used), grid);
end
