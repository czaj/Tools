function fullSaveName = writeResultsXlsx(EstimOpt,Results,ResultsOut,fileBase,saveDir)
% writeResultsXlsx saves model output as a macro-free formatted .xlsx file with
% the sheets Results (the formatted results table), Script and Log (the calling
% script and the screen output) and Word 2dp / Word 4dp (each estimate with its
% significance stars and standard error in one cell, for pasting into Word).
%
% EstimOpt.XlsxEngine selects how the file is written:
%   'native' (default) - the .xlsx file (Office Open XML) is written directly.
%                        No Excel is needed; works on all platforms, in several
%                        MATLAB sessions at the same time and in non-interactive
%                        sessions (e.g. jobs started over SSH or as a service).
%   'excel'            - Excel through COM automation (Windows with Excel only);
%                        falls back to 'native' if Excel fails.
% The estimation results never depend on this file: if writing fails, a warning
% is issued and an empty name is returned.

if nargin < 5 || isempty(saveDir)
    saveDir = pwd;
end
if ~exist(saveDir,'dir')
    mkdir(saveDir);
end

fileBase = safeExcelFileBase(fileBase);
fullSaveName = fullfile(saveDir,[fileBase '.xlsx']);

engine = 'native';
if isfield(EstimOpt,'XlsxEngine') && ~isempty(EstimOpt.XlsxEngine)
    engine = lower(char(string(EstimOpt.XlsxEngine)));
end

if strcmp(engine,'excel') && ispc
    try
        fullSaveName = writeWithExcel(EstimOpt,Results,ResultsOut,saveDir,fullSaveName);
        return
    catch ME
        warning('writeResultsXlsx:ExcelExportFailed', ...
            'Excel export failed (writing the file without Excel instead): %s', ME.message);
    end
end

try
    fullSaveName = writeNative(EstimOpt,Results,ResultsOut,saveDir,fullSaveName);
catch ME
    warning('writeResultsXlsx:ExportFailed','Writing %s failed: %s', fullSaveName, ME.message);
    fullSaveName = '';
end
end

function fullSaveName = writeWithExcel(EstimOpt,Results,ResultsOut,saveDir,fullSaveName)
% Excel through COM; closes Excel and rethrows on failure
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
    'setupDceOutputDefaults.m','DataCleanDCE.m','DataCleanDCE2.m','DataCleanDCE_MDCEV.m','DataCleanCDM.m','CDM.m','CDM_hurdle.m','CDM_post.m'};
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

%% ---------------------------------------------------------------------------
%% Writing the .xlsx file without Excel (Office Open XML, ECMA-376)
%% The sheets and formats follow the Excel version above: Results (Calibri 10,
%% thin grey borders on the used range, bold first two rows, 0.0000 for
%% estimates and diagnostics, fitted column widths), Script and Log (text,
%% Consolas 9, width 160), Word 2dp / Word 4dp (text, wrapped, top-aligned).

function fullSaveName = writeNative(EstimOpt,Results,ResultsOut,saveDir,fullSaveName)
if isempty(ResultsOut)
    ResultsOut = {''};
end
sheets = resultsSheet(ResultsOut);
lines = textFileLines(getSourceFile(EstimOpt));
if ~isempty(lines)
    sheets(end+1) = textSheet('Script',lines);
end
lines = textFileLines(getLogFile(EstimOpt,Results,saveDir));
if ~isempty(lines)
    sheets(end+1) = textSheet('Log',lines);
end
rows2 = makeWordResults(ResultsOut,2);
if ~isempty(rows2)
    sheets(end+1) = wordSheet('Word 2dp',rows2);
    sheets(end+1) = wordSheet('Word 4dp',makeWordResults(ResultsOut,4));
end

if isfield(EstimOpt,'xlsOverwrite') && EstimOpt.xlsOverwrite == 0
    fullSaveName = nextAvailableName(fullSaveName);
end
tmpFile = [tempname '.xlsx'];
cleanupTmp = onCleanup(@() deleteIfExists(tmpFile));
writeXlsxPackage(tmpFile,sheets);
[ok,msg] = movefile(tmpFile,fullSaveName,'f');
if ~ok % e.g. the file is open in Excel
    altName = nextAvailableName(fullSaveName);
    [ok,msg2] = movefile(tmpFile,altName,'f');
    if ~ok
        error('%s %s',msg,msg2);
    end
    warning('writeResultsXlsx:Renamed','%s could not be replaced (%s); saved as %s.',fullSaveName,msg,altName);
    fullSaveName = altName;
end
end

function S = resultsSheet(content)
[nr,nc] = size(content);
style = ones(nr,nc);          % 1: thin grey borders on the whole block
style(1:min(2,nr),:) = 2;     % 2: bold first two rows
widths = zeros(1,nc);
for row = 1:nr
    for col = 1:nc
        value = content{row,col};
        if isnumeric(value) && isscalar(value) && isfinite(value) && shouldUseFourDecimals(content,row,col)
            style(row,col) = style(row,col) + 2;   % 3, 4: four decimals
            len = numel(sprintf('%.4f',value));
        else
            len = numel(displayText(value));
        end
        widths(col) = max(widths(col),len);
    end
end
widths(widths > 0) = min(max(1.1*widths(widths > 0) + 1.5,4),100); % fitted widths (Calibri 10)
S = sheetStruct('Results',content,style,widths);
end

function S = textSheet(sheetName,lines)
S = sheetStruct(sheetName,lines(:),5*ones(numel(lines),1),160); % 5: text, Consolas 9
end

function S = wordSheet(sheetName,rows)
S = sheetStruct(sheetName,rows(:),6*ones(numel(rows),1),16);    % 6: text, wrapped, top
end

function S = sheetStruct(sheetName,cells,style,widths)
S = struct('name',safeSheetName(sheetName),'cells',{cells},'style',style,'widths',widths);
end

function lines = textFileLines(filePath)
lines = {};
if isempty(filePath) || exist(filePath,'file') ~= 2
    return
end
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
end

function txt = displayText(value)
if ischar(value)
    txt = value(:)';
elseif isstring(value) && isscalar(value)
    txt = char(value);
elseif (isnumeric(value) || islogical(value)) && isscalar(value) && isreal(value)
    txt = sprintf('%.10g',double(value));
else
    txt = '';
end
end

function writeXlsxPackage(fileName,sheets)
root = tempname;
mkdir(fullfile(root,'_rels'));
mkdir(fullfile(root,'xl','_rels'));
mkdir(fullfile(root,'xl','worksheets'));
cleanupRoot = onCleanup(@() rmdir(root,'s'));

nSheets = numel(sheets);
strings = containers.Map('KeyType','char','ValueType','double');
nRefs = 0;
files = {'[Content_Types].xml','_rels/.rels','xl/workbook.xml','xl/_rels/workbook.xml.rels', ...
         'xl/styles.xml','xl/sharedStrings.xml'};
for k = 1:nSheets
    [xml,n] = worksheetXml(sheets(k),strings,k == 1);
    nRefs = nRefs + n;
    writeUtf8(fullfile(root,'xl','worksheets',sprintf('sheet%d.xml',k)),xml);
    files{end+1} = sprintf('xl/worksheets/sheet%d.xml',k); %#ok<AGROW>
end

hdr = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
ns = 'http://schemas.openxmlformats.org';
sheetTypes = sprintf(['<Override PartName="/xl/worksheets/sheet%d.xml" ContentType="application/' ...
    'vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'],1:nSheets);
writeUtf8(fullfile(root,'[Content_Types].xml'),[hdr '<Types xmlns="' ns '/package/2006/content-types">' ...
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' ...
    '<Default Extension="xml" ContentType="application/xml"/>' ...
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' ...
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' ...
    '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>' ...
    sheetTypes '</Types>']);
writeUtf8(fullfile(root,'_rels','.rels'),[hdr '<Relationships xmlns="' ns '/package/2006/relationships">' ...
    '<Relationship Id="rId1" Type="' ns '/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' ...
    '</Relationships>']);
sheetList = '';
rels = '';
for k = 1:nSheets
    sheetList = [sheetList sprintf('<sheet name="%s" sheetId="%d" r:id="rId%d"/>',xmlEscape(sheets(k).name),k,k)]; %#ok<AGROW>
    rels = [rels sprintf('<Relationship Id="rId%d" Type="%s/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet%d.xml"/>',k,ns,k)]; %#ok<AGROW>
end
writeUtf8(fullfile(root,'xl','workbook.xml'),[hdr '<workbook xmlns="' ns '/spreadsheetml/2006/main" ' ...
    'xmlns:r="' ns '/officeDocument/2006/relationships"><bookViews><workbookView activeTab="0"/></bookViews>' ...
    '<sheets>' sheetList '</sheets></workbook>']);
rels = [rels sprintf('<Relationship Id="rId%d" Type="%s/officeDocument/2006/relationships/styles" Target="styles.xml"/>',nSheets+1,ns)];
rels = [rels sprintf('<Relationship Id="rId%d" Type="%s/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>',nSheets+2,ns)];
writeUtf8(fullfile(root,'xl','_rels','workbook.xml.rels'),[hdr '<Relationships xmlns="' ns '/package/2006/relationships">' rels '</Relationships>']);
writeUtf8(fullfile(root,'xl','styles.xml'),[hdr stylesXml(ns)]);

% shared strings in index order
if strings.Count > 0
    keys = strings.keys;
    idx = cell2mat(strings.values(keys));
    [~,order] = sort(idx);
    si = cellfun(@(t) ['<si><t xml:space="preserve">' xmlEscape(t) '</t></si>'],keys(order),'UniformOutput',false);
    si = [si{:}];
else
    si = '';
end
writeUtf8(fullfile(root,'xl','sharedStrings.xml'),[hdr '<sst xmlns="' ns '/spreadsheetml/2006/main" ' ...
    sprintf('count="%d" uniqueCount="%d">',nRefs,strings.Count) si '</sst>']);

zipName = [tempname '.zip'];
zip(zipName,files,root);
[ok,msg] = movefile(zipName,fileName,'f');
if ~ok
    error('%s',msg);
end
end

function [xml,nRefs] = worksheetXml(S,strings,selected)
[nr,nc] = size(S.cells);
nRefs = 0;
colNames = arrayfun(@excelColumnName,1:max(nc,1),'UniformOutput',false);
rowXml = cell(nr,1);
for r = 1:nr
    rs = sprintf('%d',r);
    parts = cell(1,nc);
    for c = 1:nc
        ref = [colNames{c} rs];
        st = S.style(r,c);
        if st > 0
            sAttr = sprintf(' s="%d"',st);
        else
            sAttr = '';
        end
        value = S.cells{r,c};
        if (isnumeric(value) || islogical(value)) && isscalar(value) && isreal(value) && isfinite(value)
            parts{c} = sprintf('<c r="%s"%s><v>%.17g</v></c>',ref,sAttr,double(value));
            continue
        end
        txt = displayText(value);      % text; non-finite numbers as NaN / Inf
        txt = regexprep(txt,'[\x00-\x08\x0B\x0C\x0E-\x1F]','');
        if numel(txt) > 32767
            txt = txt(1:32767);
        end
        if isempty(txt)
            if st > 0
                parts{c} = sprintf('<c r="%s"%s/>',ref,sAttr);
            else
                parts{c} = '';
            end
            continue
        end
        if isKey(strings,txt)
            k = strings(txt);
        else
            k = strings.Count;
            strings(txt) = k;
        end
        nRefs = nRefs + 1;
        parts{c} = sprintf('<c r="%s"%s t="s"><v>%d</v></c>',ref,sAttr,k);
    end
    rowXml{r} = ['<row r="' rs '">' [parts{:}] '</row>'];
end
cols = '';
for c = 1:numel(S.widths)
    if S.widths(c) > 0
        cols = [cols sprintf('<col min="%d" max="%d" width="%.2f" customWidth="1"/>',c,c,S.widths(c))]; %#ok<AGROW>
    end
end
if ~isempty(cols)
    cols = ['<cols>' cols '</cols>'];
end
if selected
    view = '<sheetView tabSelected="1" workbookViewId="0"/>';
else
    view = '<sheetView workbookViewId="0"/>';
end
ns = 'http://schemas.openxmlformats.org';
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<worksheet xmlns="' ns '/spreadsheetml/2006/main" xmlns:r="' ns '/officeDocument/2006/relationships">' ...
    '<dimension ref="A1:' colNames{max(nc,1)} sprintf('%d',max(nr,1)) '"/>' ...
    '<sheetViews>' view '</sheetViews><sheetFormatPr defaultRowHeight="12.75"/>' cols ...
    '<sheetData>' [rowXml{:}] '</sheetData></worksheet>'];
end

function xml = stylesXml(ns)
% cell formats: 0 default, 1 results (borders), 2 results bold, 3 results 0.0000,
% 4 results bold 0.0000, 5 text Consolas 9, 6 text wrapped and top-aligned
border = ['<left style="thin"><color rgb="FFC0C0C0"/></left><right style="thin"><color rgb="FFC0C0C0"/></right>' ...
    '<top style="thin"><color rgb="FFC0C0C0"/></top><bottom style="thin"><color rgb="FFC0C0C0"/></bottom><diagonal/>'];
xml = ['<styleSheet xmlns="' ns '/spreadsheetml/2006/main">' ...
    '<numFmts count="1"><numFmt numFmtId="164" formatCode="0.0000"/></numFmts>' ...
    '<fonts count="3"><font><sz val="10"/><name val="Calibri"/><family val="2"/></font>' ...
    '<font><b/><sz val="10"/><name val="Calibri"/><family val="2"/></font>' ...
    '<font><sz val="9"/><name val="Consolas"/><family val="3"/></font></fonts>' ...
    '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>' ...
    '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border>' border '</border></borders>' ...
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' ...
    '<cellXfs count="7">' ...
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' ...
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>' ...
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"/>' ...
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>' ...
    '<xf numFmtId="164" fontId="1" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>' ...
    '<xf numFmtId="49" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>' ...
    '<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1">' ...
    '<alignment vertical="top" wrapText="1"/></xf></cellXfs>' ...
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' ...
    '</styleSheet>'];
end

function txt = xmlEscape(txt)
txt = strrep(txt,'&','&amp;');
txt = strrep(txt,'<','&lt;');
txt = strrep(txt,'>','&gt;');
txt = strrep(txt,'"','&quot;');
end

function writeUtf8(fileName,txt)
fid = fopen(fileName,'w');
if fid < 0
    error('Cannot write %s',fileName);
end
closeFile = onCleanup(@() fclose(fid));
fwrite(fid,unicode2native(txt,'UTF-8'),'uint8');
end

function deleteIfExists(fileName)
if exist(fileName,'file') == 2
    delete(fileName);
end
end
