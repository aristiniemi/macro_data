function fetch_url(url, file)
% FETCH_URL  Download URL to FILE with base MATLAB (websave), or copy a local file.
%
%   fetch_url(url, file)
%
%   If URL is the path of an existing local file, it is copied instead of
%   downloaded. This lets the series list point at a file that was obtained
%   by other means (for example received by e-mail), while keeping the same
%   download log and checks. Downloads use websave in MATLAB and urlwrite in
%   GNU Octave, which has no websave. Any failure raises an error; nothing is
%   written on failure.

if exist(url, 'file') == 2
    [ok, msg] = copyfile(url, file);
    if ~ok
        error('macrodata:copy', 'Cannot copy %s to %s: %s', url, file, msg);
    end
    return
end

if exist('websave', 'file') == 2 || exist('websave', 'builtin') == 5
    options = weboptions('Timeout', 120);
    websave(file, url, options);
elseif exist('urlwrite', 'file') == 2 || exist('urlwrite', 'builtin') == 5
    [~, ok, msg] = urlwrite(url, file);
    if ~ok
        error('macrodata:download', 'Download of %s failed: %s', url, msg);
    end
else
    error('macrodata:download', 'Neither websave nor urlwrite is available.');
end

info = dir(file);
if isempty(info) || info.bytes == 0
    error('macrodata:download', 'Download of %s produced an empty file.', url);
end
end
