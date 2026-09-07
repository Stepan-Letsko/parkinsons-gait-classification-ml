%% (B) Feature Extraction (Demographics) with Cohort Mean Imputation (replacing the missing values with an overall mean value)
%Extracting features from the demographics_filtered.xlsx

clear; clc;                                                     %clearing workspace and command window

path = "data/"; %path to folder — place demographics_filtered.xlsx and the GRF .txt recordings in a local "data/" folder next to this script

inFile  = path + "demographics_filtered.xlsx";      %specifying input file with the filtered 80 IDs
T = readtable(inFile, 'PreserveVariableNames', true);   % reading the table while preserving original headers

%normalizing grouping variables to strings
if ~isstring(T.Group) && ~iscellstr(T.Group), T.Group = string(T.Group); end   %ensuring Group is string

%selecting five demographic features to analyze
features = ["Age","Height (meters)","Weight (kg)","TUAG","Speed_01 (m/sec)"];          %choosing the five features

%defining colors for plotting PD vs CO
colPD = [0.85 0.33 0.10];                                                       %setting color for PD
colCO = [0.00 0.45 0.74];                                                       %setting color for CO

% creating logical masks for the two cohorts
isPD = T.Group == "PD";                                                         %marking PD rows
isCO = T.Group == "CO";                                                         %marking CO rows

%defining a helper for summary statistics while ignoring NaNs
statf = @(x) struct( ...
    'N'     , sum(isfinite(x)), ...                                             %counting finite observations
    'Min'   , min(x,[],'omitnan'), ...                                          %computing minimum
    'Max'   , max(x,[],'omitnan'), ...                                          %computing maximum
    'Mean'  , mean(x,'omitnan'), ...                                            %computing mean
    'Std'   , std(x,'omitnan'), ...                                             %computing standard deviation
    'Median', median(x,'omitnan'));                                             %computing median

%preallocating tidy tables for overall and groupwise statistics
rowNames = features(:);                                                         %storing feature names as row identifiers
All  = table('Size',[numel(features) 6], 'VariableTypes', repmat("double",1,6), ...
             'VariableNames', {'N','Min','Max','Mean','Std','Median'}, ...
             'RowNames', rowNames);                                             %creating table for overall stats
PD   = All;                                                                     %copying layout for PD-only stats
CO   = All;                                                                     %copying layout for CO-only stats

%looping over features to impute, compute statistics, and draw distributions
for k = 1:numel(features)                                                       %iterating through selected features
    f = features(k);                                                            %selecting current feature name

    %verifying column existence
    if ~ismember(f, string(T.Properties.VariableNames))
        warning('Feature "%s" not found. Skipping.', f);                        %warning if feature missing
        continue;                                                               %moving to next feature
    end

    %extracting raw values
    xAll = T.(f);  xAll = xAll(:);                                              %getting the full column as vector
    xPD  = T.(f);  xPD  = xPD(isPD);                                            %getting PD subset
    xCO  = T.(f);  xCO  = xCO(isCO);                                            %getting CO subset

    %converting possible string/cell entries to numeric and removing ' - '
    if iscell(xAll), xAll = str2double(strrep(xAll,' - ','')); end              %converting cell strings to numeric
    if iscell(xPD),  xPD  = str2double(strrep(xPD ,' - ','')); end              %converting PD cells to numeric
    if iscell(xCO),  xCO  = str2double(strrep(xCO ,' - ','')); end              %converting CO cells to numeric
    if isstring(xAll), xAll = str2double(strrep(xAll,' - ','')); end            %converting string arrays to numeric
    if isstring(xPD),  xPD  = str2double(strrep(xPD ,' - ','')); end            %converting PD strings to numeric
    if isstring(xCO),  xCO  = str2double(strrep(xCO ,' - ','')); end            %converting CO strings to numeric

    %preparing an assigned copy of the full feature
    xImp = xAll;                                                                %creating assigned vector copy

    % performing cohort mean imputation (PD mean for PD NaNs, CO mean for CO NaNs)
    muPD = mean(xPD, 'omitnan');                                                % computing PD cohort mean
    muCO = mean(xCO, 'omitnan');                                                % computing CO cohort mean
    xImp(isnan(xImp) & isPD) = muPD;                                            % imputing PD NaNs with PD mean
    xImp(isnan(xImp) & isCO) = muCO;                                            % imputing CO NaNs with CO mean

    % extracting imputed PD and CO subsets from the imputed full vector
    xPD_imp = xImp(isPD);                                                       % getting imputed PD values
    xCO_imp = xImp(isCO);                                                       % getting imputed CO values

    % computing summary statistics on imputed data
    sAll = statf(xImp);                                                         % computing overall stats after imputation
    sPD  = statf(xPD_imp);                                                      % computing PD stats after imputation
    sCO  = statf(xCO_imp);                                                      % computing CO stats after imputation

    % storing statistics in the preallocated tables
    All{k,:} = [sAll.N sAll.Min sAll.Max sAll.Mean sAll.Std sAll.Median];       % saving overall stats
    PD{k,:}  = [sPD.N  sPD.Min  sPD.Max  sPD.Mean  sPD.Std  sPD.Median];        % saving PD stats
    CO{k,:}  = [sCO.N  sCO.Min  sCO.Max  sCO.Mean  sCO.Std  sCO.Median];        % saving CO stats

    % opening an on-screen figure for the current feature
    figure('Color','w','Position',[200 200 900 450]);                           %creating figure window

    %choosing a sensible number of bins from finite values
    xf = xImp(isfinite(xImp));                                                  %collecting finite values
    if numel(xf) >= 10                                                          %checking sample size
        nb = max(10, min(40, round(sqrt(numel(xf)))));                          % electing bin count based on size
    else
        nb = 8;                                                                  % using a fallback bin count
    end

    % plotting overlaid histograms for CO and PD using imputed data
    histogram(xCO_imp, nb, 'Normalization','pdf', 'FaceColor', colCO, ...
        'FaceAlpha', 0.35, 'EdgeColor','none'); hold on;                        % plotting CO histogram
    histogram(xPD_imp, nb, 'Normalization','pdf', 'FaceColor', colPD, ...
        'FaceAlpha', 0.35, 'EdgeColor','none');                                 % plotting PD histogram

    % marking group means with vertical lines
    xline(sCO.Mean,'-','CO mean','Color',colCO,'LineWidth',1.5, ...
        'LabelVerticalAlignment','bottom','LabelOrientation','horizontal');     % adding CO mean line
    xline(sPD.Mean,'-','PD mean','Color',colPD,'LineWidth',1.5, ...
        'LabelVerticalAlignment','top','LabelOrientation','horizontal');        % adding PD mean line

    % formatting axes and legend
    grid on; box on;                                                             % enabling grid and box
    title(sprintf('Distribution of %s (PD vs CO):', f), 'Interpreter','none'); % setting title
    xlabel(f, 'Interpreter','none'); ylabel('PDF');                              % labeling axes
    legend({'CO','PD'}, 'Location','best');                                      % adding legend

    %leaving the figure open for on-screen viewing
end

%assembling summary tables with a visible Feature column
Summary_All = addvars(All, rowNames, 'Before',1, 'NewVariableNames','Feature'); % adding feature names to overall
Summary_PD  = addvars(PD , rowNames, 'Before',1, 'NewVariableNames','Feature'); % adding feature names to PD
Summary_CO  = addvars(CO , rowNames, 'Before',1, 'NewVariableNames','Feature'); % adding feature names to CO

% printing summary tables to the Command Window
disp('================  SUMMARY (all groups combined, after imputation)  ================');
disp(Summary_All);                                                                % displaying overall table

disp('========================  SUMMARY (PD only, after imputation)  ====================');
disp(Summary_PD);                                                                 % displaying PD table

disp('====================  SUMMARY (controls only, after imputation)  ===================');
disp(Summary_CO);                                                                 % displaying CO table


%% (B) Example GRF plotting and event detection (columns 18 & 19)

dataFile = path + "GaCo06_01.txt"; %specifying the GRF recording to plot
Fs = 100;   %setting sampling rate (Hz) per dataset docs

% reading the TXT file 
X = readmatrix(dataFile); %reading all columns from the text file
left  = X(:,18);  %extracting total GRF for left foot (column 18)
right = X(:,19);  %extracting total GRF for right foot (column 19)
N = size(X,1); %determining number of samples
t = (0:N-1).'/Fs; %creating time vector in seconds

% First diagram, full lenght signal
figure('Color','w','Position',[100 100 900 500]); %creating figure window for full-length plots
tiledlayout(2,1,'Padding','compact','TileSpacing','compact'); %setting a two-row layout

nexttile;  %selecting top subplot
plot(t, left, 'LineWidth', 1.0); %plotting left GRF
xlabel('Time (s)'); ylabel('GRF Left (N)'); %labeling axes
title(strrep(dataFile,'_','\_'));  %adding title with file name
grid on;                                                          %enabling grid

nexttile;  %selecting bottom subplot
plot(t, right, 'LineWidth', 1.0);  %plotting right GRF
xlabel('Time (s)'); ylabel('GRF Right (N)');  %labeling axes
grid on; %enabling grid

% Second diagram (10s up close view) with markers for local max/min 
dur = t(end); %getting total duration
win = 10;  %setting window length (s) for zoomed view
t0 = max(0, dur/2 - win/2);  %selecting center window around mid-recording
seg = t >= t0 & t < (t0 + win);  %building logical mask for the 10 s segment

tSeg  = t(seg);  %extracting segment time
Lseg  = left(seg);  %extracting left GRF segment
Rseg  = right(seg);   %extracting right GRF segment

% choosing contact threshold (N) for initial/final contact detection
th = 50;   %setting contact threshold

% detecting initial and final contact via threshold crossings (rising/falling edges)
icL = tSeg( find( Lseg(1:end-1) <  th & Lseg(2:end) >= th ) + 1 );%detecting left initial contacts (rising > th)
fcL = tSeg( find( Lseg(1:end-1) >= th & Lseg(2:end) <  th ) + 1 );%detecting left final contacts  (falling < th)
icR = tSeg( find( Rseg(1:end-1) <  th & Rseg(2:end) >= th ) + 1 );%detecting right initial contacts
fcR = tSeg( find( Rseg(1:end-1) >= th & Rseg(2:end) <  th ) + 1 );%detecting right final contacts

% detecting "M" peaks and mid-stance minima for annotation
minPeakDist = round(0.4*Fs);   % setting minimum distance between peaks (~0.4 s)
[pL, lPL] = findpeaks(Lseg, 'MinPeakDistance', minPeakDist,'MinPeakProminence', 50);  % finding left peaks with basic constraints
[pR, lPR] = findpeaks(Rseg, 'MinPeakDistance', minPeakDist, 'MinPeakProminence', 50);  %finding right peaks

% mid-stance minima are local minima between peaks; using peaks of the inverted signal
[mL, lML] = findpeaks(-Lseg, 'MinPeakDistance', round(0.3*Fs),'MinPeakProminence', 30);%finding left minima (invert signal)
[mR, lMR] = findpeaks(-Rseg, 'MinPeakDistance', round(0.3*Fs), 'MinPeakProminence', 30); %finding right minima

% creating the zoomed figure
figure('Color','w','Position',[100 100 900 550]); %creating figure window for segment and annotations
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');%setting two panels: left then right

% --- panel for left foot
nexttile;  %selecting left panel
plot(tSeg, Lseg, 'LineWidth', 1.2); hold on; %plotting left GRF segment
yline(th,':','Threshold');  %plotting detection threshold for context
plot(tSeg(lPL), pL, 'v', 'MarkerSize',6, 'MarkerFaceColor',[0 .45 .74], 'MarkerEdgeColor','k'); %marking peaks
plot(tSeg(lML), -mL, '^', 'MarkerSize',6, 'MarkerFaceColor',[0.85 .33 .10], 'MarkerEdgeColor','k'); %marking minima
xline(icL, '--g', {'IC'}); %marking initial contacts (IC)
xline(fcL, '--r', {'FC'}); %marking final contacts (FC)
xlabel('Time (s)'); ylabel('GRF Left (N)'); %labeling axes
title('Left foot – peaks (v), mid-stance minima (^), IC (green), FC (red)'); %adding legend text to title
grid on; hold off;%finishing left panel

% --- panel for right foot
nexttile; %selecting right panel
plot(tSeg, Rseg, 'LineWidth', 1.2); hold on; %plotting right GRF segment
yline(th,':','Threshold'); %plotting detection threshold
plot(tSeg(lPR), pR, 'v', 'MarkerSize',6, 'MarkerFaceColor',[0 .45 .74], 'MarkerEdgeColor','k'); %marking peaks
plot(tSeg(lMR), -mR, '^', 'MarkerSize',6, 'MarkerFaceColor',[0.85 .33 .10], 'MarkerEdgeColor','k'); %marking minima
xline(icR, '--g', {'IC'});  %marking initial contacts (IC)
xline(fcR, '--r', {'FC'}); %marking final contacts (FC)
xlabel('Time (s)'); ylabel('GRF Right (N)'); %labeling axes
title('Right foot – peaks (v), mid-stance minima (^), IC (green), FC (red)'); %adding legend text to title
grid on; hold off;%finishing right panel

%% (B) Feature Extraction (Sensor Driven features)

%  list of files to process
listStr = [ ...
"GaCo06_01.txt	GaCo02_01.txt	SiCo27_01.txt	GaCo01_01.txt	SiCo18_01.txt	SiCo06_01.txt" + ...
" SiCo08_01.txt	SiCo19_01.txt	GaCo04_01.txt	SiCo20_01.txt	SiCo12_01.txt	GaCo16_01.txt	SiCo24_01.txt" + ...
" SiCo21_01.txt	GaCo14_01.txt	SiCo17_01.txt	GaCo11_01.txt	SiCo16_01.txt	SiCo04_01.txt" + ...
" SiCo09_01.txt	SiCo03_01.txt	SiCo10_01.txt	SiCo22_01.txt	SiCo26_01.txt	GaCo12_01.txt	" + ...
"SiCo25_01.txt	SiCo28_01.txt	SiCo14_01.txt	SiCo07_01.txt	SiCo11_01.txt	SiCo15_01.txt	GaCo13_01.txt	" + ...
"GaCo10_01.txt	GaCo03_01.txt	GaCo05_01.txt	SiCo29_01.txt	SiCo23_01.txt	SiCo01_01.txt	SiCo05_01.txt" + ...
" GaCo08_01.txt	SiPt33_01.txt	SiPt05_01.txt	GaPt13_01.txt	GaPt03_01.txt	GaPt19_01.txt	GaPt12_01.txt" + ...
"    GaPt23_01.txt	SiPt07_01.txt	SiPt25_01.txt	SiPt15_01.txt	GaPt30_01.txt	SiPt16_01.txt	SiPt24_01.txt" + ...
"    SiPt36_01.txt	GaPt06_01.txt	SiPt27_01.txt	SiPt21_01.txt	SiPt30_01.txt	SiPt17_01.txt" + ...
"    GaPt07_01.txt	SiPt39_01.txt	SiPt23_01.txt	SiPt18_01.txt	GaPt24_01.txt	SiPt32_01.txt	SiPt34_01.txt" + ...
"    GaPt27_01.txt	SiPt31_01.txt	SiPt09_01.txt	GaPt20_01.txt	SiPt12_01.txt	GaPt14_01.txt	SiPt04_01.txt	" + ...
"SiPt40_01.txt	GaPt17_01.txt	SiPt22_01.txt	GaPt26_01.txt	SiPt29_01.txt	SiPt28_01.txt	SiPt35_01.txt" ...
]; %storing the pasted filenames string

fileNames = string(regexp(listStr, '\S+\.txt', 'match'));%extracting only tokens that end with .txt
dataDir   = "data";
filePaths = fullfile(dataDir, fileNames);% full paths
baseIDs   = regexprep(fileNames, '(_\d+)?\.txt$', ''); %making base IDs by removing suffixes
Group     = repmat("CO", numel(fileNames), 1); %setting default cohort to control
Group(contains(fileNames,"Pt",'IgnoreCase',true)) = "PD"; %setting cohort to PD if filename contains 'Pt'

dataDir = ".";%setting directory where the .txt files are located
Fs = 100; %setting sampling frequency in Hz

% feature list 
featNames = [ ...
    "StepCount", ...            %total detected steps across both feet
    "StrideTimeMean", ...       %mean stride time in seconds
    "StrideTimeCV", ...         %coefficient of variation of stride time
    "StrideTimeAsym", ...       %left-right stride time asymmetry
    "PeakGRF_Mean", ...         %mean of GRF maxima (N)
    "PeakGRF_Std", ...          %standard deviation of GRF maxima (N)
    "MinGRF_Mean", ...          %mean of mid-stance minima (N)
    "DoubleSupportRatio", ...   %fraction of time both feet in contact
    "ContactTimeMean", ...      %mean stance time (s) based on IC→FC
    "LoadingRate_Mean" ...      %mean loading rate from IC to first peak (N/s)
];

F = array2table(nan(numel(fileNames), numel(featNames)), ...
     'VariableNames', featNames);  %creating a table to hold features
F.ID    = baseIDs(:);    %adding the base IDs to the table
F.File  = fileNames(:);  %adding the filenames to the table
F.Group = Group(:);      %adding the cohort labels to the table
F = movevars(F, {'ID','File','Group'}, 'Before', 1);  %moving ID/File/Group to the front

% event detection parameters 
th          = 30; %choosing a contact threshold in Newtons
minPeakDist = round(0.40 * Fs); %setting minimum distance between peaks (samples)
minPkProm   = 50; %setting minimum prominence for maxima
minMnProm   = 30; %setting minimum prominence for minima

% ---main loop over files
for i = 1:numel(fileNames) %iterating over all filenames
    fp = filePaths(i); %constructing the full path to the file
    if ~isfile(fp) %checking the file exists
        warning("File not found: %s (features set to NaN).", fp); %warning when file is missing
        continue;  %skipping to the next file
    end

    X = readmatrix(fp); %reading the file into a numeric matrix
    if size(X,2) < 19  %checking the file has the expected columns
        warning("File has <19 columns: %s (features set to NaN).", fp); %warning when columns are insufficient
        continue;  %skipping to the next file
    end

    L = X(:,18);%extracting left total GRF from column 18
    R = X(:,19);%extracting right total GRF from column 19

    S = derive_features_from_grf(L, R, Fs, th, ... %deriving features from the two GRF signals
         minPeakDist, minPkProm, minMnProm); %passing detector parameters to the helper

    for k = 1:numel(featNames)%iterating over feature names
        F{i, featNames(k)} = S.(featNames{k}); %writing the derived feature into the table
    end
end

% --printing per-feature summary tables to the Command Window
print_summary(F, featNames); %printing summary tables for All / PD / CO

% --plotting PD vs CO distributions for each feature on screen
plot_distributions(F, featNames); %showing overlaid histograms with group means

%% (C) Creating complete feature matrix and performing normilisation 
% This block merges the five demographic variables with the sensor-derived table F,
% We also need to align rows by a shared base ID as the data from both tables is not
% in the same order and imputing missing demographic values by cohort mean,

%ensuring demographics table and selected feature list exist
if ~exist('T','var') || ~istable(T)
    T = readtable('demographics_filtered.xlsx', 'PreserveVariableNames', true); %reading demographics
end
if ~exist('features','var')
    features = ["Age","Height (meters)","Weight (kg)","TUAG","Speed_01 (m/sec)"]; %list of demographic features to pull
end

% locate an ID-like key in the demographics table to match F.ID
candKeys = ["ID","Id","id","Record","record","File","file","Filename","filename"]; %likely column names that identify a record
keyInT   = candKeys(ismember(candKeys, string(T.Properties.VariableNames)));%keeping only those that actually exist in T
if isempty(keyInT)
    error('Could not find an ID/Record/File column in demographics table T.'); % stop if no usable key is found
end
keyInT = keyInT(1);  %choosing the first matching key

%building the base IDs from T that line up with F.ID 
demID = string(T.(keyInT)); %taking the key column as a string
demID = regexprep(demID,'\s+','');  %removing internal spaces like "Ga Co 06"
demID = regexprep(demID,'(_\d+)?(\.txt)?$',''); % stripping suffixes like "_01" or ".txt" → "GaCo06"

%constructing a clean demographics subtable by keyed by ID 
Dem = table();  %empty table
Dem.ID = demID(:);%inserting the base IDs as the key column

demFeatNames = features(:); %ensuring the column vector of requested demo features
for k = 1:numel(demFeatNames) %loop over each requested feature
    vn = demFeatNames(k); %variable name
    if ~ismember(vn, string(T.Properties.VariableNames))%if the column is missing in T
        warning('Demographic feature "%s" not found in T. Filling with NaN.', vn);%warning if NaN
        Dem.(vn) = nan(height(Dem),1);
        continue
    end
    x = T.(vn); %grabbing the raw column
    if iscell(x),    x = strrep(x,' - ',''); x = str2double(x); end  %cellstr → numeric
    if isstring(x),  x = strrep(x,' - ',''); x = str2double(x); end  %string  → numeric
    Dem.(vn) = x; %write cleaned numeric column
end

%keeping Group from sensors (F)
if ismember("Group", string(Dem.Properties.VariableNames))
    Dem.Group = []; %droping any Group in demographics
end

%deduplicate demographics by ID
[~, firstIdx] = unique(Dem.ID, 'stable'); %keeping first occurrence for each ID
Dem = Dem(firstIdx, :);

%left-join demographics onto the sensor table (preserving all F rows)
X_all = outerjoin(F, Dem, 'Keys','ID', 'MergeKeys',true, 'Type','left');%adding demo columns where IDs match

% -- place demographic columns right after Group (fixes earlier movevars error) ----
demoOrder = demFeatNames(ismember(demFeatNames, string(X_all.Properties.VariableNames))); % which requested demo columns actually exist
if ~isempty(demoOrder)
    X_all = movevars(X_all, demoOrder, 'After', 'Group');
end

%imputing missing DEMOGRAPHIC values using cohort means
demCols = demoOrder; %demographic columns present in X_all
for k = 1:numel(demCols)
    vn = demCols(k); %column name
    x  = X_all{:, vn};%pull the column as numeric

    mPD = (X_all.Group == "PD");%mask for PD rows
    mCO = (X_all.Group == "CO"); %mask for control rows

    muPD  = mean(x(mPD), 'omitnan'); %PD mean (ignore NaNs)
    muCO  = mean(x(mCO), 'omitnan');  %CO mean

    toFillPD = mPD & ~isfinite(x); %positions to fill in PD
    toFillCO = mCO & ~isfinite(x);  %positions to fill in CO
    x(toFillPD) = muPD; %impute PD NaNs with PD mean
    x(toFillCO) = muCO; %impute CO NaNs with CO mean

    X_all{:, vn} = x;  % write the imputed column back
end


%% (C) Feature re-scaling, Min–Max normalisation to [0,1] for all continuous features
%also computing and printing the statistical summary of the normalised data


%ensuring combined table exists
if ~exist('X_all','var') || ~istable(X_all)
    error('X_all not found. Please run the combine step first to create X_all.');
end

%identifying the numeric feature columns to scale
vn        = string(X_all.Properties.VariableNames);%all column names
isNumeric = varfun(@isnumeric, X_all, 'OutputFormat','uniform');%numeric vars
exclude   = ismember(vn, ["ID","File","Group"]); %Not sclaling
featCols  = vn(isNumeric & ~exclude); %numeric feature columns to scale

if isempty(featCols)
    error('No numeric feature columns found to scale.');
end

%computing the global min/max per feature (across the entire dataset)
Xnum = X_all{:, featCols};%numeric matrix (N×D)
cmin = min(Xnum, [], 1, 'omitnan');%vector of minima
cmax = max(Xnum, [], 1, 'omitnan');% vector of maxima
span = cmax - cmin;%1×D range

%handling constant columns, mapping everything to 0
span_bad = (span==0 | ~isfinite(span));
span_tmp = span; span_tmp(span_bad) = 1; %avoiding divide-by-zero

%applying min–max scaling
Xscaled = (Xnum - cmin) ./ span_tmp;% scale to [0,1]

%building the scaled table: 
X_scaled = X_all; %copy original combined table
X_scaled{:, featCols} = Xscaled; %write back scaled features

%Identifying the scaled numeric feature columns
vn        = string(X_scaled.Properties.VariableNames);
isNumeric = varfun(@isnumeric, X_scaled, 'OutputFormat','uniform');
featCols  = vn(isNumeric & ~ismember(vn, ["ID","File","Group"]));

%Making Stat summary 
statf = @(x) struct( ...
    'N'     , sum(isfinite(x)), ...
    'Min'   , min(x,[],'omitnan'), ...
    'Max'   , max(x,[],'omitnan'), ...
    'Mean'  , mean(x,'omitnan'), ...
    'Std'   , std(x,'omitnan'), ...
    'Median', median(x,'omitnan') );

Summary_Normalised = table('Size',[numel(featCols) 6], ...
    'VariableTypes', repmat("double",1,6), ...
    'VariableNames', {'N','Min','Max','Mean','Std','Median'}, ...
    'RowNames', cellstr(featCols));

for k = 1:numel(featCols)
    s = statf(X_scaled{:, featCols(k)});
    Summary_Normalised{k,:} = [s.N s.Min s.Max s.Mean s.Std s.Median];
end

Summary_Normalised = addvars(Summary_Normalised, featCols(:), ...
    'Before', 1, 'NewVariableNames', 'Feature');

disp('--- Summary of normalised features (0–1) ---');
disp(Summary_Normalised);


%% (D) K Nearest Neighbours — Part (i): wrapper FS inside 10-fold CV
% Note: In order to run this block Statistics and Machine Learning Toolbox must be installed
% The code block does the following:
% 1) Splitting the data into 10 outer folds (8 rows per fold)
% 2) loop over the 10 outer folds for each k value
%    On the training part of a fold, run a forward wrapper feature selection
%    with a 5-fold inner CV and a KNN(K) classifier.
%    Train KNN on the selected features and evaluate on the outer test part.
%    Collect metrics (Accuracy, F1, AUC) and how many features were selected.
% 3) Aggregate mean+-std across folds and report which features were most chosen.

if ~exist('X_scaled','var') || ~istable(X_scaled)% Ensuring the scaled feature table exists and is a table.
    error('X_scaled not found. Please run parts (B) and (C) first.'); %error message
end

% preparing the design matrix and labels
allNames  = string(X_scaled.Properties.VariableNames);%Pulling every column name (we will use this to separate IDs/labels from predictors).
predictorNames = allNames(~ismember(allNames, ["ID","File","Group"]));%Keeping only the actual features (drop identifiers + target label).
Xmat      = X_scaled{:, predictorNames};  %Extracting the  predictors as a numeric matrix
ystr      = string(X_scaled.Group(:)); %Taking the target column, ensuring it is a string array
y         = categorical(ystr);  %Converting labels to categorical
posClass  = categorical("PD");  %Defining which class is  positive" for F1/AUC

% 10-fold, stratified
rng(42,'twister');  % Setting the  RNG seed to make CV splits and results reproducible.
cvOuter = cvpartition(y, 'KFold', 10);  % Build a 10-fold partition
% cvpartition creates train/test logical indices for each fold

K_list = [1 3 5 7 9];   % The K values we’ll compare in KNN 
Results = table('Size',[numel(K_list) 7], ...  %Preallocating a results table with 7 columns…
    'VariableTypes', ["double","double","double","double","double","double","double"], ... %numeric types for means/stds and avg 
    'VariableNames', {'Acc_mean','Acc_std','F1_mean','F1_std','AUC_mean','AUC_std','AvgNumFeatures'}, ...
    'RowNames', compose('K=%d',K_list));  %Row names

%storing selection masks per fold 
SelectedMasks = cell(numel(K_list), cvOuter.NumTestSets);

%helper for metrics
metric_fn = @(ytrue, yhat, scorePos) ...% wrapper to compute [acc, f1, auc]
    local_metrics(ytrue, yhat, scorePos, posClass); %We pass the posClass so F1/AUC are computed with PD as positive.

%main loop over K 
for kk = 1:numel(K_list) %Iterate over k values
    K = K_list(kk);  %current K for KNN.

    accF  = zeros(cvOuter.NumTestSets,1); %Per-fold accuracy placeholder.
    f1F   = zeros(cvOuter.NumTestSets,1); %Per-fold F1 placeholder.
    aucF  = zeros(cvOuter.NumTestSets,1); %Per-fold AUC placeholder.
    nFeat = zeros(cvOuter.NumTestSets,1); %Per-fold number of selected features.

    for fold = 1:cvOuter.NumTestSets %Go through the 10 outer folds (train/test splits).
        % split indices for this outer fold
        trIdx = training(cvOuter, fold);%Logical indices for training rows in this fold.
        teIdx = test(cvOuter, fold); %Logical indices for testing rows in this fold.

        Xtr = Xmat(trIdx, :);     ytr = y(trIdx);%training predictors and labels.
        Xte = Xmat(teIdx, :);     yte = y(teIdx);%testing predictors and labels.

        %wrapper feature selection on the training data only
        % We perform feature selection INSIDE the training set to avoid using the test data.
        % We’ll use forward selection (sequentialfs) driven by validation error of a KNN(K).
        % sequentialfs: adds features that improve a chosen criterion

        %classification error on validation data for a KNN
        critfun = @(Xtr_fs, Ytr_fs, Xval_fs, Yval_fs) ... % Defining the objective function the selector tries to MINIMIZE.
            1 - mean(predict( ... %We compute (1 - validation accuracy) = validation error.
                  fitcknn(Xtr_fs, Ytr_fs, ...  %fitcknn: trains a KNN classifier on the current feature subset.
                          'NumNeighbors', K, ... %Use the current K (from outer loop).
                          'Standardize', false, ... %Features are already min-max scaled
                          'Distance', 'euclidean'), ...  % Euclidean distance
                  Xval_fs) == Yval_fs); %applies the trained KNN to the validation fold.

        %inner CV for FS
        cvInner = cvpartition(ytr, 'KFold', 5); %Building a stratified 5-fold splitter on TRAINING labels 

        % forward selection; no fixed number of features , stops when no improvement
        inModel = sequentialfs(critfun, Xtr, ytr, ... % Running forward sequential feature selection on the training data
                    'cv', cvInner, ... %using the inner CV splitter for validation estimates.
                    'direction','forward', ... %forward start empty, add best feature at each step.
                    'options', statset('Display','off')); %output for cleaner logs.
        % sequentialfs returns a logical mask (size of predictors) of the chosen subset.

        SelectedMasks{kk, fold} = inModel;%Keeping the mask
        nFeat(fold) = sum(inModel); %Recording how many features were selected in this fold.

        %training the final KNN on selected features
        mdl = fitcknn(Xtr(:, inModel), ytr, ...%Training the final KNN on the training set restricted to selected features.
                      'NumNeighbors', K, ...%Same K as used by the selector criterion.
                      'Standardize', false, ...%Still off, scaling was done in Part C.
                      'Distance', 'euclidean');%Keep distance consistent

        [yhat, score] = predict(mdl, Xte(:, inModel));%Predicting class labels and class scores
        %predicttion on KNN returns:
        % yhat  = predicted categorical labels,
        % score = N×C matrix of class scores 

        %probability/score for the positive class (PD) for AUC
        [~, posCol] = ismember(posClass, mdl.ClassNames);%Finding which column in score corresponds to PD.
        scorePos = score(:, posCol); %Extracting PD scores for ROC/AUC computation.

        [accF(fold), f1F(fold), aucF(fold)] = metric_fn(yte, yhat, scorePos);% Computing Accuracy, F1, and AUC for this fold.
    end

    Results{kk, 'Acc_mean'}      = mean(accF); %Average accuracy over 10 folds for this K.
    Results{kk, 'Acc_std'}       = std(accF); %Std dev of accuracy across folds.
    Results{kk, 'F1_mean'}       = mean(f1F); %Average F1 over folds
    Results{kk, 'F1_std'}        = std(f1F); %Std dev of F1 across folds.
    Results{kk, 'AUC_mean'}      = mean(aucF); %Average AUC over folds.
    Results{kk, 'AUC_std'}       = std(aucF); %Std dev of AUC across folds.
    Results{kk, 'AvgNumFeatures'}= mean(nFeat); %On average, how many features the wrapper picked

    %printing a quick progress line
    fprintf('K=%d | Acc %.3f±%.3f | F1 %.3f±%.3f | AUC %.3f±%.3f | Avg feats %.1f\n', ...
        K, mean(accF), std(accF), mean(f1F), std(f1F), mean(aucF), std(aucF), mean(nFeat));
end

disp('=== KNN (wrapper FS inside 10-fold CV): mean ± std across folds ===');
disp(Results);  % Showing the metrics table.

% Showing which features were most often selected for the best K
%We pick the K with the highest mean AUC and list the most
%frequently selected features across its 10 folds. 
[~, bestRow] = max(Results.AUC_mean + 1e-6*Results.F1_mean);%Argmax by AUC; add tiny e*F1 to break near-ties 
bestK = K_list(bestRow); % Recovering the actual K value.
masksBest = SelectedMasks(bestRow, :); %Getting the 10 masks for this best K.
freq = zeros(1, numel(predictorNames));%Counter for how often each feature was picked.
for f = 1:numel(masksBest) %Loop over folds
    if ~isempty(masksBest{f}) % If mask exist
        freq = freq + masksBest{f}(:).'; %add the logical mask
    end
end
[~, order] = sort(freq, 'descend'); %Sort features by how often they were selected
fprintf('Most frequently selected features for best K=%d:\n', bestK);
for i = 1:min(12, numel(order)) %Print top 12 
    fprintf('  %2d×  %s\n', freq(order(i)), predictorNames(order(i))); 
end

%% (D)(ii) Weighted KNN (K=7) — wrapper feature selction inside the same 10-fold CV

bestK = 7;  % use K=7

% pulling predictors/labels from the scaled table 
allNames       = string(X_scaled.Properties.VariableNames);%all column names
predictorNames = allNames(~ismember(allNames, ["ID","File","Group"])); %feature columns only
Xmat           = X_scaled{:, predictorNames}; %numeric design matrix
y              = categorical(string(X_scaled.Group(:))); %class labels
posClass       = categorical("PD"); %positive class for metrics

% preallocating fold-level containers (10 folds)
accF  = zeros(cvOuter.NumTestSets,1); %accuracy per fold
f1F   = zeros(cvOuter.NumTestSets,1); %F1 per fold
aucF  = zeros(cvOuter.NumTestSets,1); %AUC per fold
nFeat = zeros(cvOuter.NumTestSets,1); %features selected per fold

%metric wrapper
metric_fn = @(ytrue, yhat, scorePos) local_metrics(ytrue, yhat, scorePos, posClass);

%outer 10-fold loop
for fold = 1:cvOuter.NumTestSets
    trIdx = training(cvOuter, fold);%training indices
    teIdx = test(cvOuter, fold); %test indices

    Xtr = Xmat(trIdx,:);   ytr = y(trIdx); %training data
    Xte = Xmat(teIdx,:);   yte = y(teIdx); %test data

    %forward wrapper selection on train only, with weighted KNN in the criterion
    cvInner = cvpartition(ytr,'KFold',5);% 5-fold inner CV
    critfun = @(Xtr_fs,Ytr_fs,Xval_fs,Yval_fs) ...%minimising validation error
        1 - mean( predict( fitcknn(Xtr_fs,Ytr_fs, ...
                                   'NumNeighbors',bestK, ...
                                   'Standardize',false, ...
                                   'Distance','euclidean', ...
                                   'DistanceWeight','inverse'), ...
                            Xval_fs) == Yval_fs );

    inModel = sequentialfs(critfun, Xtr, ytr, ... %forward add until no gain
                           'cv',cvInner, 'direction','forward', ...
                           'options',statset('Display','off'));
    nFeat(fold) = sum(inModel); %record subset size

    %training final weighted KNN on selected features and evaluate on TEST
    mdlW = fitcknn(Xtr(:,inModel), ytr, ...
                   'NumNeighbors',bestK, ...
                   'Standardize',false, ...
                   'Distance','euclidean', ...
                   'DistanceWeight','inverse'); %weighted

    [yhat, score] = predict(mdlW, Xte(:,inModel));%predictions + scores
    [~, posCol]   = ismember(posClass, mdlW.ClassNames);%PD score column
    scorePos      = score(:,posCol); %PD scores for AUC

    [accF(fold), f1F(fold), aucF(fold)] = metric_fn(yte, yhat, scorePos);%compute metrics
end

%display summary table
ResultsW = table(mean(accF), std(accF), mean(f1F), std(f1F), ...
                 mean(aucF,'omitnan'), std(aucF,'omitnan'), mean(nFeat), ...
    'VariableNames', {'Acc_mean','Acc_std','F1_mean','F1_std','AUC_mean','AUC_std','AvgNumFeatures'}, ...
    'RowNames', compose('K=%d (weighted)',bestK));
disp('=== Weighted KNN (inverse distance): mean ± std across folds ===');
disp(ResultsW);


%% (E)(i) SVM with wrapper FS inside 10-fold Cross validation
%Note: we re-use some of the vectors from part (D)

C_list = [0.1 1 10];  %the three C values to test
ResultsSVM = table('Size',[numel(C_list) 7], ...  %results table (one row per C)
    'VariableTypes', ["double","double","double","double","double","double","double"], ...
    'VariableNames', {'Acc_mean','Acc_std','F1_mean','F1_std','AUC_mean','AUC_std','AvgNumFeatures'}, ...
    'RowNames', compose('C=%.1g',C_list));                                 

SelectedMasksSVM = cell(numel(C_list), cvOuter.NumTestSets); %storing the chosen subsets per fold
metric_fn = @(ytrue,yhat,scorePos) local_metrics(ytrue,yhat,scorePos,posClass); %same metric helper

for cc = 1:numel(C_list) %looping over C values
    Cval = C_list(cc); %current BoxConstraint

    accF = zeros(cvOuter.NumTestSets,1); %per-fold accuracy
    f1F  = zeros(cvOuter.NumTestSets,1); %per-fold F1
    aucF = zeros(cvOuter.NumTestSets,1); %per-fold AUC
    nF   = zeros(cvOuter.NumTestSets,1); %per-fold #features

    for fold = 1:cvOuter.NumTestSets %outer 10-fold loop
        trIdx = training(cvOuter,fold);  teIdx = test(cvOuter,fold); %split indices
        Xtr = Xmat(trIdx,:);   ytr = y(trIdx); %TRAIN split
        Xte = Xmat(teIdx,:);   yte = y(teIdx); %TEST split

        cvInner = cvpartition(ytr,'KFold',5); %inner 5-fold for FS

        %wrapper criterion = 1 - validation accuracy of the linear SVM with BoxConstraint = Cval
        critfun = @(Xtr_fs,Ytr_fs,Xval_fs,Yval_fs) ...
            1 - mean( predict( fitcsvm(Xtr_fs,Ytr_fs, ...
                                        'KernelFunction','linear', ... %linear SVM
                                        'BoxConstraint',Cval, ... %set C
                                        'Standardize',false), ... %already min–max scaled
                               Xval_fs) == Yval_fs );

        inMask = sequentialfs(critfun, Xtr, ytr, ... %forward FS on TRAIN only
                              'cv',cvInner, 'direction','forward', ...
                              'options',statset('Display','off'));
        SelectedMasksSVM{cc,fold} = inMask; %store subset for this fold
        nF(fold) = sum(inMask); %record subset size

        mdl = fitcsvm(Xtr(:,inMask), ytr, ... %train final SVM on selected features
                      'KernelFunction','linear', ...
                      'BoxConstraint',Cval, ...
                      'Standardize',false);

        [yhat, score] = predict(mdl, Xte(:,inMask)); %test predictions + scores
        [~,posCol] = ismember(posClass, mdl.ClassNames); %locate PD score column
        scorePos = score(:,posCol); %PD scores for AUC

        [accF(fold), f1F(fold), aucF(fold)] = metric_fn(yte, yhat, scorePos); %compute metrics
    end

    %compute across outer folds for this C
    ResultsSVM{cc,'Acc_mean'}       = mean(accF);
    ResultsSVM{cc,'Acc_std'}        = std(accF);
    ResultsSVM{cc,'F1_mean'}        = mean(f1F);
    ResultsSVM{cc,'F1_std'}         = std(f1F);
    ResultsSVM{cc,'AUC_mean'}       = mean(aucF,'omitnan');
    ResultsSVM{cc,'AUC_std'}        = std(aucF,'omitnan');
    ResultsSVM{cc,'AvgNumFeatures'} = mean(nF);

    fprintf('C=%g | Acc %.3f±%.3f | F1 %.3f±%.3f | AUC %.3f±%.3f | Avg feats %.1f\n', ...
        Cval, mean(accF), std(accF), mean(f1F), std(f1F), mean(aucF), std(aucF), mean(nF));
end

disp('=== SVM (linear) with wrapper FS inside 10-fold CV: mean ± std ===');
disp(ResultsSVM);

% Finding the highest number of features selected
numFeatsMat = cellfun(@sum, SelectedMasksSVM);

%per-C maximum and overall maximum
maxPerC      = max(numFeatsMat, [], 2);% size
[overallMax, iC] = max(maxPerC);  %which C gave the global max
iFold         = find(numFeatsMat(iC,:) == overallMax, 1, 'first'); %one fold with that max

% the corresponding mask & name
mask_max   = SelectedMasksSVM{iC, iFold};%logical mask at the max
featNames_max = predictorNames(mask_max);

fprintf(' highest number features selected = %d (C=%g, fold=%d)\n', ...
        overallMax, C_list(iC), iFold);

%% (E)(ii) SVM with wrapper-based FS but FIXED number of features (6)
% Here we repeat part (i) but now we *force* the wrapper-based  feature selection
% algorithm (sequentialfs) to select a fixed number of features (6)

% ensuring the variable overallMax exists
if ~exist('overallMax','var') || overallMax < 1
    error('overallMax not found. Run part (i) first to get the highest #features.');
end

%Displaying the number of features being forced in this experiment
fprintf('Part (ii): forcing NFeatures = %d in every fold.\n', overallMax);

%Createing an empty results table to store performance metrics
% One row per C value; same structure as in part (i)
ResultsSVM_fixed = table('Size',[numel(C_list) 7], ...
    'VariableTypes', ["double","double","double","double","double","double","double"], ...
    'VariableNames', {'Acc_mean','Acc_std','F1_mean','F1_std','AUC_mean','AUC_std','AvgNumFeatures'}, ...
    'RowNames', compose('C=%.1g',C_list));

%Creating cell array to store feature masks selected per fold
SelectedMasksSVM_fixed = cell(numel(C_list), cvOuter.NumTestSets);

%Begining outer loop over all C values (C=0.1, 1, 10)
for cc = 1:numel(C_list)
    Cval = C_list(cc); % current BoxConstraint

    %Preallocating per-fold performance vectors
    accF = zeros(cvOuter.NumTestSets,1); %accuracy per outer fold
    f1F  = zeros(cvOuter.NumTestSets,1); %F1-score per outer fold
    aucF = zeros(cvOuter.NumTestSets,1); %AUC per outer fold
    nF   = zeros(cvOuter.NumTestSets,1); %number of features per outer fold

    %Begining the outer 10-fold cross-validation loop
    for fold = 1:cvOuter.NumTestSets
        %Splitting the data into training and test subsets for this outer fold
        trIdx = training(cvOuter,fold);  
        teIdx = test(cvOuter,fold);      
        Xtr = Xmat(trIdx,:);   ytr = y(trIdx);  %training data
        Xte = Xmat(teIdx,:);   yte = y(teIdx);  %test data

        %Inner 5-fold CV for feature selection
        cvInner = cvpartition(ytr,'KFold',5);

        %Defining the wrapper criterion function
        %The goal is to minimize this criterion. We define it as: 1 - mean(validation accuracy)
        % where accuracy is computed by fitting an SVM with given Cval.
        critfun = @(Xtr_fs,Ytr_fs,Xval_fs,Yval_fs) ...
            1 - mean( predict( fitcsvm(Xtr_fs,Ytr_fs, ...
                                        'KernelFunction','linear', ...
                                        'BoxConstraint',Cval, ...
                                        'Standardize',false), ...
                               Xval_fs) == Yval_fs );

        %Performing sequential forward selection
        %This time we FIX the number of features to 6
        % So the algorithm will keep adding features until it reaches exactly
        inMask_fixed = sequentialfs(critfun, Xtr, ytr, ...
                                    'cv', cvInner, ...
                                    'direction','forward', ...
                                    'NFeatures', overallMax, ...
                                    'options', statset('Display','off'));

        %Storing the logical mask of selected features for this fold
        SelectedMasksSVM_fixed{cc,fold} = inMask_fixed;

        %Recording how many features were selected (should always equal 6)
        nF(fold) = sum(inMask_fixed);

        %Training the final SVM on the TRAIN set using selected features
        mdl = fitcsvm(Xtr(:,inMask_fixed), ytr, ...
                      'KernelFunction','linear', ...
                      'BoxConstraint',Cval, ...
                      'Standardize',false);

        %Evaluating on the TEST set
        [yhat, score] = predict(mdl, Xte(:,inMask_fixed)); % predictions + scores

        %Identifying which column of 'score' corresponds to the positive class
        [~,posCol] = ismember(posClass, mdl.ClassNames);
        scorePos = score(:,posCol);  %extracting the PD class scores for AUC

        %Computing the Accuracy, F1, and AUC metrics using helper function
        [accF(fold), f1F(fold), aucF(fold)] = metric_fn(yte, yhat, scorePos);
    end %end outer fold loop

    %Getting the results across outer folds
    %Computing mean and standard deviation of all three metrics
    ResultsSVM_fixed{cc,'Acc_mean'}       = mean(accF);
    ResultsSVM_fixed{cc,'Acc_std'}        = std(accF);
    ResultsSVM_fixed{cc,'F1_mean'}        = mean(f1F);
    ResultsSVM_fixed{cc,'F1_std'}         = std(f1F);
    ResultsSVM_fixed{cc,'AUC_mean'}       = mean(aucF,'omitnan');
    ResultsSVM_fixed{cc,'AUC_std'}        = std(aucF,'omitnan');
    ResultsSVM_fixed{cc,'AvgNumFeatures'} = mean(nF);  

    %Printing the formatted results for each C value
    fprintf('[FIXED %2d feats] C=%g | Acc %.3f±%.3f | F1 %.3f±%.3f | AUC %.3f±%.3f\n', ...
        overallMax, Cval, mean(accF), std(accF), mean(f1F), std(f1F), mean(aucF), std(aucF));
end %end C loop

% Display final results table
disp('=== SVM (linear) with wrapper FS, FIXED #features (part ii): mean ± std ===');
disp(ResultsSVM_fixed);

%% (F)(i) Random Forest (100 trees, MaxNumSplits=10)

rng(42,'twister'); %setting the RNG seed for reproducible results

%handles
metric_fn = @(ytrue, yhat, scorePos) local_metrics(ytrue, yhat, scorePos, posClass); %wrapper pointing to metric function

%RF hyperparameters
numTrees_i  = 100;%number of trees
maxSplits   = 10; %maximum number of splits per tree
tTree_i     = templateTree('MaxNumSplits', maxSplits);%tree learner template

%Results
ResultsRF_i = table('Size',[1 7], ... % preallocating a 1x7 results table
    'VariableTypes', ["double","double","double","double","double","double","double"], ...%numeric columns
    'VariableNames', {'Acc_mean','Acc_std','F1_mean','F1_std','AUC_mean','AUC_std','AvgNumFeatures'}, ... %column names
    'RowNames', "RF-100trees"); %row label

SelectedMasksRF = cell(1, cvOuter.NumTestSets);%storing the selected feature masks per outer fold
nFeatRF         = zeros(cvOuter.NumTestSets,1);%storing the number of selected features per fold

accF = zeros(cvOuter.NumTestSets,1);%per fold accuracy
f1F  = zeros(cvOuter.NumTestSets,1);%per fold F1
aucF = zeros(cvOuter.NumTestSets,1);%per fold AUC

for fold = 1:cvOuter.NumTestSets %iterating over outer CV folds
    trIdx = training(cvOuter, fold);  teIdx = test(cvOuter, fold);%getting the logical indices for train/test in this fold
    Xtr = Xmat(trIdx,:);  ytr = y(trIdx);%training predictors and labels
    Xte = Xmat(teIdx,:);  yte = y(teIdx);%test predictors and labels

    %Inner CV for FS
    cvInner = cvpartition(ytr, 'KFold', 5);%building the inner 5-fold CV on training data

    critfun = @(Xtr_fs, Ytr_fs, Xval_fs, Yval_fs) ... %defining the objective the FS minimizes
        1 - mean( predict( fitcensemble(Xtr_fs, Ytr_fs, ... %training the RF on current subset
                                        'Method','Bag', ... %bagging
                                        'Learners', tTree_i, ... %tree template
                                        'NumLearningCycles', numTrees_i, ... %number of trees
                                        'ClassNames', categories(Ytr_fs)), ... %preserving the class order
                           Xval_fs) == Yval_fs ); % computing the validation accuracy and converting to error

    %Forward FS with automatic stopping
    inMask = sequentialfs(critfun, Xtr, ytr, ... %performing forward selection on training set
                          'cv', cvInner, ...  %using the inner CV for validation
                          'direction','forward', ... %forward strategy
                          'options', statset('Display','off'));          

    SelectedMasksRF{fold} = inMask;%storing the selected-subset mask for this fold
    nFeatRF(fold) = sum(inMask);  %recording  the number of selected features

    % Training the final RF on selected features
    mdl = fitcensemble(Xtr(:,inMask), ytr, ... %training the RF on selected features
                       'Method','Bag', ... %bagging
                       'Learners', tTree_i, ... tree template
                       'NumLearningCycles', numTrees_i, ...%number of trees
                       'ClassNames', categories(ytr)); %class names

    [yhat, score] = predict(mdl, Xte(:,inMask));%predicting the labels and scores on test split
    [~, posCol]   = ismember(posClass, mdl.ClassNames);%finding the column of positive class in the score matrix
    scorePos      = score(:, posCol); %extracting the positive class scores

    [accF(fold), f1F(fold), aucF(fold)] = metric_fn(yte, yhat, scorePos);%computing the metrics for this fold
end


ResultsRF_i{1,'Acc_mean'}       = mean(accF);%mean accuracy across folds
ResultsRF_i{1,'Acc_std'}        = std(accF);%std of accuracy
ResultsRF_i{1,'F1_mean'}        = mean(f1F);%mean F1
ResultsRF_i{1,'F1_std'}         = std(f1F); %std of F1
ResultsRF_i{1,'AUC_mean'}       = mean(aucF,'omitnan'); %mean AUC
ResultsRF_i{1,'AUC_std'}        = std(aucF,'omitnan'); %std of AUC
ResultsRF_i{1,'AvgNumFeatures'} = mean(nFeatRF);  %average number of features selected

disp('=== Random Forest (100 trees, wrapper FS, 10-fold CV): mean ± std ===');%header for results
disp(ResultsRF_i); %displaying the results table

%Highest number of features selected across folds (to use in part ii)
overallMax_RF = max(nFeatRF);  %computing the maximum number of features picked in part (i)
fprintf('The highest number of features selected across folds = %d\n', overallMax_RF); % printing maximum

%% (F)(ii) Random Forest (20 trees) with wrapper FS


numTrees_ii = 20; %number of trees for part (ii)
tTree_ii    = templateTree('MaxNumSplits', maxSplits);%tree template for part (ii)

ResultsRF_ii = table('Size',[1 7], ... %preallocating the results table for part (ii)
    'VariableTypes', ["double","double","double","double","double","double","double"], ... %numeric columns
    'VariableNames', {'Acc_mean','Acc_std','F1_mean','F1_std','AUC_mean','AUC_std','AvgNumFeatures'}, ... %column names
    'RowNames', "RF-20trees (fixed)");                          

accF = zeros(cvOuter.NumTestSets,1); %per-fold accuracy 
f1F  = zeros(cvOuter.NumTestSets,1); % er-fold F1
aucF = zeros(cvOuter.NumTestSets,1); %per-fold AUC
nF   = zeros(cvOuter.NumTestSets,1); %per-fold number features chosen

for fold = 1:cvOuter.NumTestSets %iterating the outer folds
    trIdx = training(cvOuter, fold);  teIdx = test(cvOuter, fold);% training/testing indices for this fold
    Xtr = Xmat(trIdx,:);  ytr = y(trIdx);  %training data
    Xte = Xmat(teIdx,:);  yte = y(teIdx);  %test data

    cvInner = cvpartition(ytr, 'KFold', 5); %inner 5-fold CV for FS

    critfun = @(Xtr_fs, Ytr_fs, Xval_fs, Yval_fs) ... %objective for FS using 20-tree RF
        1 - mean( predict( fitcensemble(Xtr_fs, Ytr_fs, ...
                                        'Method','Bag', ...
                                        'Learners', tTree_ii, ...
                                        'NumLearningCycles', numTrees_ii, ...
                                        'ClassNames', categories(Ytr_fs)), ...
                           Xval_fs) == Yval_fs );  %validation error

    %Forcing the selector to take exactly overallMax_RF +1 features
    inMask_fixed = sequentialfs(critfun, Xtr, ytr, ... %running the forward FS with fixed size
                                'cv', cvInner, ... %inner CV for validation
                                'direction','forward', ... %forward selection
                                'NFeatures', overallMax_RF + 1, ... %forcing a higher number of features than max from (i)
                                'options', statset('Display','off'));  
    nF(fold) = sum(inMask_fixed); %recording the number of features selected this fold

    mdl20 = fitcensemble(Xtr(:,inMask_fixed), ytr, ... %training the 20-tree RF on selected features
                         'Method','Bag', ...
                         'Learners', tTree_ii, ...
                         'NumLearningCycles', numTrees_ii, ...
                         'ClassNames', categories(ytr));                      

    [yhat, score] = predict(mdl20, Xte(:,inMask_fixed)); %predicting on test set
    [~, posCol]   = ismember(posClass, mdl20.ClassNames);% position of positive class in scores
    scorePos      = score(:, posCol);  %extracting the positive-class scores

    [accF(fold), f1F(fold), aucF(fold)] = metric_fn(yte, yhat, scorePos); %computing the metrics for this fold
end

ResultsRF_ii{1,'Acc_mean'}       = mean(accF);  %mean accuracy across folds
ResultsRF_ii{1,'Acc_std'}        = std(accF);   %std of accuracy
ResultsRF_ii{1,'F1_mean'}        = mean(f1F);   %mean F1
ResultsRF_ii{1,'F1_std'}         = std(f1F);    %std of F1
ResultsRF_ii{1,'AUC_mean'}       = mean(aucF,'omitnan');  %mean AUC
ResultsRF_ii{1,'AUC_std'}        = std(aucF,'omitnan');  %std of AUC
ResultsRF_ii{1,'AvgNumFeatures'} = mean(nF);    %average number of features selected

disp('=== Random Forest (20 trees, wrapper FS with FIXED #features): mean ± std ==='); % header for part (ii) results
disp(ResultsRF_ii);   %displaying part (ii) results


%% helper function (metrics) 
function [acc, f1, auc] = local_metrics(ytrue, yhat, scorePos, posClass)
    % Purpose: compute Accuracy, F1 (with an explicit positive class), and AUC from predictions.
    % Inputs:
    % ytrue     = ground-truth categorical labels 
    % yhat      = predicted categorical labels 
    % scorePos  = numeric vector of scores for the positive class (PD)
    % posClass  = the categorical label considered positive

    % accuracy
    acc = mean(yhat == ytrue);

    %F1 (define positive class explicitly)
    ytrue = categorical(ytrue); yhat = categorical(yhat);  % Ensuring both are categorical for clean comparisons.
    TP = sum( yhat==posClass & ytrue==posClass ); %True Positives: predicted PD and actually PD.
    FP = sum( yhat==posClass & ytrue~=posClass ); %False Positives: predicted PD but actually control.
    FN = sum( yhat~=posClass & ytrue==posClass ); %False Negatives: predicted control but actually PD.
    
    if TP+FP==0, prec = 0; else, prec = TP/(TP+FP); end % Precision = TP/(TP+FP)
    if TP+FN==0, rec  = 0; else, rec  = TP/(TP+FN); end %Recall (Sensitivity) = TP/(TP+FN); same guarding.
    if prec+rec==0, f1 = 0; else, f1 = 2*prec*rec/(prec+rec); end %F1 = harmonic mean

    % AUC(ROC), use perfcurve over the positive class scores
    try
        [~,~,~,auc] = perfcurve(ytrue, scorePos, posClass);% perfcurve: builds ROC and returns AUC for the specified positive class.
    catch
        % if scores are degenerate (e.g., single class in fold)
        auc = NaN; % If a fold had only one class, ROC is undefined, return NaN.
    end
end


%% helper function: feature derivation 
function S = derive_features_from_grf(L, R, Fs, th, minPeakDist, minPkProm, minMnProm)
    N  = numel(L); %determining the number of samples
    t  = (0:N-1).'/Fs; %creating a time vector in seconds

    cL = L > th; %creating a left contact mask using the threshold
    cR = R > th; %creating a right contact mask using the threshold

    icL = t(find(~cL(1:end-1) &  cL(2:end)) + 1); %detecting left initial contacts (rising edges)
    fcL = t(find( cL(1:end-1) & ~cL(2:end)) + 1); %detecting left final contacts  (falling edges)
    icR = t(find(~cR(1:end-1) &  cR(2:end)) + 1); %detecting right initial contacts
    fcR = t(find( cR(1:end-1) & ~cR(2:end)) + 1); %detecting right final contacts

    strideL = diff(icL); %computing left stride times (IC to next IC)
    strideR = diff(icR); %computing right stride times (IC to next IC)
    stride  = [strideL; strideR];  %combining stride times from both feet

    strideMean = mean(stride, 'omitnan');  %computing mean stride time across both feet
    strideCV   = std(stride, 'omitnan') / strideMean; %computing coefficient of variation of stride time

    muL = mean(strideL, 'omitnan'); %computing left mean stride time
    muR = mean(strideR, 'omitnan'); %computing right mean stride time
    muB = mean([strideL; strideR], 'omitnan'); %computing overall mean stride time
    asym = abs(muL - muR) / muB; %computing stride-time asymmetry ratio

    [pL,locPL] = findpeaks(L, 'MinPeakDistance',minPeakDist, ...  %detecting left GRF maxima with constraints
                                 'MinPeakProminence',minPkProm);  %applying minimum prominence for robustness
    [pR,locPR] = findpeaks(R, 'MinPeakDistance',minPeakDist, ...  %detecting right GRF maxima with constraints
                                 'MinPeakProminence',minPkProm);  %applying minimum prominence for robustness
    [mL,~]     = findpeaks(-L,'MinPeakDistance',round(0.3*Fs), ...%detecting left mid-stance minima on inverted signal
                                 'MinPeakProminence',minMnProm);  %applying minimum prominence for minima
    [mR,~]     = findpeaks(-R,'MinPeakDistance',round(0.3*Fs), ...%detecting right mid-stance minima on inverted signal
                                 'MinPeakProminence',minMnProm);  %applying minimum prominence for minima

     
    % helper that converts a contact mask into IC->FC durations
    function durs = mask_to_durations(c, tvec)
        %rising (IC) and falling (FC) edge indices
        r = find(~c(1:end-1) &  c(2:end)) + 1;   %IC indices
        f = find( c(1:end-1) & ~c(2:end)) + 1;   %FC indices
        if isempty(r) || isempty(f)
            durs = [];
            return
        end
        %stop any FC that occurs before the first IC
        if f(1) < r(1), f(1) = []; end
        if isempty(f)
            durs = [];
            return
        end
        % pairing chronologically (IC then FC)
        K = min(numel(r), numel(f));
        r = r(1:K);  f = f(1:K);
        d = tvec(f) - tvec(r);                   %stance durations (s)
        durs = d(isfinite(d) & d > 0);           %keep valid positives
    end

    %durations from each foot
    ctL = mask_to_durations(cL, t);
    ctR = mask_to_durations(cR, t);

    %combine and average
    ctimes = [ctL; ctR];
    ctMean = mean(ctimes, 'omitnan');   %ContactTimeMean


    ctMean = mean(ctimes, 'omitnan');   %computing mean contact time in seconds

    loadRates = [];      %initializing a vector for loading rates
    for k = 1:min(numel(icL), numel(locPL))  %iterating over left IC to first peak pairs
        idxIC = max(1, round(icL(k)*Fs)); %converting left IC time to index
        idxPk = locPL(k);  %getting the index of the first left peak
        if idxPk > idxIC   %ensuring peak occurs after IC
            dF = L(idxPk) - L(idxIC);   %computing rise in force
            dt = (idxPk - idxIC) / Fs;  %computing elapsed time
            if dt > 0   %checking for positive duration
                loadRates(end+1,1) = dF/dt; %computing loading rate and appending it
            end
        end
    end
    for k = 1:min(numel(icR), numel(locPR))  %iterating over right IC to first peak pairs
        idxIC = max(1, round(icR(k)*Fs));  %converting right IC time to index
        idxPk = locPR(k);   %getting the index of the first right peak
        if idxPk > idxIC   %ensuring peak occurs after IC
            dF = R(idxPk) - R(idxIC);  %computing rise in force
            dt = (idxPk - idxIC) / Fs;  %computing elapsed time
            if dt > 0  %checking for positive duration
                loadRates(end+1,1) = dF/dt; %computing loading rate and appending it
            end
        end
    end

    dsr = sum((L>th) & (R>th)) / N; %computing the double support ratio across time

    S = struct();  %creating a structure to hold feature values
    S.StepCount          = numel(pL) + numel(pR); %assigning total step count
    S.StrideTimeMean     = strideMean;  %assigning mean stride time
    S.StrideTimeCV       = strideCV;  %assigning stride time coefficient of variation
    S.StrideTimeAsym     = asym;  %assigning stride time asymmetry
    S.PeakGRF_Mean       = mean([pL; pR], 'omitnan'); %assigning mean of GRF peaks
    S.PeakGRF_Std        = std([pL; pR],  'omitnan'); %assigning standard deviation of GRF peaks
    S.MinGRF_Mean        = mean([-mL; -mR], 'omitnan');%assigning mean of GRF minima
    S.DoubleSupportRatio = dsr;  %assigning double support ratio
    S.ContactTimeMean    = ctMean; %assigning mean contact time
    S.LoadingRate_Mean   = mean(loadRates, 'omitnan'); %assigning mean loading rate
end




%% helper function: print summary tables 
function print_summary(F, featNames)
    groups = ["All","PD","CO"]; %defining the groups to summarise
    masks  = {true(height(F),1), F.Group=="PD", F.Group=="CO"}; %creating row masks for each group
    for g = 1:numel(groups)  %iterating over groups
        fprintf('\n===== SUMMARY (%s) =====\n', groups(g));%printing section heading
        T = table(); %creating a new summary table
        T.Feature = featNames(:);%inserting the feature names as the first column
        stats = nan(numel(featNames),5); %allocating an array for statistics
        for k = 1:numel(featNames)  %iterating over features
            x = F{masks{g}, featNames(k)}; %extracting values for the current group
            stats(k,1) = min(x,[],'omitnan'); %computing minimum
            stats(k,2) = max(x,[],'omitnan'); %computing maximum
            stats(k,3) = mean(x,'omitnan');  %computing mean
            stats(k,4) = std(x,'omitnan');  %computing standard deviation
            stats(k,5) = median(x,'omitnan'); %computing median
        end
        T.Min    = stats(:,1); %appending minimum column
        T.Max    = stats(:,2); %appending maximum column
        T.Mean   = stats(:,3); %appending mean column
        T.Std    = stats(:,4); %appending standard deviation column
        T.Median = stats(:,5); %appending median column
        disp(T); %displaying the summary table
    end
end


%% helper function: PD vs CO distributions
function plot_distributions(F, featNames)
    colPD = [0.85 0.33 0.10];  %defining the color for PD
    colCO = [0.00 0.45 0.74];  %defining the color for controls
    isPD  = F.Group=="PD";     %creating a mask for PD rows
    isCO  = F.Group=="CO";     %creating a mask for control rows
    for k = 1:numel(featNames) %iterating over features
        xPD = F{isPD, featNames(k)}; %extracting PD values for the feature
        xCO = F{isCO, featNames(k)}; %extracting control values for the feature
        figure('Color','w','Position',[200 200 900 450]); %creating a figure window
        xf = [xPD; xCO]; xf = xf(isfinite(xf)); %collecting finite values for binning
        if numel(xf) >= 10  %choosing the number of bins based on sample size
            nb = max(10, min(40, round(sqrt(numel(xf))))); %setting the bin count using the sqrt rule
        else
            nb = 8;  %using a small default when data are scarce
        end
        histogram(xCO, nb, 'Normalization','pdf', ... %plotting control histogram as a PDF
            'FaceColor', colCO, 'FaceAlpha', 0.35, 'EdgeColor','none'); hold on; %styling the control histogram
        histogram(xPD, nb, 'Normalization','pdf', ...  %plotting PD histogram as a PDF
            'FaceColor', colPD, 'FaceAlpha', 0.35, 'EdgeColor','none'); %styling the PD histogram
        xline(mean(xCO,'omitnan'),'-','CO mean','Color',colCO,'LineWidth',1.5, ...
            'LabelVerticalAlignment','bottom','LabelOrientation','horizontal');  %drawing a line for the control mean
        xline(mean(xPD,'omitnan'),'-','PD mean','Color',colPD,'LineWidth',1.5, ...
            'LabelVerticalAlignment','top','LabelOrientation','horizontal'); %drawing a line for the PD mean
        grid on; box on; %enabling grid and box for readability
        title(sprintf('Distribution of %s (PD vs CO)', featNames(k)), 'Interpreter','none'); %adding a title
        xlabel(featNames(k), 'Interpreter','none'); %labeling the x-axis with the feature name
        ylabel('PDF');  %labeling the y-axis as probability density
        legend({'CO','PD'}, 'Location','best'); %adding a legend for the two cohorts
    end
end

