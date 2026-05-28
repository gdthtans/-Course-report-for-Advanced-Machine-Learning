function [YPred, mdl] = predict_SVM(trainData, predLength, windowSize)
    % 核心修正：引入自适应维度清洗，强制转换为列向量
    % 彻底免疫外部传入数据是行向量导致的反向转置维度坍缩问题
    trainData = trainData(:);
    
    maxTrainLength = windowSize * 2;
    if length(trainData) > maxTrainLength
        trainData = trainData(end-maxTrainLength+1 : end);
    end

    N = length(trainData);
    numSamples = N - windowSize;
    XTrain = zeros(numSamples, windowSize);
    
    for i = 1:windowSize
        XTrain(:, i) = trainData(i : i+numSamples-1);
    end
    YTrain = trainData(windowSize+1 : end);

    opts = struct('Optimizer', 'bayesopt', 'ShowPlots', false, ...
        'AcquisitionFunctionName', 'expected-improvement-plus', ...
        'MaxObjectiveEvaluations', 30, 'UseParallel', true);

    mdl = fitrsvm(XTrain, YTrain, ...
        'KernelFunction', 'gaussian', ...
        'Standardize', true, ...
        'OptimizeHyperparameters', 'auto', ...
        'HyperparameterOptimizationOptions', opts);

    YPred = zeros(predLength, 1);
    % 此时 trainData 已绝对是列向量，转置后必然生成 1 x windowSize 的行向量
    % 完美契合 SVM 要求的单一样本多维特征矩阵形态
    currentInput = trainData(end-windowSize+1 : end)'; 
    
    for i = 1:predLength
        predVal = predict(mdl, currentInput);
        YPred(i) = predVal;
        currentInput = [currentInput(2:end), predVal];
    end
end