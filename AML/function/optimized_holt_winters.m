function [predictions, level, trend, season, optimized_params, mse] = optimized_holt_winters(data, period, num_predictions, initial_guess, optim_options)
% optimized_holt_winters 使用 Holt-Winters 指数平滑方法进行预测，并用 Nelder-Mead (fminsearch) 优化参数
%
% 输入:
%   data:              时间序列数据 (列向量)
%   period:            季节性周期长度
%   num_predictions:   需要预测的未来期数
%   initial_guess:     [alpha_0, beta_0, gamma_0] 的初始猜测值 (可选，默认 [0.3, 0.1, 0.3])
%                      如果提供，长度必须为3，且每个值在(0,1)区间内。
%   optim_options:     传递给 fminsearch 的选项结构体 (可选)
%
% 输出:
%   predictions:       预测值 (长度为 num_predictions 的向量)
%   level:             估计的水平项 (与输入数据等长)
%   trend:             估计的趋势项 (与输入数据等长)
%   season:            估计的季节性项 (与输入数据等长)
%   optimized_params:  优化后的参数 [alpha_opt, beta_opt, gamma_opt]
%   mse:               使用优化参数在训练集上的均方误差 (拟合优度指标)

    if nargin < 3
        error('需要提供至少3个输入参数: data, period, num_predictions');
    end
    if nargin < 4 || isempty(initial_guess)
        initial_guess = [0.3, 0.1, 0.3]; % 默认初始猜测
    end
    if length(initial_guess) ~= 3 || any(initial_guess <= 0 | initial_guess >= 1)
        error('initial_guess 必须是长度为3的向量，且每个元素在(0,1)区间内。');
    end

    % 定义目标函数 (嵌套函数，可以访问主函数 workspace 中的变量)
    % 目标是最小化训练数据上的 MSE
    objective_func = @(params) hw_mse_objective(data, period, params);

    % 设置 fminsearch 选项
    default_options = optimset('fminsearch');
    if nargin < 5 || isempty(optim_options)
        options = default_options;
    else
        options = optimset(default_options, optim_options); % 合并用户选项
    end

    % 使用 fminsearch (Nelder-Mead) 优化参数
    % 设定边界约束 (0, 1) 是通过目标函数返回 Inf 来处理的
    [optimized_params, mse] = fminsearch(objective_func, initial_guess, options);

    % 使用优化后的参数重新运行 Holt-Winters 模型以获取预测和成分
    alpha_opt = optimized_params(1);
    beta_opt = optimized_params(2);
    gamma_opt = optimized_params(3);

    % 调用原始的 Holt-Winters 函数
    [~, level, trend, season] = holt_winters(data, period, alpha_opt, beta_opt, gamma_opt);
    % 计算预测
    n = length(data);
    predictions = zeros(num_predictions, 1);
    for i = 1:num_predictions
        h = i;
        predictions(i) = (level(n) + h * trend(n)) * season(mod(n - period + h - 1, period) + 1);
    end
end