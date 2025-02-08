clc; clear; close all;

% Define the main dataset folder and categories
imageFolder = 'dataset';
categories = {'Biodegradable', 'Non-Biodegradable', 'Hazardous'};

% Initialize arrays to store features and labels
features = [];
labels = [];

% Loop over each category folder
for i = 1:length(categories)
    folderPath = fullfile(imageFolder, categories{i});
    imageFiles = dir(fullfile(folderPath, '*.jpg'));  % Adjust if your images are in a different format
    
    if isempty(imageFiles)
        warning(['No images found in folder: ', folderPath]);
        continue;
    end
    
    % Process each image in the folder
    for j = 1:length(imageFiles)
        imgPath = fullfile(folderPath, imageFiles(j).name);
        img = imread(imgPath);
        img = imresize(img, [256 256]);  % Standardize image size
        
        % Convert image to grayscale (for texture feature extraction)
        grayImg = rgb2gray(img);
        
        % Extract Color Features: Compute mean color for each channel (R, G, B)
        colorFeatures = mean(mean(img, 1), 2);  % Returns a 1x3 vector
        
        % Extract a Texture Feature using the Gray-Level Co-occurrence Matrix (GLCM)
        glcm = graycomatrix(grayImg, 'Offset', [2 0]);
        textureFeature = mean2(glcm);  % Compute the mean of the GLCM
        
        % Combine the features into a single row vector
        imageFeatures = [colorFeatures(:)', textureFeature];
        
        % Append the features and the corresponding label (using index i)
        features = [features; imageFeatures];
        labels = [labels; i];  
    end
end

% Convert numeric labels to categorical (helps with SVM training)
labels = categorical(labels);

% Check if any features were extracted
if isempty(features)
    error('No features were extracted. Please check your dataset folders and image files.');
end

% Train the SVM Classifier with a linear kernel
classifier = fitcecoc(features, labels);


% Save the trained classifier for future use
save('waste_classifier.mat', 'classifier');

disp('? SVM Classifier trained and saved successfully.');
