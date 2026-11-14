function [D,TailRows] = hessianDiagnostics(H,iH,g,J,BActive,label,Bounds)
% HESSIANDIAGNOSTICS Quality checks for the covariance matrix of an estimate.
%
% Syntax:   D = hessianDiagnostics(H,iH,g,J,BActive,label)
%           [D,TailRows] = hessianDiagnostics(H,iH,g,J,BActive,label,Bounds)
%
% Inputs:
%    H       - observed Hessian of the negative log-likelihood, restricted to
%              the parameters the covariance matrix was computed for
%    iH      - covariance matrix (inverse of H); either restricted like H or
%              expanded to all parameters, as returned by direcXpnd
%    g       - gradient at the estimate; all parameters or restricted
%    J       - observation-level jacobian of the negative log-likelihood
%              (rows = observations or respondents, columns = parameters;
%              all parameters or restricted). Pass [] when it is not
%              available cheaply - the BHHH comparison is then skipped.
%              A char string instead of a matrix skips the comparison too
%              and is reported as the reason
%    BActive - indicator of the parameters H refers to, one entry per
%              parameter of the model
%    label   - model name used in printed messages (e.g. 'MXL')
%    Bounds  - (optional) acceptance interval for the median standard error
%              ratio, default [0.8 1.25]
%
% Outputs:
%    D        - struct of diagnostics (fields listed below)
%    TailRows - n-by-2 cell array of label/value pairs for the Tail of the
%               toolbox output, so that the numbers are printed next to the
%               'Hessian' row and saved in the .xlsx file
%
% Diagnostics (the checklist of section 7.3 of the standard error report of
% 14.11.2026, natural_england/outputs/DCE_se_diagnosis_v2_2026-11-14/):
%    MedianSERatioBHHH - median over parameters of SE(BHHH)/SE(Hessian).
%              This is the information matrix equality test. At a true
%              maximum of a correctly specified likelihood it is about 1.
%              A value far from 1 in a simulated model means the point
%              maximizes the simulated likelihood of one particular set of
%              draws rather than the likelihood itself, and that the
%              standard errors are too small. Raising the number of draws
%              by orders of magnitude does not repair it.
%    MinEigHessian   - smallest eigenvalue of the observed Hessian; it has
%              to be positive at a maximum.
%    MaxAbsGradient  - largest absolute gradient element at the estimate.
%    MaxNewtonStepSE - largest Newton step |(H\g)_j| expressed in standard
%              errors of the same parameter; small means that the reported
%              point and the reported curvature agree with each other.
%    NNonFiniteSE    - number of free parameters without a finite standard
%              error.
%
% The function never changes an estimate - it only reads matrices the
% toolbox has already computed. Failures are reported as NaN diagnostics
% rather than errors, so that no model is lost because of a check.

if nargin < 6 || isempty(label)
    label = 'Hessian';
end
if nargin < 7 || isempty(Bounds)
    Bounds = [0.8 1.25];
end

D = struct( ...
    'label', label, ...
    'NParams', NaN, ...
    'NFree', NaN, ...
    'MedianSERatioBHHH', NaN, ...
    'SERatioSource', 'not available', ...
    'MinEigHessian', NaN, ...
    'MaxAbsGradient', NaN, ...
    'MaxNewtonStepSE', NaN, ...
    'NNonFiniteSE', NaN, ...
    'Bounds', Bounds, ...
    'SERatioOutsideBounds', false, ...
    'Note', '');

if nargin >= 4 && (ischar(J) || isstring(J))
    D.Note = char(J);
    J = [];
end

try
    H = full(H);
    if isempty(H) || size(H,1) ~= size(H,2)
        D.Note = 'Hessian missing or not square';
        TailRows = diagnosticsTail(D);
        return
    end
    n = size(H,1);

    if nargin < 5 || isempty(BActive)
        BActive = ones(n,1);
    end
    active = BActive(:) ~= 0;
    D.NParams = numel(active);
    D.NFree = n;
    if sum(active) ~= n
        % H does not follow BActive - treat every row of H as a free
        % parameter and leave the vectors unrestricted
        active = true(n,1);
        D.NParams = n;
    end

    Hs = (H + H')/2;
    if all(isfinite(Hs(:)))
        D.MinEigHessian = min(real(eig(Hs)));
    end

    se = seFromCov(iH,active,n);
    D.NNonFiniteSE = sum(~isfinite(se) | se <= 0);

    if ~isempty(g)
        gv = restrictVector(g(:),active,n);
        D.MaxAbsGradient = max(abs(gv));
        if numel(gv) == n
            step = quietSolve(Hs,gv);
            if ~isempty(step)
                stepSE = abs(step)./se;
                if any(isfinite(stepSE))
                    D.MaxNewtonStepSE = max(stepSE(isfinite(stepSE)));
                end
            end
        end
    end

    if ~isempty(J)
        Jm = J;
        if size(Jm,2) == numel(active) && sum(active) ~= numel(active)
            Jm = Jm(:,active);
        end
        if size(Jm,2) == n && all(isfinite(Jm(:)))
            seB = seFromInfo(Jm'*Jm);
            ok = isfinite(seB) & isfinite(se) & seB > 0 & se > 0;
            if any(ok)
                D.MedianSERatioBHHH = median(seB(ok)./se(ok));
                D.SERatioSource = sprintf('BHHH outer product, %d of %d parameters',sum(ok),n);
            else
                D.Note = 'BHHH standard errors not computable';
            end
        else
            D.Note = 'jacobian not conformable with the Hessian';
        end
    end

    if isfinite(D.MedianSERatioBHHH)
        D.SERatioOutsideBounds = D.MedianSERatioBHHH < Bounds(1) || D.MedianSERatioBHHH > Bounds(2);
    end

    TailRows = diagnosticsTail(D);

    if D.SERatioOutsideBounds
        warning('hessianDiagnostics:InformationMatrixEquality', ...
            ['%s: median SE(BHHH)/SE(Hessian) = %.3g is outside [%.2f, %.2f], so the ', ...
            'information matrix equality fails - the reported point is most likely a maximum ', ...
            'of this particular set of draws rather than of the true likelihood, and these ', ...
            'standard errors are not fit for a table.'], ...
            label,D.MedianSERatioBHHH,Bounds(1),Bounds(2));
    end
catch ME
    D.Note = ['diagnostics failed: ',ME.message];
    TailRows = diagnosticsTail(D);
end

end


function v = restrictVector(v,active,n)
% Keep the entries of a full-length vector that the Hessian refers to.
if numel(v) == numel(active) && sum(active) ~= numel(active) && numel(v) ~= n
    v = v(active);
end
end


function se = seFromCov(A,active,n)
% Standard errors from a covariance matrix, restricted when it is expanded.
se = NaN(n,1);
if isempty(A)
    return
end
A = full(A);
if size(A,1) ~= size(A,2)
    return
end
if size(A,1) == numel(active) && sum(active) ~= numel(active) && size(A,1) ~= n
    A = A(active,active);
end
if size(A,1) ~= n
    return
end
d = diag(A);
d(~isfinite(d) | d <= 0) = NaN;
se = sqrt(d);
end


function se = seFromInfo(A)
% Standard errors from an information matrix (here the BHHH outer product).
n = size(A,1);
se = NaN(n,1);
iA = quietInverse(A);
if isempty(iA)
    return
end
d = diag(iA);
d(~isfinite(d) | d <= 0) = NaN;
se = sqrt(d);
end


function iA = quietInverse(A)
% Inverse without the mldivide ill-conditioning warnings.
iA = [];
A = (A + A')/2;
if any(~isfinite(A(:)))
    return
end
if rcond(A) < 1e-15
    return
end
[R,p] = chol(A);
if p == 0
    iA = R \ (R' \ eye(size(A,1)));
    iA = (iA + iA')/2;
else
    iA = pinv(A);
end
end


function x = quietSolve(A,b)
% Solve A*x = b without the mldivide ill-conditioning warnings.
x = [];
A = (A + A')/2;
if any(~isfinite(A(:))) || any(~isfinite(b(:)))
    return
end
if rcond(A) < 1e-15
    x = pinv(A)*b;
    return
end
[R,p] = chol(A);
if p == 0
    x = R \ (R' \ b);
else
    x = pinv(A)*b;
end
end


function TailRows = diagnosticsTail(D)
% Label/value pairs printed next to the 'Hessian' row and saved to .xlsx.
TailRows = { ...
    'Median SE(BHHH)/SE(H)', ratioText(D); ...
    'Min eigenvalue of H',   numText(D.MinEigHessian,'%.4g'); ...
    'Max abs. gradient',     numText(D.MaxAbsGradient,'%.4g'); ...
    'Max Newton step (SE)',  numText(D.MaxNewtonStepSE,'%.4g'); ...
    'Parameters without SE', numText(D.NNonFiniteSE,'%d')};
end


function txt = ratioText(D)
if isfinite(D.MedianSERatioBHHH)
    txt = sprintf('%.4g',D.MedianSERatioBHHH);
    if D.SERatioOutsideBounds
        txt = sprintf('%s   (outside [%.2f, %.2f] - standard errors not fit for a table)', ...
            txt,D.Bounds(1),D.Bounds(2));
    end
elseif ~isempty(D.Note)
    txt = D.Note;
else
    txt = 'not available';
end
end


function txt = numText(x,fmt)
if isempty(x) || ~isfinite(x)
    txt = 'n/a';
elseif strcmp(fmt,'%d')
    txt = sprintf('%d',round(x));
else
    txt = sprintf(fmt,x);
end
end
