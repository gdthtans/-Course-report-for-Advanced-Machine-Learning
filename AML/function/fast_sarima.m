% [EstMdl, EstParamCov, logL, info] = estimate(Mdl, x(end-s*2:end)', 'Display', 'off', 'Options', optimoptions('fmincon', 'Display', 'off'));
function [coeffs, y_pred_final] = fast_sarima(p, d, q, P, D, Q, s, x, pred_len)
    % FAST_SARIMA_SOLVER 基于伪线性回归(OLS)的快速SARIMA参数估计与预测
    % 
    % 输入:
    %   p, d, q    : 非季节性阶数 (如 6, 0, 6)
    %   P, D, Q    : 季节性阶数 (如 1, 1, 0)
    %   s          : 周期长度 (如 3146)
    %   x          : 完整速度数据序列 (列向量，建议包含至少2个周期)
    %   pred_len   : 预测步长 (即 horizon h, 如 7)
    %
    % 输出:
    %   coeffs     : 估计出的模型参数结构体
    %   y_pred_final: 未来 pred_len 个时刻的预测绝对值

    %% 1. 数据预处理：执行差分 (Differencing)
    y = x;
    
    % (1) 季节性差分 D (通常 D=1)
    if D == 1
        % 每一圈减去上一圈对应位置
        y_seas_diff = y(s+1:end) - y(1:end-s);
        % 记录被减去的基准，用于后续还原
        seasonal_base = y(1:end-s); 
    else
        y_seas_diff = y;
        seasonal_base = zeros(size(y));
    end
    
    % (2) 非季节性差分 d (通常 d=0 或 1)
    if d == 1
        y_work = diff(y_seas_diff);
        % 记录常规差分的基准
        reg_base = y_seas_diff(1:end-1);
    else
        y_work = y_seas_diff;
        reg_base = zeros(size(y_seas_diff));
    end
    
    % y_work 是我们要拟合的平稳序列 (Stationary Series)
    N = length(y_work);

    %% 2. 第一阶段：利用高阶 AR 模型估算残差 (Proxy Residuals)
    % 为了线性化 MA 项，我们需要先得到残差的估计值
    % 方法：拟合一个长阶 AR 模型 (High-order AR)
    ar_long_order = max(15, p + s*P); % 确保阶数够长
    if ar_long_order > N/2
        ar_long_order = floor(N/4); % 保护措施，防止数据不够
    end
    
    % 构建长阶 AR 的回归矩阵
    valid_start = ar_long_order + 1;
    valid_len_ar = N - ar_long_order;
    
    X_ar_long = zeros(valid_len_ar, ar_long_order);
    Y_ar_long = y_work(valid_start:end);
    
    for i = 1:valid_len_ar
        idx = valid_start + i - 1;
        X_ar_long(i, :) = y_work(idx-1 : -1 : idx-ar_long_order)';
    end
    
    % 求解长阶 AR 参数
    phi_long = X_ar_long \ Y_ar_long;
    
    % 计算估算残差 (residuals_proxy)
    % 注意：前 ar_long_order 个点的残差设为0
    residuals_proxy = zeros(N, 1);
    residuals_proxy(valid_start:end) = Y_ar_long - X_ar_long * phi_long;

    %% 3. 第二阶段：构建完整 SARIMA 的线性回归矩阵
    % 目标方程: y_t = \phi * AR + \Phi * SAR + \theta * MA
    
    % 确定回归矩阵的起始点 (需要足够的数据回溯)
    max_lag = max([p, q, s*P]); 
    train_start = max_lag + 1;
    train_len = N - max_lag;
    
    % 初始化特征矩阵 X_mat 和目标向量 Y_vec
    % 参数总数 = p + P + q + Q (暂时忽略常数项)
    num_params = p + P + q + Q;
    X_mat = zeros(train_len, num_params);
    Y_vec = y_work(train_start:end);
    
    for i = 1:train_len
        curr_t = train_start + i - 1;
        col_idx = 1;
        
        % [Part 1] 非季节性 AR (p)
        if p > 0
            X_mat(i, col_idx : col_idx+p-1) = y_work(curr_t-1 : -1 : curr_t-p)';
            col_idx = col_idx + p;
        end
        
        % [Part 2] 季节性 AR (P)
        % 注意：这是针对“差分后数据”的季节性滞后
        if P > 0
            for k = 1:P
                X_mat(i, col_idx) = y_work(curr_t - k*s);
                col_idx = col_idx + 1;
            end
        end
        
        % [Part 3] 非季节性 MA (q) -> 使用刚才估算的 residuals_proxy
        if q > 0
            X_mat(i, col_idx : col_idx+q-1) = residuals_proxy(curr_t-1 : -1 : curr_t-q)';
            col_idx = col_idx + q;
        end
        
        % [Part 4] 季节性 MA (Q) -> 使用 residuals_proxy
        if Q > 0
            for k = 1:Q
                X_mat(i, col_idx) = residuals_proxy(curr_t - k*s);
                col_idx = col_idx + 1;
            end
        end
    end
    
    %% 4. 求解模型参数 (OLS)
    % 这一步非常快，是简单的矩阵运算
    beta = X_mat \ Y_vec;
    
    % 解析参数并存入结构体
    idx = 1;
    if p>0, coeffs.phi = beta(idx:idx+p-1); idx=idx+p; else, coeffs.phi=[]; end
    if P>0, coeffs.Phi = beta(idx:idx+P-1); idx=idx+P; else, coeffs.Phi=[]; end
    if q>0, coeffs.theta = beta(idx:idx+q-1); idx=idx+q; else, coeffs.theta=[]; end
    if Q>0, coeffs.Theta = beta(idx:idx+Q-1); idx=idx+Q; else, coeffs.Theta=[]; end

    %% 5. 多步预测 (Multi-step Forecasting)
    % 我们需要向未来迭代 pred_len 步
    
    % 准备历史缓存 (History Buffer) 用于迭代
    % 我们需要最新的数据来预测未来
    hist_y = y_work;                  % 差分后的历史观测
    hist_e = residuals_proxy;         % 历史残差
    
    forecasts_diff = zeros(pred_len, 1);
    
    for step = 1:pred_len
        % 当前需要预测的时间索引 (相对于 hist_y 的末尾 + step)
        % 在循环中，我们将预测值 append 到 hist_y 中，所以总是取 hist_y(end)
        
        feat_vec = [];
        
        % 构造 AR 特征
        if p > 0
            feat_vec = [feat_vec; hist_y(end : -1 : end-p+1)]; 
        end
        
        % 构造 Seasonal AR 特征
        if P > 0
            for k = 1:P
                % 注意：如果 step 还没超过 s，取历史；如果超过 s，取之前的预测值
                feat_vec = [feat_vec; hist_y(end - k*s + 1)];
            end
        end
        
        % 构造 MA 特征
        if q > 0
            % 对于未来的 MA (残差)，因为不可知，期望值为 0
            % 但对于刚过去的几步，如果 step <= q，我们仍利用之前的已知残差
            temp_ma = zeros(q, 1);
            for k = 1:q
                if k < step
                    temp_ma(k) = 0; % 未来的随机噪声设为0
                else
                    temp_ma(k) = hist_e(end - (k-step)); % 取历史残差
                end
            end
            feat_vec = [feat_vec; temp_ma];
        end
        
        % 构造 Seasonal MA 特征
        if Q > 0
            for k = 1:Q
                 feat_vec = [feat_vec; 0]; % 简化处理：通常长周期后的残差假设为0
            end
        end
        
        % 计算当前步的预测值 (差分域)
        y_hat_step = feat_vec' * beta;
        forecasts_diff(step) = y_hat_step;
        
        % 更新历史 buffer (将预测值作为“真实值”放入，用于下一步迭代)
        hist_y = [hist_y; y_hat_step];
        hist_e = [hist_e; 0]; % 预测的残差期望为0
    end
    
    %% 6. 还原数据 (Inverse Differencing)
    % 现在的 forecasts_diff 是 y_work 域的预测，需要还原回 x 域
    
    y_pred_final = zeros(pred_len, 1);
    
    % 这里的逻辑是：预测值 = 差分预测值 + 基准值
    % 因为我们要预测的是 t+1, t+2 ... 
    % 对应的基准是上一周期的对应时刻 t+1-s, t+2-s ...
    
    % 获取原始数据 x 的最后 s 个点，作为未来的基准
    % (假设未来走势和上一圈的这部分基准相似)
    last_cycle_base = x(end-s+1 : end); 
    
    % 注意：如果 pred_len 很长超过 s (不太可能)，需要循环处理。
    % 这里假设 pred_len << s
    future_base = last_cycle_base(1:pred_len); 
    
    % 如果只有季节性差分 D=1, d=0 (推荐配置)
    if D == 1 && d == 0
        % 预测值 = 偏差预测 + 上一圈的值
        y_pred_final = forecasts_diff + future_base;
        
    % 如果有 d=1 (非推荐，但处理一下)
    elseif D == 1 && d == 1
        % 先累加 d=1
        last_val_diff = y_seas_diff(end);
        cumsum_diff = cumsum([last_val_diff; forecasts_diff]);
        forecasts_seas_diff = cumsum_diff(2:end);
        
        % 再加回季节性
        y_pred_final = forecasts_seas_diff + future_base;
    end
end