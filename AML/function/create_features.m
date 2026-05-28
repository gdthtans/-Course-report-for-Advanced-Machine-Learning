%% 通用辅助函数：生成滞后特征矩阵
function [X, Y] = create_features(data, lookback, step)
    num_samples = length(data) - lookback - step + 1;
    X = zeros(num_samples, lookback);
    Y = zeros(num_samples, 1);
    for i = 1:num_samples
        X(i, :) = data(i : i + lookback - 1)';
        Y(i) = data(i + lookback + step - 1);
    end
end