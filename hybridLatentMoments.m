function moments = hybridLatentMoments(X,E,R)
% Moments of [repelem(X,R,1)'; E] without expanding respondent covariates.
% E is draw-by-column: all R draws for one respondent are contiguous.
N = size(X,1);
assert(isscalar(R) && R >= 1 && R == fix(R) && size(E,2) == R*N,...
    'Tools:Hybrid:DrawShape','Expected R draws per respondent.');
assert(all(isfinite(X),'all') && all(isfinite(E),'all'),...
    'Tools:Hybrid:Nonfinite','Structural covariates and draws must be finite.');
assert(N*R > 1,'Tools:Hybrid:Normalization','Latent normalization requires at least two draws.');
mx = mean(X,1);
me = mean(E,2);
Xc = X-mx;
D = size(X,2);
J = size(E,1);
S = zeros(D+J);
S(1:D,1:D) = R*(Xc'*Xc);
for first = 1:32:N
    ids = first:min(first+31,N);
    e = E(:,(first-1)*R+1:ids(end)*R)-me;
    eSum = reshape(sum(reshape(e,J,R,[]),2),J,[]);
    S(D+1:end,1:D) = S(D+1:end,1:D)+eSum*Xc(ids,:);
    S(D+1:end,D+1:end) = S(D+1:end,D+1:end)+e*e';
end
S(1:D,D+1:end) = S(D+1:end,1:D)';
moments = struct('mean',[mx';me],'covariance',S/(N*R-1));
end
