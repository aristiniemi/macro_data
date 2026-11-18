% BUILD_DATASET  Download the raw series and build the quarterly dataset.
%
%   Run this script from MATLAB (or GNU Octave) in any folder:
%       run('path/to/macrodata/build_dataset.m')
%   Everything a user may want to change is an option below. Paths are
%   relative to the folder of this script unless given as absolute paths.
%
%   Output (in opts.output_folder):
%       <output_name>.csv            quarterly dataset, one column per variable
%       <output_name>.mat            the same as struct data, plus meta
%       <output_name>_metadata.json  options and derived numbers used
%       <output_name>_dashboard.html a page to look at the data (optional)
%   Raw downloads are kept in opts.raw_folder/<country> with a download log.

% ======================= options (edit here) ==============================
opts = struct();

% Country: 'US' or 'EA'. It selects the rows of series_list.csv and the
% build function build_<country>_quarterly.m. Options set to 'auto' take the
% country's default, stated in that function and recorded in the metadata:
%                      US          EA
%   sample_start       1947Q1      1995Q1
%   index_base         1992Q3      1999Q1
%   hours_mean_start   1964Q1      start (first observation)
%   population_series  CNP16OV     POP (annual, interpolated; alternative POP1574)
opts.country = 'US';

% Sample: first quarter and last quarter of the output grid. 'last' means
% the last quarter for which real GDP is published.
opts.sample_start = 'auto';
opts.sample_end = 'last';

% Base quarter of the population and employment indices.
opts.index_base = 'auto';

% Population used for per-capita variables: the series name from the list
% ('auto' = country default), and 'smoothed' (HP trend of log population
% with lambda below, which removes level jumps from new population controls)
% or 'raw' (quarterly series as published).
opts.population_series = 'auto';
opts.population = 'smoothed';
opts.hp_lambda = 1600;

% Range over which hours are demeaned for labobs. 'start' and 'last' mean
% the first and last available observation, so the mean moves when data are
% added; the range and the mean actually used are written to the metadata.
opts.hours_mean_start = 'auto';
opts.hours_mean_end = 'last';

% Interest rate, excess bond premium and shadow rate within the quarter:
% 'average' of the months (daily values for the shadow rate) or 'last' month.
opts.rate_aggregation = 'average';

% Replace the policy rate in robs by the shadow rate over this range
% ('YYYYQn' strings), for example '2008Q3' and '2022Q1' for the US. Leave
% both empty to use the policy rate throughout.
opts.shadow_rate_start = '';
opts.shadow_rate_end = '';

% Folders and file names. 'auto' names the output <country>_quarterly.
opts.raw_folder = 'data/raw';
opts.output_folder = 'data/output';
opts.output_name = 'auto';

% Set download to false to rebuild from the raw files of an earlier run.
opts.download = true;

% Build the HTML dashboard next to the output files.
opts.make_dashboard = true;
% ======================= end of options ===================================

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end
addpath(fullfile(here, 'src'));
addpath(fullfile(here, 'dashboard'));
opts.raw_folder = absolute_path(opts.raw_folder, here);
opts.output_folder = absolute_path(opts.output_folder, here);
if strcmpi(opts.output_name, 'auto')
    opts.output_name = sprintf('%s_quarterly', lower(opts.country));
end

list = read_series_list(fullfile(here, 'series_list.csv'), opts.country);
if opts.download
    raw = download_series(list, fullfile(opts.raw_folder, opts.country));
else
    raw = load_raw(fullfile(opts.raw_folder, opts.country), opts.country);
end

builder = str2func(sprintf('build_%s_quarterly', lower(opts.country)));
[data, meta] = builder(raw, opts);
write_dataset(data, meta, opts.output_folder, opts.output_name);

if opts.make_dashboard
    make_dashboard(opts.output_folder, opts.output_name, fullfile(opts.raw_folder, opts.country));
end

function p = absolute_path(p, base)
if isempty(p)
    p = base;
elseif ~(p(1) == '/' || p(1) == '\' || (numel(p) > 1 && p(2) == ':'))
    p = fullfile(base, p);
end
end
