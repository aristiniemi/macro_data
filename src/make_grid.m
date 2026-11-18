function grid = make_grid(o, q_last)
% MAKE_GRID  Quarter indices of the output grid from the sample options.
%
%   grid = make_grid(o, q_last)
%
%   o.sample_start is a 'YYYYQn' string. o.sample_end is a 'YYYYQn' string or
%   'last', which means q_last (the last quarter of the reference series,
%   real GDP).

qstart = quarter_index(o.sample_start);
if strcmpi(o.sample_end, 'last')
    qend = q_last;
else
    qend = quarter_index(o.sample_end);
end
if qend < qstart
    error('macrodata:build', 'sample_end is before sample_start.');
end
grid = (qstart:qend)';
end
