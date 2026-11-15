function [D,TailRows] = dceHessDiagnostics(Results,EstimOpt,W,label,llFun,robustApplied)
%DCEHESSDIAGNOSTICS Hessian quality diagnostics for an estimated model.
%
% Syntax:   [D,TailRows] = dceHessDiagnostics(Results,EstimOpt,W,label)
%           [D,TailRows] = dceHessDiagnostics(Results,EstimOpt,W,label,llFun)
%           [D,TailRows] = dceHessDiagnostics(Results,EstimOpt,W,label,llFun,robustApplied)
%
% Inputs:
%    Results - the module's Results, with Results.hess already restricted to
%              the free parameters and Results.ihess computed from it, and
%              before any robust sandwich is applied to Results.ihess
%    EstimOpt - the module's EstimOpt; HessEstFix, NumGrad, BActive and
%              RobustStd are read when present
%    W       - the weights of the likelihood, as the module's own robust block
%              uses them; [] or 1 for an unweighted model
%    label   - model name used in printed messages, e.g. 'LC'
%    llFun   - (optional) handle @(b) LL(b) returning the negative
%              log-likelihood per observation (or per respondent) and its
%              analytical jacobian as a second output. It is called once, at
%              Results.bhat, only when the module has no jacobian at hand and
%              EstimOpt.NumGrad is 0; that costs one gradient evaluation.
%    robustApplied - (optional) true when the module turns Results.ihess into
%              a robust sandwich afterwards, so that the output says the
%              diagnostics describe the model-based covariance instead. Pass
%              EstimOpt.RobustStd == 1 from the modules that do it; the modules
%              that ignore RobustStd leave it out. Default false.
%
% Outputs as in hessianDiagnostics: the struct of diagnostics and the
% label/value rows for the Tail of the toolbox output.
%
% This is the bookkeeping that every module shares around
% hessianDiagnostics: where the BHHH comparison matrix comes from, and why it
% is unavailable when it is. Nothing here changes an estimate or a standard
% error - all of it reads matrices the module has already computed.
%
% The module's own jacobian is reused only for HessEstFix 0 and 5, where the
% modules store a genuine observation-level jacobian. For 1 and 2 the reported
% standard errors are the BHHH ones, so the comparison is reported as not
% applicable instead of a meaningless 1; for the remaining settings the
% jacobian is recomputed from llFun.

if nargin < 3 || isempty(W)
    W = 1;
end
if nargin < 4 || isempty(label)
    label = 'Hessian';
end

HessEstFix = optField(EstimOpt,'HessEstFix',0);
NumGrad = optField(EstimOpt,'NumGrad',0);
BActive = optField(EstimOpt,'BActive',[]);

if HessEstFix == 1 || HessEstFix == 2
    J = 'not applicable - the reported standard errors are BHHH';
elseif (HessEstFix == 0 || HessEstFix == 5) && isfield(Results,'jacobian') && ...
        ~isempty(Results.jacobian) && ismatrix(Results.jacobian) && ...
        size(Results.jacobian,1) > size(Results.jacobian,2)
    J = Results.jacobian;                      % already weighted by the module
elseif NumGrad ~= 0
    J = 'not available with a numerical gradient (EstimOpt.NumGrad = 1)';
elseif nargin >= 5 && ~isempty(llFun) && isfield(Results,'bhat')
    try
        [~,J] = llFun(Results.bhat);
        J = J.*W;
    catch ME
        J = ['not available - analytical jacobian failed (',ME.message,')'];
    end
else
    J = 'not available for this model';
end

[D,TailRows] = hessianDiagnostics(getField(Results,'hess'),getField(Results,'ihess'), ...
    getField(Results,'g'),J,BActive,label);

if nargin >= 6 && ~isempty(robustApplied) && robustApplied
    D.Note = 'model-based covariance (inverse Hessian), not the reported robust standard errors';
    TailRows = [TailRows; ...
        {'Diagnostics refer to','the model-based covariance (inverse Hessian), not the reported robust standard errors'}];
end

end


function v = optField(S,name,default)
if isstruct(S) && isfield(S,name) && ~isempty(S.(name))
    v = S.(name);
else
    v = default;
end
end


function v = getField(S,name)
if isstruct(S) && isfield(S,name)
    v = S.(name);
else
    v = [];
end
end
