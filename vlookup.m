function data_target = vlookup(id_target, id_source, data_source)

[~,idx] = ismember(id_target,id_source);
data_target = data_source(idx(idx~=0),:);

% [la,idx] = ismember(id_target,id_source); ...
% data_target = data_source(idx(la),:);