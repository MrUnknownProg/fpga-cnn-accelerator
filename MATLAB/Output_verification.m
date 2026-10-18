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

