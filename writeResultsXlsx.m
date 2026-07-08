function fullSaveName = writeResultsXlsx(EstimOpt,Results,ResultsOut,fileBase,saveDir)
% writeResultsXlsx saves model output as a macro-free formatted .xlsx file.

if nargin < 5 || isempty(saveDir)
    saveDir = pwd;
end
if ~exist(saveDir,'dir')
    mkdir(saveDir);
end

fileBase = safeExcelFileBase(fileBase);
fullSaveName = fullfile(saveDir,[fileBase '.xlsx']);

try
    runningExcel = [];
    try
        runningExcel = actxGetRunningServer('Excel.Application');
    catch
    end

    excel = actxserver('Excel.Application');
    excel.Visible = 0;
    excel.DisplayAlerts = 0;

    excelWorkbook = excel.Workbooks.Add;
    trimDefaultSheets(excelWorkbook);

    excelSheet1 = excelWorkbook.Sheets.get('Item',1);
    excelSheet1.Name = 'Results';
    excelSheet1.Activate;
    writeCellBlock(excelSheet1,ResultsOut);
    formatResultsSheet(excelSheet1,ResultsOut);

    addTextFileSheet(excelWorkbook,'Script',getSourceFile(EstimOpt));
    addTextFileSheet(excelWorkbook,'Log',getLogFile(EstimOpt,Results,saveDir));
    addWordResultsSheets(excelWorkbook,ResultsOut);
    excelSheet1.Activate;

    fullSaveName = resolveSaveName(fullSaveName,EstimOpt,runningExcel);
    excelWorkbook.ConflictResolution = 2;
    SaveAs(excelWorkbook,fullSaveName,51); % 51 = xlOpenXMLWorkbook (.xlsx, no macros)
    excelWorkbook.Saved = 1;
    Close(excelWorkbook)
    Quit(excel)
    delete(excel)
catch ME
    warning('writeResultsXlsx:ExcelExportFailed', ...
        'Excel export failed: %s', getReport(ME,'extended','hyperlinks','off'));

    try
        if exist('excelWorkbook','var')
            Close(excelWorkbook,false);
        end
    catch
    end

    try
        if exist('excel','var')
            Quit(excel);
            delete(excel);
        end
    catch
    end

    rethrow(ME)
end
end

function trimDefaultSheets(excelWorkbook)
while excelWorkbook.Sheets.Count > 1
    excelWorkbook.Sheets.Item(excelWorkbook.Sheets.Count).Delete;
end
end

function writeCellBlock(sheet,content)
if isempty(content)
    sheet.Range('A1').Value = '';
    return
end

rangeName = ['A1:' excelColumnName(size(content,2)) num2str(size(content,1))];
sheet.Range(rangeName).Value = content;
end

function formatResultsSheet(sheet,content)
usedRange = sheet.UsedRange;
usedRange.Font.Name = 'Calibri';
usedRange.Font.Size = 10;
try
    usedRange.Borders.LineStyle = 1;
    usedRange.Borders.ColorIndex = 15;
catch
end
try
    sheet.Rows.Item(1).Font.Bold = 1;
    sheet.Rows.Item(2).Font.Bold = 1;
catch
end
formatSelectedNumbers(sheet,content);
try
    sheet.Columns.AutoFit;
catch
end
end

function formatSelectedNumbers(sheet,content)
for row = 1:size(content,1)
    for col = 1:size(content,2)
        value = content{row,col};
        if isnumeric(value) && isscalar(value) && isfinite(value) && shouldUseFourDecimals(content,row,col)
            sheet.Range([excelColumnName(col) num2str(row)]).NumberFormat = '0.0000';
        end
    end
end
end

function tf = shouldUseFourDecimals(content,row,col)
tf = isDiagnosticRow(content,row) || isEstimateColumn(content,row,col);
end

function tf = isEstimateColumn(content,row,col)
tf = false;
for headerRow = row-1:-1:1
    header = cellText(content{headerRow,col});
    if any(strcmpi(header,{'coef.','st.err.','p-value'}))
        tf = true;
        return
    end
end
end

function tf = isDiagnosticRow(content,row)
if size(content,2) < 2
    tf = false;
    return
end
label = lower(cellText(content{row,1}));
tf = contains(label,'ll at convergence') || ...
     contains(label,'ll at constant') || ...
     contains(label,'mcfadden') || ...
     contains(label,'ben-akiva') || ...
     strcmp(label,'aic/n') || ...
     strcmp(label,'bic/n');
end

function addWordResultsSheets(excelWorkbook,content)
rows2 = makeWordResults(content,2);
rows4 = makeWordResults(content,4);
if isempty(rows2)
    return
end
addWordResultsSheet(excelWorkbook,'Word 2dp',rows2);
addWordResultsSheet(excelWorkbook,'Word 4dp',rows4);
end

function addWordResultsSheet(excelWorkbook,sheetName,rows)
sheet = excelWorkbook.Sheets.Add([],excelWorkbook.Sheets.Item(excelWorkbook.Sheets.Count));
sheet.Name = safeSheetName(sheetName);
sheet.Columns.Item(1).NumberFormat = '@';
sheet.Range(['A1:A' num2str(numel(rows))]).Value = rows(:);
sheet.Cells.Font.Name = 'Calibri';
sheet.Cells.Font.Size = 10;
sheet.Columns.Item(1).ColumnWidth = 16;
sheet.Columns.Item(1).WrapText = 1;
sheet.Columns.Item(1).VerticalAlignment = -4160; % xlTop
end

function rows = makeWordResults(content,digits)
rows = {};
for headerRow = 1:size(content,1)
    for col = 1:max(0,size(content,2)-2)
        if isCoefHeader(content,headerRow,col)
            rows = [rows; collectWordResultsForColumn(content,headerRow,col,digits)]; %#ok<AGROW>
        end
    end
end
end

function tf = isCoefHeader(content,row,col)
tf = strcmpi(cellText(content{row,col}),'coef.') && ...
     col + 2 <= size(content,2) && ...
     strcmpi(cellText(content{row,col+2}),'st.err.');
end

function rows = collectWordResultsForColumn(content,headerRow,col,digits)
rows = {};
for row = headerRow+1:size(content,1)
    if any(cellfun(@(x) strcmpi(cellText(x),'coef.'),content(row,:)))
        break
    end
    coef = content{row,col};
    se = content{row,col+2};
    if isnumeric(coef) && isscalar(coef) && isfinite(coef) && ...
            isnumeric(se) && isscalar(se) && isfinite(se)
        stars = strtrim(cellText(content{row,col+1}));
        if isempty(stars) && col + 3 <= size(content,2)
            stars = starsFromP(content{row,col+3});
        end
        rows(end+1,1) = {[formatNumber(coef,digits) stars newline '(' formatNumber(se,digits) ')']}; %#ok<AGROW>
    end
end
end

function txt = formatNumber(value,digits)
if abs(value) < 0.5 * 10^-digits
    value = 0;
end
txt = sprintf(['%0.' num2str(digits) 'f'],value);
end

function stars = starsFromP(value)
stars = '';
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    return
end
if value <= 0.01
    stars = '***';
elseif value <= 0.05
    stars = '**';
elseif value <= 0.1
    stars = '*';
end
end

function txt = cellText(value)
if ischar(value)
    txt = strtrim(value);
elseif isstring(value) && isscalar(value)
    txt = strtrim(char(value));
else
    txt = '';
end
end

function addTextFileSheet(excelWorkbook,sheetName,filePath)
if isempty(filePath) || exist(filePath,'file') ~= 2
    return
end

sheet = excelWorkbook.Sheets.Add([],excelWorkbook.Sheets.Item(excelWorkbook.Sheets.Count));
sheet.Name = safeSheetName(sheetName);
sheet.Columns.Item(1).NumberFormat = '@';

try
    text = fileread(filePath);
catch readError
    text = sprintf('[Could not read %s: %s]',filePath,readError.message);
end
text = strrep(text,char(0),'');
lines = regexp(text,'\r\n|\n|\r','split')';
if isempty(lines)
    lines = {''};
end

lines = [{['File: ' filePath]; ''}; lines(:)];
maxRows = 1048576;
if numel(lines) > maxRows
    lines = [{'[Truncated to Excel row limit.]'}; lines(end-maxRows+2:end)];
end

sheet.Range(['A1:A' num2str(numel(lines))]).Value = lines;
sheet.Cells.Font.Name = 'Consolas';
sheet.Cells.Font.Size = 9;
sheet.Columns.Item(1).ColumnWidth = 160;
sheet.Columns.Item(1).WrapText = 0;
end

function filePath = getOptionFile(EstimOpt,fieldNames)
filePath = '';
for i = 1:numel(fieldNames)
    if isfield(EstimOpt,fieldNames{i}) && ~isempty(EstimOpt.(fieldNames{i}))
        candidate = char(string(EstimOpt.(fieldNames{i})));
        if exist(candidate,'file') == 2
            filePath = candidate;
            return
        end
    end
end
end

function filePath = getSourceFile(EstimOpt)
filePath = getOptionFile(EstimOpt,{'SourceScript','ScriptFile','ScriptPath'});
if isempty(filePath)
    filePath = inferSourceScript();
end
end

function filePath = getLogFile(EstimOpt,Results,saveDir)
filePath = getOptionFile(EstimOpt,{'OutputLogFile','DiaryFile','LogFile'});
if ~isempty(filePath)
    return
end
filePath = currentDiaryFile();
if ~isempty(filePath) && exist(filePath,'file') == 2
    return
end
if isstruct(Results) && isfield(Results,'output_txt') && ~isempty(Results.output_txt)
    candidate = char(string(Results.output_txt));
    if exist(candidate,'file') == 2
        filePath = candidate;
        return
    end
end
filePath = newestOutputLog(EstimOpt,saveDir);
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

function filePath = newestOutputLog(EstimOpt,saveDir)
filePath = '';
if isfield(EstimOpt,'OutputDir') && ~isempty(EstimOpt.OutputDir)
    logDir = char(string(EstimOpt.OutputDir));
else
    logDir = saveDir;
end
if exist(logDir,'dir') ~= 7
    return
end

files = dir(fullfile(logDir,'*.txt'));
if isempty(files)
    return
end

sourceFile = getSourceFile(EstimOpt);
if ~isempty(sourceFile)
    [~,sourceBase] = fileparts(sourceFile);
    matches = contains({files.name},sourceBase,'IgnoreCase',true);
    if any(matches)
        files = files(matches);
    end
end

[~,idx] = max([files.datenum]);
filePath = fullfile(logDir,files(idx).name);
end

function fullSaveName = resolveSaveName(fullSaveName,EstimOpt,runningExcel)
if isfield(EstimOpt,'xlsOverwrite') && EstimOpt.xlsOverwrite == 0
    fullSaveName = nextAvailableName(fullSaveName);
elseif isfield(EstimOpt,'xlsOverwrite') && EstimOpt.xlsOverwrite == 1 ...
        && ~isempty(runningExcel) && workbookIsOpen(runningExcel,fullSaveName)
    fullSaveName = nextAvailableName(fullSaveName);
end
end

function tf = workbookIsOpen(excelApp,fullSaveName)
tf = false;
wbs = excelApp.Workbooks;
for i = 1:wbs.Count
    if strcmpi(char(wbs.Item(i).FullName),fullSaveName)
        tf = true;
        return
    end
end
end

function fileName = nextAvailableName(fileName)
[folder,baseName,ext] = fileparts(fileName);
i = 1;
while exist(fileName,'file') == 2
    fileName = fullfile(folder,sprintf('%s(%d)%s',baseName,i,ext));
    i = i + 1;
end
end

function columnName = excelColumnName(column)
columnName = '';
while column > 0
    modulo = mod(column - 1,26);
    columnName = [char(65 + modulo) columnName]; %#ok<AGROW>
    column = floor((column - modulo) / 26);
end
end

function sourceScript = inferSourceScript()
sourceScript = '';
stack = dbstack('-completenames');
skipFiles = {'writeResultsXlsx.m','genOutput.m','genOutput_LCMXL.m', ...
    'setupDceOutputDefaults.m','DataCleanDCE.m','DataCleanDCE2.m','DataCleanDCE_MDCEV.m'};
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

function fileBase = safeExcelFileBase(fileBase)
fileBase = char(string(fileBase));
fileBase = regexprep(fileBase,'[\r\n\t]+',' ');
fileBase = regexprep(fileBase,'[<>:"/\\|?*]+',' - ');
fileBase = regexprep(fileBase,'\s+',' ');
fileBase = strtrim(fileBase);
fileBase = regexprep(fileBase,'[\. ]+$','');
if isempty(fileBase)
    fileBase = 'results';
end
maxLen = 150;
if length(fileBase) > maxLen
    fileBase = strtrim(fileBase(1:maxLen));
    fileBase = regexprep(fileBase,'[\. ]+$','');
end
end

function sheetName = safeSheetName(sheetName)
sheetName = char(string(sheetName));
sheetName = regexprep(sheetName,'[\[\]\:\*\?\/\\]+','_');
sheetName = strtrim(sheetName);
if isempty(sheetName)
    sheetName = 'Sheet';
end
sheetName = sheetName(1:min(31,length(sheetName)));
end
