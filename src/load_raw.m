function raw = load_raw(raw_folder, country)
% LOAD_RAW  Load previously downloaded raw series saved by download_series.
%
%   raw = load_raw(raw_folder, country)
file = fullfile(raw_folder, sprintf('raw_%s.mat', country));
if ~exist(file, 'file')
    error('macrodata:noRaw', 'No raw data file %s. Run with opts.download = true first.', file);
end
s = load(file);
raw = s.raw;
fprintf('Loaded %d raw series from %s (downloaded %s)\n', numel(raw), file, raw(1).downloaded);
end
