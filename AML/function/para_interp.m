function output_array = para_interp(input_array)
  % 输入参数检查
    if nargin < 1
        error('请输入一个一维数组');
    end
    
    % 获取数组长度
    n = length(input_array);
    output_array = zeros(1, n); % 初始化输出数组
    
    % 找到所有变化点的位置
    change_points = [1, find(diff(input_array) ~= 0) + 1, n + 1];
    
    % 获取数组中的最大值
    max_value = max(input_array);
    
    % 对每个数字段进行线性插值
    for i = 1:(length(change_points) - 1)
        start_idx = change_points(i);
        end_idx = change_points(i + 1) - 1;
        
        k = input_array(start_idx); % 当前段的数字
        segment_length = end_idx - start_idx + 1; % 当前段的长度
        
        if k < max_value
            % 如果不是最大值段，进行从k到k+1的线性插值，但不达到k+1
            % 使用segment_length+1个点，然后取前segment_length个点
            temp_points = linspace(k, k + 1, segment_length + 1);
            output_array(start_idx:end_idx) = temp_points(1:segment_length);
        else
            % 如果是最大值段，保持为k，不进行插值
            output_array(start_idx:end_idx) = k;
        end
    end
end
