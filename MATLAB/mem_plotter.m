clc;
clear;
close all;

%% Read .mem file
filename = 'hand_drawn9.mem';      % Change to your file name

fid = fopen(filename, 'r');
assert(fid ~= -1, 'Cannot open file.');

% Read each line as an 8-bit binary string
data = textscan(fid, '%8s');
fclose(fid);

bin = data{1};

%% Convert binary strings to decimal
pixels = bin2dec(bin);

%% Check size
if length(pixels) ~= 28*28
    error('Expected 784 pixels, found %d.', length(pixels));
end

%% Reshape into image
% MNIST is stored row-wise
img = reshape(pixels, [28,28])';

%% Display
figure;
imshow(uint8(img), []);
colormap(gray);
colorbar;
title('MNIST Image');

% %% Optional: Display enlarged with nearest-neighbor interpolation
% figure;
% imagesc(img);
% colormap(gray);
% axis image;
% axis off;
% set(gca,'YDir','normal');
% title('Enlarged MNIST Image');