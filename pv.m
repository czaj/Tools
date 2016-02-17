function result = pv(m,s)

s(logical(imag(s)) | s<0) = NaN;

result = (1-normcdf(abs(m)./s,0,1))*2;

% result = NaN(size(m));
% result(~logical(imag(s)) & s>=0) = (1-normcdf(abs(m(~logical(imag(s)) & s>=0))./real(s(~logical(imag(s)) & s>=0)),0,1))*2;    

% if any(s < 0) || ~isreal(s)
%     result = zeros(size(m));    
%     for i = 1:length(m)
%         if s(i) < 0 || ~isreal(s(i))
%             result(i) = NaN;
%         else
%             result(i) = (1-normcdf(abs(m(i))./real(s(i)),0,1))*2;
%         end
%     end
% else
%     result = (1-normcdf(abs(m)./s,0,1))*2;
% end
