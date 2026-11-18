function [header, cells] = read_csv_cells(file)
% READ_CSV_CELLS  Read a comma-separated text file into cell arrays of strings.
%
%   [header, cells] = read_csv_cells(file)
%
%   header is a 1-by-K cell array with the column names from the first line.
%   cells is an N-by-K cell array of strings, one row per data line. Fields
%   enclosed in double quotes may contain commas and doubled quotes ("").
%   Empty lines are skipped. Rows with a different number of fields than the
%   header raise an error, so that a damaged download is never read partially.
%
%   Uses only base MATLAB (also runs in GNU Octave).

text = fileread(file);
% Remove a UTF-8 byte order mark if present.
if numel(text) >= 3 && all(double(text(1:3)) == [239 187 191])
    text = text(4:end);
end
text = strrep(text, sprintf('\r\n'), sprintf('\n'));
text = strrep(text, sprintf('\r'), sprintf('\n'));
lines = strsplit(text, sprintf('\n'));
lines = lines(~cellfun(@(s) isempty(strtrim(s)), lines));
if isempty(lines)
    error('macrodata:emptyFile', 'File %s is empty.', file);
end

header = split_csv_line(lines{1});
K = numel(header);
N = numel(lines) - 1;
cells = cell(N, K);
for i = 1:N
    fields = split_csv_line(lines{i + 1});
    if numel(fields) ~= K
        error('macrodata:badCsvRow', ...
            'Line %d of %s has %d fields, header has %d.', i + 1, file, numel(fields), K);
    end
    cells(i, :) = fields;
end
end

function fields = split_csv_line(line)
% Split one CSV line into fields, honouring double quotes.
fields = {};
field = '';
inquotes = false;
i = 1;
n = numel(line);
while i <= n
    c = line(i);
    if inquotes
        if c == '"'
            if i < n && line(i + 1) == '"'
                field(end + 1) = '"'; %#ok<AGROW>
                i = i + 1;
            else
                inquotes = false;
            end
        else
            field(end + 1) = c; %#ok<AGROW>
        end
    else
        if c == '"'
            inquotes = true;
        elseif c == ','
            fields{end + 1} = strtrim(field); %#ok<AGROW>
            field = '';
        else
            field(end + 1) = c; %#ok<AGROW>
        end
    end
    i = i + 1;
end
fields{end + 1} = strtrim(field);
end
