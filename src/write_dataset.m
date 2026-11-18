function write_dataset(data, meta, output_folder, name)
% WRITE_DATASET  Write the quarterly dataset as CSV, .mat and a metadata file.
%
%   write_dataset(data, meta, output_folder, name)
%
%   data is a struct with the fields date (cell array of 'YYYYQn'), year,
%   quarter, and one numeric column vector per variable. meta is a struct
%   with the options and derived quantities (see build_us_quarterly).
%   Files written:
%     <name>.csv            one row per quarter, one column per variable,
%                           missing values empty
%     <name>.mat            variables data and meta
%     <name>_metadata.json  meta as JSON

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end
names = fieldnames(data);
T = numel(data.date);

csvfile = fullfile(output_folder, [name '.csv']);
fid = fopen(csvfile, 'w');
if fid < 0
    error('macrodata:write', 'Cannot write %s.', csvfile);
end
fprintf(fid, '%s\n', strjoin(names', ','));
for t = 1:T
    row = cell(1, numel(names));
    for k = 1:numel(names)
        v = data.(names{k});
        if iscell(v)
            row{k} = v{t};
        elseif isnan(v(t))
            row{k} = '';
        elseif v(t) == round(v(t)) && abs(v(t)) < 1e15
            row{k} = sprintf('%d', round(v(t)));
        else
            row{k} = sprintf('%.12g', v(t));
        end
    end
    fprintf(fid, '%s\n', strjoin(row, ','));
end
fclose(fid);

save(fullfile(output_folder, [name '.mat']), '-v7', 'data', 'meta');

jsonfile = fullfile(output_folder, [name '_metadata.json']);
try
    txt = jsonencode(meta, 'PrettyPrint', true);
catch
    txt = jsonencode(meta);
end
fid = fopen(jsonfile, 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);

fprintf('Wrote %s (%d quarters, %d columns), %s.mat and %s\n', csvfile, T, numel(names), ...
    fullfile(output_folder, name), jsonfile);
end
