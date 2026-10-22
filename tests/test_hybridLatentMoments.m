function test_hybridLatentMoments
X = [ones(7,1),reshape(sin(1:21),7,3)];
E = reshape(cos(1:105),3,35);
m = hybridLatentMoments(X,E,5);
Z = [repelem(X,5,1)';E];
assert(max(abs(m.mean-mean(Z,2))) < 1e-14);
assert(max(abs(m.covariance-cov(Z')),[],'all') < 1e-14);
A = reshape(sin(1:14),2,7);
raw = A*Z;
s = sqrt(sum((A*m.covariance).*A,2));
assert(max(abs(s-std(raw,0,2))) < 1e-14);
% Derivatives must use moments from the whole sample, including a singleton block.
lv = (raw-A*m.mean)./s;
for k = 1:numel(A)
    [i,j] = ind2sub(size(A),k);
    h = 1e-5; ap = A; am = A; ap(k) = ap(k)+h; am(k) = am(k)-h;
    fp = ap*Z; fp = (fp-mean(fp,2))./std(fp,0,2);
    fm = am*Z; fm = (fm-mean(fm,2))./std(fm,0,2);
    expected = (Z(j,:)-m.mean(j)-lv(i,:)*(A(i,:)*m.covariance(:,j))/s(i))/s(i);
    assert(max(abs((fp(i,:)-fm(i,:))/(2*h)-expected)) < 1e-8);
end
fprintf('hybridLatentMoments: exact pooled moments and derivatives passed.\n');
end
