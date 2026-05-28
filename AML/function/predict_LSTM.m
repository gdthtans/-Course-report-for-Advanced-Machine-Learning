function [YPred, net] = predict_LSTM(trainData, predLength, windowSize)
% PREDICT_LSTM (Direct Multi-step 终极版)
% 彻底废除 For 循环，采用 Sequence-to-Vector 直接多步输出，消除所有误差累积！
    
    %% 0. 硬件环境初始化：开启 CUDA 前向兼容性
    try
        parallel.gpu.enableCUDAForwardCompatibility(true);
    catch ME
        warning('CUDA Forward Compatibility activation failed. Detailed error: %s', ME.message);
    end

    % 确保数据为列向量
    trainData = trainData(:);
    N = length(trainData);
    
    %% 1. 数据预处理：Z-score 归一化 (学术级严谨要求)
    mu_train = mean(trainData);
    sig_train = std(trainData);
    trainDataNorm = (trainData - mu_train) / sig_train;
    
%% 2. 构建特征与标签序列 (强化版：强制单精度，极大减轻底层计算压力)
    numSamples = N - windowSize - predLength + 1;
    XTrain = cell(numSamples, 1);
    
    % 【修改 1】：强制初始化为 single 单精度！计算量和内存瞬间减半！
    YTrain = zeros(numSamples, predLength, 'single'); 
    
    for i = 1:numSamples
        % 【修改 2】：将送入网络的数据强制转换为 single
        XTrain{i} = single(trainDataNorm(i : i+windowSize-1)'); 
        YTrain(i, :) = single(trainDataNorm(i+windowSize : i+windowSize+predLength-1)');
    end

%% 3. 【优化版架构】：BiLSTM 特征强化 + 线性稳定解码
%% 3. 网络架构：稍微增加一点 Dropout 防震荡
    layers = [ ...
        sequenceInputLayer(1, 'Normalization', 'none', 'Name', 'input')
        bilstmLayer(256, 'OutputMode', 'last', 'Name', 'bilstm_1')
        % Dropout 稍微提回 0.2，这是防止权重过度自信、引发 NaN 的一道防火墙
        dropoutLayer(0.2, 'Name', 'drop_1')
        fullyConnectedLayer(predLength, 'Name', 'output_fc')
        regressionLayer('Name', 'output_layer')];

    %% 4. 训练超参数优化：极限防爆配置
    options = trainingOptions('adam', ...
        'MaxEpochs', 200, ...              
        'MiniBatchSize', 128, ...           % 保持小 Batch 解决显存问题
        'InitialLearnRate', 0.002, ...    % 【极其关键】：从 0.001 再次折半到 0.0005！宁可慢一点，绝不翻车。
        'L2Regularization', 1e-4, ...      % 【新增防线】：给权重加 0.0001 的衰减惩罚，绝对禁止权重趋于无限大！
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropPeriod', 50, ...     
        'LearnRateDropFactor', 0.5, ...
        'GradientThreshold', 0.5, ...      % 【防线收紧】：更加严苛的梯度截断
        'GradientThresholdMethod', 'absolute-value', ... % 【防线修改】：绝对值截断
        'Shuffle', 'every-epoch', ...
        'Verbose', 1, ...                  
        'Plots', 'training-progress', ...
        'ExecutionEnvironment', 'gpu');
    %% 5. 网络训练
    % 注意：此时网络是在学习 [1 x windowSize] -> [1 x predLength] 的复杂高维映射
    net = trainNetwork(XTrain, YTrain, layers, options);
    
    %% 6. 【核心修改】：直接预测 (告别 For 循环！)
    % 提取最后一段历史窗口作为初始输入
    currentInput = gpuArray(single(trainDataNorm(end-windowSize+1 : end)'));
    
    % 仅需一次前向传播，直接获得未来所有步的预测轨迹，彻底消灭误差累积！
    YPred_norm_vector = predict(net, {currentInput}, 'ExecutionEnvironment', 'gpu');
    
    % 将输出转为标准的列向量格式
    YPred_norm = YPred_norm_vector(:);
    
    %% 7. 反归一化并回传至 CPU 内存
    YPred = gather(YPred_norm) * sig_train + mu_train;
end