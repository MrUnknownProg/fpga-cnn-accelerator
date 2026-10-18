clear; clc; close all;

%% ================= LOAD MNIST =================
mn = load("mnist.mat");
XTrain = mn.digits_train;
YTrain = mn.labels_train;
XTest  = mn.digits_test;
YTest  = mn.labels_test;

% Reshape
XTrain = reshape(XTrain, 28, 28, 1, []);
XTest  = reshape(XTest,  28, 28, 1, []);

% Normalize (float for training)
XTrain = single(XTrain) / 255;
XTest  = single(XTest)  / 255;

YTrain = categorical(YTrain);
YTest  = categorical(YTest);

fprintf("MNIST loaded successfully.\n");

%% ================= CNN ARCHITECTURE =================
layers = [
    imageInputLayer([28 28 1], ...
        "Normalization","none", ...
        "Name","input")

    convolution2dLayer(3, 1, ...
        "Padding",[0 0 0 0], ...
        "Stride",[1 1], ...
        "Name","conv1")

    reluLayer("Name","relu1")

    maxPooling2dLayer(2, ...
        "Stride",2, ...
        "Name","pool1")

    fullyConnectedLayer(10, ...
        "Name","fc")

    softmaxLayer("Name","softmax")

    classificationLayer("Name","output")
];

%% ================= TRAINING OPTIONS =================
options = trainingOptions("adam", ...
    "MaxEpochs", 50, ...
    "MiniBatchSize", 256, ...
    "InitialLearnRate", 0.001, ...
    "Shuffle","every-epoch", ...
    "Verbose", true, ...
    "Plots","training-progress");

%% ================= TRAIN =================
net = trainNetwork(XTrain, YTrain, layers, options);

%% ================= TEST =================
YPred = classify(net, XTest);
acc = mean(YPred == YTest);
fprintf("Test Accuracy = %.2f%%\n", acc*100);

%% ================= EXTRACT CONV WEIGHTS =================
convLayer = net.Layers(2);

kernel = convLayer.Weights;   % 3x3x1x1
bias   = convLayer.Bias;

kernel = squeeze(kernel);     % 3x3

fprintf("\n=== FLOAT KERNEL ===\n");
disp(kernel);

%% ================= QUANTIZATION =================

% Dynamic scaling (IMPORTANT)
max_val = max(abs(kernel(:)));

if max_val == 0
    SCALE = 1;
else
    SCALE = 127 / max_val;
end

kernel_q = int8(round(kernel * SCALE));
bias_q   = int16(round(bias * SCALE));

fprintf("\n=== INT8 KERNEL ===\n");
disp(kernel_q);

%% ================= EXPORT WEIGHTS =================

fid = fopen('weights.mem', 'w');

% Convert to row-major (VERY IMPORTANT)
kernel_flat = reshape(kernel_q.', [], 1);

for i = 1:9
    % Preserve signed 2's complement
    val = typecast(int8(kernel_flat(i)), 'uint8');
    fprintf(fid, '%s\n', dec2bin(val, 8));
end

fclose(fid);

fprintf("weights.mem exported (SIGNED CORRECT)\n");

%% =========================================================
%% EXTRACT FC LAYER
%% =========================================================

fcLayer = net.Layers(5);

fcW = fcLayer.Weights;
fcB = fcLayer.Bias;

fprintf("\nFC WEIGHT SIZE\n");
disp(size(fcW));

fprintf("FC BIAS SIZE\n");
disp(size(fcB));

%% =========================================================
%% QUANTIZE FC
%% =========================================================

fc_max = max(abs(fcW(:)));

if fc_max == 0
    FC_SCALE = 1;
else
    FC_SCALE = 127/fc_max;
end

fcW_q = int8(round(fcW*FC_SCALE));
fcB_q = int16(round(fcB*FC_SCALE));

fprintf("\nFC SCALE = %.4f\n",FC_SCALE);

%% =========================================================
%% EXPORT FC WEIGHTS
%% =========================================================

fid = fopen('fc_weights.mem','w');

for neuron = 1:10

    for feature = 1:169

        val = typecast( ...
            int8(fcW_q(neuron,feature)), ...
            'uint8');

        fprintf(fid,'%s\n',dec2bin(val,8));

    end

end

fclose(fid);

fprintf("fc_weights.mem exported\n");

%% =========================================================
%% EXPORT FC BIAS
%% =========================================================

fid = fopen('fc_bias.mem','w');

for i = 1:10

    val = typecast( ...
        int16(fcB_q(i)), ...
        'uint16');

    fprintf(fid,'%s\n',dec2bin(val,16));

end

fclose(fid);

fprintf("fc_bias.mem exported\n");

%% ================= DEBUG =================

fprintf("\n=== DEBUG INFO ===\n");
fprintf("Kernel range: [%d, %d]\n", min(kernel_q(:)), max(kernel_q(:)));
fprintf("Bias: %d\n", bias_q);

if max(kernel_q(:)) == 127 || min(kernel_q(:)) == -128
    fprintf("WARNING: Saturation detected\n");
else
    fprintf("GOOD: No saturation\n");
end

fprintf("\nREADY FOR FPGA TEST\n");

%% ================== TRAINED NET ===========
save('trained_net.mat', 'net');
fprintf("Network saved to trained_net.mat\n");
