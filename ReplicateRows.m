function Y = ReplicateRows(X,no,varargin)

% only tested for column vectors 

Y = repmat(X,1,no)';
Y = Y(:);