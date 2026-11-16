function [D,TailRows] = dceSimDiagnostics(Results,EstimOpt,W,label,err,llFunE,essFun,Thresholds)
%DCESIMDIAGNOSTICS Simulator diagnostics for an estimated model.
%
% Syntax:   [D,TailRows] = dceSimDiagnostics(Results,EstimOpt,W,label,err,llFunE)
%           [D,TailRows] = dceSimDiagnostics(...,llFunE,essFun)
%           [D,TailRows] = dceSimDiagnostics(...,llFunE,essFun,Thresholds)
%
% Inputs:
%    Results - the module's Results, with bhat, g, hess and ihess as the
%              Hessian diagnostics use them
%    EstimOpt - the module's EstimOpt; NP, NRep, NumGrad and BActive are read
%    W       - the weights of the likelihood, [] or 1 for an unweighted model
%    label   - model name used in printed messages, e.g. 'MXL'
%    err     - the module's draws, dim x NRep*NP with NRep consecutive columns
%              per respondent (err_mtx or err_sliced in every module that has
%              them)
%    llFunE  - handle @(b,E) LL(b) taking the draws as its second argument and
%              returning the negative log-likelihood per respondent and its
%              analytical jacobian as a second output. It is called once.
%    essFun  - (optional) handle @() ess returning the effective number of
%              draws per respondent, or raising an error when the
%              specification is not supported (see mxl_drawESS)
%    Thresholds - (optional) passed to simDiagnostics
%
% The draw-set check rotates the respondents' draw blocks by half the sample
% and re-evaluates the gradient at the reported estimate. The rotation is a
% permutation of the draw blocks between respondents, so the pooled set of
% draws, the number of draws and anything normalised on draw moments stay
% exactly as they were: only the question "which part of the net integrates
% respondent i" changes, and the answer should not move the estimate. Costs one
% gradient evaluation and changes nothing.

if nargin < 3 || isempty(W), W = 1; end
if nargin < 4 || isempty(label), label = 'Simulator'; end
if nargin < 8, Thresholds = []; end

NP = optField(EstimOpt,'NP',NaN);
NRep = optField(EstimOpt,'NRep',NaN);

if nargin >= 7 && ~isempty(essFun)
    try
        ess = essFun();
    catch ME
        ess = ME.message;
    end
else
    ess = 'not computed for this model';
end

if nargin >= 6
    rot = rotationCheck(Results,EstimOpt,W,err,llFunE,NP,NRep);
else
    rot = 'not computed for this model';
end

[D,TailRows] = simDiagnostics(ess,NRep,rot,label,Thresholds);

end


function rot = rotationCheck(Results,EstimOpt,W,err,llFunE,NP,NRep)
rot = '';
if isempty(llFunE) || ~isa(llFunE,'function_handle')
    rot = 'not computed for this model';
    return
end
if optField(EstimOpt,'NumGrad',0) ~= 0
    rot = 'not available with a numerical gradient (EstimOpt.NumGrad = 1)';
    return
end
if ~isfield(Results,'bhat') || isempty(Results.bhat) || ~isfield(Results,'hess') || ...
        isempty(Results.hess)
    rot = 'the estimate or its Hessian is missing';
    return
end
if isempty(err) || ~ismatrix(err) || ~isfinite(NP) || ~isfinite(NRep) || ...
        size(err,2) ~= NP*NRep
    rot = 'the draw matrix layout is not recognised';
    return
end
if NP < 4 || NRep < 2
    rot = 'too few respondents or draws';
    return
end

try
    k = floor(NP/2);
    cols = mod((0:NP*NRep-1) + k*NRep,NP*NRep) + 1;
    [~,j] = llFunE(Results.bhat,err(:,cols));
    g = sum(j.*W,1)';
    g = full(g(:));

    H = full(Results.hess);
    nH = size(H,1);
    BActive = optField(EstimOpt,'BActive',[]);
    act = true(numel(g),1);
    if ~isempty(BActive) && numel(BActive) == numel(g) && sum(BActive(:) ~= 0) == nH
        act = BActive(:) ~= 0;
    end
    gv = g(act);
    if numel(gv) ~= nH
        rot = 'the jacobian is not conformable with the Hessian';
        return
    end

    iH = [];
    if isfield(Results,'ihess') && ~isempty(Results.ihess)
        iH = full(Results.ihess);
        if size(iH,1) == numel(g) && numel(g) ~= nH
            iH = iH(act,act);
        end
    end
    se = NaN(nH,1);
    if ~isempty(iH) && size(iH,1) == nH
        d = diag(iH);
        d(~isfinite(d) | d <= 0) = NaN;
        se = sqrt(d);
    end

    rot = struct('MaxAbsGradient',max(abs(gv)),'MaxNewtonStepSE',NaN, ...
        'MedianNewtonStepSE',NaN,'Offset',k,'ReferenceMaxAbsGradient',NaN,'Note','');
    if isfield(Results,'g') && ~isempty(Results.g)
        gr = full(Results.g(:));
        if numel(gr) == numel(act) && numel(gr) ~= nH
            gr = gr(act);
        end
        rot.ReferenceMaxAbsGradient = max(abs(gr));
    end
    step = quietSolve((H + H')/2,gv);
    if ~isempty(step)
        stepSE = abs(step)./se;
        if any(isfinite(stepSE))
            rot.MaxNewtonStepSE = max(stepSE(isfinite(stepSE)));
            rot.MedianNewtonStepSE = median(stepSE(isfinite(stepSE)));
        end
    end
catch ME
    rot = ['the check failed: ',ME.message];
end
end


function x = quietSolve(A,b)
% A\b without a near-singularity warning; [] when it cannot be computed.
x = [];
if isempty(A) || isempty(b) || size(A,1) ~= size(A,2) || size(A,1) ~= numel(b)
    return
end
if ~all(isfinite(A(:))) || ~all(isfinite(b(:)))
    return
end
if rcond(A) < 1e-15
    x = pinv(A)*b;
else
    x = A\b;
end
end


function v = optField(S,name,default)
if isstruct(S) && isfield(S,name) && ~isempty(S.(name))
    v = S.(name);
else
    v = default;
end
end
