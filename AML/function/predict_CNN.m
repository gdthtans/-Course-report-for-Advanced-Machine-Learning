function [YPred, net] = predict_CNN(trainData, predLength, windowSize)
    % 核心修正：挂载 CUDA 向前兼容协议
    try
        parallel.gpu.enableCUDAForwardCompatibility(true);
    catch
    end

    trainData = trainData(:);
    N = length(trainData);
    numSamples = N - windowSize;
    
    % 核心修正 1：在内存预分配阶段直接声明为 single (单精度)
    % 彻底释放 RTX 5070 Ti 庞大的 FP32 硬件算力，避免双精度节流
    XTrain = zeros(windowSize, 1, 1, numSamples, 'single');
    YTrain = zeros(numSamples, 1, 'single');
    
    for i = 1:numSamples
        XTrain(:, 1, 1, i) = single(trainData(i : i+windowSize-1)'); 
        YTrain(i) = single(trainData(i+windowSize));
    end
    
    % 核心修正 2：利用 gpuArray 将庞大的训练张量一次性常驻物理显存
    % 彻底消灭每个 Batch 训练时 CPU 到 GPU 的 PCIe 总线数据搬运延迟
    XTrain = gpuArray(XTrain);
    YTrain = gpuArray(YTrain);
    
    layers = [ ...
        imageInputLayer([windowSize, 1, 1], 'Normalization', 'zscore', 'Name', 'input')
        
        convolution2dLayer([7, 1], 16, 'Padding', 'same', 'Name', 'conv1')
        reluLayer('Name', 'relu1')
        maxPooling2dLayer([4, 1], 'Stride', [4, 1], 'Name', 'pool1') 
        
        convolution2dLayer([5, 1], 32, 'Padding', 'same', 'Name', 'conv2')
        reluLayer('Name', 'relu2')
        maxPooling2dLayer([4, 1], 'Stride', [4, 1], 'Name', 'pool2')
        
        flattenLayer('Name', 'flatten')
        fullyConnectedLayer(64, 'Name', 'fc1')
        reluLayer('Name', 'relu3')
        fullyConnectedLayer(1, 'Name', 'fc_out')
        regressionLayer('Name', 'output')];
        
    % 核心修正 3：由于显存通信已无延迟且算力全开，将批次大小激增至 256
    options = trainingOptions('adam', ...
        'MaxEpochs', 100, ...
        'MiniBatchSize', 256, ... 
        'InitialLearnRate', 0.001, ... 
        'GradientThreshold', 1, ...
        'Shuffle', 'every-epoch', ...
        'Verbose', 0, ...
        'ExecutionEnvironment', 'gpu',...
        'plots','training-progress'); 
    
    net = trainNetwork(XTrain, YTrain, layers, options);
    
    YPred = zeros(predLength, 1);
    currentInput = trainData(end-windowSize+1 : end)';
    
    for i = 1:predLength
        % 预测时同样使用单精度类型，保持底层计算图类型一致性
        netInput = single(reshape(currentInput, [windowSize, 1, 1]));
        predVal = predict(net, netInput);
        
        scalarPred = double(predVal(1));
        YPred(i) = scalarPred;
        
        currentInput = [currentInput(2:end), scalarPred];
    end
end