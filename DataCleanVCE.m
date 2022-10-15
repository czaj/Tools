function [INPUT, Results, EstimOpt, OptimOpt] = DataCleanVCE(INPUT,EstimOpt)

if nansum(INPUT.Y<0)
    cprintf(rgb('DarkOrange'),'WARNING: There are negatives values in INPUT.Y. At the moment DataCleanDCE_MDCEV is not customized for such event. Try to check and adjust data manually.\n')
end

inputnames = fieldnames(INPUT);
for i=1:length(inputnames)
    INPUT.(inputnames{(i)}) = double(INPUT.(inputnames{(i)}));
end

EstimOpt.Rows = size(INPUT.Xa,1)/EstimOpt.NAlt;
if EstimOpt.Rows ~= EstimOpt.NP * EstimOpt.NCT
    error ('Dataset needs to include the same number of choice tasks and alternatives per person. Some can later be skipped with EstimOpt.DataComplete and EstimOpt.MissingInd')
end

for i=1:length(inputnames)
    if size(INPUT.(inputnames{(i)}),1) ~= EstimOpt.NP*EstimOpt.NAlt*EstimOpt.NCT
        fprintf('\nWarning: INPUT.%s has incorrect length\n', i, inputnames{(i)})
        error('Warning: Please check if each vector in INPUT has the same length (NAlt*NCT*NP)')
    end
end

if isfield(INPUT,'MissingInd') == 0 || isempty(INPUT.MissingInd)
    INPUT.MissingInd = zeros(size(INPUT.Y));
end

EstimOpt.MissingAlt = [];
EstimOpt.MissingCT = [];

if sum(INPUT.MissingInd) == 0
    INPUT.TIMES = EstimOpt.NCT * ones(EstimOpt.NP,1);
    Y_tmp = reshape(INPUT.Y,[EstimOpt.NAlt,size(INPUT.Y,1)./EstimOpt.NAlt]);
    if sum(INPUT.TIMES) ~= sum(nansum(Y_tmp)>0)
        cprintf(rgb('DarkOrange'),'WARNING: Dataset not complete (missing Y?) - imputing non-empty EstimOpt.MissingInd.\n')
        INPUT.MissingInd = (nansum(Y_tmp,1) <= 0);
        % Ommit whole CT
        INPUT.MissingInd = repmat(INPUT.MissingInd,[EstimOpt.NAlt,1]);
        INPUT.MissingInd = INPUT.MissingInd(:);
        Y_tmp = reshape(INPUT.Y,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
        INPUT.TIMES = squeeze(sum(nansum(Y_tmp)>0));
    end
    %WZ: EstimOpt.NCTMiss = EstimOpt.NCT * ones(EstimOpt.NP,1);
    %WZ: EstimOpt.NAltMiss = EstimOpt.NAlt * ones(EstimOpt.NP,1);
end

MissingInd_tmp = reshape(INPUT.MissingInd,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
MissingCT = sum(MissingInd_tmp,1) == EstimOpt.NAlt; % missing NCT
MissingP = sum(MissingCT,2) == EstimOpt.NCT; % respondents with all NCT missing

if sum(MissingP) > 0 % respondents with 0 NCTs - remove from INPUT
    MissingPrep = reshape(MissingP(ones(EstimOpt.NAlt,1,1),ones(1,EstimOpt.NCT,1),:),EstimOpt.NAlt*EstimOpt.NCT*EstimOpt.NP,1);
    INPUT_fields = fieldnames(INPUT);
    for i = 1:size(INPUT_fields,1)
        tmp = INPUT.(INPUT_fields{i});
        if isempty(tmp)
            continue
        elseif isequal(INPUT_fields{i},'TIMES') % || isequal(INPUT_fields{i},'W')
            tmp(reshape(MissingP,[size(MissingP,3),1]),:) = [];
        else
            tmp(MissingPrep,:) = [];
        end
        INPUT.(INPUT_fields{i}) = tmp;
    end
    cprintf(rgb('DarkOrange'), ['WARNING: Dataset includes ', num2str(sum(MissingP)), ' respondents with 0 completed choice tasks. Adjusting NP from ', num2str(EstimOpt.NP), ' to ',num2str(EstimOpt.NP-sum(MissingP)) ,'.\n'])
    EstimOpt.NP = EstimOpt.NP - sum(MissingP);
    EstimOpt.Rows = size(INPUT.Xa,1)/EstimOpt.NAlt;
    if EstimOpt.Rows ~= EstimOpt.NP * EstimOpt.NCT
        error ('Dataset needs to include the same number of choice tasks and alternatives per person. Some can later be skipped with EstimOpt.DataComplete and EstimOpt.MissingInd.')
    end
    MissingInd_tmp = reshape(INPUT.MissingInd,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
    MissingCT = sum(MissingInd_tmp,1) == EstimOpt.NAlt;
end

Y_tmp = reshape(INPUT.Y,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
Y_tmp(MissingCT(ones(EstimOpt.NAlt,1,1),:,:)) = NaN;
Xa_tmp = reshape(INPUT.Xa,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP,size(INPUT.Xa,2));
Xa_tmp(MissingCT(ones(EstimOpt.NAlt,1,1,1),:,:,ones(1,1,1,size(Xa_tmp,4)))) = NaN;
if any(MissingCT(:)) > 0 % respondents with missing NCT - replace Xa and Y with NaN
    cprintf ('text', ['The dataset contains ',num2str(sum(sum(MissingCT))),' choice tasks with missing responses (out of the total of ',num2str(numel(MissingCT)) ,' choice tasks).\n'])
    INPUT.Y = Y_tmp(:);
    INPUT.Xa = reshape(Xa_tmp,[size(INPUT.Xa)]);
end
if sum(sum((nansum(Y_tmp,1) < 0) ~= MissingCT)) > 0
    error ('Index for rows to skip (EstimOpt.MissingInd) not consistent with available observations (Y) - there are choice tasks with erroneously coded response variable.')
end
% Check if there are missing alternatives (NaNs in the CT which don't
% replace ones)
MissingAlt = MissingInd_tmp;
MissingAlt(isnan(Y_tmp)) = 1; % missing alternatives need to have NaN as a response variable
MissingAltCT = (sum(MissingAlt,1) > 0) & (sum(MissingAlt,1) < EstimOpt.NAlt);
MissingAltCT = MissingAltCT(ones(EstimOpt.NAlt,1,1),:,:);
MissingAlt = MissingAlt & MissingAltCT;

if sum(sum(sum(MissingAlt))) > 0 % respondents with missing ALT - replace Xa and Y with NaN
    Y_tmp(MissingAlt) = NaN;
    Xa_tmp(MissingAlt(:,:,:,ones(1,1,1,size(Xa_tmp,4)))) = NaN;
    cprintf ('text', ['The dataset contains ',num2str(sum(sum(MissingAltCT(1,:,:)))) ,' choice tasks with missing alternatives (out of the total of ', num2str(numel(MissingCT(1,:,:))-sum(sum(MissingCT))) ,' complete choice tasks).\n'])
    INPUT.Y = Y_tmp(:);
    INPUT.Xa = reshape(Xa_tmp,[size(INPUT.Xa)]);
end

alt_sort = false;
for i = 1:EstimOpt.NAlt-1
    if squeeze(sum(sum(MissingAlt(EstimOpt.NAlt-i,:,:) == 1 & MissingAlt(EstimOpt.NAlt-i+1,:,:) == 0,2),3)) > 0        
        alt_sort = true;
    end
end

if alt_sort
    cprintf(rgb('DarkOrange'), ['WARNING: Missing alternatives must come last in the choice task - sorting each choice task \n'])
    % sort alternatives:
    idx_missing_alt = reshape(MissingAlt, size(INPUT.MissingInd));
    fields = fieldnames(INPUT);    
    for i = 1:numel(fields) 
        if isequal(fields{i},'TIMES') % we do not sort  TIMES     
            continue
        else
            tmp = [INPUT.(fields{i}),idx_missing_alt];
            size_tmp = size(tmp);
            tmp = reshape(tmp,[EstimOpt.NAlt,EstimOpt.NCT*EstimOpt.NP,size_tmp(2)]);
            tmp = permute(tmp,[1,3,2]);
            for j = 1:size(tmp,3)
                tmp(:,:,j) =  sortrows(tmp(:,:,j),size_tmp(2));
            end
            tmp = permute(tmp,[1,3,2]);
            INPUT.(fields{i}) = reshape(tmp(:,:,1:end-1),[size_tmp(1),size_tmp(2)-1]);
        end
    end
    
    % recreate indexes:
    MissingAlt = reshape(MissingAlt,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
    MissingCT = sum(MissingInd_tmp,1) == EstimOpt.NAlt;
    MissingAltCT = (sum(MissingAlt,1) > 0) & (sum(MissingAlt,1) < EstimOpt.NAlt);
    MissingAltCT = MissingAltCT(ones(EstimOpt.NAlt,1,1),:,:);
    MissingAlt = MissingAlt & MissingAltCT;
    Y_tmp = reshape(INPUT.Y,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
    Y_tmp(MissingCT(ones(EstimOpt.NAlt,1,1),:,:)) = NaN;
end

if sum(sum((nansum(Y_tmp,1) <0) ~= MissingCT))
    error ('Index for rows to skip (EstimOpt.MissingInd) not consistent with available observations (Y) - there are choice tasks with erroneously coded response variable.')
end

EstimOpt.MissingAlt = MissingAlt;
EstimOpt.MissingCT = reshape(MissingCT,[EstimOpt.NCT,EstimOpt.NP]);
INPUT.TIMES = squeeze(sum(nansum(Y_tmp)>0));
EstimOpt.NCTMiss = EstimOpt.NCT - sum(EstimOpt.MissingCT,1)';
EstimOpt.NAltMissIndExp = sum(MissingAlt == 0,1);
EstimOpt.NAltMissInd = reshape(EstimOpt.NAltMissIndExp,[EstimOpt.NCT,EstimOpt.NP]);
EstimOpt.NAltMissIndExp = reshape(EstimOpt.NAltMissIndExp(ones(EstimOpt.NAlt,1),:,:), EstimOpt.NAlt*EstimOpt.NCT, EstimOpt.NP);
EstimOpt.NAltMiss = EstimOpt.NAlt - squeeze(sum(sum(EstimOpt.MissingAlt,1),2)./(reshape(EstimOpt.NCTMiss,[1,1,EstimOpt.NP])));

EstimOpt.NObs = sum(INPUT.TIMES);

if isfield(INPUT,'W') && ~isempty(INPUT.W)
    if any(size(INPUT.W(:)) ~= size(INPUT.Y(:)))
        error('Incorrect size of the weights vector')
    else
        INPUT.W = INPUT.W(:);
        INPUT.W = INPUT.W(1:EstimOpt.NCT.*EstimOpt.NAlt:end);
        if (sum(INPUT.W) ~= EstimOpt.NP) && (~isfield('EstimOpt','NoScalingW') || EstimOpt.NoScalingW == 0)
            cprintf(rgb('DarkOrange'), ['WARNING: Scaling weights for unit mean. \n'])
            INPUT.W = INPUT.W.*size(INPUT.W,1)./sum(INPUT.W);
        end
    end
else
    INPUT.W = ones(EstimOpt.NP,1);
end
INPUT.W = ReplicateRows(INPUT.W,EstimOpt.NCT);

if isfield(EstimOpt,'RobustStd') == 0
    EstimOpt.RobustStd = 0; % do not use robust standard errors
end

expenses = INPUT.Y .* INPUT.priceMat;
income = INPUT.I;
if sum(expenses>income)
    error ('In some cases expenses (INPUT.Y.*INPUT.priceMat) are bigger than income (INPUT.Y). Adjust or reject those observations.')
end

EstimOpt.NVarA = size(INPUT.Xa,2); % Number of attributes

if isfield(EstimOpt,'HaltonSkip') == 0
    EstimOpt.HaltonSkip = 1; % specify no of rows in halton sequence to skip (default=1)
end
if isfield(EstimOpt,'HaltonLeap') == 0
    EstimOpt.HaltonLeap = 0; % specify no of rows in halton sequence to leap (default=0)
end

if isfield(EstimOpt,'Draws') == 0
    EstimOpt.Draws = 6; % specify draws type (default = Sobol with scrambling)
end

if isfield(EstimOpt,'NRep') == 0
    EstimOpt.NRep = 1e3; % specify no. of draws
end

EstimOpt.Seed1 = 179424673;
EstimOpt.Seed2 = 7521436817;

if isfield(EstimOpt,'ConstVarActive') == 0
    EstimOpt.ConstVarActive = 0;
end
if isfield(EstimOpt,'Display') == 0
    EstimOpt.Display = 1;
end

if isfield(EstimOpt,'NumGrad') == 0 || (EstimOpt.NumGrad ~= 0 && EstimOpt.NumGrad ~= 1)
    EstimOpt.NumGrad = 0; % 1 for numerical gradient, 0 for analytical
end

if isfield(EstimOpt,'HessEstFix') == 0 || (EstimOpt.HessEstFix ~= 0 && EstimOpt.HessEstFix ~= 1)
    EstimOpt.HessEstFix = 0; % 0 = use optimization Hessian, 1 = use jacobian-based (BHHH) Hessian, 2 - use high-precision jacobian-based (BHHH) Hessian 3 - use numerical Hessian
end

if isfield(EstimOpt,'ApproxHess') == 0 || (EstimOpt.ApproxHess ~= 0 && EstimOpt.ApproxHess ~= 1)
    EstimOpt.ApproxHess = 1;
end

if isfield(EstimOpt,'RealMin') == 0 || (EstimOpt.RealMin ~= 0 && EstimOpt.RealMin ~= 1)
    EstimOpt.RealMin = 0;
end

EstimOpt.Draws = 6; % 1 - pseudo-random, 2 - Latin Hypercube, 3 - Halton, 4 - Halton RR scrambled, 5 - Sobol, 6 - Sobol MAO scrambled
EstimOpt.NSdSim = 1e4; % number of draws for simulating standard deviations

EstimOpt.Profile = 1;
%  EstimOpt.SpecProfile = [1 1 1; 1 1 1]; % First row for Alphas, second for gamma  

%% OptimOpt

if isfield(EstimOpt, 'ConstVarActive') == 0 || EstimOpt.ConstVarActive == 0 % no contstaints on parameters
    OptimOpt = optimoptions('fminunc');
    OptimOpt.Algorithm = 'quasi-newton'; %'trust-region';
elseif EstimOpt.ConstVarActive == 1 % there are some constraints on parameters
    OptimOpt = optimoptions('fmincon');
    OptimOpt.Algorithm = 'interior-point'; %'sqp'; 'active-set'; 'trust-region-reflective';
end

OptimOpt.GradObj = 'on'; %'off';
% OptimOpt.FinDiffType = 'central'; % ('forward')
% OptimOpt.Hessian = 'user-supplied'; % ('off'), only used by trust-region

if isfield(EstimOpt,'FunctionTolerance')
    OptimOpt.FunctionTolerance = EstimOpt.FunctionTolerance; % df / gradient precision level
elseif isfield(EstimOpt,'eps')
    OptimOpt.FunctionTolerance = EstimOpt.eps;
end
if isfield(EstimOpt,'StepTolerance')
    OptimOpt.StepTolerance = EstimOpt.TolX; % step precision level
elseif isfield(EstimOpt,'eps')
    OptimOpt.StepTolerance = EstimOpt.eps;
end
if isfield(EstimOpt,'OptimalityTolerance')
    OptimOpt.OptimalityTolerance = EstimOpt.OptimalityTolerance; % dB precision level
elseif isfield(EstimOpt,'eps')
    OptimOpt.OptimalityTolerance = EstimOpt.eps;
end

OptimOpt.MaxIter = 1e4;

OptimOpt.FunValCheck = 'on';
OptimOpt.Diagnostics = 'off';
% OptimOpt.GradObj = 'on';
OptimOpt.MaxFunEvals = 1e5*size(INPUT.Xa,2); %Maximum number of function evaluations allowed (1000)
OptimOpt.OutputFcn = @outputf;


%% Estimate constants-only MDCEV model:

INPUT_0.Y = INPUT.Y;
INPUT_0.Xa = eye(EstimOpt.NAlt);
INPUT_0.Xa = INPUT_0.Xa(:,1:end-1);
INPUT_0.Xa = INPUT_0.Xa((1:size(INPUT_0.Xa,1))' * ones(1,EstimOpt.NP*EstimOpt.NCT), (1:size(INPUT_0.Xa,2))');
INPUT_0.Xs = double.empty(size(INPUT_0.Y,1),0);
INPUT_0.MissingInd = INPUT.MissingInd;
INPUT_0.W = INPUT.W; %ones(EstimOpt.NP,1);
INPUT_0.I = INPUT.I;
INPUT_0.priceMat = INPUT.priceMat;
EstimOpt_0 = EstimOpt;
EstimOpt_0.NLTVariables = [];
EstimOpt_0.ConstVarActive = 0;
%EstimOpt_0.BActive = [];
EstimOpt_0.NVarA = EstimOpt.NAlt - 1;
EstimOpt_0.NVarS = 0;
EstimOpt_0.OPTIM = 1;
EstimOpt_0.Display = 0;
EstimOpt_0.WTP_space = 0;
EstimOpt_0.ApproxHess = 1;
OptimOpt_0 = optimoptions('fminunc');
OptimOpt_0.Algorithm = 'trust-region';
OptimOpt_0.GradObj = 'on';
OptimOpt_0.Hessian = 'off';
OptimOpt_0.Display = 'off';
OptimOpt_0.FunValCheck= 'off';
OptimOpt_0.Diagnostics = 'off';
Results.MDCEV0 = MDCEV(INPUT_0,EstimOpt_0,OptimOpt_0);
