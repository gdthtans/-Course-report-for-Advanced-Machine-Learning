function fig_obj = MyFigureAdjust(gcf, gca, nargin , beishu)
%nargin里面自带0.8倍率
axiswith=0.5*beishu;
mfontsize=8.5*beishu;%小论文用8.5号字

set(gca,'Linewidth',axiswith)
set (gca, 'FontSize', mfontsize ); 

%%
%包括大小和字体调整,去白边，适合论文
% get(gca,'colororder') %matlab 默认的颜色阶
% imshow(I, 'border', 'tight');图像去白边；https://zhuanlan.zhihu.com/p/26407515
% img = getimage(gcf);                                 %获取当前坐标系图像
% imwrite(img,'img.tiff', 'tiff', 'Resolution', 600)   %只有tiff可以使用Resolution参数， png可以使用X/YResolution， 参考help imwrite

% 图形文件格式矢量（eps适合latex，emf适合:用save命令word,pdf,svg适合浏览器）还是图像文件格式（jpg，bmp，tif）? word 只接受emf,wmf格式的矢量图
% print('Figure1','-djpeg','-r600'); % png无损压缩，jpeg有损压缩
% 输出pdf，简单线图用pdf或eps(-deps)，AI打开编辑 print('Figure2','-djpeg','-r600'); %输出jpg， 复杂、数据量大的彩图用jpg，600ppi
%%
mydefaultfontsize = mfontsize; % 默认为轴坐标的字体大小
mydefaultwidth = 8.5;
if length(nargin) ==1
    if size(nargin{:},2) == 2
        var_wh = nargin{:};
    else
        var_flag = nargin{:};
    end
end
if length(nargin) ==2
    if size(nargin{1},2) == 2
        var_wh = nargin{1}; var_flag = nargin{2};
    else
        var_wh = nargin{2}; var_flag = nargin{1};
    end
end
if exist('var_flag')
    flag_resize = var_flag(1); flag_fontsize = var_flag(2); flag_rmwhite = var_flag(3);
else
    flag_resize = 1; % 尺寸缩放默认[7.6 5.7],
    flag_fontsize = 1; % 字体修改默认轴上10 points,xylabe 10*1.1=12; legend = 0.9*10=9
    flag_rmwhite = 1; % 去除白边
end
if exist('var_wh')
    VarWidth = var_wh(1);  VarHeight= var_wh(2);
else
    VarWidth = mydefaultwidth; %cm; A4纸张，2.5cm左右边框
    VarHeight = VarWidth * 3/4; %cm
end
if flag_fontsize, axisfontsize = mydefaultfontsize; end % 轴上字体大小

fig_obj = gcf; % 获取当前figure
var_legend = findobj(fig_obj, 'type', 'Legend'); % 利用findobj找对象
var_axes_temp = findobj(fig_obj, 'type', 'Axes'); % 轴对象
var_axes = var_axes_temp(end:-1:1);
var_lines = var_axes.Children; %所有线条

if flag_resize % 大小尺寸
    fig_obj.Color = [1.0, 1.0, 1.0]; % background color
    fig_obj.Units = 'centimeters'; % 用cm来定义word中真实大小
    
    fig_obj.Position(3:4) = [VarWidth, VarHeight]/1.25;%/1.25; % 7cmx5.25cm； 8*6
    set(fig_obj, 'PaperPositionMode', 'auto'); % 保持纵横比
end
if flag_fontsize % 字体大小
    % FontSizeMode = 'manual'; %'auto'
    FontNameArray = {'FontName', 'FontSize', 'FontWeight' };
    FontValueArray = {'Time New Roman',axisfontsize, 'normal'};
    set(var_axes, 'FontSize', axisfontsize, 'FontName', 'Time New Roman') % 设置轴上的字体[统一改变label和title的大小1.1倍]
    set([var_legend], FontNameArray, {'Time New Roman',axisfontsize*1.1, 'normal'}) % 设置legend上的字体
    % xyLabeaNameArray = {'FontName', 'FontSize', 'FontWeight' };
    % xyLabeValueArray = {'Time New Roman',myfontsize*1.1, 'normal'};
    % set([var_axes.XLabel; var_axes.YLabel;], xyLabeaNameArray, xyLabeValueArray) % 设置xy轴上的字体
end
if flag_rmwhite % %flag_rmwhite % 去除白边
    rmstyle = 'sty4';
    switch rmstyle
        case 'sty1'
            set(gca,'LooseInset',get(gca,'TightInset'))
        case 'sty2'
            set(gca,'LooseInset',[0 0 0 0])
        case 'sty3'
            for i = 1:length(var_axes)
                ax = var_axes(i);
                outerpos = ax.OuterPosition;
                ti = ax.TightInset;
                left = outerpos(1) + ti(1);
                bottom = outerpos(2) + ti(2);
                ax_width = outerpos(3) - ti(1) - ti(3);
                ax_height = outerpos(4) - ti(2) - ti(4);
                %             ax.Position = [left bottom ax_width ax_height];
                temp(i,:) = [left bottom ax_width ax_height];
            end
            for i = 1:length(var_axes)
                var_axes(i).Position = temp(i,:);
            end
%         case 'sty4'
% %             FcnRemoveWhiteSpaceV5(fig_obj,var_axes(1),MarginLeft1, MarginRight1,MarginTop1, MarginBottom1); % 网络下载 subplots
% %             FcnRemoveWhiteSpaceV5(fig_obj,var_axes(1),0.035, 0.035, 0.025, 0.025); % 网络下载 subplots,0.02 是百分之2
%             FcnRemoveWhiteSpaceV5(gcf,var_axes,0.02, 0.02, 0.025, 0.025); % 网络下载 subplots,0.02 是百分之2

    end
end

if 1 % 显示结果
    disp('[Width, Height]');disp([gcf.Position(3),fig_obj.Position(4)])
    FontNameArray = {'FontName', 'FontSize', 'FontWeight' };
    FinalFonts1 = get([var_axes], FontNameArray); disp(['----var_axes---']);disp(FinalFonts1)
    FinalFonts2 = get([var_axes.XLabel, var_axes.YLabel,var_legend], FontNameArray);
    disp(['---- XLabel;     YLabel;     var_legend----']);disp(FinalFonts2)
    
end

if 0 % 线条改变
    var_line = findobj( var_axes, 'type', 'Line'); % 线对象
    % 'Linestyle', 'Color', 'LineWidth', 'Marker', 'MarkerSize'
    NameArray = {'Linestyle', 'Color', 'LineWidth'};
    ValueArray = {
        '-', 'r', 2;
        '--', 'b', 2;};
    set(var_line, NameArray, ValueArray);
    % set(findobj(get(gca,'Children'),'LineWidth',0.5),'LineWidth',2);
    % axes('position',[0.55,0.55,0.3,0.3]);%关键在这句！所画的小图
    
    % 把matlab双坐标轴的颜色设置为黑色:https://blog.csdn.net/cmdtth/article/details/77461061
    [AX,H1,H2] =plotyy(x,y1,x,y2,@plot);% 获取坐标轴、图像句柄
    set(get(AX(1),'ylabel'),'string', 'the utility of bank');
    set(get(AX(2),'ylabel'),'string', 'optimal R of borrower');
    xlabel('number of iterations');
    set(H1,'Linestyle','--');
    set(H2,'Linestyle',':');
    legend('utility of bank','optimal R of borrower')
    set(AX(:),'Ycolor','k') %设定两个Y轴的颜色为黑色
end

if 0
    % figure;
    % % 更改特定线条的颜色
    % % 绘制一个线条并以 p 的形式返回图形线条对象。将行的 Color 属性设置为 'red'。
    % P = plot(rand(4));
    % set(P,'Color','red')
    % P = plot(rand(4));
    % NameArray = {'LineStyle'};
    % ValueArray = {'-','--',':','-.'}';
    % set(P,NameArray,ValueArray)
    %
    % x = 0:30;
    % y = [1.5*cos(x); 4*exp(-.1*x).*cos(x); exp(.05*x).*cos(x)]';
    % S = stem(x,y);
    % NameArray = {'Marker','Tag'};
    % ValueArray = {'o','Decaying Exponential';...
    %    'square','Growing Exponential';...
    %    '*','Steady State'};
    % set(S,NameArray,ValueArray)
    
    % set(fig_obj,'Position',[100 100 260 220]);
    % set(gca,'Position',[.13 .17 .80 .74]);  %调整 XLABLE和YLABLE不会被切掉
    % figure_FontSize=8;
    % figure_FontWeight = 'bold';
    % % set(get(gca,'XLabel'),'FontSize',figure_FontSize,'Vertical','top');
    % % set(get(gca,'YLabel'),'FontSize',figure_FontSize,'Vertical','middle');
    % set(findobj('FontSize',10),'FontSize',figure_FontSize);
    % set(findobj('FontWeight','normal'),'FontWeight',figure_FontWeight);
    % % var_axes = get(gcf,'Children');
end
