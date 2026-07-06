function [W, p, dF] = waldtestx(hfun, b0, hess)

% save tmp1

h = feval(@(b) hfun(b), b0);
dF = length(h);
H = jacobianest(@(b) hfun(b), b0);
if rank(H) < size(H,1), warning('waldtestx: H is rank-deficient'); end
W = h' * ((H*(hess\H')) \ h);
p =  1 - chi2cdf(W,dF);
