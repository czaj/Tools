function H = hessianFromGradient(gradFun,b,BActive)
% HESSIANFROMGRADIENT Hessian as central differences of an analytical gradient.
%
% Syntax:   H = hessianFromGradient(gradFun,b)
%           H = hessianFromGradient(gradFun,b,BActive)
%
% Inputs:
%    gradFun - function handle returning the gradient of the objective
%              function (e.g. the negative log-likelihood) at a parameter
%              vector, as a vector of the same length
%    b       - parameter vector at which the Hessian is evaluated
%    BActive - (optional) indicator of active parameters; rows and columns
%              of inactive parameters are set to zero
%
% Each active parameter is perturbed by +/- eps^(1/3)*max(|b_j|,1); the
% result is symmetrized. Compared with second differences of the objective
% function (e.g. hessian.m), the error is of the order of the gradient
% precision and only 2 gradient evaluations per parameter are needed.

b = b(:);
n = numel(b);
if nargin < 3 || isempty(BActive)
    BActive = ones(n,1);
end
active = BActive(:) ~= 0;
H = zeros(n);
for j = find(active)'
    step = eps^(1/3)*max(abs(b(j)),1);
    bp = b;
    bm = b;
    bp(j) = b(j) + step;
    bm(j) = b(j) - step;
    gp = gradFun(bp);
    gm = gradFun(bm);
    H(:,j) = (gp(:) - gm(:))/(bp(j) - bm(j));
end
H(~active,:) = 0;
H(:,~active) = 0;
H = (H + H')/2;
end
