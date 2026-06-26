function stop = outputf(x,optimvalues,state)
global B_backup
persistent LL_backup IterTime

% outputf prints per-iteration optimizer progress and keeps B_backup current.
% Date/time is the wall-clock time at which the row was printed.

stop = false;

if nargin < 3
    return
end

switch state
    case 'init'
        disp('')
        fprintf('%6s %6s %15s %15s %19s %15s %15s %10s   %19s  %s\n', ...
            'Iter.','Eval.','max|dB|','Step','f(x)','df prev','Opt. Cond.','Iter sec','Date/time','Procedure');
        LL_backup = NaN;
        B_backup = x;
        IterTime = tic;

    case 'iter'
        if isempty(IterTime)
            IterTocNote = NaN;
        else
            IterTocNote = toc(IterTime);
        end

        iteration = get_optim_field(optimvalues,'iteration',NaN);
        funccount = get_optim_field(optimvalues,'funccount',NaN);
        stepsize = get_optim_field(optimvalues,'stepsize',NaN);
        fval = get_optim_field(optimvalues,'fval',NaN);
        firstorderopt = get_optim_field(optimvalues,'firstorderopt',NaN);
        procedure = get_optim_field(optimvalues,'procedure','');
        nowstr = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));

        if iteration == 0 || isempty(B_backup) || any(size(B_backup) ~= size(x))
            dB = NaN;
            df = NaN;
        else
            dB = max(abs(x(:) - B_backup(:)));
            df = LL_backup - fval;
        end

        if ~(ischar(procedure) || isstring(procedure)) || isempty(procedure)
            procedure = '-';
        end
        fprintf('%6d %6d %15.10f %15.10f %19.10f %15.10f %15.10f %10.4f   %19s  %s\n', ...
            iteration,funccount,dB,stepsize,fval,df,firstorderopt,IterTocNote,nowstr,char(procedure));

        B_backup = x;
        LL_backup = fval;
        IterTime = tic;

    case 'done'
        IterTime = [];
end
end

function value = get_optim_field(s,field,defaultValue)
if isstruct(s) && isfield(s,field) && ~isempty(s.(field))
    value = s.(field);
else
    value = defaultValue;
end
end
