function [INPUT, Results, EstimOpt, OptimOpt] = DataCleanDCE2(INPUT,EstimOpt)

% global TolB
% save tmp_DataCleanDCE
% return

%% test dataset
% clear all
% clc
% EstimOpt.NAlt = 3
% EstimOpt.NCT = 1
% EstimOpt.NP =5000
% % Define the file path
% filePath = '/Users/E5470/OneDrive/Pulpit/matlabmyfiles/data5';
% % Read the matrix data (skips non-numeric headers automatically)
% INPUT.Y = readmatrix(filePath);
% filePath1 = '/Users/E5470/OneDrive/Pulpit/matlabmyfiles/dataxnan';
% INPUT.Xa = readmatrix(filePath1);
% EstimOpt.NamesA = {'1','2','-Cost'};
%% 

inputnames = fieldnames(INPUT);
for i=1:length(inputnames)
    INPUT.(inputnames{(i)}) = double(INPUT.(inputnames{(i)}));
end

EstimOpt.Rows = size(INPUT.Xa,1)/EstimOpt.NAlt;
if EstimOpt.Rows ~= EstimOpt.NP * EstimOpt.NCT
    error ('Dataset needs to include the same number of choice tasks and alternatives per person. Some can later be skipped with EstimOpt.DataComplete and EstimOpt.MissingInd')
end

if isfield(INPUT,'MissingInd') == 0 || isempty(INPUT.MissingInd)
    INPUT.MissingInd = zeros(size(INPUT.Y));
end

EstimOpt.MissingAlt = [];
EstimOpt.MissingCT = [];

% Sometimes there are no properly filled MissingInd vector
% Must be checked
if sum(INPUT.MissingInd) == 0
% if (sum(INPUT.TIMES) ~= nansum(INPUT.Y)) || any(isnan(INPUT.Y))
    % Check if there are NaNs instead of ones in the answers data
    % If yes, then the corresponding CT must be ommited
    INPUT.TIMES = EstimOpt.NCT * ones(EstimOpt.NP,1);
    if sum(INPUT.TIMES) ~= nansum(INPUT.Y)
        cprintf(rgb('DarkOrange'),'WARNING: Dataset not complete (missing Y?) - imputing non-empty EstimOpt.MissingInd.\n')
        Y_tmp = reshape(INPUT.Y,[EstimOpt.NAlt,size(INPUT.Y,1)./EstimOpt.NAlt]);
%         INPUT.MissingInd = sum(Y_tmp,1) ~= 1;
        INPUT.MissingInd = nansum(Y_tmp,1) ~= 1;
        % Ommit whole CT
        INPUT.MissingInd = repmat(INPUT.MissingInd,[EstimOpt.NAlt,1]);
        INPUT.MissingInd = INPUT.MissingInd(:);
        Y_tmp = reshape(INPUT.Y,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
        INPUT.TIMES = squeeze(sum(nansum(Y_tmp)));
    end
    EstimOpt.NCTMiss = EstimOpt.NCT * ones(EstimOpt.NP,1);
    EstimOpt.NAltMiss = EstimOpt.NAlt * ones(EstimOpt.NP,1);
end

MissingInd_tmp = reshape(INPUT.MissingInd,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
MissingCT = sum(MissingInd_tmp,1) == EstimOpt.NAlt; % missing NCT
MissingP = sum(MissingCT,2) == EstimOpt.NCT; % respondents with all NCT missing

if sum(MissingP) > 0 % respondents with 0 NCTs - remove from INPUT
    MissingPrep = reshape(MissingP(ones(EstimOpt.NAlt,1,1),ones(1,EstimOpt.NCT,1),:),EstimOpt.NAlt*EstimOpt.NCT*EstimOpt.NP,1);
    %     INPUT_fields = fields(INPUT);
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
    %cprintf(rgb('DarkOrange'), 'WARNING: Dataset includes %d respondents with 0 completed choice tasks. Adjusting NP from %d to %d .\n', sum(MissingP), EstimOpt.NP, EstimOpt.NP-sum(MissingP))
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
    %cprintf ('text', 'The dataset contains %d choice tasks with missing responses (out of the total of %d choice tasks).\n', sum(sum(MissingCT)),numel(MissingCT))
    cprintf ('text', ['The dataset contains ',num2str(sum(sum(MissingCT))),' choice tasks with missing responses (out of the total of ',num2str(numel(MissingCT)) ,' choice tasks).\n'])
    INPUT.Y = Y_tmp(:);
    INPUT.Xa = reshape(Xa_tmp,[size(INPUT.Xa)]);
end
if sum(sum((nansum(Y_tmp,1) ~= 1) ~= MissingCT)) > 0
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
    %cprintf ('text', 'The dataset contains %d choice tasks with missing alternatives (out of the total of %d complete choice tasks).\n', sum(sum(MissingAltCT(1,:,:))),numel(MissingCT(1,:,:))-sum(sum(MissingCT)))
    cprintf ('text', ['The dataset contains ',num2str(sum(sum(MissingAltCT(1,:,:)))) ,' choice tasks with missing alternatives (out of the total of ', num2str(numel(MissingCT(1,:,:))-sum(sum(MissingCT))) ,' complete choice tasks).\n'])
    INPUT.Y = Y_tmp(:);
    INPUT.Xa = reshape(Xa_tmp,[size(INPUT.Xa)]);
end

alt_sort = false;
for i = 1:EstimOpt.NAlt-1
    if squeeze(sum(sum(MissingAlt(EstimOpt.NAlt-i,:,:) == 1 & MissingAlt(EstimOpt.NAlt-i+1,:,:) == 0,2),3)) > 0        
        %         error('Missing alternatives must come last in the choice task')
        alt_sort = true;
    end
end

if alt_sort
    cprintf(rgb('DarkOrange'), ['WARNING: Missing alternatives must come last in the choice task - sorting each choice task \n'])
    % sort alternatives:
%     idx_missing_alt = INPUT.MissingInd;
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
%     MissingAlt = reshape(INPUT.MissingInd,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
    MissingAlt = reshape(MissingAlt,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
    MissingCT = sum(MissingInd_tmp,1) == EstimOpt.NAlt;
    MissingAltCT = (sum(MissingAlt,1) > 0) & (sum(MissingAlt,1) < EstimOpt.NAlt);
    MissingAltCT = MissingAltCT(ones(EstimOpt.NAlt,1,1),:,:);
    MissingAlt = MissingAlt & MissingAltCT;
    Y_tmp = reshape(INPUT.Y,EstimOpt.NAlt,EstimOpt.NCT,EstimOpt.NP);
    Y_tmp(MissingCT(ones(EstimOpt.NAlt,1,1),:,:)) = NaN;
end

if sum(sum((nansum(Y_tmp,1) ~= 1) ~= MissingCT))
    error ('Index for rows to skip (EstimOpt.MissingInd) not consistent with available observations (Y) - there are choice tasks with erroneously coded response variable.')
end

EstimOpt.MissingAlt = MissingAlt;
%     EstimOpt.MissingCT = squeeze(MissingCT);
EstimOpt.MissingCT = reshape(MissingCT,[EstimOpt.NCT,EstimOpt.NP]);
INPUT.TIMES = squeeze(sum(nansum(Y_tmp)));
EstimOpt.NCTMiss = EstimOpt.NCT - sum(EstimOpt.MissingCT,1)';
%     EstimOpt.NAltMiss = EstimOpt.NAlt - squeeze(sum(EstimOpt.MissingAlt(:,1,:),1));
EstimOpt.NAltMissIndExp = sum(MissingAlt == 0,1);
EstimOpt.NAltMissInd = reshape(EstimOpt.NAltMissIndExp,[EstimOpt.NCT,EstimOpt.NP]);
EstimOpt.NAltMissIndExp = reshape(EstimOpt.NAltMissIndExp(ones(EstimOpt.NAlt,1),:,:), EstimOpt.NAlt*EstimOpt.NCT, EstimOpt.NP);
EstimOpt.NAltMiss = EstimOpt.NAlt - squeeze(sum(sum(EstimOpt.MissingAlt,1),2)./(reshape(EstimOpt.NCTMiss,[1,1,EstimOpt.NP])));
% end

% INPUT.Xa(isnan(INPUT.MissingInd),:) = NaN; % exp(X*B) do not influence U_sum

EstimOpt.NObs = sum(INPUT.TIMES);

if isfield(INPUT,'W') && ~isempty(INPUT.W)
    if any(size(INPUT.W(:)) ~= size(INPUT.Y(:)))
        error('Incorrect size of the weights vector')
    else
        INPUT.W = INPUT.W(:);
%         INPUT.W = INPUT.W(INPUT.Y(:)==1);
%         INPUT.W = INPUT.W(1:EstimOpt.NCT:end);
        INPUT.W = INPUT.W(1:EstimOpt.NCT.*EstimOpt.NAlt:end);
        if (sum(INPUT.W) ~= EstimOpt.NP) && (~isfield('EstimOpt','NoScalingW') || EstimOpt.NoScalingW == 0)
            cprintf(rgb('DarkOrange'), ['WARNING: Scaling weights for unit mean. \n'])
            INPUT.W = INPUT.W.*size(INPUT.W,1)./sum(INPUT.W);
        end
    end
else
    INPUT.W = ones(EstimOpt.NP,1);
end

if isfield(EstimOpt,'RobustStd') == 0
    EstimOpt.RobustStd = 0; % do not use robust standard errors
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
OptimOpt.MaxFunEvals = 1e5*size(INPUT.Xa,2); %Maximum number of function evaluations allowed (1000)
OptimOpt.OutputFcn = @outputf;


%% Estimate constants-only MNL model:

INPUT_0.Y = INPUT.Y;
INPUT_0.Xa = eye(EstimOpt.NAlt);
INPUT_0.Xa = INPUT_0.Xa(:,1:end-1);
INPUT_0.Xa = INPUT_0.Xa((1:size(INPUT_0.Xa,1))' * ones(1,EstimOpt.NP*EstimOpt.NCT), (1:size(INPUT_0.Xa,2))');
INPUT_0.Xs = double.empty(size(INPUT_0.Y,1),0);
INPUT_0.MissingInd = INPUT.MissingInd;
INPUT_0.W = INPUT.W; %ones(EstimOpt.NP,1);
EstimOpt_0 = EstimOpt;
EstimOpt_0.NLTVariables = [];
EstimOpt_0.ConstVarActive = 0;
EstimOpt_0.BActive = [];
EstimOpt_0.NVarA = EstimOpt.NAlt - 1;
EstimOpt_0.NVarS = 0;
EstimOpt_0.OPTIM = 1;
EstimOpt_0.Display = 0;
EstimOpt_0.WTP_space = 0;
OptimOpt_0 = optimoptions('fminunc');
OptimOpt_0.Algorithm = 'quasi-newton';
OptimOpt_0.GradObj = 'off';
OptimOpt_0.Hessian = 'off';
OptimOpt_0.Display = 'off';
OptimOpt_0.FunValCheck= 'off';
OptimOpt_0.Diagnostics = 'off';
Results.MNL0 = MNL(INPUT_0,[],EstimOpt_0,OptimOpt_0);
% Results.MNL0.LL = 1;

save tmp1

% % if exist('output','dir') == 0
% % 	mkdir('output')
% % end
% % EstimOpt.fnameout = ('output\results');
% 
% % if isfield(EstimOpt,'Evaluate')==0
% %     EstimOpt.Evaluate = 0;
% % end
% %
% % if isfield(EstimOpt,'SCEXP')==0
% %     EstimOpt.SCEXP = 1;
% % end
% 
% % display statistics
% cprintf('text', 'Number of respondents:\n')
% cprintf('text', '- total: %d\n', EstimOpt.NP)
% 
% tasks_sum = accumarray(EstimOpt.NCTMiss(:),1,[EstimOpt.NCT 1]);
% facingCT = [];
% for i = 1:EstimOpt.NCT
%         if tasks_sum(i) ~= 0
%             fprintf('- facing %d choice tasks: %d (%4.2f%%)\n', i, tasks_sum(i), (tasks_sum(i)/EstimOpt.NP)*100)
%             facingCT = cat(2, facingCT, tasks_sum(i));
%         else 
%             facingCT = cat(2, facingCT, 0);
%         end
% end
% 
% alt_sum = accumarray(EstimOpt.NAltMiss(:),1,[EstimOpt.NAlt 1]);
% facingAlt = [];
% for i = 1:EstimOpt.NAlt
%         if alt_sum(i) ~= 0
%             fprintf('- facing %d alternatives: %d (%4.2f%%)\n', i, alt_sum(i), (alt_sum(i)/EstimOpt.NP)*100)
%             facingAlt = cat(2, facingAlt, alt_sum(i));
%         else
%             facingAlt = cat(2, facingAlt, 0);
%         end
% end
% 
% 
% alt_aux = repmat((1:EstimOpt.NAlt)', EstimOpt.NP*EstimOpt.NCT, 1).*INPUT.Y; % which alternative was selected (0 - not selected, >0 the alternative with this number was selected, NaN - this alternative was not available)
% 
% temp_count = 0;
% always_count = 0;
% always_choosing = [];
% for i = 1:EstimOpt.NAlt
%     for j = 1:EstimOpt.NP
%         for k = 1:(EstimOpt.NCT*EstimOpt.NAlt)
%             if alt_aux(k + EstimOpt.NCT*EstimOpt.NAlt*(j-1)) == i
%                 temp_count = temp_count + 1;
%             end
%         end
% 
%         if temp_count == EstimOpt.NCT
%             always_count = always_count + 1;
%         end
%         temp_count = 0;
%     end
%     fprintf('- always choosing alternative %d: %d (%4.2f%%)\n', i, always_count, round((always_count/EstimOpt.NP)*100,2))
%     always_choosing = cat(2, always_choosing, always_count);
%     always_count = 0;
% end
% 
% 
% % How many times a given alternative was selected:
% cprintf('text', 'Number of choices:\n')
% num_choices = [];
% for i=1:EstimOpt.NAlt
%     fprintf('- alternative %d: %d (%4.2f%%)\n', i, sum(alt_aux==i), round((sum(alt_aux==i)/sum(alt_aux>0)*100),2))
%     num_choices = cat(2, num_choices, sum(alt_aux==i));
% end
% 
% % How many times a given alternative was chosen depending on how many alternatives were available:
% n_alt_CT = reshape(alt_aux, EstimOpt.NAlt, [])'; % separate CT in each row
% n_alt_CT_aux = sum(n_alt_CT >= 0, 2); % how many alternatives were available in each CT
% n_alt_CT_aux2 = ReplicateRows(n_alt_CT_aux, EstimOpt.NAlt); % repeat the above information so that respondents can later be filtered according to how many CTs they have seen
% alt_aux2 = alt_aux(n_alt_CT_aux2==i); % we focus only on respondents who have seen a given number of alternatives
% 
% % for i=1:EstimOpt.NAlt
% %     fprintf('Number of choices (when %d alternatives were available): %d (%4.2f%%)\n', i, sum(n_alt_CT_aux==i), round(sum(n_alt_CT_aux==i)/sum(n_alt_CT_aux>0)*100,2))
% %     alt_aux2 = alt_aux(n_alt_CT_aux2==i); % we focus only on respondents who have seen a given number of alternatives
% %     for j=1:EstimOpt.NAlt
% %         fprintf('- alternative %d: %d (%4.2f%%)\n', j, sum(alt_aux2==j), round((sum(alt_aux2==j)/sum(alt_aux2>0)*100),2))
% %     end
% % end
% 
% 
% % attribute statistics
% % cprintf('text', 'Number of choices per attribute:\n')
% 
% chosen_atr = (INPUT.Xa).*INPUT.Y;
% % for j = 1:size(INPUT.Xa,2)
% %     fprintf('- %s: %d (%4.2f%%)\n', EstimOpt.NamesA{j}, sum(chosen_atr(:,j)>0 | chosen_atr(:,j)<0), (sum(chosen_atr(:,j)>0 | chosen_atr(:,j)<0)/sum(~isnan(chosen_atr(:,4)))*100))
% % end
% 
% cprintf('text', 'Choice attributes:\n')
% tableStatistics = table;
% Xa_ = [round(nanmean(chosen_atr),2); round(nanmedian(chosen_atr),2); round(quantile(chosen_atr, 0.25),2); round(quantile(chosen_atr, 0.75),2); round(nanstd(chosen_atr),2); round(min(chosen_atr),2); round(max(chosen_atr),2); round(mode(chosen_atr),2); round(100*sum(isnan(chosen_atr))./(sum(isnan(chosen_atr))+sum(~isnan(chosen_atr))),2)];
% if isempty(EstimOpt.NamesA)==1
%     tableStatistics = array2table(Xa_, 'RowNames', {'mean', 'median', ' quantile 0.25', ' quantile 0.75', 'std', 'min', 'max', 'mode'});
%     atrY = [round(nanmean(INPUT.Y),2); round(nanmedian(INPUT.Y),2); round(quantile(INPUT.Y, 0.25),2); round(quantile(INPUT.Y, 0.75),2); round(nanstd(INPUT.Y),2); round(min(INPUT.Y),2); round(max(INPUT.Y),2); round(mode(INPUT.Y),2); round(100*sum(isnan(INPUT.Y))./(sum(isnan(INPUT.Y))+sum(~isnan(INPUT.Y))),2)];
%     tableStatistics.("Y") = atrY;
%     disp(tableStatistics)
% else
%     tableStatistics = array2table(Xa_, 'RowNames', {'mean', 'median', ' quantile 0.25', ' quantile 0.75', 'std', 'min', 'max', 'mode', 'NaN (%)'}, 'VariableNames', EstimOpt.NamesA);
%     atrY = [round(nanmean(INPUT.Y),2); round(nanmedian(INPUT.Y),2); round(quantile(INPUT.Y, 0.25),2); round(quantile(INPUT.Y, 0.75),2); round(nanstd(INPUT.Y),2); round(min(INPUT.Y),2); round(max(INPUT.Y),2); round(mode(INPUT.Y),2); round(100*sum(isnan(INPUT.Y))./(sum(isnan(INPUT.Y))+sum(~isnan(INPUT.Y))),2)];
%     tableStatistics.("Y") = atrY;
%     disp(tableStatistics)
% end
% 
% %cprintf('text', 'Choice attributes for each level:\n');
% 
% Xa_level_array = [];
% count_level_array = [];
% count_level = [];
% for i = 1:size(INPUT.Xa,2)
%     unique(rmmissing(INPUT.Xa(:,i)));
%     atr_level = transpose(unique(rmmissing(INPUT.Xa(:,i))));
%     for j = 1:numel(unique(rmmissing(INPUT.Xa(:,i))))
%         count_level = cat(2, count_level, sum(rmmissing(chosen_atr(:,i)) == atr_level(j)));
%     end
% count_level_array = cat(2, count_level_array, count_level);
% Xa_level_array = cat(2, Xa_level_array, atr_level);
% count_level = [];
% end
% 
% %declaring names of columns
% count_NamesLevel = [];
% count_NamesLevelTemp2 = [];
% count_NamesLevelTemp = [];
% NamesLevel = [];
% tableStatisticsLevel= table;
% for i = 1:size(INPUT.Xa,2)
% atr_level = transpose(unique(rmmissing(INPUT.Xa(:,i))));
%     for j = 1:numel(unique(rmmissing(INPUT.Xa(:,i))))
%         count_NamesLevelTemp = strcat(EstimOpt.NamesA{i}, '=', num2str(atr_level(j), '%d'));
%         count_NamesLevelTemp2 = {count_NamesLevelTemp};
%         count_NamesLevel = cat(2, count_NamesLevel, count_NamesLevelTemp2);
%     end
% %NamesLevel = cat(2, NamesLevel, count_NamesLevel);
% end
% 
% save tmp1
% 
% % overall sum of NCT*NP*NAlt
% for i = 1:EstimOpt.NCT
%     ts_real(i) = tasks_sum(i)*i;
% end
% 
% for i = 1:EstimOpt.NAlt
%     as_real(i) = alt_sum(i)*i;
% end
% 
% 
% % tableStatisticsLevel = array2table(round(count_level_array/(sum(ts_real)*(sum(as_real)/EstimOpt.NP)),2), 'RowNames', {'Choice frequency (%)'}, 'VariableNames', count_NamesLevel);
% tableStatisticsLevel = array2table((count_level_array/(sum(ts_real)*(sum(as_real)/EstimOpt.NP))), 'RowNames', {'Choice frequency (%)'}, 'VariableNames', count_NamesLevel);
% 
% 
% 
% 
% 
% %disp(tableStatisticsLevel)
% 
% GeneralStatistics.EstimOpt.NP = EstimOpt.NP;
% GeneralStatistics.facingCT = facingCT;
% GeneralStatistics.facingAlt = facingAlt;
% GeneralStatistics.always_choosing = always_choosing;
% GeneralStatistics.num_choices = num_choices;
% GeneralStatistics.tableStatistics = tableStatistics;
% GeneralStatistics.tableStatisticsLevel = tableStatisticsLevel;
% Results.GeneralStatistics = GeneralStatistics;

%% 



format bank

% ------------------------------------------------------------
% CT validity from Y: a CT is valid if exactly one alt was chosen
% ------------------------------------------------------------
Y3 = reshape(INPUT.Y, EstimOpt.NAlt, EstimOpt.NCT, EstimOpt.NP);            % [NAlt x NCT x NP]
if (EstimOpt.NCT>1)    
    valid_ct = squeeze(nansum(Y3,1) == 1);                                  % [NCT x NP] true if CT has a recorded choice
else
    Y3_size = size(Y3);
    valid_ct = reshape(nansum(Y3,1) == 1,[Y3_size(2:end) 1]);
end

NCT_per_person = sum(valid_ct,1)';                                          % [NP x 1] integer #CT faced

% ------------------------------------------------------------
% Respondents by # of CT faced (1..NCT)
% ------------------------------------------------------------
cprintf('text','Number of respondents:\n');
cprintf('text','- total: %d\n', EstimOpt.NP);

maxCT = EstimOpt.NCT;
idxCT = NCT_per_person; idxCT(isnan(idxCT) | idxCT<0) = 0;                  % safety
tasks_sum_full = accumarray(idxCT+1, 1, [maxCT+1 1]);                       % include 0-bin then drop
facingCT = tasks_sum_full(2:end)';                                          % 1 x NCT

for k = 1:maxCT
    if facingCT(k) > 0
        fprintf('- facing %d choice tasks: %d (%.2f%%)\n', k, facingCT(k), 100*facingCT(k)/EstimOpt.NP);
    end
end

% ------------------------------------------------------------
% Respondents by # of alternatives faced (mode across their valid CTs)
% (what you asked for: counts of RESPONDENTS, not CTs)
% ------------------------------------------------------------

if (EstimOpt.NCT>1)    
    alts_per_ct = squeeze(sum(~isnan(Y3),1));                               % [NCT x NP], #available alts per CT                                    % [NCT x NP] true if CT has a recorded choice
else
    alts_per_ct = reshape(sum(~isnan(Y3)),[Y3_size(2:end) 1]);
end

alts_per_ct(~valid_ct) = NaN;                                               % ignore invalid CTs

alts_per_person = NaN(EstimOpt.NP,1);
for j = 1:EstimOpt.NP
    x = alts_per_ct(:,j); x = x(~isnan(x));
    if ~isempty(x), alts_per_person(j) = mode(x); end
end

idxAlt = alts_per_person; idxAlt(isnan(idxAlt) | idxAlt < 1) = [];          % drop unclassified
alt_resp_counts = accumarray(idxAlt, 1, [EstimOpt.NAlt 1]);                 % counts of respondents by #alts
facingAlt = alt_resp_counts.';                                              % 1 x NAlt (respondent-level)

for a = 1:EstimOpt.NAlt
    if alt_resp_counts(a) > 0
        fprintf('- facing %d alternatives: %d (%.2f%%)\n', a, alt_resp_counts(a), 100*alt_resp_counts(a)/EstimOpt.NP);
    end
end

% ------------------------------------------------------------
% Which alternative was chosen in each valid CT
% ------------------------------------------------------------
alt_aux = repmat((1:EstimOpt.NAlt)', EstimOpt.NP*EstimOpt.NCT, 1) .* INPUT.Y;  % chosen alt id, 0 if not chosen, NaN if unavailable
A   = reshape(alt_aux, EstimOpt.NAlt, EstimOpt.NCT, EstimOpt.NP);
Ch  = squeeze(nansum(A,1));                                                    % [NCT x NP], chosen alt id per CT (0 if invalid CT)

% ------------------------------------------------------------
% "Always choosing alternative i" (vs each person's observed #CTs)
% ------------------------------------------------------------
eqMat = false(EstimOpt.NCT, EstimOpt.NP, EstimOpt.NAlt);
for a = 1:EstimOpt.NAlt
    eqMat(:,:,a) = (Ch == a);
end
cntPerPers      = squeeze(sum(eqMat,1));                                    % [NP x NAlt]
alwaysMask      = (cntPerPers == NCT_per_person);                           % implicit expansion
always_choosing = sum(alwaysMask, 1);                                       % 1 x NAlt

for iAlt = 1:EstimOpt.NAlt
    fprintf('- always choosing alternative %d: %d (%.2f%%)\n', ...
        iAlt, always_choosing(iAlt), 100*always_choosing(iAlt)/EstimOpt.NP);
end

% ------------------------------------------------------------
% How many times each alternative was chosen overall
% ------------------------------------------------------------
totChoices  = sum(NCT_per_person);                                          % total valid CTs
num_choices = squeeze(sum(sum(eqMat,1),2)).';                               % 1 x NAlt
cprintf('text','Number of choices:\n');
for iAlt = 1:EstimOpt.NAlt
    fprintf('- alternative %d: %d (%.2f%%)\n', iAlt, num_choices(iAlt), 100*num_choices(iAlt)/totChoices);
end

% ------------------------------------------------------------
% Choice attributes tables (ALL vs SELECTED)
% Both tables include Xa and Y; display to 2 dp; no rounding of values
% ------------------------------------------------------------

% ---- Masks at row level ----
valid_ct3    = repmat(reshape(valid_ct, [1, EstimOpt.NCT, EstimOpt.NP]), [EstimOpt.NAlt, 1, 1]); % [NAlt x NCT x NP]
mask_all_rows = valid_ct3(:);                                               % rows in CTs where a choice was recorded
mask_sel_rows = (INPUT.Y == 1);                                             % rows of selected alts only

% ---- Variable names (safe & valid) ----
K = size(INPUT.Xa,2);
if isempty(EstimOpt.NamesA)
    varNames = arrayfun(@(i) sprintf('X%d',i), 1:K, 'UniformOutput', false);
else
    tmpNames = EstimOpt.NamesA;
    if isstring(tmpNames), tmpNames = cellstr(tmpNames); end
    varNames = cellstr(matlab.lang.makeValidName(tmpNames));                % enforce valid table var names
end

rowNames = {'mean','median','quantile 0.25','quantile 0.75','std','min','max','mode','NaN (%)'};

% =========================
% tableStatistics_all
% =========================
cprintf('text','Choice attributes (ALL alts within CTs with a recorded choice):\n');

X_all = INPUT.Xa;
Y_all = INPUT.Y;

% Stats for Xa (ALL)
Xa_all = NaN(9, K);
den_all = sum(mask_all_rows);
for c = 1:K
    xc = X_all(mask_all_rows, c);
    xcn = xc(~isnan(xc));
    if ~isempty(xcn)
        Xa_all(1,c) = mean(xcn);
        Xa_all(2,c) = median(xcn);
        Xa_all(3,c) = quantile(xcn,0.25);
        Xa_all(4,c) = quantile(xcn,0.75);
        Xa_all(5,c) = std(xcn);
        Xa_all(6,c) = min(xcn);
        Xa_all(7,c) = max(xcn);
        Xa_all(8,c) = mode(xcn);
    end
    Xa_all(9,c) = 100*sum(isnan(xc))/max(den_all,1);  % NaN (%) among considered rows
end

tableStatistics_all = array2table(Xa_all, 'RowNames', rowNames, 'VariableNames', varNames);

% Y (ALL)
yc  = Y_all(mask_all_rows);
ycn = yc(~isnan(yc));
Y_all_vec = NaN(9,1);
if ~isempty(ycn)
    Y_all_vec(1) = mean(ycn);
    Y_all_vec(2) = median(ycn);
    Y_all_vec(3) = quantile(ycn,0.25);
    Y_all_vec(4) = quantile(ycn,0.75);
    Y_all_vec(5) = std(ycn);
    Y_all_vec(6) = min(ycn);
    Y_all_vec(7) = max(ycn);
    Y_all_vec(8) = mode(ycn);
end
Y_all_vec(9) = 100*sum(isnan(yc))/max(den_all,1);

tableStatistics_all.("Y") = Y_all_vec;

disp(tableStatistics_all);

% =========================
% tableStatistics_selected
% =========================
cprintf('text','Choice attributes (SELECTED alts only):\n');

X_sel = INPUT.Xa;
Y_sel = INPUT.Y;

% Stats for Xa (SELECTED)
Xa_sel = NaN(9, K);
den_sel = sum(mask_sel_rows);
for c = 1:K
    xc = X_sel(mask_sel_rows, c);
    xcn = xc(~isnan(xc));
    if ~isempty(xcn)
        Xa_sel(1,c) = mean(xcn);
        Xa_sel(2,c) = median(xcn);
        Xa_sel(3,c) = quantile(xcn,0.25);
        Xa_sel(4,c) = quantile(xcn,0.75);
        Xa_sel(5,c) = std(xcn);
        Xa_sel(6,c) = min(xcn);
        Xa_sel(7,c) = max(xcn);
        Xa_sel(8,c) = mode(xcn);
    end
    Xa_sel(9,c) = 100*sum(isnan(xc))/max(den_sel,1);  % NaN (%) among considered rows
end

tableStatistics_selected = array2table(Xa_sel, 'RowNames', rowNames, 'VariableNames', varNames);

% Y (SELECTED)
yc2  = Y_sel(mask_sel_rows);
ycn2 = yc2(~isnan(yc2));
Y_sel_vec = NaN(9,1);
if ~isempty(ycn2)
    Y_sel_vec(1) = mean(ycn2);
    Y_sel_vec(2) = median(ycn2);
    Y_sel_vec(3) = quantile(ycn2,0.25);
    Y_sel_vec(4) = quantile(ycn2,0.75);
    Y_sel_vec(5) = std(ycn2);
    Y_sel_vec(6) = min(ycn2);
    Y_sel_vec(7) = max(ycn2);
    Y_sel_vec(8) = mode(ycn2);
end
Y_sel_vec(9) = 100*sum(isnan(yc2))/max(den_sel,1);

tableStatistics_selected.("Y") = Y_sel_vec;

disp(tableStatistics_selected);


% ------------------------------------------------------------
% Level selection rates (ALL alts within CTs with a recorded choice)
% For each attribute column in Xa:
%   - take every observed (non-NaN) level within valid CTs,
%   - denominator: #rows where Xa==level AND CT valid,
%   - numerator:   #rows where Xa==level AND Y==1,
%   - Pct_selected = 100 * numerator / denominator
% ------------------------------------------------------------
cprintf('text','Level selection rates (ALL alts within CTs with a recorded choice):\n');

attrCol  = {};
levelVal = [];
nAvail   = [];
nSel     = [];
pctSel   = [];

X_all = INPUT.Xa;                                                           % same Xa used in the ALL table
colLevelsCount = 0;

for c = 1:K
    col = X_all(:,c);
    considerAll = mask_all_rows & ~isnan(col);                              % rows in valid CTs with this attr observed
    if ~any(considerAll), continue; end

    levs = unique(col(considerAll));
    for li = 1:numel(levs)
        lev = levs(li);

        % Denominator: appearances of this level among ALL alts in valid CTs
        idxAll = considerAll & (col == lev);
        nA = sum(idxAll);

        % Numerator: appearances of this level among SELECTED rows
        idxSel = mask_sel_rows & ~isnan(col) & (col == lev);
        nS = sum(idxSel);

        pS = 100 * nS / max(nA,1);

        attrCol{end+1,1}  = varNames{c};
        levelVal(end+1,1) = lev;
        nAvail(end+1,1)   = nA;
        nSel(end+1,1)     = nS;
        pctSel(end+1,1)   = pS;
        colLevelsCount    = colLevelsCount + 1;
    end
end

tableStatistics_levels = table( ...
    attrCol, levelVal, nAvail, nSel, pctSel, ...
    'VariableNames', {'Attribute','Level','N_available','N_selected','Pct_selected'});

% Optional: sort for readability
tableStatistics_levels = sortrows(tableStatistics_levels, {'Attribute','Level'});

disp(tableStatistics_levels);


% ------------------------------------------------------------
% Pack results
% ------------------------------------------------------------
GeneralStatistics.EstimOpt.NP              = EstimOpt.NP;
GeneralStatistics.facingCT                 = facingCT;                      % respondents by #CT faced
GeneralStatistics.facingAlt                = facingAlt;                     % respondents by #alts faced (mode per person)
GeneralStatistics.always_choosing          = always_choosing;               % 1 x NAlt
GeneralStatistics.num_choices              = num_choices;                   % 1 x NAlt
GeneralStatistics.tableStatistics_all      = tableStatistics_all;           % ALL alts & CTs (with recorded choice)
GeneralStatistics.tableStatistics_selected = tableStatistics_selected;      % SELECTED alts only
GeneralStatistics.tableStatistics_levels   = tableStatistics_levels;
Results.GeneralStatistics                  = GeneralStatistics;


% ------------------------------------------------------------
% Straightlining
% ------------------------------------------------------------

% for CT
Y3 = reshape(INPUT.Y, EstimOpt.NAlt, EstimOpt.NCT, EstimOpt.NP);            % [NAlt x NCT x NP]                                                       % sum for each choice
valid_ct3_sum = (squeeze(nansum(Y3, 2)))';
NCT_per_person_repeated = repmat(NCT_per_person, 1, EstimOpt.NAlt);
Y3_percent = valid_ct3_sum./NCT_per_person_repeated;                        % percent for each choice
% nb_of_respondent = (1:EstimOpt.NP)';
% straightlining_CT = array2table(Y3_percent);
% straightlining_CT.("Respondent") = nb_of_respondent;

% histogram
tcl = tiledlayout(1,EstimOpt.NAlt);

for i = 1:EstimOpt.NAlt
    histogram_all = subplot(1, EstimOpt.NAlt, i);
    h = histogram(Y3_percent(:,i));
    c = h.BinWidth;
    h.BinWidth = 0.1;

    dataMean = mean(Y3_percent(:,i));
    dataMedian = median(Y3_percent(:,i));
    dataMode = mode(Y3_percent(:,i));
    grid on;
    hold on;
    % vertical lines with basic statistics
    xline(dataMean, 'Color', 'r', 'LineWidth', 2);
    xline(dataMedian, 'Color', 'g', 'LineWidth', 2);
    xline(dataMode, 'Color', 'y', 'LineWidth', 2);
    hold off
    
    i_str = num2str(i);
    title(['alternative ' i_str]);
end

sgtitle('Histogram showing how often respondents selected subsequent alternatives ');

fig = gcf;
fig.Position(3) = fig.Position(3) + 5000;
subplot_legend = legend(['number of' sprintf('\n') 'respondents'], 'mean', 'median', 'mode');
subplot_legend.Position(1) = 0.05;
subplot_legend.Position(2) = 0.7;

end