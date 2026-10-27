function test_dceQuasiDraws
E=dceSimulationDefaults(struct('NP',3));
assert(E.Draws==6 && E.NRep==1024 && E.HaltonSkip==0 && E.HaltonLeap==0 && strcmp(E.SobolLayout,'respondent'));
E.NRep=32;E.Seed1=317;before=rng;U=dceQuasiDraws(E,4);assert(isequal(before,rng));
E.NRep=64;V=dceQuasiDraws(E,4);
for n=1:3
    u=U((n-1)*32+(1:32),:);assert(isequal(u,V((n-1)*64+(1:32),:)));
    for j=1:4,assert(all(histcounts(u(:,j),(0:32)/32)==1));end
end
assert(~isequal(U(1:32,:),U(33:64,:)));
assert(isequal(dceQuasiDraws(E,4,[3 1]),[V(129:192,:);V(1:64,:)]));
E.NP=4;W=dceQuasiDraws(E,4);assert(isequal(V,W(1:192,:)));
E.Seed1=318;assert(~isequal(W,dceQuasiDraws(E,4)));
E.NRep=1000;explicit=dceSimulationDefaults(E);assert(explicit.NRep==1000);
assert(isequal(size(dceQuasiDraws(E,2)),[4000 2]));
for type=[3 4 5 6]
    e=struct('NP',3,'NRep',16,'Draws',type,'Seed1',17,'HaltonSkip',1,'HaltonLeap',0,'SobolLayout','global');
    rng(e.Seed1);
    if type<5,h=haltonset(3,'Skip',1);else,h=sobolset(3,'Skip',1);end
    if type==4,h=scramble(h,'RR2');elseif type==6,h=scramble(h,'MatousekAffineOwen');end
    old=net(h,48);assert(isequal(old,dceQuasiDraws(e,3)));
    assert(isequal(old(17:32,:),dceQuasiDraws(e,3,2)));
end
E.Draws=5;E.NRep=32;E.HaltonSkip=0;
U=dceQuasiDraws(E,3);assert(all(U>0 & U<1,'all') && all(isfinite(norminv(U)),'all'));
assert(isequal(U(1:32,:),U(33:64,:)) && U(1,1)==eps/2);
E=dceSimulationDefaults(struct('Draws',3));assert(E.NRep==1000 && E.HaltonSkip==1);
fprintf('QMC_DEFAULTS_PREFIX_BALANCE_SEED_BLOCK_LEGACY_ENDPOINT_TESTS_PASS\n');
end
