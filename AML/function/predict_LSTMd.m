function [YPred, net] = predict_LSTMd(trainData, predLength, windowSize)
    % PREDICT_LSTM 面向非平稳工业数据的差分自回归预测函数
    % 终极修正：采用一阶差分（Residual Prediction）彻底解决高位死锁与门控饱和问题
    
    %% 0. 硬件环境初始化
    try
        parallel.gpu.enableCUDAForwardCompatibility(true);
    catch
        % 忽略警告，继续执行
    end

    trainData = trainData(:);
    
    %% 1. 核心算法重构：一阶差分 (First-Order Differencing)
    % 将绝对值序列转化为平稳的变化量序列，消除 LSTM 的累积饱和
    diffData = diff(trainData); 
    N_diff = length(diffData);
    
    %% 2. 差分数据的 Z-score 归一化
    mu_diff = mean(diffData);
    sig_diff = std(diffData);
    diffNorm = (diffData - mu_diff) / sig_diff;
    
    %% 3. 构建特征与标签序列（基于差分数据）
    numSamples = N_diff - windowSize;
    XTrain = cell(numSamples, 1);
    YTrain = zeros(numSamples, 1);
    
    for i = 1:numSamples
        % 输入过去 windowSize 个时间步的"变化量"
        XTrain{i} = gpuArray(diffNorm(i : i+windowSize-1)'); 
        % 预测下一个时间步的"变化量"
        YTrain(i) = diffNorm(i+windowSize);
    end
    YTrain = gpuArray(YTrain);
    
    %% 4. 构建网络：回归经典的简单因果 LSTM
    % 差分数据极为平稳，无需复杂的缓冲层，直接提取时序动态
    layers = [
        sequenceInputLayer(1, 'Normalization', 'none', 'Name', 'input')
        
        lstmLayer(64, 'OutputMode', 'sequence', 'Name', 'lstm_1')
        dropoutLayer(0.2, 'Name', 'dropout_1') 
        
        lstmLayer(32, 'OutputMode', 'last', 'Name', 'lstm_2')
        
        fullyConnectedLayer(1, 'Name', 'fc_out')
        regressionLayer('Name', 'regression_out')
    ];

    %% 5. 超参数配置 (保持快速迭代配置)
    options = trainingOptions('adam', ...
        'MaxEpochs', 30, ...                   % 差分数据容易收敛，50个Epoch足够验证趋势
        'MiniBatchSize', 128, ...              
        'InitialLearnRate', 0.002, ...         
        'LearnRateSchedule', 'none', ...       % 关闭学习率衰减，保持恒定步长
        'L2Regularization', 1e-4, ...          
        'GradientThreshold', 1, ...
        'GradientThresholdMethod', 'l2norm', ... 
        'Shuffle', 'every-epoch', ...
        'Verbose', 0, ...
        'Plots', 'training-progress', ...
        'DispatchInBackground', true, ...
        'ExecutionEnvironment', 'gpu');
        
    %% 6. 网络训练
    net = trainNetwork(XTrain, YTrain, layers, options);
    
    %% 7. 差分域的多步自回归预测
    YPred_diff_norm = zeros(predLength, 1, 'gpuArray');
    
    % 取训练集最后一段差分窗口作为初始输入
    currentDiffInput = gpuArray(diffNorm(end-windowSize+1 : end)');
    
    for i = 1:predLength
        % 预测下一步的"变化量"
        predDiffVal = predict(net, {currentDiffInput}, 'ExecutionEnvironment', 'gpu');
        YPred_diff_norm(i) = predDiffVal;
        
        % 滑动差分窗口
        currentDiffInput = [currentDiffInput(2:end), predDiffVal];
    end
    
    %% 8. 反归一化与积分还原 (Inverse Difference)
    % 1. 将预测的差分值还原为实际物理量纲的变化量 (mm/s)
    YPred_diff = gather(YPred_diff_norm) * sig_diff + mu_diff;
    
    % 2. 利用原始序列的最后一个绝对真实值，进行累加还原 (Cumulative Sum)
    % Y_t = Y_{t-1} + delta_Y
    lastTrueValue = trainData(end);
    YPred = lastTrueValue + cumsum(YPred_diff);
    
end