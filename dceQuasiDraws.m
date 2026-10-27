function U = dceQuasiDraws(E,dimension,ids)
% Uniform QMC draws: NRep consecutive rows per requested respondent.
% Sobol respondent scrambles use fixed substreams, independent of NRep/NP.
% SobolLayout='global' restores the historical single-sequence block layout.
E=dceSimulationDefaults(E);
validateattributes(dimension,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(E.NP,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(E.NRep,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(E.Seed1,{'numeric'},{'scalar','integer','nonnegative','<',2^32,'finite'});
validateattributes(E.HaltonSkip,{'numeric'},{'scalar','integer','nonnegative','finite'});
validateattributes(E.HaltonLeap,{'numeric'},{'scalar','integer','nonnegative','finite'});
assert(isscalar(E.Draws) && ismember(E.Draws,3:6),'DCE:Draws:Type','QMC Draws must be 3, 4, 5 or 6.');
assert((ischar(E.SobolLayout) || isstring(E.SobolLayout)) && ...
    ismember(string(E.SobolLayout),["respondent","global"]),'DCE:Draws:Layout','SobolLayout must be respondent or global.');
if nargin<3,ids=1:E.NP;end
validateattributes(ids,{'numeric'},{'vector','integer','positive','<=',E.NP,'finite'});
ids=ids(:)';R=E.NRep;
if E.Draws<5 || strcmp(E.SobolLayout,'global')
    % Retain the old randomization and stream advancement for reproducibility.
    rng(E.Seed1);
    if E.Draws<5
        h=haltonset(dimension,'Skip',E.HaltonSkip,'Leap',E.HaltonLeap);
        if E.Draws==4,h=scramble(h,'RR2');end
    else
        h=sobolset(dimension,'Skip',E.HaltonSkip,'Leap',E.HaltonLeap);
        if E.Draws==6,h=scramble(h,'MatousekAffineOwen');end
    end
    if isequal(ids,1:E.NP),U=net(h,E.NP*R);
    else,indices=(1:R)'+(ids-1)*R;U=h(indices(:),:);end
else
    h=sobolset(dimension,'Skip',E.HaltonSkip,'Leap',E.HaltonLeap);
    if E.Draws==5
        % An explicitly unscrambled rule uses a common deterministic net.
        U=repmat(net(h,R),numel(ids),1);
    else
        previous=RandStream.getGlobalStream;
        restore=onCleanup(@() RandStream.setGlobalStream(previous)); %#ok<NASGU>
        stream=RandStream('mrg32k3a','Seed',E.Seed1);
        RandStream.setGlobalStream(stream);
        U=zeros(numel(ids)*R,dimension);
        for k=1:numel(ids)
            stream.Substream=ids(k);
            randomNet=scramble(h,'MatousekAffineOwen');
            U((k-1)*R+(1:R),:)=net(randomNet,R);
        end
    end
end
assert(all(isfinite(U),'all') && all(U>=0 & U<=1,'all'),'DCE:Draws:Range','Invalid uniform QMC points.');
% Do not drop a Sobol point to avoid infinite inverse-CDF values.
U(U==0)=eps/2;U(U==1)=1-eps/2;
end
