function o = resolve_options(opts, defaults)
% RESOLVE_OPTIONS  Replace 'auto' options by the country defaults of a build function.
%
%   o = resolve_options(opts, defaults)
%
%   Every field of opts whose value is the string 'auto' is replaced by the
%   value of the same field in defaults. Fields of defaults that opts lacks
%   are added. The result also records, in o.auto_resolved, which fields
%   were filled in this way, so that the metadata can show it.

o = opts;
o.auto_resolved = {};
names = fieldnames(defaults);
for k = 1:numel(names)
    f = names{k};
    if ~isfield(o, f) || (ischar(o.(f)) && strcmpi(o.(f), 'auto'))
        o.(f) = defaults.(f);
        o.auto_resolved{end + 1} = f;
    end
end
end
