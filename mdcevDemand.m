function D = mdcevDemand(logMU,prices,alphas,gammas,income,num)
% Batched budget-equation bisection for a bounded MDCEV prediction block.
income = reshape(income,1,[]);
assert(all(isfinite(income) & income >= 0) && all(isfinite(prices) & prices > 0,'all'),...
    'Tools:MDCEV:Budget','Income must be finite and nonnegative; prices must be finite and positive.');
assert(all(isfinite(alphas) & alphas < 1,'all') && all(isfinite(gammas) & gammas > 0,'all') && all(isfinite(logMU),'all'),...
    'Tools:MDCEV:Utility','Invalid utility-profile parameters or marginal utilities.');
inva = 1./(1-alphas);
high = max(logMU,[],1)+1;
if ~isempty(num), high = min(high,logMU(num,:,:)); end
spend = @(lambda) sum(prices.*gammas.*max(expm1((logMU-lambda).*inva),0),1);
if any(spend(high) > income,'all')
    error('Tools:MDCEV:Numeraire','The requested numeraire cannot be positive in every task/draw of this block.');
end
span = 10; low = high-span;
below = spend(low) < income;
while any(below,'all')
    span = 2*span; low(below) = high(below)-span;
    below = spend(low) < income;
end
for k = 1:80
    mid = (low+high)/2; over = spend(mid) > income;
    low(over) = mid(over); high(~over) = mid(~over);
end
D = gammas.*max(expm1((logMU-(low+high)/2).*inva),0);
end
