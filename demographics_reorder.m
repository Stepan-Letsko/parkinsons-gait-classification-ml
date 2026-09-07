%% Filter demographics to a specific ID list (keeping the exact header order)
% Put this .m file in the same folder as demographics.xls or demographics.html

% ===== 1) Your list as given (paste exactly) =====
listStr = [
"ASSIGNED_ID	GaCo06_01.txt	GaCo02_01.txt	SiCo27_01.txt	GaCo01_01.txt	SiCo18_01.txt	SiCo06_01.txt	SiCo08_01.txt	SiCo19_01.txt	GaCo04_01.txt	SiCo20_01.txt	SiCo12_01.txt	GaCo16_01.txt	SiCo24_01.txt	SiCo21_01.txt	GaCo14_01.txt	SiCo17_01.txt	GaCo11_01.txt	SiCo16_01.txt	SiCo04_01.txt	SiCo09_01.txt	SiCo03_01.txt	SiCo10_01.txt	SiCo22_01.txt	SiCo26_01.txt	GaCo12_01.txt	SiCo25_01.txt	SiCo28_01.txt	SiCo14_01.txt	SiCo07_01.txt	SiCo11_01.txt	SiCo15_01.txt	GaCo13_01.txt	GaCo10_01.txt	GaCo03_01.txt	GaCo05_01.txt	SiCo29_01.txt	SiCo23_01.txt	SiCo01_01.txt	SiCo05_01.txt	GaCo08_01.txt	SiPt33_01.txt	SiPt05_01.txt	GaPt13_01.txt	GaPt03_01.txt	GaPt19_01.txt	GaPt12_01.txt	GaPt23_01.txt	SiPt07_01.txt	SiPt25_01.txt	SiPt15_01.txt	GaPt30_01.txt	SiPt16_01.txt	SiPt24_01.txt	SiPt36_01.txt	GaPt06_01.txt	SiPt27_01.txt	SiPt21_01.txt	SiPt30_01.txt	SiPt17_01.txt	GaPt07_01.txt	SiPt39_01.txt	SiPt23_01.txt	SiPt18_01.txt	GaPt24_01.txt	SiPt32_01.txt	SiPt34_01.txt	GaPt27_01.txt	SiPt31_01.txt	SiPt09_01.txt	GaPt20_01.txt	SiPt12_01.txt	GaPt14_01.txt	SiPt04_01.txt	SiPt40_01.txt	GaPt17_01.txt	SiPt22_01.txt	GaPt26_01.txt	SiPt29_01.txt	SiPt28_01.txt	SiPt35_01.txt"
];

% ===== 2) Parse IDs: drop the first token (assignment ID) and strip '_nn.txt' =====
tokens = regexp(listStr, '\S+', 'match');
tokens = tokens(2:end);                                % remove the leading assignment ID token
baseIDs = regexprep(tokens, '(_\d+)?\.txt$', '');      % e.g., 'GaCo06_01.txt' -> 'GaCo06'
baseIDs = unique(string(baseIDs));                     % ensure unique IDs

% ===== 3) Read the demographics table =====
tbl = [];
if exist('demographics.xls','file')
    tbl = readtable('demographics.xls', 'PreserveVariableNames', true);
elseif exist('demographics.html','file')
    tbl = readtable('demographics.html', 'PreserveVariableNames', true);
else
    error('Could not find demographics.xls or demographics.html in the current folder.');
end

% Make sure ID is string
if ~ismember('ID', tbl.Properties.VariableNames)
    error('Could not find an "ID" column in the demographics file.');
end
tbl.ID = string(tbl.ID);

% ===== 4) Filter rows to only those IDs =====
keepMask = ismember(tbl.ID, baseIDs);
tblKeep = tbl(keepMask, :);

% Report any requested IDs not found (useful sanity check)
missing = setdiff(baseIDs, tblKeep.ID);
if ~isempty(missing)
    fprintf('Warning: %d IDs from your list were NOT found in demographics and will be skipped:\n', numel(missing));
    disp(missing');
end

% ===== 5) Keep the exact header order you asked for =====
desiredCols = [ ...
    "ID","Study","Group","Subjnum","Gender","Age", ...
    "Height (meters)","Weight (kg)","HoehnYahr","UPDRS","UPDRSM", ...
    "TUAG","Speed_01 (m/sec)","Speed_10" ...
];

% Check columns exist (and tell you if any are missing)
missingCols = setdiff(desiredCols, string(tblKeep.Properties.VariableNames));
if ~isempty(missingCols)
    fprintf('Note: These columns were not found and will be omitted: %s\n', strjoin(missingCols, ', '));
end
presentCols = desiredCols(ismember(desiredCols, string(tblKeep.Properties.VariableNames)));

% Reorder/select columns
tblOut = tblKeep(:, presentCols);

% ===== 6) Optional cleaning: convert lone " - " cells to missing =====
for c = 1:width(tblOut)
    if iscell(tblOut.(c))
        tblOut.(c) = strrep(tblOut.(c), ' - ', '');
    elseif isstring(tblOut.(c))
        tblOut.(c)(tblOut.(c)==" - ") = missing;
    end
end

% ===== 7) Save the reconstructed document (same headers, only your IDs) =====
writetable(tblOut, 'demographics_filtered.xlsx', 'WriteMode','overwrite');
writetable(tblOut, 'demographics_filtered.csv');  % convenient for quick viewing

fprintf('Done. Kept %d rows and %d columns. Output: demographics_filtered.xlsx / .csv\n', height(tblOut), width(tblOut));
