clear; clc; 

% File paths
file1 = 'matlab_pool_output.txt'; % Reference/Gold output
file2 = 'pool_output.txt';        % RTL/Hardware output

% Format mode options: 'binary_int8', 'hex_int8', or 'decimal'
fileFormat = 'binary_int8'; 

%% ================= READ & PARSE FILES =================
data1 = readDataFile(file1, fileFormat);
data2 = readDataFile(file2, fileFormat);

if length(data1) ~= length(data2)
    error('File length mismatch! File 1 has %d elements, File 2 has %d elements.', ...
          length(data1), length(data2));
end

%% ================= ERROR METRICS CALCULATION =================
absError = abs(data1 - data2);
sqError  = (data1 - data2).^2;

maxErr = max(absError);
mae    = mean(absError);
mse    = mean(sqError);
rmse   = sqrt(mse);

%% ================= ACCURACY CALCULATION =================
% Correct matches count when data values match exact class predictions
correctPredictions = (data1 == data2);
accuracyPercent    = (sum(correctPredictions) / length(data1)) * 100;

%% ================= DISPLAY RESULTS =================
fprintf('====================================================\n');
fprintf('           RTL VS GOLDEN MODEL ANALYSIS             \n');
fprintf('====================================================\n');
fprintf('Total Samples Evaluated : %d\n', length(data1));
fprintf('Correct Predictions     : %d / %d\n', sum(correctPredictions), length(data1));
fprintf('Testing Accuracy        : %.2f%%\n', accuracyPercent);
fprintf('----------------------------------------------------\n');
fprintf('Maximum Error           : %.6f\n', maxErr);
fprintf('Mean Absolute Error (MAE): %.6f\n', mae);
fprintf('Mean Squared Error  (MSE): %.6f\n', mse);
fprintf('Root Mean Sq. Error (RMSE): %.6f\n', rmse);
fprintf('====================================================\n');

%% ================= HELPER FUNCTION =================
function data = readDataFile(filename, formatType)
    if ~exist(filename, 'file')
        error('File not found: %s', filename);
    end
    
    fid = fopen(filename, 'r');
    rawText = textscan(fid, '%s');
    fclose(fid);
    rawStrings = rawText{1};
    
    % Filter out empty lines
    rawStrings = rawStrings(~cellfun(@isempty, rawStrings));
    data = zeros(length(rawStrings), 1);
    
    switch lower(formatType)
        case 'binary_int8'
            for k = 1:length(rawStrings)
                str = strtrim(rawStrings{k});
                
                % Replace RTL 'X', 'x', 'Z', 'z' states with '0'
                str = regexprep(str, '[xXzZ]', '0');
                
                % Remove any non-binary characters
                str = regexprep(str, '[^01]', '');
                
                if isempty(str)
                    data(k) = 0;
                else
                    uVal = uint8(bin2dec(str));
                    data(k) = double(typecast(uVal, 'int8'));
                end
            end
            
        case 'hex_int8'
            for k = 1:length(rawStrings)
                str = strtrim(rawStrings{k});
                str = regexprep(str, '[xXzZ]', '0');
                str = regexprep(str, '[^0-9a-fA-F]', '');
                
                if isempty(str)
                    data(k) = 0;
                else
                    uVal = uint8(hex2dec(str));
                    data(k) = double(typecast(uVal, 'int8'));
                end
            end
            
        case 'decimal'
            data = str2double(rawStrings);
            data = data(~isnan(data));
            
        otherwise
            error('Unsupported formatType. Use "binary_int8", "hex_int8", or "decimal".');
    end
end