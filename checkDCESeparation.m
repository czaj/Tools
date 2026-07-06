function D = checkDCESeparation(INPUT,EstimOpt)
% Fast pre-estimation diagnostics for obvious DCE separation/non-identification.

D = struct('Messages',{{}},'NMessages',0);

maxLevels = optNumber(EstimOpt,'SeparationMaxLevels',20);
maxPrint = optNumber(EstimOpt,'SeparationMaxWarnings',40);
showOutput = optNumber(EstimOpt,'Display',1) ~= 0;

Y = INPUT.Y(:);
validChoice = isfinite(Y);
if isfield(INPUT,'MissingInd') && ~isempty(INPUT.MissingInd)
    validChoice = validChoice & INPUT.MissingInd(:) == 0;
end

if isfield(INPUT,'Xa') && ~isempty(INPUT.Xa)
    namesA = optNames(EstimOpt,'NamesA',size(INPUT.Xa,2),'Xa');
    D = matrixChecks(D,'Xa',INPUT.Xa,namesA,validChoice,false);
    D = separationChecks(D,'choice Y','Xa',Y,INPUT.Xa,namesA,validChoice,maxLevels);
end

if isfield(INPUT,'Xs') && ~isempty(INPUT.Xs)
    namesS = optNames(EstimOpt,'NamesS',size(INPUT.Xs,2),'Xs');
    v = validRowsFor(INPUT.Xs,validChoice);
    D = matrixChecks(D,'Xs',INPUT.Xs,namesS,v,false);
    D = separationChecks(D,'choice Y','Xs',Y,INPUT.Xs,namesS,v,maxLevels);
end

if isfield(INPUT,'Xm') && ~isempty(INPUT.Xm)
    namesM = optNames(EstimOpt,'NamesM',size(INPUT.Xm,2),'Xm');
    v = validRowsFor(INPUT.Xm,validChoice);
    D = matrixChecks(D,'Xm',INPUT.Xm,namesM,v,false);
    if isfield(INPUT,'Xa') && size(INPUT.Xm,1) == size(INPUT.Xa,1)
        [Xam,namesAM] = interactionMatrix(INPUT.Xa,INPUT.Xm,namesA,namesM);
        D = matrixChecks(D,'Xa.*Xm',Xam,namesAM,v,false);
        D = separationChecks(D,'choice Y','Xa.*Xm',Y,Xam,namesAM,v,maxLevels);
    end
end

[Xmea,missingMea] = respondentMatrix(getField(INPUT,'Xmea'),EstimOpt,getField(EstimOpt,'MissingIndMea'));
[XmeaExp,~] = respondentMatrix(getField(INPUT,'Xmea_exp'),EstimOpt,[]);
[Xstr,~] = respondentMatrix(getField(INPUT,'Xstr'),EstimOpt,[]);

if ~isempty(Xstr)
    namesStr = optNames(EstimOpt,'NamesStr',size(Xstr,2),'Xstr');
    D = matrixChecks(D,'Xstr',Xstr,namesStr,true(size(Xstr,1),1),false);
end

if ~isempty(XmeaExp)
    namesMeaExp = optNames(EstimOpt,'NamesMeaExp',size(XmeaExp,2),'XmeaExp');
    D = matrixChecks(D,'Xmea_exp',XmeaExp,namesMeaExp,true(size(XmeaExp,1),1),true);
end

if ~isempty(Xmea)
    namesMea = optNames(EstimOpt,'NamesMea',size(Xmea,2),'Xmea');
    for i = 1:size(Xmea,2)
        y = Xmea(:,i);
        v = isfinite(y);
        if ~isempty(missingMea) && size(missingMea,1) == size(Xmea,1)
            v = v & missingMea(:,i) == 0;
        end
        if numel(unique(y(v))) < 2
            D = addIssue(D,sprintf('Xmea "%s" has fewer than two observed levels.',namesMea{i}));
        end
        if ~isempty(XmeaExp)
            D = separationChecks(D,['measurement ' namesMea{i}],'Xmea_exp',y,XmeaExp,namesMeaExp,v,maxLevels);
        end
        if ~isempty(Xstr)
            D = separationChecks(D,['measurement ' namesMea{i}],'Xstr',y,Xstr,namesStr,v,maxLevels);
        end
    end
end

if showOutput && D.NMessages > 0
    warnLine('Potential pre-estimation separation/identification issues detected:');
    n = min(D.NMessages,maxPrint);
    for i = 1:n
        warnLine(D.Messages{i});
    end
    if D.NMessages > maxPrint
        warnLine(sprintf('%d more issue(s) not printed; see Results.SeparationDiagnostics.Messages.',D.NMessages-maxPrint));
    end
end
end

function D = matrixChecks(D,block,X,names,valid,withIntercept)
if isempty(X) || size(X,2) == 0
    return
end
valid = validRowsFor(X,valid);
Xv = X(valid,:);
for j = 1:size(Xv,2)
    x = Xv(:,j);
    if isempty(x) || numel(unique(x(isfinite(x)))) < 2
        D = addIssue(D,sprintf('%s "%s" is constant or empty after filtering.',block,names{j}));
    end
end
Xv = Xv(all(isfinite(Xv),2),:);
if withIntercept && ~isempty(Xv)
    Xv = [ones(size(Xv,1),1),Xv];
end
if ~isempty(Xv) && size(Xv,2) > 1
    r = rank(Xv);
    if r < size(Xv,2)
        D = addIssue(D,sprintf('%s design is rank deficient (rank=%d/%d).',block,r,size(Xv,2)));
    end
end
end

function D = separationChecks(D,outcomeName,block,y,X,names,valid,maxLevels)
if isempty(X) || size(X,1) ~= numel(y)
    return
end
valid = validRowsFor(X,valid) & isfinite(y(:));
y = y(:);
for j = 1:size(X,2)
    x = X(:,j);
    v = valid & isfinite(x);
    xv = x(v);
    yv = y(v);
    if numel(unique(yv)) < 2
        continue
    end
    ux = unique(xv);
    if numel(ux) < 2 || numel(ux) > maxLevels
        continue
    end
    for k = 1:numel(ux)
        idx = xv == ux(k);
        uy = unique(yv(idx));
        if isscalar(uy)
            D = addIssue(D,sprintf('%s "%s" value %s only appears with %s=%s (n=%d).',block,names{j},valueLabel(ux(k)),outcomeName,valueLabel(uy(1)),sum(idx)));
        end
    end
end
end

function [X,names] = interactionMatrix(A,M,namesA,namesM)
nA = size(A,2);
nM = size(M,2);
X = zeros(size(A,1),nA*nM);
names = cell(nA*nM,1);
k = 0;
for j = 1:nA
    for m = 1:nM
        k = k + 1;
        X(:,k) = A(:,j).*M(:,m);
        names{k} = [namesA{j} ' * ' namesM{m}];
    end
end
end

function [X,missing] = respondentMatrix(Xin,EstimOpt,missingIn)
X = [];
missing = [];
if isempty(Xin)
    return
end
rowPerP = EstimOpt.NAlt*EstimOpt.NCT;
if size(Xin,1) == EstimOpt.NP
    X = Xin;
elseif size(Xin,1) == rowPerP*EstimOpt.NP
    idx = (1:rowPerP:size(Xin,1))';
    X = Xin(idx,:);
else
    X = Xin;
end
if ~isempty(missingIn)
    if size(missingIn,1) == size(Xin,1) && size(Xin,1) == rowPerP*EstimOpt.NP
        missing = missingIn(idx,:);
    elseif size(missingIn,1) == size(X,1)
        missing = missingIn;
    end
end
end

function valid = validRowsFor(X,validIn)
if nargin < 2 || isempty(validIn) || isscalar(validIn)
    valid = true(size(X,1),1);
elseif numel(validIn) == size(X,1)
    valid = validIn(:);
else
    valid = true(size(X,1),1);
end
valid = valid & all(isfinite(X),2);
end

function names = optNames(EstimOpt,field,n,prefix)
if isfield(EstimOpt,field) && numel(EstimOpt.(field)) == n
    raw = EstimOpt.(field);
    if iscell(raw)
        names = raw(:);
    elseif isnumeric(raw)
        names = cellstr(num2str(raw(:)));
    else
        names = cellstr(raw);
    end
else
    names = strcat(prefix,cellstr(num2str((1:n)')));
end
for i = 1:numel(names)
    if ~ischar(names{i})
        names{i} = char(string(names{i}));
    end
end
end

function value = optNumber(s,field,defaultValue)
if isstruct(s) && isfield(s,field) && ~isempty(s.(field))
    value = s.(field);
else
    value = defaultValue;
end
end

function value = getField(s,field)
if isstruct(s) && isfield(s,field)
    value = s.(field);
else
    value = [];
end
end

function D = addIssue(D,msg)
D.NMessages = D.NMessages + 1;
D.Messages{D.NMessages,1} = msg;
end

function s = valueLabel(x)
s = num2str(x,12);
end

function warnLine(msg)
if exist('cprintf','file') == 2 && exist('rgb','file') == 2
    cprintf(rgb('DarkOrange'),['WARNING: ' msg '\n'])
else
    fprintf(2,'WARNING: %s\n',msg);
end
end
