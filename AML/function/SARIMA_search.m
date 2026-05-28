function [results, EstMdl] = SARIMA_search(x, orderRange)
%SEARCHSARIMAAICBIC SARIMA模型AIC/BIC网格定阶搜索


% 存储结果的结构体数组

%p 根据你的数据特性和先验知识调整这些范围
p_vals = orderRange.p;       % 非季节性自回归阶数 (简化范围以加快示例)
d_vals = orderRange.d;         % 非季节性差分阶数 (通常由数据平稳性决定)
q_vals = orderRange.q;       % 非季节性移动平均阶数 (简化范围以加快示例)

P_vals = orderRange.P;       % 季节性自回归阶数 (简化范围以加快示例)
D_vals = orderRange.D;         % 季节性差分阶数 (通常由数据季节性决定)
Q_vals = orderRange.Q;       % 季节性移动平均阶数 (简化范围以加快示例)
s_vals = orderRange.s;        % 季节性周期 (例如，月度数据为12)
Mdl = arima('Constant', 0, 'D', 0, 'Seasonality', 0);
clear results;
results = struct(...
                'p', 0, 'd', 0, 'q', 0, ...
                'P', 0, 'D', 0, 'Q', 0, 's', 0, ...
                'AIC', inf, 'BIC', inf, 'Model', Mdl);
numcircle=length(p_vals)*length(q_vals)*length(P_vals)*length(Q_vals);
for i=1:numcircle-1
       results(end+1,:) = struct(...
                'p', 0, 'd', 0, 'q', 0, ...
                'P', 0, 'D', 0, 'Q', 0, 's', 0, ...
                'AIC', inf, 'BIC', inf, 'Model', Mdl);
end

%% 3. 遍历参数空间并计算AIC/BIC
try
    pcnt = 0;
    total_iterations = numel(p_vals) * numel(d_vals) * numel(q_vals) * ...
                       numel(P_vals) * numel(D_vals) * numel(Q_vals) * numel(s_vals);
    % 预先过滤掉明显无效的组合以减少迭代
    valid_combinations = {};
    for p = p_vals
        for d = d_vals
            for q = q_vals
                for P = P_vals
                    for D = D_vals
                        for Q = Q_vals
                            for s = s_vals
                                if ~((p==0 && q==0 && P==0 && Q==0) || s <= 0)
                                    valid_combinations{end+1} = [p, d, q, P, D, Q, s];
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    total_valid = numel(valid_combinations);
    if total_valid == 0
        error('没有有效的参数组合可供搜索。请检查参数范围。');
    end
    
    % waitbar_handle = waitbar(0, '正在搜索最佳SARIMA参数...');
    % parfor_progress(total_valid);
    parfor i = 1:total_valid
        combo = valid_combinations{i};
        p = combo(1); d = combo(2); q = combo(3);
        P = combo(4); D = combo(5); Q = combo(6); s = combo(7);
        
        % waitbar(i/total_valid, waitbar_handle, ...
        %         sprintf('正在处理: SARIMA(%d,%d,%d)(%d,%d,%d)_%d', p,d,q,P,D,Q,s));
        % parfor_progress;
        % 定义SARIMA模型
        Mdl = arima('Constant', 0, 'D', d, 'Seasonality', s);
        if p > 0
            Mdl.AR = repmat({NaN}, 1, p); % 使用 NaN 作为占位符，让 estimate 估计
            % Mdl.ARLags = 1:p;
        end
        if q > 0
            Mdl.MA = repmat({NaN}, 1, q);
            % Mdl.MALags = 1:q;
        end
        if P > 0
            Mdl.SAR = repmat({NaN}, 1, P);
            % Mdl.SARLags = (1:P) * s;
        end
        if Q > 0
            Mdl.SMA = repmat({NaN}, 1, Q);
            % Mdl.SMALags = (1:Q) * s;
        end
        
        try
            % 拟合模型
            
            [EstMdl, EstParamCov, logL, info] = estimate(Mdl, x', 'Display', 'off', 'Options', optimoptions('fmincon', 'Display', 'off'));
            numParam=1+p+q+P+Q+1;
            % 提取AIC和BIC
            % aicbic 函数的第一个输出是 AIC，第二个是 BIC
            [aic, bic] = aicbic(logL,numParam)
            
            % 存储结果
            results(i,:) = struct(...
                'p', p, 'd', d, 'q', q, ...
                'P', P, 'D', D, 'Q', Q, 's', s, ...
                'AIC', aic, 'BIC', bic, 'Model', EstMdl);
                
        catch ME
             % 如果模型拟合失败（例如奇异矩阵、不收敛），则跳过该参数组合
             fprintf('警告: 模型 SARIMA(%d,%d,%d)(%d,%d,%d)_%d 拟合失败: %s\n', ...
                     p,d,q,P,D,Q,s, ME.message);
        end
    end
    % close(waitbar_handle);
catch ME
    % if exist('waitbar_handle', 'var')
    %     close(waitbar_handle);
    % end
    rethrow(ME);
end


%% 4. 寻找最佳模型 (基于AIC和BIC)
if isempty(results)
    warning('在指定的参数范围内未找到可拟合的模型。');
    best_model_aic = [];
    best_model_bic = [];
else
    % 找到AIC最小的模型
    [~, idx_aic] = min([results.AIC]);
    best_model_aic = results(idx_aic);

    % 找到BIC最小的模型
    [~, idx_bic] = min([results.BIC]);
    best_model_bic = results(idx_bic);

    fprintf('\n--- 基于AIC的最佳模型 ---\n');
    fprintf('SARIMA(%d,%d,%d)(%d,%d,%d)_%d\n', ...
        best_model_aic.p, best_model_aic.d, best_model_aic.q, ...
        best_model_aic.P, best_model_aic.D, best_model_aic.Q, best_model_aic.s);
    fprintf('AIC: %.4f\n', best_model_aic.AIC);

    fprintf('\n--- 基于BIC的最佳模型 ---\n');
    fprintf('SARIMA(%d,%d,%d)(%d,%d,%d)_%d\n', ...
        best_model_bic.p, best_model_bic.d, best_model_bic.q, ...
        best_model_bic.P, best_model_bic.D, best_model_bic.Q, best_model_bic.s);
    fprintf('BIC: %.4f\n', best_model_bic.BIC);

    % 显示基于AIC的最佳模型的详细信息 (通常AIC和BIC会选择相近的模型)
    fprintf('\n--- AIC最优模型详细信息 ---\n');
    disp(best_model_aic.Model);
end
EstMdl=best_model_bic.Model;
