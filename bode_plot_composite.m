%% 复合开环传递函数 Bode 图绘制
%  G(s) = 10(s+1) / [s(s+5)(s^2+2s+4)]
%  分子阶数 m=1, 分母阶数 n=4
%
%  典型环节分解:
%    比例环节:   K = 10
%    一阶微分:   (s+1)          零点 s = -1
%    积分环节:   1/s            极点 s = 0
%    惯性环节:   1/(s+5)        极点 s = -5
%    振荡环节:   1/(s^2+2s+4)   极点 s = -1±j√3  (ωn=2, ζ=0.5)
%
%  作者: Claude (Anthropic)
%  日期: 2026-05-22



%% 1. 定义各典型环节
s = tf('s');

K  = 10;                        % 比例环节
G1 = s + 1;                     % 一阶微分环节
G2 = 1/s;                       % 积分环节
G3 = 1/(s + 5);                 % 惯性环节
G4 = 1/(s^2 + 2*s + 4);        % 振荡环节 (wn=2, zeta=0.5)

%% 2. 复合开环传递函数
G = K * G1 * G2 * G3 * G4;

fprintf('========== 开环传递函数 ==========\n');
G

fprintf('========== 零点 ==========\n');
disp(zero(G));
fprintf('========== 极点 ==========\n');
disp(pole(G));

%% 3. 计算稳定裕度
[Gm, Pm, Wcg, Wcp] = margin(G);
fprintf('\n========== 稳定裕度 ==========\n');
fprintf('增益裕度 Gm = %.2f dB  (在 ωcg = %.2f rad/s)\n', 20*log10(Gm), Wcg);
fprintf('相角裕度 Pm = %.2f°    (在 ωcp = %.2f rad/s)\n', Pm, Wcp);

%% 4. 绘制 Bode 图 (含增益裕度和相角裕度标注)
figure('Position', [100 100 900 600], 'Color', 'w');
margin(G);
grid on;
title({'开环传递函数 Bode 图 (含裕度标注)'; ...
       'G(s) = 10(s+1) / [s(s+5)(s^2+2s+4)]'}, 'FontSize', 13);

%% 5. 单独的 Bode 图 (无裕度标注)
figure('Position', [100 100 900 600], 'Color', 'w');
bode(G);
grid on;
title({'开环传递函数 Bode 图'; ...
       'G(s) = 10(s+1) / [s(s+5)(s^2+2s+4)]'}, 'FontSize', 13);
