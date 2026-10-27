function E = dceSimulationDefaults(E)
% Shared defaults; explicit simulation settings are never rounded or replaced.
if ~isfield(E,'Draws') || isempty(E.Draws), E.Draws=6; end
sobol=ismember(E.Draws,[5 6]);
if ~isfield(E,'NRep') || isempty(E.NRep)
    E.NRep=1000;if sobol,E.NRep=1024;end
end
if ~isfield(E,'HaltonSkip') || isempty(E.HaltonSkip)
    E.HaltonSkip=double(~sobol);
end
if ~isfield(E,'HaltonLeap') || isempty(E.HaltonLeap),E.HaltonLeap=0;end
if ~isfield(E,'SobolLayout') || isempty(E.SobolLayout),E.SobolLayout='respondent';end
if ~isfield(E,'Seed1') || isempty(E.Seed1),E.Seed1=179424673;end
end
