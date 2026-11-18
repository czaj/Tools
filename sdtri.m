function [C,correlations] = sdtri(B1,VARB1,EstimOpt,unitRows)
% Latent marginal SDs, delta-method SEs and Wald p-values for a column-packed
% lower factor. Columns of C: SD, SE, p.
B1 = B1(:);
m = numel(B1);
d = (sqrt(8*m+1)-1)/2;
if d ~= floor(d) || ~isequal(size(VARB1),[m m]) || numel(EstimOpt.Dist)~=d
    error('sdtri:Dimensions','Check dimensions of the factor, covariance and distributions.');
end
if nargin<4, unitRows = ismember(EstimOpt.Dist,[3:5 9:17]); end
[row,~] = find(tril(true(d)));
rows = accumarray(row,(1:m)',[],@(idx){sort(idx)});
C = NaN(d,3);
for i = 1:d
    if unitRows(i)
        C(i,1:2) = [1 0]; % standardized latent row in the likelihood
        continue
    end
    idx = rows{i};
    v = B1(idx);
    C(i,1) = norm(v);
    if C(i,1)>0
        derivative = v/C(i,1);
        variance = derivative'*VARB1(idx,idx)*derivative;
        if isfinite(variance) && variance>=0, C(i,2) = sqrt(variance); end
        if C(i,2)>0, C(i,3) = pv(C(i,1),C(i,2)); end
    end
end

if nargout<2, return; end
% Pair order is the strict lower triangle. Columns: i, j, latent rho, SE, p(rho=0).
[i,j] = find(tril(true(d),-1));
correlations = [i,j,NaN(length(i),3)];
L = zeros(d);
L(tril(true(d))) = B1;
for k = 1:length(i)
    a = i(k); b = j(k);
    if ~all(ismember(EstimOpt.Dist([a b]),[0 1])) || any(C([a b],1)==0), continue; end
    u = L(a,:)/C(a,1); v = L(b,:)/C(b,1);
    rho = u*v';
    correlations(k,3) = rho;
    if abs(rho)>=1, continue; end
    idx = [rows{a}(:);rows{b}(:)];
    gradient = [(v(1:a)-rho*u(1:a))/C(a,1),(u(1:b)-rho*v(1:b))/C(b,1)]';
    variance = gradient'*VARB1(idx,idx)*gradient;
    if isfinite(variance) && variance>0
        correlations(k,4:5) = [sqrt(variance),2*normcdf(-abs(rho)/sqrt(variance))];
    end
end
end
