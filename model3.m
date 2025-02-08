clc; clear; close all;

%% Set Working Directory and Define File Paths
cd('C:\Users\Nitro-V\Documents\MATLAB');
disp(['Current working directory: ', pwd]);

% Define paths for the Excel file and HTML report
excelFile = fullfile(pwd, 'waste_classification.xlsx');
htmlFile  = fullfile(pwd, 'waste_report.html');

%% PART 1: Image Processing, Classification, and Data Collection

% Select multiple JPEG images using a file selection dialog
[imgNames, imgFolder] = uigetfile({'*.jpg;*.jpeg', 'JPEG Images (*.jpg, *.jpeg)'}, ...
    'Select Waste Images', 'MultiSelect', 'on');

if isequal(imgNames, 0)
    disp('No files selected.');
    return;
end

% Convert a single selection to cell array for uniform handling
if ischar(imgNames)
    imgNames = {imgNames};
end

numImages = length(imgNames);

% Load the pre-trained classifier
load('waste_classifier.mat', 'classifier');

% Initialize storage for new data (columns: Image_Name, Category, Weight_kg)
newData = cell(numImages, 3);

for i = 1:numImages
    % Build full image path
    imgPath = fullfile(imgFolder, imgNames{i});
    
    % Read and preprocess the image
    img = imread(imgPath);
    img = imresize(img, [256, 256]);  % Resize to match training images
    grayImg = rgb2gray(img);
    
    % Extract features: mean color (across channels) and a texture feature (via GLCM)
    colorFeatures = mean(mean(img, 1), 2);
    glcm = graycomatrix(grayImg, 'Offset', [2 0]);
    textureFeature = mean2(glcm);
    featuresNew = [colorFeatures(:)', textureFeature];
    
    % Predict the waste category
    predictedIndex = predict(classifier, featuresNew);
    categories = {'Biodegradable', 'Non-Biodegradable', 'Hazardous'};
    predictedLabel = categories{predictedIndex};
    
    % Display the image with its predicted category (optional)
    figure;
    imshow(img);
    title(['Category: ', predictedLabel]);
    
    % Ask the user to input the weight for the image (in kg)
    validWeight = false;
    while ~validWeight
        weightInput = inputdlg(['Enter weight (kg) for ', imgNames{i}], 'Input Weight', [1 50]);
        if isempty(weightInput)
            disp(['No weight entered for ', imgNames{i}, '. Setting weight as 0 kg.']);
            weightValue = 0;
            validWeight = true;
        else
            weightValue = str2double(weightInput{1});
            if ~isnan(weightValue) && weightValue >= 0
                validWeight = true;
            else
                disp('Invalid input! Please enter a valid weight in kg.');
            end
        end
    end
    
    % Store the image name, predicted category, and weight in newData
    newData(i, :) = {imgNames{i}, predictedLabel, weightValue};
end

% Convert new data to a table
newDataTable = cell2table(newData, 'VariableNames', {'Image_Name', 'Category', 'Weight_kg'});

% Check if the Excel file already exists; if so, append new data; otherwise, create new
if exist(excelFile, 'file') == 2
    try
        oldData = readtable(excelFile);
        % Ensure column names match before merging
        if width(oldData) ~= width(newDataTable) || ~all(strcmp(oldData.Properties.VariableNames, newDataTable.Properties.VariableNames))
            warning('Existing Excel file structure is incorrect. Overwriting with new data.');
            finalTable = newDataTable;
        else
            finalTable = [oldData; newDataTable];
        end
    catch ME
        warning('Could not read existing Excel file. Creating a new one. Error: %s', ME.message);
        finalTable = newDataTable;
    end
else
    finalTable = newDataTable;
end

% Write the combined table to the Excel file
writetable(finalTable, excelFile);
disp(['? Data saved to ', excelFile]);

%% PART 2: Generate HTML Report from Excel Data

% Verify that the Excel file exists and read its data
if exist(excelFile, 'file') ~= 2
    error('Excel file not found! Ensure waste_classification.xlsx exists.');
end

dataTable = readtable(excelFile);

% Ensure the table has the expected columns
expectedColumns = {'Image_Name', 'Category', 'Weight_kg'};
if ~all(ismember(expectedColumns, dataTable.Properties.VariableNames))
    error('Excel file does not have expected columns: Image_Name, Category, Weight_kg');
end

% Get unique categories and calculate the total weight per category
uniqueCategories = unique(dataTable.Category);
totalWeights = zeros(length(uniqueCategories), 1);
for i = 1:length(uniqueCategories)
    totalWeights(i) = sum(dataTable.Weight_kg(strcmp(dataTable.Category, uniqueCategories{i})));
end

% Open an HTML file for writing
fid = fopen(htmlFile, 'w');
if fid == -1
    error('Could not open HTML file for writing.');
end

% Write HTML header and inline CSS for styling
fprintf(fid, '<!DOCTYPE html>\n<html>\n<head>\n');
fprintf(fid, '<title>Waste Classification Report</title>\n');
fprintf(fid, '<style>\n');
fprintf(fid, 'body { font-family: Arial, sans-serif; margin: 40px; background-color: #f4f4f4; text-align: center; }\n');
fprintf(fid, 'h1 { color: #333; }\n');
fprintf(fid, 'table { width: 80%%; margin: auto; border-collapse: collapse; background: white; }\n');
fprintf(fid, 'th, td { padding: 10px; border: 1px solid #ddd; text-align: center; }\n');
fprintf(fid, 'th { background-color: #4CAF50; color: white; }\n');
fprintf(fid, 'tr:nth-child(even) { background-color: #f2f2f2; }\n');
fprintf(fid, 'img { width: 100px; height: auto; border-radius: 5px; }\n');
fprintf(fid, '</style>\n</head>\n<body>\n');

% Write the report title
fprintf(fid, '<h1>Waste Classification Report</h1>\n');

% Write summary table: Total weight per category
fprintf(fid, '<h2>Total Waste Summary</h2>\n');
fprintf(fid, '<table>\n<tr><th>Category</th><th>Total Weight (kg)</th></tr>\n');
for i = 1:length(uniqueCategories)
    fprintf(fid, '<tr><td>%s</td><td>%.2f kg</td></tr>\n', uniqueCategories{i}, totalWeights(i));
end
fprintf(fid, '</table>\n');

% Write detailed item-wise data table
fprintf(fid, '<h2>Item Details</h2>\n');
fprintf(fid, '<table>\n<tr><th>Image</th><th>Category</th><th>Weight (kg)</th></tr>\n');
for i = 1:height(dataTable)
    imgName = dataTable.Image_Name{i};
    category = dataTable.Category{i};
    weight = dataTable.Weight_kg(i);
    % Assumes the images are in the same folder as the HTML report
    fprintf(fid, '<tr>\n');
    fprintf(fid, '<td><img src="%s" alt="%s"></td>\n', imgName, imgName);
    fprintf(fid, '<td>%s</td>\n', category);
    fprintf(fid, '<td>%.2f kg</td>\n', weight);
    fprintf(fid, '</tr>\n');
end
fprintf(fid, '</table>\n');

fprintf(fid, '</body>\n</html>\n');
fclose(fid);

disp(['? HTML report generated: ', htmlFile]);
