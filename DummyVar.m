function D = DummyVar(group, varargin)
%DUMMYVAR Dummy variable coding with unique-level handling.
%   X = DUMMYVAR(GROUP) returns a matrix X of 0/1 dummies for GROUP, using
%   only the levels that actually appear in GROUP.
%   - Numeric data: levels are sorted ascending by value.
%   - Text/categorical: levels are sorted lexicographically.
%
%   X = DUMMYVAR(GROUP, ColumnSkip) removes the ColumnSkip-th dummy column,
%   where ColumnSkip refers to the n-th level in the ascending order above.
%   (When GROUP contains multiple grouping variables, ColumnSkip applies only
%   when there is exactly one grouping variable; otherwise it is ignored.)
%
%   GROUP may be:
%     - a numeric vector/matrix (each column is a grouping variable),
%     - a categorical vector,
%     - a cellstr vector,
%     - a cell array whose elements are grouping vectors (possibly mixed types).
%
%   Missing values (NaN / <undefined> / "") yield NaN in the corresponding
%   dummy block row.
%
%   Example:
%       g = [10 20 10 30 20 10]';
%       X = DummyVar(g)           % levels: [10 20 30] -> 3 columns
%       X2 = DummyVar(g, 2)       % drops the 2nd level (20)
%
%   See also CATEGORICAL, UNIQUE, REMOVECATS.

%   © You, 2025. Based on MathWorks' original DUMMYVAR documentation pattern.

% ---- Parse ColumnSkip
if nargin > 1
    ColumnSkip = varargin{1};
else
    ColumnSkip = 0;
end

% ---- Normalize GROUP into a matrix of grouping variables (as columns)
[G, m, n, levelsPerCol] = normalize_group(group);

% ---- Build dummy matrix with exactly the present (unique) levels
k_per_col = cellfun(@numel, levelsPerCol);
total_cols = sum(k_per_col);
D = zeros(m, total_cols);

col_offset = 0;
for j = 1:n
    idx = G(:, j); % integer codes 1..K_j for present levels, NaN for missing
    K = k_per_col(j);

    % set NaN rows for this block to NaN
    nan_rows = isnan(idx);
    if any(nan_rows)
        D(nan_rows, col_offset + (1:K)) = NaN;
    end

    % place ones via linear indices
    rows = find(~nan_rows);
    cols = col_offset + idx(rows);
    lin = sub2ind([m, total_cols], rows, cols);
    D(lin) = 1;

    col_offset = col_offset + K;
end

% ---- Apply ColumnSkip only for single grouping variable (clear semantics)
if (n == 1) && ColumnSkip ~= 0
    K = k_per_col(1);
    if ColumnSkip < 1 || ColumnSkip > K
        warning('DummyVar:ColumnSkipOutOfRange', ...
            ['ColumnSkip=%d is out of range for %d level(s); ' ...
             'skipping the first level instead.'], ColumnSkip, K);
        ColumnSkip = 1;
    end
    D(:, ColumnSkip) = [];
end

end % function DummyVar

% ======================================================================
function [G, m, n, levelsPerCol] = normalize_group(group)
% Returns:
%   G  : m-by-n numeric matrix of integer codes (1..K_j), NaN for missing
%   m,n: size
%   levelsPerCol: 1-by-n cell, each is a vector/cellstr of sorted unique levels

    levelsPerCol = {};
    if isa(group,'categorical')
        % single categorical vector
        if size(group,2) ~= 1
            error('stats:dummyvar:BadCateGroup', ...
                  'Categorical grouping variable must be a column vector.');
        end
        [codes, levels] = encode_one(group);
        G = codes;
        m = size(G,1); n = 1;
        levelsPerCol = {levels};

    elseif iscell(group) && ~ischar(group)
        % cell array of grouping vectors (possibly mixed types)
        n = numel(group);
        codesAll = cell(1,n);
        levelsPerCol = cell(1,n);
        m = [];
        for j = 1:n
            gj = group{j};
            [codes, levels] = encode_one(gj);
            if isempty(m)
                m = size(codes,1);
            elseif size(codes,1) ~= m
                error('stats:dummyvar:InputSizeMismatch', ...
                      'All grouping variables must have the same number of rows.');
            end
            codesAll{j} = codes;
            levelsPerCol{j} = levels;
        end
        G = cell2mat(codesAll);

    else
        % numeric vector/matrix or cellstr vector
        if isvector(group)
            group = group(:);
        end
        [m,n] = size(group);
        G = zeros(m,n);
        levelsPerCol = cell(1,n);
        for j = 1:n
            [codes, levels] = encode_one(group(:,j));
            G(:,j) = codes;
            levelsPerCol{j} = levels;
        end
    end

    % Make sure G is double
    G = double(G);
end

% ======================================================================
function [codes, levels] = encode_one(gj)
% Map a single grouping vector gj into:
%   codes  : m-by-1 integer codes 1..K in ascending level order; NaN for missing
%   levels : the sorted list of present levels (numeric ascending or lexicographic)

    m = numel(gj);

    if isa(gj,'categorical')
        miss = ismissing(gj);
        % turn into cellstr for lexicographic sorting of present categories
        s = cellstr(gj);
        s = s(:);
        s(miss) = [];                 % drop missings before unique
        levels = unique(s);           % lexicographic ascending
        % Build map from string to code
        codes = nan(m,1);
        if ~isempty(levels)
            % Create dictionary
            [~,~,ic] = unique(cellstr(gj(~miss))); % ic maps present rows -> compact
            % But ic follows category order; rebuild using our "levels"
            presentVals = cellstr(gj(~miss));
            [~, pos] = ismember(presentVals, levels);
            codes(~miss) = pos;
        end

    elseif iscellstr(gj) || (iscell(gj) && all(cellfun(@ischar, gj)))
        % cell array of char
        gj = gj(:);
        miss = cellfun(@(x) isempty(x) || (isstring(x) && strlength(x)==0), gj);
        vals = gj(~miss);
        levels = unique(vals);        % lexicographic ascending
        codes = nan(m,1);
        if ~isempty(levels)
            [~, pos] = ismember(vals, levels);
            codes(~miss) = pos;
        end

    elseif isstring(gj)
        gj = cellstr(gj);             % delegate to cellstr branch
        [codes, levels] = encode_one(gj);

    else
        % numeric (or logical)
        gj = double(gj(:));
        miss = isnan(gj);
        vals = gj(~miss);
        levels = unique(vals);        % numeric ascending
        codes = nan(m,1);
        if ~isempty(levels)
            [~, pos] = ismember(vals, levels);
            codes(~miss) = pos;
        end
    end
end
