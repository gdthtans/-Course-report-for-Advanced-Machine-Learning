% --- 嵌套的 Holt-Winters 核心计算函数 ---
function [fitted_values, level, trend, season] = holt_winters(data, period, alpha, beta, gamma)
    n = length(data);
    if n < 2 * period
        error('数据长度至少需要是季节性周期的两倍');
    end

    level = zeros(n, 1);
    trend = zeros(n, 1);
    season = zeros(n, 1);

    % 初始化季节性成分
    for i = 1:period
        % 更稳健的初始化
        seasonal_averages = NaN(1, floor(n/period));
        for j = 1:length(seasonal_averages)
            idx = i + (j-1)*period;
            if idx <= n
                seasonal_averages(j) = data(idx);
            end
        end
        season(i) = mean(seasonal_averages) / mean(data); % 相对于整体均值
    end
    % 标准化季节性成分使其均值为1
    season(1:period) = season(1:period) / mean(season(1:period));


    % 初始化水平和趋势 (使用前两个周期)
    avg_period1 = mean(data(1:period));
    avg_period2 = mean(data(period+1:min(2*period, n)));
    initial_trend = (avg_period2 - avg_period1) / period;
    % L_m = D_m / S_1
    level(period) = data(period) / season(mod(period - 1, period) + 1);
    trend(period) = initial_trend;

    % Holt-Winters 递推公式
    for i = period+1:n
        level(i) = alpha * (data(i) / season(mod(i - period - 1, period) + 1)) + (1 - alpha) * (level(i-1) + trend(i-1));
        trend(i) = beta * (level(i) - level(i-1)) + (1 - beta) * trend(i-1);
        season(i) = gamma * (data(i) / level(i)) + (1 - gamma) * season(mod(i - period - 1, period) + 1);
    end

    fitted_values = (level + trend) .* season;
end