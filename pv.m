function result = pv(m,varargin)

if nargin < 1 % check no. of inputs
    error('Too few input arguments')
end

if nargin == 1
    if size(m,2) > 2
        cprintf(rgb('DarkOrange'),'WARNING: using the first 2 columns only \n');
        s = m(:,2);
        m = m(:,1);
    elseif size(m,2) == 2
        s = m(:,2);
        m = m(:,1);
    else 
        error('Too few input arguments - one argument input must have 2+ columns')
    end
else
    m = m(:,1); %data musi be in columns
    s = varargin{1};
end

s(logical(imag(s)) | s < 0) = NaN;

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
