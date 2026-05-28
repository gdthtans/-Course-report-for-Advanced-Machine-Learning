# 工业机器人进给速度在线预测程序说明

本项目用于复现课程报告中的工业机器人进给速度在线预测实验，核心流程包括机器人 TCP 位置数据读取、进给速度构造、Butterworth 低通滤波、群延时补偿、参数域映射、参数域 SARIMA 建模、SVR/1D-CNN/Bi-LSTM 对比实验、快速 SARIMA 在线预测以及实验结果可视化。

项目中包含两个主脚本：

- `feedrate_predict.m`：预测主逻辑脚本，完成数据读取、信号预处理、参数域建模、对比模型预测和误差计算。
- `fig_E1sar.m`：可视化脚本，用于绘制速度预处理、参数域周期性分析、AIC 热力图、预测结果和残差对比图。

> 注意：`fig_E1sar.m` 依赖 `feedrate_predict.m` 运行后保留在 MATLAB 工作区中的变量，因此应先运行预测主脚本，再运行可视化脚本。

---

## 1. 运行环境

建议使用以下环境运行程序：

| 项目 | 推荐配置 |
|---|---|
| 操作系统 | Windows 10 / Windows 11 64 位 |
| MATLAB 版本 | MATLAB R2022b 及以上版本 |
| CPU | Intel Core i5/i7 或同等性能处理器 |
| 内存 | 建议不低于 16 GB |
| GPU | 非必需；仅在训练 1D-CNN 和 Bi-LSTM 对比模型时可用于加速 |
| 数据文件格式 | 当前脚本默认读取 `.txt` 文件，具体格式可参考示例输入`RobotPos250624.txt`|

当前脚本中的主要采样与滤波参数为：

```matlab
Ts = 0.004;      % 采样周期，4 ms
Fs = 1/Ts;       % 采样频率，250 Hz
fc = 8;          % Butterworth 低通滤波截止频率，8 Hz
order = 2;       % 二阶 Butterworth 滤波器
f_motion = 1.5;  % 运动主频，用于群延时估计
```

---

## 2. 依赖工具箱

### 2.1 必需工具箱

| 工具箱 | 主要用途 | 典型函数 |
|---|---|---|
| Signal Processing Toolbox | Butterworth 滤波、群延时分析、自相关峰值检测 | `butter`、`filter`、`grpdelay`、`findpeaks` |
| Econometrics Toolbox | ARIMA/SARIMA 建模、预测、ADF 检验、白噪声检验、自相关/偏自相关分析 | `arima`、`forecast`、`autocorr`、`parcorr`、`adftest`、`lbqtest` |
| Statistics and Machine Learning Toolbox | SVR 对比模型训练与预测 | `fitrsvm`、`predict` |
| Deep Learning Toolbox | 1D-CNN 和 Bi-LSTM 对比模型训练与预测 | `trainNetwork`、`predict`、`sequenceInputLayer`、`convolution1dLayer`、`bilstmLayer` |
| 2000 palettes | 实验图配色所用工具箱01
| 200 colormaps | 实验图配色所用工具箱02

### 2.2 可选工具箱

| 工具箱 | 适用情况 |
|---|---|
| Optimization Toolbox | 若 `SARIMA_search` 或其他 SARIMA 参数估计函数内部调用 `fmincon`、`optimoptions` 等优化函数，则需要该工具箱。 |
| Parallel Computing Toolbox | 若希望使用 GPU 或并行计算加速 1D-CNN、Bi-LSTM 或网格搜索过程，可安装该工具箱。 |
| 2000 palettes | 实验图配色所用工具箱01,如不安装须换为其他默认颜色|
| 200 colormaps | 实验图配色所用工具箱02,如不安装须换为其他默认颜色|
---

## 3. 文件与目录结构

建议将代码和数据整理为如下结构：

```text
project_root/
├─ feedrate_predict.m              # 预测主逻辑脚本
├─ fig_E1sar.m                     # 结果可视化脚本
├─ feedrate_predict.asv            # MATLAB 自动备份文件，非主代码
├─ README.md
└─ function/                       # 自定义函数目录
   ├─ SARIMA_search.m
   ├─ fast_sarima.m
   ├─ para_interp.m
   ├─ predict_SVM.m
   ├─ predict_CNN.m
   ├─ predict_LSTM.m
   ├─ predict_LSTMd.m
   ├─ MyFigureAdjust.m
   ├─ optimized_holt_winters.m
   ├─ holt_winters.m
   ├─ hw_mse_objective.m
   ├─ localFitOneModel.m
   ├─ create_features.m
   ├─ centeredFFT.m
   └─ arc_simpson.m
```

当前脚本中至少需要以下数据文件：

- `RobotPos250624.txt`：机器人实测数据。脚本中通过 `importdata('RobotPos250624.txt')` 读取。
- `pnt.txt`：规划刀路点数据。脚本中通过 `importdata('pnt.txt')` 读取。


> 如果运行时报出“未定义函数或变量”，通常是因为上述自定义函数、数据文件或中间变量未加入当前路径或尚未生成。

---

## 4. 使用流程

### 4.1 准备数据与代码

1. 将 `feedrate_predict.m`、`fig_E1sar.m`、`RobotPos250624.txt` 和 `pnt.txt` 放在同一工程目录中。
2. 将自定义函数放入工程目录或 `functions/` 子目录中。
3. 打开 MATLAB，并将当前工作目录切换到工程根目录。
4. 将文件夹AML及其子文件夹的内容包含到路径：


### 4.2 运行预测主逻辑

在 MATLAB 命令行中运行：

```matlab
feedrate_predict
```

该脚本主要完成以下任务：

1. 读取机器人采集数据 `RobotPos250624.txt` 和规划刀路点 `pnt.txt`。
2. 将姿态角由角度制转换为弧度制。
3. 根据机器人 TCP 位置序列计算原始差分进给速度。
4. 设计二阶 Butterworth 低通滤波器，并对位置和速度数据进行滤波。
5. 通过 `grpdelay` 计算主频附近的滤波群延时，并构造群延时补偿后的速度序列。
6. 将时间域速度序列映射到参数域，得到参数域速度序列。
7. 通过自相关函数估计参数域周期长度，并进行季节差分和平稳性检验。
8. 使用 `SARIMA_search` 对 SARIMA 候选阶次进行 AIC 搜索。
9. 采用 MATLAB 内置 `forecast` 进行传统 SARIMA 预测。
10. 分别运行 SVR、1D-CNN 和 LSTM/Bi-LSTM 对比模型。
11. 调用 `fast_sarima` 进行快速参数更新和参数域预测。
12. 输出 RMSE、残差和、计算时间等实验指标。


### 4.3 运行结果可视化

在 `feedrate_predict.m` 成功运行后，保持 MATLAB 工作区变量不清空，然后运行：

```matlab
fig_E1sar
```

该脚本主要绘制以下图表：

1. 原始差分速度、ABB 速度、Butterworth 滤波速度和群延时补偿速度对比图。
2. 参数域速度序列、自相关函数和季节差分序列图。
3. ARIMA 与 SARIMA 候选模型的 AIC 热力图。
4. 对比方法的时域进给速度预测图与残差对比图。
5. 所提方法与对比方法的时域进给速度预测图与残差对比图。

---

## 5. 注意事项

0. 本项目所用输入数据上传于Release v1.0.0 ，分别为'RobotPos250624.txt'与'pnt.txt'。此外本项目配备了在本机运行的实验数据，上传于Release v1.0.0 'matlab20260527'中，加载后可直接运行`fig_E1sar.m`。
1. 当前代码为实验脚本，部分参数采用固定索引，例如 `128739`、`6328`、`134597`、`3012` 等。这些参数与当前实验数据长度和加工周期有关。若更换数据集，需要相应修改索引范围。
2. `fig_E1sar.m` 依赖预测脚本运行后的工作区变量。若单独运行可视化脚本，可能出现变量未定义错误。
3. 可视化脚本中使用了 `x_end`、`y`、`x_iir`、`x_acc`、`res_iir`、`res_fast` 和 `res_sarima` 等变量。若这些变量没有在 `feedrate_predict.m` 中自动生成，需要在运行可视化脚本前手动生成或从结果文件中加载。
4. 若 MATLAB 版本较低，部分函数行为可能不同。例如，`forecast` 的输入格式在不同版本中可能存在差异，需要根据当前版本适当调整。
5. 若运行深度学习对比模型较慢，可先注释 1D-CNN 和 LSTM/Bi-LSTM 部分，仅运行本文方法和 SVR 对比模型。
6. 若只希望复现本文核心在线预测方法，需要保证 `fast_sarima.m`、`para_interp.m` 和相关数据文件可用；深度学习相关函数主要用于对比实验。

---
