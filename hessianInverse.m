function [iH, diagnostics] = hessianInverse(H, label)
%HESSIANINVERSE Invert Hessian-like matrices with diagnostics.

if nargin < 2 || isempty(label)
    label = 'Hessian';
end

diagnostics = struct( ...
    'label', label, ...
    'n', size(H,1), ...
    'rank', NaN, ...
    'rcond', NaN, ...
    'isSymmetric', false, ...
    'isIllConditioned', false, ...
    'usedPinv', false, ...
    'method', '');

if isempty(H)
    iH = H;
    diagnostics.method = 'empty';
    return
end

if size(H,1) ~= size(H,2)
    error('hessianInverse:NonSquare','%s must be square.', label);
end

if any(~isfinite(H(:)))
    warning('hessianInverse:NonFinite','%s contains NaN/Inf; returning NaN covariance.', label);
    iH = NaN(size(H));
    diagnostics.method = 'nonfinite';
    return
end

H = full(H);
n = size(H,1);
normH = norm(H,'fro');
symTol = 100 * eps(max(1,normH));
diagnostics.isSymmetric = norm(H - H','fro') <= symTol;
diagnostics.rcond = rcond(H);
diagnostics.rank = rank(H);
diagnostics.isIllConditioned = diagnostics.rank < n || diagnostics.rcond < 1e-12;

if diagnostics.isIllConditioned
    warning('hessianInverse:IllConditioned', ...
        '%s is rank deficient or ill-conditioned (rank=%d/%d, rcond=%.3g). Standard errors may be unreliable.', ...
        label, diagnostics.rank, n, diagnostics.rcond);
end

if diagnostics.rank < n
    diagnostics.method = 'pinv-rankdeficient';
    diagnostics.usedPinv = true;
    iH = pinv(H);
    if diagnostics.isSymmetric
        iH = (iH + iH')/2;
    end
    return
end

I = eye(n);

try
    if diagnostics.isSymmetric
        Hs = (H + H')/2;
        [R,p] = chol(Hs);
        if p == 0
            diagnostics.method = 'chol';
            iH = R \ (R' \ I);
        else
            [R,p] = chol(-Hs);
            if p == 0
                diagnostics.method = 'chol-negative';
                iH = -(R \ (R' \ I));
            else
                diagnostics.method = 'mldivide-symmetric';
                iH = Hs \ I;
            end
        end
        iH = (iH + iH')/2;
    else
        warning('hessianInverse:NonSymmetric','%s is not symmetric; using a nonsymmetric solve.', label);
        diagnostics.method = 'mldivide';
        iH = H \ I;
    end
catch ME
    warning('hessianInverse:SolveFailed','%s solve failed (%s); using pinv fallback.', label, ME.message);
    diagnostics.method = 'pinv';
    diagnostics.usedPinv = true;
    iH = pinv(H);
end

if any(~isfinite(iH(:)))
    warning('hessianInverse:NonFiniteInverse','%s inverse solve returned NaN/Inf; using pinv fallback.', label);
    diagnostics.method = 'pinv';
    diagnostics.usedPinv = true;
    iH = pinv(H);
end

if diagnostics.isSymmetric
    iH = (iH + iH')/2;
end

end
