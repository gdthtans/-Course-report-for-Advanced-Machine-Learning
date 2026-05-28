% --- 嵌套的目标函数 ---
function mse = hw_mse_objective(data, period, params)
    alpha = params(1);
    beta = params(2);
    gamma = params(3);

    % 检查参数边界
    if any(params <= 0 | params >= 1)
        mse = Inf;
        return;
    end

    try
        [fitted_values, ~, ~, ~] = holt_winters(data, period, alpha, beta, gamma);
        % 计算训练数据上的均方误差
        residuals = data - fitted_values;
        mse = mean(residuals.^2);
    catch
        % 如果计算过程中出错（例如数值不稳定），返回 Inf
        mse = Inf;
    end
end
