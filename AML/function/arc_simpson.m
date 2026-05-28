function arc_length = arc_simpson(points)
% ARC_LENGTH_SIMPSON 使用 Simpson 积分公式计算三维曲线的弧长
%   输入:
%       points: 一个 3 x n 的矩阵，其中每一列代表曲线上的一个点 [x; y; z]
%   输出:
%       arc_length: 曲线的近似弧长

% 检查输入
if ~ismatrix(points) || size(points, 1) ~= 3
    error('输入必须是一个 3 x n 矩阵');
end

n = size(points, 2);

% 处理边界情况
if n < 2
    arc_length = 0;
    return;
elseif n == 2
    % 两点间距离
    arc_length = norm(points(:, 2) - points(:, 1));
    return;
end

% 计算相邻点之间的距离 (ds/dt 的近似值)
distances = sqrt(sum(diff(points, 1, 2).^2, 1)); % 1 x (n-1) 向量

% Simpson 规则需要偶数个子区间 (奇数个点)
% 如果区间数是奇数，则对前 n-2 个点应用 Simpson 规则，最后两个用梯形规则
if mod(n-1, 2) == 1 % n 是偶数，有奇数个区间
    % 应用复合 Simpson 规则于前 n-1 个点 (n-2 个区间，偶数)
    if n > 2
        h = 1; % 假设参数步长为 1，因为我们是基于点的索引
        simpson_sum = distances(1); % 第一个区间左端点
        for i = 2:(n-2)
            if mod(i, 2) == 0
                simpson_sum = simpson_sum + 4 * distances(i);
            else
                simpson_sum = simpson_sum + 2 * distances(i);
            end
        end
        simpson_sum = simpson_sum + distances(n-1); % 最后一个区间右端点
        arc_length = (h / 3) * simpson_sum;
    else
        arc_length = 0; % 不应到达这里，因为 n==2 已处理
    end
    
    % 加上最后一段的梯形规则近似
    arc_length = arc_length + distances(end); % h*(f(n-1)+f(n))/2, 这里 h=1, f是距离
    
else
    % 区间数是偶数，直接应用复合 Simpson 规则
    h = 1;
    simpson_sum = distances(1);
    for i = 2:(n-1)
        if mod(i, 2) == 0
            simpson_sum = simpson_sum + 4 * distances(i);
        else
            simpson_sum = simpson_sum + 2 * distances(i);
        end
    end
    simpson_sum = simpson_sum + distances(end);
    arc_length = (h / 3) * simpson_sum;
end

end



