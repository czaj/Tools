function [D,TailRows] = simDiagnostics(ess,NRep,rot,label,Thresholds)
%SIMDIAGNOSTICS Is the simulator good enough for the reported estimates?
%
% Syntax:   [D,TailRows] = simDiagnostics(ess,NRep,rot,label)
%           [D,TailRows] = simDiagnostics(ess,NRep,rot,label,Thresholds)
%
% Inputs:
%    ess   - NP x 1 effective number of draws per respondent (Kish, see
%            mxl_drawESS), or a char/string explaining why it is unavailable
%    NRep  - the number of draws per respondent
%    rot   - struct with the result of re-evaluating the gradient at the
%            reported estimate after rotating the respondents' draw blocks:
%            fields MaxAbsGradient, MaxNewtonStepSE, MedianNewtonStepSE,
%            Offset and, optionally, ReferenceMaxAbsGradient; or a char/string
%            explaining why it is unavailable
%    label - model name used in the printed messages, e.g. 'MXL'
%    Thresholds - (optional) [MinDraws, MaxShareBelow, MaxShiftSE], default
%            [10, 0.05, 1]: a respondent with fewer than MinDraws effective
%            draws has a likelihood resting on a handful of draws; a warning is
%            raised when more than MaxShareBelow of respondents are in that
%            state, or when rotating the draw blocks would move some parameter
%            by more than MaxShiftSE of its own standard errors. Both defaults
%            are rules of thumb measured on the DEFRA farmers and the toolbox
%            demo data (see DRAWS.md); a shift below the threshold still
%            matters for an individual parameter.
%
% Outputs:
%    D        - struct of diagnostics, for Results.diagnostics
%    TailRows - label/value rows for the Tail of the toolbox output
%
% Kish ESS describes weight concentration. A rotated-block Newton step is a
% local sensitivity check. Independent full refits check coefficient and SE
% stability. ISCeiling is the legacy name for R/medianESS (ESS units only).
% DrawsSuggested remains present as NaN for existing readers.

if nargin < 4 || isempty(label)
    label = 'Simulator';
end
if nargin < 5 || isempty(Thresholds)
    Thresholds = [10, 0.05, 1];
end
MinDraws = Thresholds(1);
MaxShareBelow = Thresholds(2);
MaxShiftSE = Thresholds(3);

D = struct( ...
    'label', label, ...
    'NDraws', NaN, ...
    'NP', NaN, ...
    'MedianESS', NaN, ...
    'MedianESSShare', NaN, ...
    'P05ESS', NaN, ...
    'MinESS', NaN, ...
    'NUnassessed', NaN, ...
    'NBelowMinDraws', NaN, ...
    'ShareBelowMinDraws', NaN, ...
    'MinDraws', MinDraws, ...
    'RotatedMaxAbsGradient', NaN, ...
    'RotatedStepSE', NaN, ...
    'PairedStepSE', NaN, ...
    'RotatedMedianStepSE', NaN, ...
    'RotationOffset', NaN, ...
    'ReferenceMaxAbsGradient', NaN, ...
    'StarvedDraws', false, ...
    'DrawSetSpecific', false, ...
    'DrawsSuggested', NaN, ...
    'ISCeiling', NaN, ...
    'Advice', '', ...
    'Thresholds', [MinDraws, MaxShareBelow, MaxShiftSE], ...
    'ESSNote', '', ...
    'RotationNote', '');

if nargin >= 2 && ~isempty(NRep) && isscalar(NRep) && isfinite(NRep)
    D.NDraws = NRep;
end

%% draw concentration
if ischar(ess) || isstring(ess)
    D.ESSNote = char(ess);
elseif isempty(ess)
    D.ESSNote = 'not available for this model';
else
    try
        e = ess(:);
        D.NP = numel(e);
        e = e(isfinite(e));
        D.NUnassessed = D.NP-numel(e);
        if isempty(e)
            D.ESSNote = 'no finite effective draw counts';
        else
            D.MedianESS = median(e);
            D.P05ESS = quantileSimple(e,0.05);
            D.MinESS = min(e);
            if isfinite(D.NDraws) && D.NDraws > 0
                D.MedianESSShare = D.MedianESS/D.NDraws;
            end
            D.NBelowMinDraws = sum(e < MinDraws);
            D.ShareBelowMinDraws = D.NBelowMinDraws/D.NP;
            D.StarvedDraws = D.ShareBelowMinDraws > MaxShareBelow;
        end
    catch ME
        D.ESSNote = ['effective draw counts failed: ',ME.message];
    end
end

%% draw-set dependence of the reported optimum
if ischar(rot) || isstring(rot)
    D.RotationNote = char(rot);
elseif isempty(rot) || ~isstruct(rot)
    D.RotationNote = 'not available for this model';
else
    if isfield(rot,'MaxAbsGradient'), D.RotatedMaxAbsGradient = rot.MaxAbsGradient; end
    if isfield(rot,'MaxNewtonStepSE'), D.RotatedStepSE = rot.MaxNewtonStepSE; end
    if isfield(rot,'MedianNewtonStepSE'), D.RotatedMedianStepSE = rot.MedianNewtonStepSE; end
    if isfield(rot,'Offset'), D.RotationOffset = rot.Offset; end
    if isfield(rot,'ReferenceMaxAbsGradient')
        D.ReferenceMaxAbsGradient = rot.ReferenceMaxAbsGradient;
    end
    if isfield(rot,'Note') && ~isempty(rot.Note), D.RotationNote = char(rot.Note); end
    if isfield(rot,'PairedStepSE') && isfinite(rot.PairedStepSE)
        D.PairedStepSE = rot.PairedStepSE;
        D.DrawSetSpecific = D.PairedStepSE > MaxShiftSE;

    end
end

%% which remedy the numbers point to
D = simAdvice(D,MaxShiftSE);

TailRows = simTail(D);

%% warnings
if D.StarvedDraws
    warning('simDiagnostics:StarvedDraws', ...
        ['%s: %.1f%% of respondents (%d of %d) have fewer than %g effective draws out of %d ', ...
        '(minimum %.3g). A few draws carry much of their simulated likelihood. ', ...
        'Compare coefficients and standard errors across independent draw sequences.'], ...
        label,100*D.ShareBelowMinDraws,D.NBelowMinDraws,D.NP,MinDraws,D.NDraws,D.MinESS);
end
if D.DrawSetSpecific
    warning('simDiagnostics:DrawSetSpecific', ...
        '%s: draw sensitivity exceeds the %.3g SE check level. %s',label,MaxShiftSE,D.Advice);
end
end

function D = simAdvice(D,MaxShiftSE)
if isfinite(D.MedianESS) && D.MedianESS > 0 && isfinite(D.NDraws)
    D.ISCeiling = D.NDraws/D.MedianESS;
end
if D.DrawSetSpecific || D.StarvedDraws
    D.Advice = ['Check the original score and curvature. Refit from multiple starts on fixed draws, ', ...
        'then compare coefficients and SEs using independent draws or a different integration rule.'];
elseif isfinite(D.PairedStepSE)
    D.Advice = 'Small draw-sensitivity measure for one rotation. Use independent refits to assess coefficient and SE stability.';
end
end

function TailRows = simTail(D)
TailRows = cell(0,2);
if isfinite(D.MedianESS)
    txt = sprintf('median %s of %s',numText(D.MedianESS),numText(D.NDraws));
    if isfinite(D.MedianESSShare)
        txt = [txt,sprintf(' (%.0f%%)',100*D.MedianESSShare)];
    end
    txt = [txt,sprintf(', 5th pct. %s, min %s',numText(D.P05ESS),numText(D.MinESS))];
    TailRows = [TailRows; {'Effective draws',txt}];
    TailRows = [TailRows; {sprintf('Respondents <%g draws',D.MinDraws), ...
        sprintf('%d of %d (%.1f%%)',D.NBelowMinDraws,D.NP,100*D.ShareBelowMinDraws)}];
elseif ~isempty(D.ESSNote)
    TailRows = [TailRows; {'Effective draws',['not available - ',D.ESSNote]}];
end
if D.NUnassessed > 0
    TailRows = [TailRows; {'Respondents without ESS',sprintf('%d of %d',D.NUnassessed,D.NP)}];
end
if isfinite(D.RotatedStepSE) || isfinite(D.RotatedMaxAbsGradient)
    TailRows = [TailRows; {'Max |g|, other draws',numText(D.RotatedMaxAbsGradient)}];
    txt = sprintf('%s SE',numText(D.RotatedStepSE));
    if isfinite(D.RotatedMedianStepSE)
        txt = [txt,sprintf(' (median %s SE)',numText(D.RotatedMedianStepSE))];
    end
    if isfinite(D.RotationOffset)
        txt = [txt,sprintf(', draw blocks rotated by %d respondents',D.RotationOffset)];
    end
    TailRows = [TailRows; {'Shift, other draws',txt}];
    if isfinite(D.PairedStepSE)
        TailRows = [TailRows; {'Paired score change',sprintf('max %.4g SE, original curvature',D.PairedStepSE)}];
    end
    if ~isempty(D.RotationNote)
        TailRows = [TailRows; {'Rotation check',D.RotationNote}];
    end
elseif ~isempty(D.RotationNote)
    TailRows = [TailRows; {'Shift, other draws',['not available - ',D.RotationNote]}];
end
if ~isempty(D.Advice)
    TailRows = [TailRows; {'What to do',D.Advice}];
end
end


function q = quantileSimple(x,p)
% Fifth percentile without the Statistics Toolbox, same convention as prctile.
x = sort(x(:));
n = numel(x);
if n == 0
    q = NaN;
    return
end
pos = p*n + 0.5;
if pos <= 1
    q = x(1);
elseif pos >= n
    q = x(n);
else
    lo = floor(pos);
    q = x(lo) + (pos - lo)*(x(lo+1) - x(lo));
end
end


function s = numText(v)
if isempty(v) || ~isfinite(v)
    s = 'n/a';
elseif v == fix(v) && abs(v) < 1e6
    s = sprintf('%d',v);
elseif abs(v) >= 100
    s = sprintf('%.0f',v);
elseif abs(v) >= 1
    s = sprintf('%.1f',v);
else
    s = sprintf('%.4g',v);
end
end
