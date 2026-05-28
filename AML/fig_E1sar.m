%% 可视化，实验数据对比


gdoc_r=slanCL(614,2);
gdoc_g=slanCL(614,4);
gdoc_b=slanCL(614,1);


% 图1：速度预处理——滤波与群延时
%%线宽设置
linw=1.5;ii1=10;figure(ii1);
hold on;
% 3. 原始差分 (噪声很大)
h3 = plot(t, V_raw, 'Color', [0.8,0.8,0.8],'LineStyle','-', 'LineWidth', 1.5); 
% 1. 真实理论速度 (基准)
% h1 = plot(t, V_acc, 'k','LineStyle','-', 'LineWidth', 2); 
% 2.机器人直接采集速度
h2 = plot(t, 1000*Sampledatas(:,7),'Color', gdoc_g,'LineStyle','--', 'LineWidth', 1.5); 

% 4. 滤波后 (平滑但滞后)
h4 = plot(t, V_filt, 'Color', gdoc_b,'LineStyle','-', 'LineWidth', 1.5); 
% 5. 补偿后 (对齐)
h5 = plot(t, V_compensated_mag, 'Color', gdoc_r,'LineStyle','-',  'LineWidth', 1.5); 

% 图例与修饰
legend([ h2, h3, h4, h5], ...
       {
        'ABB Filtered', ...
        'Raw Differenced (Noisy)', ...

        'Butterworth Filtered (Lagged)', ...
        'Ideally Compensated'}, ...
       'Location', 'Best');

xlabel('Time (s)', 'FontSize', 12);
ylabel('Feedrate (mm/s)', 'FontSize', 12);
title(sprintf('Resultant Feedrate Processing: Delay %.1f ms Compensation', delay_time_ms), 'FontSize', 14);

xlim([302 305]);box on;xticks([0:1:t(end)]);
ylim([0 60]);yticks([0:10:60]);
% truncAxis2('Y',[0.035,0.1]);
MyFigureAdjust(gcf,gca, {[22,11],[1 1 1]},1.3);%论文绘图
set(gca,'TickLength',[0.005,0.035]);
set(gcf,'Color','w');

%图2：1、参数域周期性；2、自相关函数检验；3、残差
%设置横轴
%预测序列：x(end-S*4:end-round(S*1/2))'后的一个周期 x=V_par(128739-6328*15:k:128739-6328*5); z=x(end-S*4:end)';
ls_axis;
e1_par=linspace(1,max(sarima_num),length(rob_time));

figure(ii1+1);

subplot(3,1,1);
x_exp2=ls_axis(x_end-T*5*2:k:x_end);
% x_exp2=ls_axis(end-T*5:end);

T=6398/k-150/k;
plot(x_exp2,x(end-T*5:end), 'Color', gdoc_b, 'LineWidth', 1.5);
title('原数据');
sys = arima('Constant',NaN,'ARLags',1:4,'D',0,'MALags',1:2,'SARLags',[12,24,36,48],'Seasonality',12,'SMALags',12,'Distribution','Gaussian');
xlim([x_exp2(1) 2907]);box on;xticks([2087:200:2907]);
ylim([0 50]);yticks([0:25:50]);
MyFigureAdjust(gcf,gca, {[22,11],[1 1 1]},1.3);%论文绘图
set(gca,'TickLength',[0.005,0.035]);


subplot(3,1,2);
% x_exp21=ls_axis(end-length(x_acf)+1:end);
plot(x_exp2,x_acf(1:T*5+1), 'Color', gdoc_b, 'LineWidth', 1.5);
title('自相关函数');
xlim([x_exp2(1) 2907]);box on;xticks([2087:200:2907]);
MyFigureAdjust(gcf,gca, {[22,11],[1 1 1]},1.3);%论文绘图
set(gca,'TickLength',[0.005,0.035]);


% x_pacf=parcorr(x);
subplot(3,1,3);
% plot(x_pacf) ;
% title('偏自相关函数');
plot(x_exp2,xd(end-T*5:end), 'Color', gdoc_b, 'LineWidth', 1.5) ;
title('一阶季节差分');


% ylim([0 40]);yticks([0:5:40]);
% truncAxis2('Y',[21,35]);
xlim([x_exp2(1) 2907]);box on;xticks([2087:200:2907]);
% ylim([0 40]);yticks([0:5:40]);
MyFigureAdjust(gcf,gca, {[22,11],[1 1 1]},1.3);%论文绘图
set(gca,'TickLength',[0.005,0.035]);


%E3建模结果
%  数据解析与矩阵构建 (Parsing)
results(293)=[];results(294)=[];
St = results; 

vals_p = [St.p]';
vals_q = [St.q]';
vals_P = [St.P]';
vals_Q = [St.Q]';
vals_AIC = [St.AIC]';

% 自动识别 p 和 q 的搜索范围
% p_range = unique(vals_p);
% q_range = unique(vals_q);
p_range = 2:6;
q_range = 2:6;
n_p = length(p_range);
n_q = length(q_range);

% 初始化两个 AIC 矩阵
AIC_Baseline = nan(n_p, n_q); % 对应 P=0, Q=0
AIC_Proposed = nan(n_p, n_q); % 对应 P=1, Q=0
AIC_Proposed1 = nan(n_p, n_q); % 对应 P=1, Q=1
% 填充矩阵
for i = 1:length(St)

    % 获取当前索引
    r = find(p_range == St(i).p); % 行索引 (p)
    c = find(q_range == St(i).q); % 列索引 (q)

  
    
    % 筛选 P=0, Q=0 (基准)
    if St(i).P == 0 && St(i).Q == 0 && St(i).D == 0
        AIC_Baseline(r, c) = St(i).AIC;
    end
    
    % 筛选 P=1, Q=0 (你的最优策略)
    if St(i).P == 1 && St(i).Q == 0 && St(i).D == 1
        AIC_Proposed(r, c) = St(i).AIC;
    end

        % 筛选 P=1, Q=1 (你的最优策略)
    if St(i).P == 1 && St(i).Q == 1 && St(i).D == 1
        AIC_Proposed1(r, c) = St(i).AIC;
    end
end

% 绘图 (Visualization)
figure('Color', 'w', 'Position', [100, 100, 1200, 550]);

% 寻找全局最大最小值，用于统一色标 (非常重要，否则无法对比颜色深浅)
global_min = min([min(AIC_Baseline(:)), min(AIC_Proposed(:))]);
global_max = max([max(AIC_Baseline(:)), max(AIC_Proposed(:))]);

% --- 子图 1: 无季节性 (P=0, Q=0) ---
ax1 = subplot(1, 2, 1);
h1 = heatmap(q_range, p_range, AIC_Baseline);
h1.Title = '(a) Baseline Model: ARIMA(p,0,q)';
h1.XLabel = 'MA Order (q)';
h1.YLabel = 'AR Order (p)';
h1.Colormap = parula; 
h1.ColorLimits = [global_min, 9999]; % 锁定色标
h1.GridVisible = 'off';

% --- 子图 2: 有季节性 (P=1, Q=0) ---
ax2 = subplot(1, 2, 2);
h2 = heatmap(q_range, p_range, AIC_Proposed);
h2.Title = '(b) Proposed Model: SARIMA(p,0,q)x(1,1,0)';
h2.XLabel = 'MA Order (q)';
h2.YLabel = 'AR Order (p)';
h2.Colormap = parula;
h2.ColorLimits = [global_min, 9999]; % 锁定色标
h2.GridVisible = 'off';

% --- 子图 3: 有季节性 (P=1, Q=1) ---
% ax3 = subplot(1, 3, 3);
% h2 = heatmap(q_range, p_range, AIC_Proposed1);
% h2.Title = '(b) Proposed Model: SARIMA(p,0,q)x(1,1,1)';
% h2.XLabel = 'MA Order (q)';
% h2.YLabel = 'AR Order (p)';
% h2.Colormap = parula;
% h2.ColorLimits = [global_min, 9999]; % 锁定色标
% h2.GridVisible = 'off';

% 寻找最优解位置并标记 (在 Proposed 图中)
[min_val, min_idx] = min(AIC_Proposed(:));
[row_best, col_best] = ind2sub(size(AIC_Proposed), min_idx);
best_p = p_range(row_best);
best_q = q_range(col_best);

fprintf('--------------------------------------------------\n');
fprintf('数据分析完成:\n');
fprintf('1. 基准模型 (P=0,Q=0) 最小 AIC: %.2f\n', min(AIC_Baseline(:)));
fprintf('2. 提出模型 (P=1,Q=0) 最小 AIC: %.2f\n', min_val);
fprintf('   最优参数组合: p=%d, q=%d\n', best_p, best_q);
fprintf('--------------------------------------------------\n');

% 在图上添加文字说明 (Optional)
sgtitle('AIC Model Selection Landscape: Impact of Seasonal Auto-Regression', 'FontSize', 14, 'FontWeight', 'bold');
%% 





%E4-1最终预测结果
ls_axis;e1_par;
exp2_axis=ls_axis(x_end-S*4+length(y):k:x_end-S*4+length(y)+step*2);
figure();
h1=plot(exp2_axis(1:1000),x_iir(1:1000),'Color', gdoc_b,'LineStyle','-',  'LineWidth', 1.5);hold on;
h2=plot(exp2_axis(1:1000),x_acc(1:1000),'Color', [0.8 0.8 0.8],'LineStyle','-',  'LineWidth', 1.5);hold on;
h4= plot(exp2_axis(1:1000),[y(end);y_pred_final(2:1000)],'Color', gdoc_r,'LineStyle','-',  'LineWidth', 1.5);hold on;
h3=  plot(exp2_axis(1:1000),[y(end);forData(2:1000)],'Color', gdoc_g,'LineStyle','--',  'LineWidth', 2);hold on;

% 图例与修饰
legend([ h1, h2, h3, h4], ...
       {
        'Butterworth Filtered (Lagged)', ...
        'Ground Truth Feedrate', ...
        'Traditional SARIMA', ...
        'Proposed', ...
        }, ...
       'Location', 'Best');

xlabel('Time (s)', 'FontSize', 12);
ylabel('Feedrate (mm/s)', 'FontSize', 12);

xlim([exp2_axis(1) exp2_axis(1000)]);box on;xticks([3452:30:3544]);
ylim([0 60]);yticks([0:10:60]);
% truncAxis2('Y',[0.035,0.1]);
MyFigureAdjust(gcf,gca, {[22,11],[1 1 1]},1.3);%论文绘图
set(gca,'TickLength',[0.005,0.035]);
set(gcf,'Color','w');

%E4-2残差对比
figure();
h1=plot(exp2_axis(1:1000),res_iir(1:1000),'Color', gdoc_b,'LineStyle','-',  'LineWidth', 1.5);hold on;
h3= plot(exp2_axis(1:1000),res_fast(1:1000),'Color', gdoc_r,'LineStyle','-',  'LineWidth', 1.5);hold on;
h2=  plot(exp2_axis(1:1000),res_sarima(1:1000),'Color', gdoc_g,'LineStyle','-',  'LineWidth', 1.5);hold on;



% 图例与修饰
legend([ h1, h2, h3], ...
       {
        'Butterworth Filtered (Lagged)', ...
        'Traditional SARIMA', ...
        'Proposed', ...
        }, ...
       'Location', 'Best');

xlabel('Time (s)', 'FontSize', 12);
ylabel('Feedrate (mm/s)', 'FontSize', 12);

xlim([exp2_axis(1) exp2_axis(1000)]);box on;xticks([3452:30:3544]);
ylim([-20 20]);yticks([-20:10:20]);
% truncAxis2('Y',[0.035,0.1]);
MyFigureAdjust(gcf,gca, {[15,5],[1 1 1]},1.3);%论文绘图
set(gca,'TickLength',[0.005,0.035]);
set(gcf,'Color','w');



