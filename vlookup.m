function data_target = vlookup(id_target, id_source, data_source)
% INPUT: id_target, id_source, data_source

[~,idx] = ismember(id_target,id_source);
[~,idx2] = ismember(id_source,id_target);
% data_target = data_source(idx(idx~=0),:);
data_target = zeros(size(id_target,1),size(data_source,2));
data_target(idx2,:) = data_source(idx(idx~=0),:);

% [la,idx] = ismember(id_target,id_source); ...
% data_target = data_source(idx(la),:);