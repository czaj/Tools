function EstimOpt = setupDceOutputDefaults(EstimOpt)
% setupDceOutputDefaults detects the calling script and keeps one script diary.

if nargin < 1 || isempty(EstimOpt)
    EstimOpt = struct();
end

if ~isfield(EstimOpt,'SourceScript') || isempty(EstimOpt.SourceScript)
    sourceScript = inferSourceScript();
    if ~isempty(sourceScript)
        EstimOpt.SourceScript = sourceScript;
    end
else
    sourceScript = char(string(EstimOpt.SourceScript));
end

if ~isfield(EstimOpt,'OutputDir') || isempty(EstimOpt.OutputDir)
    if ~isempty(sourceScript) && exist(sourceScript,'file') == 2
        EstimOpt.OutputDir = fullfile(fileparts(sourceScript),'output');
    else
        EstimOpt.OutputDir = fullfile(pwd,'output');
    end
end
if ~exist(EstimOpt.OutputDir,'dir')
    mkdir(EstimOpt.OutputDir);
end

currentDiary = currentDiaryFile();
if ~isempty(currentDiary)
    if isfield(EstimOpt,'OutputLogFile') && ~isempty(EstimOpt.OutputLogFile)
        requestedDiary = absolutePath(char(string(EstimOpt.OutputLogFile)));
        if strcmpi(absolutePath(currentDiary),requestedDiary)
            return
        end
        diary off;
    elseif isAutoDiary(currentDiary)
        diary off;
    else
        EstimOpt.OutputLogFile = currentDiary;
        return
    end
end

if isfield(EstimOpt,'SaveTxtOutput') && isequal(EstimOpt.SaveTxtOutput,0)
    return
end

if isfield(EstimOpt,'OutputLogFile') && ~isempty(EstimOpt.OutputLogFile)
    logFile = char(string(EstimOpt.OutputLogFile));
else
    if ~isempty(sourceScript) && exist(sourceScript,'file') == 2
        [~,scriptBase] = fileparts(sourceScript);
    else
        scriptBase = 'DCE';
    end
    logFile = fullfile(EstimOpt.OutputDir,[safeFileName(scriptBase) '_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.txt']);
    EstimOpt.OutputLogFile = logFile;
end

logDir = fileparts(logFile);
if ~isempty(logDir) && exist(logDir,'dir') ~= 7
    mkdir(logDir);
end
if exist(logFile,'file') == 2
    delete(logFile);
end
diary(logFile);
diary on;
setappdata(0,'DCEAutoDiaryFile',absolutePath(logFile));
fprintf('DCE screen output is being saved to: %s\n',logFile);
end

function tf = isAutoDiary(filePath)
tf = false;
try
    if isappdata(0,'DCEAutoDiaryFile')
        tf = strcmpi(absolutePath(filePath),absolutePath(getappdata(0,'DCEAutoDiaryFile')));
    end
catch
    tf = false;
end
end

function filePath = currentDiaryFile()
filePath = '';
try
    if strcmpi(get(0,'Diary'),'on')
        filePath = char(get(0,'DiaryFile'));
        if ~isempty(filePath)
            [folder,~,~] = fileparts(filePath);
            if isempty(folder)
                filePath = fullfile(pwd,filePath);
            end
        end
    end
catch
    filePath = '';
end
end

function filePath = absolutePath(filePath)
filePath = char(string(filePath));
[folder,name,ext] = fileparts(filePath);
if isempty(folder)
    filePath = fullfile(pwd,[name ext]);
end
end

function sourceScript = inferSourceScript()
sourceScript = '';
stack = dbstack('-completenames');
skipFiles = {'setupDceOutputDefaults.m','DataCleanDCE.m','DataCleanDCE2.m', ...
    'DataCleanDCE_MDCEV.m','DataCleanCDM.m','CDM.m','CDM_hurdle.m','CDM_post.m','writeResultsXlsx.m','genOutput.m','genOutput_LCMXL.m'};
for i = numel(stack):-1:1
    filePath = stack(i).file;
    if isempty(filePath) || exist(filePath,'file') ~= 2
        continue
    end
    [~,fileName,ext] = fileparts(filePath);
    if any(strcmpi([fileName ext],skipFiles))
        continue
    end
    sourceScript = filePath;
    return
end
end

function fileBase = safeFileName(fileBase)
fileBase = char(string(fileBase));
fileBase = regexprep(fileBase,'[\r\n\t]+',' ');
fileBase = regexprep(fileBase,'[<>:"/\\|?*]+',' - ');
fileBase = regexprep(fileBase,'\s+',' ');
fileBase = regexprep(strtrim(fileBase),'[\. ]+$','');
if isempty(fileBase)
    fileBase = 'DCE';
end
end
