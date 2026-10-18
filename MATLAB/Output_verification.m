clear; clc; close all;

%% ============================================================
% CONFIGURATION
% =============================================================
IMAGE_MEM_FILE   = 'hand_drawn7.mem';
WEIGHTS_MEM_FILE = 'weights.mem';
RTL_OUTPUT_FILE  = 'pool_output.txt';

%% ============================================================
% LOAD IMAGE FROM .MEM FILE
% =============================================================
fid = fopen(IMAGE_MEM_FILE, 'r');
if fid == -1
    error('Cannot open %s', IMAGE_MEM_FILE);
end

data = textscan(fid, '%8s');
fclose(fid);

bin = data{1};

if length(bin) ~= 28*28
    error('Expected 784 image pixels, found %d.', length(bin));
end

pixels = bin2dec(bin);

%% ============================================================
% RECONSTRUCT & DISPLAY IMAGE
% =============================================================
img = reshape(pixels, [28,28])';

figure;
imshow(uint8(img), []);
colormap(gray);
colorbar;
title('Input Image from MEM File');

%% ============================================================
% QUANTIZE INPUT (0...255 -> 0...127)
% =============================================================
img_q = int8(round(single(img) / 255 * 127));

%% ============================================================
% LOAD WEIGHTS
% =============================================================
fid = fopen(WEIGHTS_MEM_FILE, 'r');

if fid == -1
    error('Cannot open %s', WEIGHTS_MEM_FILE);
end

data = textscan(fid, '%8s');
fclose(fid);

weight_bin = data{1};

if length(weight_bin) ~= 9
    error('Expected 9 weights for 3x3 kernel, found %d.', ...
          length(weight_bin));
end

weight_uint = bin2dec(weight_bin);
weight_signed = double(weight_uint);

weight_signed(weight_signed >= 128) = ...
    weight_signed(weight_signed >= 128) - 256;

kernel_q = int8(reshape(weight_signed, [3,3])');

fprintf('\n====================================================\n');
fprintf('              QUANTIZED WEIGHTS\n');
fprintf('====================================================\n');
disp(kernel_q);

%% ============================================================
% FIXED-POINT CONVOLUTION
% =============================================================
conv_out = zeros(26,26,'int32');

for i = 1:26
    for j = 1:26

        window = int32(img_q(i:i+2,j:j+2));
        w      = int32(kernel_q);

        conv_out(i,j) = sum(window(:) .* w(:));

    end
end

%% ============================================================
% RELU
% =============================================================

conv_out(conv_out < 0) = 0;

% %% ============================================================
% % MLF SIGMOID ACTIVATION
% % =============================================================
% mlf_out = zeros(size(conv_out),'int32');
% 
% % Q10.10 Fixed-Point Constants
% C0 = 1024;
% C1 = 1100;
% C2 = 692;
% C3 = 342;
% 
% % Match hardware input scaling factor
% SCALE_FACTOR = 16.0;
% 
% for i = 1:size(conv_out,1)
%     for j = 1:size(conv_out,2)
% 
%         x_raw = double(conv_out(i,j));
% 
%         if x_raw <= 0
% 
%             y_val = 0;
% 
%         else
% 
%             % Map convolution dynamic range into polynomial domain
%             x = x_raw / SCALE_FACTOR;
% 
%             % Polynomial evaluation matching hardware pipeline
%             t1 = (C1 * x) / 1024.0;
%             t2 = (C2 * (x^2)) / (1024.0^2);
%             t3 = (C3 * (x^3)) / (1024.0^3);
% 
%             E_approx = C0 - t1 + t2 - t3;
% 
%             denom = 1024.0 + E_approx;
% 
%             if denom <= 1024.0
% 
%                 y_norm = 1.0;
% 
%             else
% 
%                 y_norm = 1024.0 / denom;
% 
%             end
% 
%             % Pass-through proportional dynamic output
%             y_val = round(x_raw * y_norm);
% 
%         end
% 
%         mlf_out(i,j) = int32(y_val);
% 
%     end
% end
% 
% conv_out = mlf_out;

%% ============================================================
% MAXPOOL (2x2 WINDOW, STRIDE = 2)
% =============================================================
pool_out = zeros(13,13,'int32');

for i = 1:13
    for j = 1:13

        block = conv_out(2*i-1:2*i, 2*j-1:2*j);

        pool_out(i,j) = max(block(:));

    end
end

matlab_map = pool_out;

%% ============================================================
% LOAD RTL POOL OUTPUT
% =============================================================
fid = fopen(RTL_OUTPUT_FILE, 'r');

if fid == -1
    error('Cannot open file. Check the name.');
end

data = textscan(fid, '%d : %d');

fclose(fid);

rtl_vals = int32(data{2});

if length(rtl_vals) ~= 169
    error('RTL output size mismatch! Expected 169 values, found %d.', ...
          length(rtl_vals));
end

%% ============================================================
% RECONSTRUCT RTL OUTPUT AS ROW-MAJOR 13x13 MAP
% =============================================================
% RTL feature memory is written as:
%
% address = 13 * row + column
%
% Therefore the sequential RTL values are interpreted
% row-by-row and transposed for MATLAB display.

rtl_map = reshape(rtl_vals, [13,13]).';

%% ============================================================
% DISPLAY MATLAB AND RTL OUTPUT IN SAME ORIENTATION
% =============================================================
figure;

subplot(1,3,1);

imagesc(matlab_map);
axis image;
colormap(gray);
colorbar;

title('MATLAB Pooled Output');
xlabel('Column');
ylabel('Row');

subplot(1,3,2);

imagesc(rtl_map);
axis image;
colormap(gray);
colorbar;

title('RTL Pooled Output');
xlabel('Column');
ylabel('Row');

%% ============================================================
% DIFFERENCE
% =============================================================
diff = matlab_map - rtl_map;

abs_diff = abs(diff);

subplot(1,3,3);

imagesc(abs_diff);
axis image;
colormap(gray);
colorbar;

title('Absolute Difference');
xlabel('Column');
ylabel('Row');

%% ============================================================
% ERROR METRICS
% =============================================================
% max_err = max(abs_diff(:));
% 
% mean_abs_err = mean(double(abs_diff(:)));
% 
% mse = mean(double(diff(:)).^2);
% 
% rmse = sqrt(mse);
% 
% fprintf('\n====================================================\n');
% fprintf('              RTL ALIGNMENT\n');
% fprintf('====================================================\n');
% fprintf('Orientation = ROW-MAJOR\n');
% fprintf('Maximum alignment error = %d\n', max_err);
% 
% fprintf('\n====================================================\n');
% fprintf('              VERIFICATION RESULTS\n');
% fprintf('====================================================\n');
% 
% fprintf('Maximum Error       = %d\n', max_err);
% fprintf('Mean Absolute Error = %.6f\n', mean_abs_err);
% fprintf('Mean Squared Error  = %.6f\n', mse);
% fprintf('RMSE                = %.6f\n', rmse);
% 
% fprintf('====================================================\n');
% 
% if max_err == 0
% 
%     fprintf('RESULT: PERFECT MATCH\n');
% 
% elseif max_err <= 5
% 
%     fprintf('RESULT: PASS - Small difference\n');
% 
% else
% 
%     fprintf('RESULT: FAIL - Check RTL\n');
% 
% end
% 
% fprintf('====================================================\n');

%% ============================================================
% SAVE MATLAB OUTPUT IN RTL FORMAT
% =============================================================
% Convert the 13x13 MATLAB map into sequential row-major data.

matlab_flat = matlab_map';
matlab_flat = matlab_flat(:);

fid = fopen('matlab_pool_output.txt', 'w');

if fid == -1
    error('Cannot open matlab_pool_output.txt for writing.');
end

for idx = 0:length(matlab_flat)-1

    fprintf(fid, '%d : %d\n', ...
            idx, matlab_flat(idx + 1));

end

fclose(fid);

fprintf('\nMATLAB pool output saved in formatted style to matlab_pool_output.txt\n');






% clear; clc; close all;
% 
% %% ============================================================
% % CONFIGURATION
% % =============================================================
% 
% IMAGE_MEM_FILE   = 'image7.mem';
% WEIGHTS_MEM_FILE = 'weights.mem';
% RTL_OUTPUT_FILE  = 'pool_output.txt';
% 
% %% ============================================================
% % LOAD IMAGE FROM .MEM FILE
% % =============================================================
% %
% % Image:
% %   784 values
% %   8-bit unsigned binary
% %   Row-wise ordering
% %
% % =============================================================
% 
% fid = fopen(IMAGE_MEM_FILE, 'r');
% 
% if fid == -1
%     error('Cannot open %s', IMAGE_MEM_FILE);
% end
% 
% data = textscan(fid, '%8s');
% fclose(fid);
% 
% bin = data{1};
% 
% if length(bin) ~= 28*28
%     error('Expected 784 image pixels, found %d.', length(bin));
% end
% 
% pixels = bin2dec(bin);
% 
% %% ============================================================
% % RECONSTRUCT IMAGE
% % =============================================================
% 
% img = reshape(pixels, [28,28])';
% 
% %% ============================================================
% % DISPLAY INPUT IMAGE
% % =============================================================
% 
% figure;
% 
% imshow(uint8(img), []);
% 
% colormap(gray);
% colorbar;
% 
% title('Input Image from MEM File');
% 
% %% ============================================================
% % QUANTIZE INPUT
% % =============================================================
% %
% % Same scaling as previous MATLAB model:
% %
% %   0...255  -->  0...127
% %
% % =============================================================
% 
% img_q = int8(round(single(img) / 255 * 127));
% 
% %% ============================================================
% % LOAD WEIGHTS FROM weights.mem
% % =============================================================
% %
% % Expected:
% %   9 values
% %   8-bit signed two's-complement binary
% %
% % =============================================================
% 
% fid = fopen(WEIGHTS_MEM_FILE, 'r');
% 
% if fid == -1
%     error('Cannot open %s', WEIGHTS_MEM_FILE);
% end
% 
% data = textscan(fid, '%8s');
% fclose(fid);
% 
% weight_bin = data{1};
% 
% %% ============================================================
% % CHECK WEIGHT SIZE
% % =============================================================
% 
% if length(weight_bin) ~= 9
%     error('Expected 9 weights for 3x3 kernel, found %d.', ...
%           length(weight_bin));
% end
% 
% %% ============================================================
% % CONVERT SIGNED 8-BIT BINARY TO DECIMAL
% % =============================================================
% 
% weight_uint = bin2dec(weight_bin);
% 
% weight_signed = double(weight_uint);
% 
% % Convert 8-bit two's complement to signed value
% weight_signed(weight_signed >= 128) = ...
%     weight_signed(weight_signed >= 128) - 256;
% 
% kernel_q = int8(weight_signed);
% 
% %% ============================================================
% % RECONSTRUCT 3x3 KERNEL
% % =============================================================
% %
% % weights.mem is assumed to be stored row-wise.
% %
% % =============================================================
% 
% kernel_q = reshape(kernel_q, [3,3])';
% 
% %% ============================================================
% % DISPLAY WEIGHTS
% % =============================================================
% 
% fprintf('\n====================================================\n');
% fprintf('              QUANTIZED WEIGHTS\n');
% fprintf('====================================================\n');
% 
% disp(kernel_q);
% 
% %% ============================================================
% % FIXED-POINT CONVOLUTION
% % =============================================================
% 
% conv_out = zeros(26,26,'int32');
% 
% for i = 1:26
%     for j = 1:26
% 
%         window = int32(img_q(i:i+2,j:j+2));
%         w      = int32(kernel_q);
% 
%         conv_out(i,j) = sum(window(:) .* w(:));
% 
%     end
% end
% 
% %% ============================================================
% % RELU
% % =============================================================
% 
% conv_out(conv_out < 0) = 0;
% 
% %% ============================================================
% % MAXPOOL
% % 2x2 WINDOW
% % STRIDE = 2
% % =============================================================
% 
% pool_out = zeros(13,13,'int32');
% 
% for i = 1:13
%     for j = 1:13
% 
%         block = conv_out(2*i-1:2*i, ...
%                          2*j-1:2*j);
% 
%         pool_out(i,j) = max(block(:));
% 
%     end
% end
% 
% matlab_map = pool_out;
% 
% %% ============================================================
% % LOAD RTL POOL OUTPUT
% % =============================================================
% 
% fid = fopen(RTL_OUTPUT_FILE, 'r');
% 
% if fid == -1
%     error('Cannot open %s', RTL_OUTPUT_FILE);
% end
% 
% data = textscan(fid, '%d : %d');
% fclose(fid);
% 
% rtl_vals = int32(data{2});
% 
% %% ============================================================
% % CHECK RTL OUTPUT SIZE
% % =============================================================
% 
% if length(rtl_vals) ~= 169
%     error('RTL output size mismatch! Expected 169 values, found %d.', ...
%           length(rtl_vals));
% end
% 
% %% ============================================================
% % RECONSTRUCT RTL 13x13 MAP
% % =============================================================
% 
% rtl_map = reshape(rtl_vals, [13,13]);
% 
% %% ============================================================
% % ALIGNMENT CHECK
% % =============================================================
% 
% rtl_direct = rtl_map;
% rtl_trans  = rtl_map';
% 
% err_direct = max(abs(matlab_map(:) - rtl_direct(:)));
% err_trans  = max(abs(matlab_map(:) - rtl_trans(:)));
% 
% if err_trans < err_direct
% 
%     rtl_map = rtl_trans;
% 
%     fprintf('\nAlignment = TRANSPOSED\n');
% 
% else
% 
%     rtl_map = rtl_direct;
% 
%     fprintf('\nAlignment = DIRECT\n');
% 
% end
% 
% %% ============================================================
% % CALCULATE DIFFERENCE
% % =============================================================
% 
% diff = matlab_map - rtl_map;
% 
% abs_diff = abs(diff);
% 
% %% ============================================================
% % ERROR METRICS
% % =============================================================
% 
% max_err = max(abs_diff(:));
% 
% mean_abs_err = mean(double(abs_diff(:)));
% 
% mse = mean(double(diff(:)).^2);
% 
% rmse = sqrt(mse);
% 
% %% ============================================================
% % NORMALIZED MSE
% % =============================================================
% 
% matlab_double = double(matlab_map);
% 
% if sum(matlab_double(:).^2) == 0
%     nmse = 0;
% else
%     nmse = sum(double(diff(:)).^2) / ...
%            sum(matlab_double(:).^2);
% end
% 
% %% ============================================================
% % PRINT RESULTS
% % =============================================================
% 
% fprintf('\n');
% fprintf('====================================================\n');
% fprintf('              VERIFICATION RESULTS\n');
% fprintf('====================================================\n');
% 
% fprintf('Image       = %s\n', IMAGE_MEM_FILE);
% fprintf('Weights     = %s\n', WEIGHTS_MEM_FILE);
% fprintf('RTL Output  = %s\n', RTL_OUTPUT_FILE);
% 
% fprintf('\n');
% 
% fprintf('Maximum Error       = %d\n', max_err);
% fprintf('Mean Absolute Error = %.6f\n', mean_abs_err);
% fprintf('Mean Squared Error  = %.6f\n', mse);
% fprintf('RMSE                = %.6f\n', rmse);
% fprintf('Normalized MSE      = %.8f\n', nmse);
% 
% fprintf('====================================================\n');
% 
% %% ============================================================
% % PASS / FAIL
% % =============================================================
% 
% if max_err == 0
% 
%     fprintf('RESULT: PERFECT MATCH\n');
% 
% elseif max_err <= 5
% 
%     fprintf('RESULT: PASS - Small difference\n');
% 
% else
% 
%     fprintf('RESULT: FAIL - Check RTL\n');
% 
% end
% 
% fprintf('====================================================\n');
% 
% %% ============================================================
% % VISUAL COMPARISON
% % =============================================================
% 
% figure;
% 
% subplot(1,3,1);
% 
% imagesc(matlab_map);
% axis image;
% colorbar;
% 
% title('MATLAB Pooled Output');
% 
% subplot(1,3,2);
% 
% imagesc(rtl_map);
% axis image;
% colorbar;
% 
% title('RTL Pooled Output');
% 
% subplot(1,3,3);
% 
% imagesc(abs_diff);
% axis image;
% colorbar;
% 
% title('Absolute Difference');
% 
% %% ============================================================
% % ERROR HISTOGRAM
% % =============================================================
% 
% figure;
% 
% histogram(double(diff(:)));
% 
% grid on;
% 
% title('RTL vs MATLAB Error Distribution');
% 
% xlabel('Error');
% ylabel('Number of Values');
% 
% %% ============================================================
% % DEBUG PRINT
% % =============================================================
% 
% fprintf('\nSample comparison:\n');
% fprintf('---------------------------------------------\n');
% fprintf(' Position      MATLAB       RTL       DIFF\n');
% fprintf('---------------------------------------------\n');
% 
% count = 0;
% 
% for i = 1:13
%     for j = 1:13
% 
%         fprintf(' (%2d,%2d)     %6d     %6d     %5d\n', ...
%             i, j, ...
%             matlab_map(i,j), ...
%             rtl_map(i,j), ...
%             diff(i,j));
% 
%         count = count + 1;
% 
%         if count == 10
%             break;
%         end
% 
%     end
% 
%     if count == 10
%         break;
%     end
% end
% 
% fprintf('---------------------------------------------\n');
% 
% %% ============================================================
% % SAVE MATLAB OUTPUT
% % =============================================================
% 
% writematrix(matlab_map, ...
%             'matlab_pool_output.txt', ...
%             'Delimiter','space');
% 
% fprintf('\nMATLAB pool output saved to matlab_pool_output.txt\n');
