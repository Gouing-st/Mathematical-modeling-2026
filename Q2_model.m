%% ========================================================================
%  Q2  Startup Community Capacity Configuration & Dynamic Growth Model
%  Full pipeline: Logistic growth -> demand -> budget-constrained optimal
%  one-shot allocation -> cloud elastic top-up -> utilisation -> figures
%  Author: modelling team          MATLAB R2025b
%  ========================================================================
clear; clc; close all;
rng(0);

outdir = fullfile(pwd,'Q2_figs');
if ~exist(outdir,'dir'); mkdir(outdir); end

%% ---------- journal style defaults ----------
set(0,'DefaultAxesFontName','Arial','DefaultTextFontName','Arial');
set(0,'DefaultAxesFontSize',11,'DefaultAxesLineWidth',1.0);
set(0,'DefaultLineLineWidth',1.8);
% colour palette (colour-blind friendly)
col.blue   = [0.00 0.45 0.74];
col.orange = [0.85 0.33 0.10];
col.green  = [0.20 0.63 0.17];
col.purple = [0.49 0.18 0.56];
col.grey   = [0.50 0.50 0.50];
col.red    = [0.80 0.14 0.14];

%% ========================================================================
%  1. PARAMETERS
%  ========================================================================
% --- scale & capacity (appendix) ---
S_total   = 10000;      % total floor area  m^2
usable    = 0.55;       % office ratio (public/service area removed)
area_pp   = 5.5;        % area per seat  m^2
K         = round(S_total*usable/area_pp);   % carrying capacity (seats)

% --- logistic growth ---
N0 = 100;               % initial occupancy (seats)
r  = 0.50;              % intrinsic growth rate
Tspan = 0:10;           % 10-year horizon

% --- demand coefficients (per person) ---
a_d = 0.40;             % hardware sets per person
b_d = 0.65;             % compute nodes per person

% --- budget (appendix) ---
B       = 2000e4;       % equipment budget  CNY (HARD constraint)
c_hw    = 3.0e4;        % unit hardware cost  CNY/set (AI workstation)
c_comp  = 2.0e4;        % unit compute cost   CNY/node (containerised GPU)

% --- penalty weights ---
w_gap  = 3.0;           % shortage penalty (hurts R&D output)
w_idle = 1.0;           % idle penalty     (asset waste)

% --- cloud elastic top-up (annual rental) ---
p_cloud_hw   = 0.30e4;  % CNY per set-year
p_cloud_comp = 0.50e4;  % CNY per node-year

% --- other cost parameters (appendix) ---
reno       = 800*S_total;         % one-off renovation
ops_annual = 25*12*S_total;       % O&M per year
soft_pp    = 1200;                % soft support per person-year
dep_annual = B*(1-0.05)/10;       % straight-line depreciation

fprintf('\n============================================================\n');
fprintf(' Q2  Capacity Configuration & Dynamic Growth  (one-shot plan)\n');
fprintf('============================================================\n');
fprintf(' Carrying capacity  K = %d seats\n',K);
fprintf(' Budget B = %.0f wan CNY | hw %.1f wan/set | compute %.1f wan/node\n',...
        B/1e4,c_hw/1e4,c_comp/1e4);

%% ========================================================================
%  2. LOGISTIC GROWTH  N(t)
%  ========================================================================
A_log = (K-N0)/N0;
Nt = @(t) K ./ (1 + A_log.*exp(-r.*t));
N  = Nt(Tspan);

t_inflect = log(A_log)/r;           % 0.5K
t_sat     = log(9*A_log)/r;         % 0.9K

fprintf('\n--- Logistic growth ---\n');
fprintf(' N(t) = %d / (1 + %.2f e^{-%.2f t})\n',K,A_log,r);
fprintf(' inflection (0.5K) at t = %.2f yr;  saturation (0.9K) at t = %.2f yr\n',...
        t_inflect,t_sat);
fprintf(' Year :'); fprintf('%6d',Tspan); fprintf('\n N(t) :'); fprintf('%6.0f',N); fprintf('\n');

%% ========================================================================
%  3. DEMAND
%  ========================================================================
D_hw   = a_d * N;       % hardware demand (sets)
D_comp = b_d * N;       % compute demand (nodes)

%% ========================================================================
%  4. BUDGET-CONSTRAINED OPTIMAL ONE-SHOT ALLOCATION
%     decision var: lambda = hardware share of equipment budget
%     objective: min sum_t [ w_gap*(gap)^2 + w_idle*(idle)^2 ]  (hw+compute)
%  ========================================================================
lam_grid = 0.01:0.001:0.99;
Jcost = zeros(size(lam_grid));
for k = 1:numel(lam_grid)
    lam  = lam_grid(k);
    nhw  = lam*B / c_hw;
    ncmp = (1-lam)*B / c_comp;
    gh = max(D_hw   - nhw ,0);  ih = max(nhw  - D_hw ,0);
    gc = max(D_comp - ncmp,0);  ic = max(ncmp - D_comp,0);
    Jcost(k) = sum(w_gap*(gh.^2+gc.^2) + w_idle*(ih.^2+ic.^2));
end
[Jmin,ix] = min(Jcost);
lam_opt = lam_grid(ix);
n_hw   = floor(lam_opt*B / c_hw);
n_comp = floor((1-lam_opt)*B / c_comp);
spent  = n_hw*c_hw + n_comp*c_comp;

fprintf('\n--- Optimal one-shot allocation ---\n');
fprintf(' lambda* = %.3f  (hardware budget share)\n',lam_opt);
fprintf(' hardware : %d sets  (%.0f wan)\n',n_hw,n_hw*c_hw/1e4);
fprintf(' compute  : %d nodes (%.0f wan)\n',n_comp,n_comp*c_comp/1e4);
fprintf(' spent    : %.1f wan / budget %.0f wan  (%.1f%%)\n',...
        spent/1e4,B/1e4,spent/B*100);

%% ========================================================================
%  5. UTILISATION & CLOUD TOP-UP
%  ========================================================================
util_hw   = min(D_hw  /n_hw  ,1)*100;
util_comp = min(D_comp/n_comp,1)*100;
gap_hw    = max(D_hw   - n_hw ,0);
gap_comp  = max(D_comp - n_comp,0);
cloud_hw_cost   = gap_hw   * p_cloud_hw;
cloud_comp_cost = gap_comp * p_cloud_comp;
cloud_cost_yr   = cloud_hw_cost + cloud_comp_cost;

avg_util_hw   = mean(util_hw(2:end));   % years 1..10
avg_util_comp = mean(util_comp(2:end));

fprintf('\n--- Utilisation (capped @100%%, yr1-10 mean) ---\n');
fprintf(' hardware %.1f%% | compute %.1f%%\n',avg_util_hw,avg_util_comp);
fprintf(' cloud top-up 10-yr total = %.1f wan (mean %.1f wan/yr)\n',...
        sum(cloud_cost_yr)/1e4,sum(cloud_cost_yr)/10/1e4);

%% ========================================================================
%  6. LIFECYCLE COST & SOFT/HARD RATIO
%  ========================================================================
soft_yr   = soft_pp*N;
hard_inv  = reno + spent;                       % renovation + equipment
soft_inv  = sum(soft_yr) + sum(cloud_cost_yr);  % soft support + cloud
ratio_h   = hard_inv/(hard_inv+soft_inv)*100;
ratio_s   = 100-ratio_h;
life_total= reno + spent + ops_annual*10 + sum(soft_yr) + sum(cloud_cost_yr);

fprintf('\n--- Lifecycle cost ---\n');
fprintf(' one-off: renovation %.0f wan + equipment %.0f wan\n',reno/1e4,spent/1e4);
fprintf(' 10-yr O&M %.0f wan | soft %.0f wan | cloud %.1f wan\n',...
        ops_annual*10/1e4,sum(soft_yr)/1e4,sum(cloud_cost_yr)/1e4);
fprintf(' 10-yr TOTAL = %.0f wan\n',life_total/1e4);
fprintf(' hard:soft investment ratio = %.1f%% : %.1f%%\n',ratio_h,ratio_s);

%% ========================================================================
%  7. FIGURES  (journal quality)
%  ========================================================================
tf = linspace(0,10,400);
Nf = Nt(tf);

% ---- FIG 1: Logistic growth curve ----
f1 = figure('Color','w','Position',[100 100 720 480]);
ax = axes(f1); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
ax.GridAlpha = 0.15;
yline(ax,K,'--','Color',col.grey,'LineWidth',1.2,'Label','Capacity K',...
      'LabelHorizontalAlignment','left','FontSize',10);
yline(ax,0.5*K,':','Color',col.orange,'LineWidth',1.0);
yline(ax,0.9*K,':','Color',col.green,'LineWidth',1.0);
plot(ax,tf,Nf,'-','Color',col.blue,'LineWidth',2.2);
plot(ax,Tspan,N,'o','MarkerSize',7,'MarkerFaceColor',col.blue,...
     'MarkerEdgeColor','w','LineWidth',1);
% inflection & saturation markers
plot(ax,t_inflect,0.5*K,'s','MarkerSize',11,'MarkerFaceColor',col.orange,...
     'MarkerEdgeColor','k');
plot(ax,t_sat,0.9*K,'^','MarkerSize',11,'MarkerFaceColor',col.green,...
     'MarkerEdgeColor','k');
text(ax,t_inflect+0.15,0.5*K-45,sprintf('Inflection\n t=%.2f yr',t_inflect),...
     'FontSize',9,'Color',col.orange);
text(ax,t_sat-2.3,0.9*K-55,sprintf('Saturation\n t=%.2f yr',t_sat),...
     'FontSize',9,'Color',col.green);
xlabel(ax,'Year  {\itt}'); ylabel(ax,'Occupancy  {\itN(t)}  (persons)');
title(ax,'Logistic Occupancy Growth Model','FontWeight','bold');
xlim(ax,[0 10]); ylim(ax,[0 K*1.08]);
legend(ax,{'Capacity','','','N(t) fitted','Yearly N(t)','Inflection','Saturation'},...
       'Location','southeast','Box','off','FontSize',9);
exportgraphics(f1,fullfile(outdir,'Fig1_logistic.png'),'Resolution',300);

% ---- FIG 2: Demand vs Supply (dual panel) ----
f2 = figure('Color','w','Position',[100 100 900 420]);
% hardware
sp1 = subplot(1,2,1); hold(sp1,'on'); box(sp1,'on'); grid(sp1,'on'); sp1.GridAlpha=0.15;
area(sp1,Tspan,D_hw,'FaceColor',col.blue,'FaceAlpha',0.18,'EdgeColor','none');
plot(sp1,Tspan,D_hw,'-o','Color',col.blue,'MarkerFaceColor',col.blue,...
     'MarkerSize',5,'MarkerEdgeColor','w');
yline(sp1,n_hw,'-','Color',col.red,'LineWidth',2,...
      'Label',sprintf('Supply = %d',n_hw),'FontSize',9,...
      'LabelHorizontalAlignment','left');
% shade shortage
idx = D_hw>n_hw;
patch(sp1,[Tspan(idx) fliplr(Tspan(idx))],...
      [D_hw(idx) fliplr(repmat(n_hw,1,sum(idx)))],col.red,...
      'FaceAlpha',0.15,'EdgeColor','none');
xlabel(sp1,'Year'); ylabel(sp1,'Hardware (sets)');
title(sp1,'(a) Hardware: Demand vs Supply','FontWeight','bold');
xlim(sp1,[0 10]);
% compute
sp2 = subplot(1,2,2); hold(sp2,'on'); box(sp2,'on'); grid(sp2,'on'); sp2.GridAlpha=0.15;
area(sp2,Tspan,D_comp,'FaceColor',col.purple,'FaceAlpha',0.18,'EdgeColor','none');
plot(sp2,Tspan,D_comp,'-o','Color',col.purple,'MarkerFaceColor',col.purple,...
     'MarkerSize',5,'MarkerEdgeColor','w');
yline(sp2,n_comp,'-','Color',col.red,'LineWidth',2,...
      'Label',sprintf('Supply = %d',n_comp),'FontSize',9,...
      'LabelHorizontalAlignment','left');
idx = D_comp>n_comp;
patch(sp2,[Tspan(idx) fliplr(Tspan(idx))],...
      [D_comp(idx) fliplr(repmat(n_comp,1,sum(idx)))],col.red,...
      'FaceAlpha',0.15,'EdgeColor','none');
xlabel(sp2,'Year'); ylabel(sp2,'Compute (nodes)');
title(sp2,'(b) Compute: Demand vs Supply','FontWeight','bold');
xlim(sp2,[0 10]);
exportgraphics(f2,fullfile(outdir,'Fig2_demand_supply.png'),'Resolution',300);

% ---- FIG 3: lambda optimisation curve ----
f3 = figure('Color','w','Position',[100 100 720 480]);
ax3 = axes(f3); hold(ax3,'on'); box(ax3,'on'); grid(ax3,'on'); ax3.GridAlpha=0.15;
plot(ax3,lam_grid,Jcost/1e6,'-','Color',col.blue,'LineWidth',2);
plot(ax3,lam_opt,Jmin/1e6,'p','MarkerSize',16,'MarkerFaceColor',col.orange,...
     'MarkerEdgeColor','k');
xline(ax3,lam_opt,'--','Color',col.grey,'LineWidth',1);
text(ax3,lam_opt+0.02,Jmin/1e6+max(Jcost/1e6)*0.06,...
     sprintf('\\lambda^* = %.3f',lam_opt),'FontSize',12,'FontWeight','bold');
xlabel(ax3,'Hardware budget share  \lambda');
ylabel(ax3,'Total mismatch penalty  {\itJ}  (\times10^6)');
title(ax3,'Optimal Budget Allocation (Grid Search)','FontWeight','bold');
xlim(ax3,[0 1]);
exportgraphics(f3,fullfile(outdir,'Fig3_lambda_opt.png'),'Resolution',300);

% ---- FIG 4: Utilisation over time ----
f4 = figure('Color','w','Position',[100 100 760 480]);
ax4 = axes(f4); hold(ax4,'on'); box(ax4,'on'); grid(ax4,'on'); ax4.GridAlpha=0.15;
b = bar(ax4,Tspan(2:end),[util_hw(2:end); util_comp(2:end)]',1,'grouped');
b(1).FaceColor=col.blue; b(1).EdgeColor='none';
b(2).FaceColor=col.purple; b(2).EdgeColor='none';
yline(ax4,60,'--','Color',col.grey,'LineWidth',1.2,'Label','Lower bound 60%',...
      'FontSize',9,'LabelHorizontalAlignment','left');
yline(ax4,avg_util_hw,':','Color',col.blue,'LineWidth',1.4);
yline(ax4,avg_util_comp,':','Color',col.purple,'LineWidth',1.4);
xlabel(ax4,'Year'); ylabel(ax4,'Utilisation (%)');
title(ax4,'Facility Utilisation (capped at 100%)','FontWeight','bold');
legend(ax4,{sprintf('Hardware (avg %.1f%%)',avg_util_hw),...
            sprintf('Compute (avg %.1f%%)',avg_util_comp)},...
       'Location','southeast','Box','off','FontSize',9);
ylim(ax4,[0 110]); xlim(ax4,[0.3 10.7]);
exportgraphics(f4,fullfile(outdir,'Fig4_utilisation.png'),'Resolution',300);

% ---- FIG 5: cloud top-up cost ----
f5 = figure('Color','w','Position',[100 100 760 460]);
ax5 = axes(f5); hold(ax5,'on'); box(ax5,'on'); grid(ax5,'on'); ax5.GridAlpha=0.15;
bc = bar(ax5,Tspan(2:end),[cloud_hw_cost(2:end); cloud_comp_cost(2:end)]'/1e4,...
         0.7,'stacked');
bc(1).FaceColor=col.blue; bc(2).FaceColor=col.purple;
bc(1).EdgeColor='none';   bc(2).EdgeColor='none';
xlabel(ax5,'Year'); ylabel(ax5,'Cloud rental cost (\times10^4 CNY)');
title(ax5,'Elastic Cloud Top-up for Capacity Gap','FontWeight','bold');
legend(ax5,{'Hardware top-up','Compute top-up'},'Location','northwest',...
       'Box','off','FontSize',9);
xlim(ax5,[0.3 10.7]);
exportgraphics(f5,fullfile(outdir,'Fig5_cloud.png'),'Resolution',300);

% ---- FIG 6: lifecycle cost composition (stacked area) ----
f6 = figure('Color','w','Position',[100 100 820 460]);
ax6 = axes(f6); hold(ax6,'on'); box(ax6,'on'); grid(ax6,'on'); ax6.GridAlpha=0.15;
Ccum = [repmat(dep_annual,1,10);        % depreciation
        repmat(ops_annual,1,10);        % O&M
        soft_yr(2:end);                 % soft support
        cloud_cost_yr(2:end)]/1e4;      % cloud
har = area(ax6,Tspan(2:end),Ccum','LineStyle','none');
har(1).FaceColor=col.grey;   har(1).FaceAlpha=0.85;
har(2).FaceColor=col.blue;   har(2).FaceAlpha=0.85;
har(3).FaceColor=col.green;  har(3).FaceAlpha=0.85;
har(4).FaceColor=col.orange; har(4).FaceAlpha=0.90;
xlabel(ax6,'Year'); ylabel(ax6,'Annual cost (\times10^4 CNY)');
title(ax6,'Annual Operating Cost Composition','FontWeight','bold');
legend(ax6,{'Depreciation','O&M','Soft support','Cloud top-up'},...
       'Location','northwest','Box','off','FontSize',9);
xlim(ax6,[1 10]);
exportgraphics(f6,fullfile(outdir,'Fig6_cost_composition.png'),'Resolution',300);

%% ========================================================================
%  8. EXPORT RESULT TABLE
%  ========================================================================
Yr = Tspan(:);
T = table(Yr, round(N(:)), round(D_hw(:),1), round(D_comp(:),1), ...
          round(util_hw(:),1), round(util_comp(:),1), ...
          round(cloud_cost_yr(:)/1e4,2), ...
          'VariableNames',{'Year','N_t','Demand_HW','Demand_Comp',...
          'Util_HW_pct','Util_Comp_pct','Cloud_wan'});
writetable(T,fullfile(outdir,'Q2_results.csv'));
disp(' '); disp('--- Result table (also saved to Q2_results.csv) ---');
disp(T);

%% ========================================================================
%  9. KEY OUTPUTS SUMMARY
%  ========================================================================
fprintf('\n============================================================\n');
fprintf(' KEY OUTPUTS\n');
fprintf('============================================================\n');
fprintf(' Seats (one-off build)      : %d\n',K);
fprintf(' Hardware sets (self-owned) : %d\n',n_hw);
fprintf(' Compute nodes (self-owned) : %d\n',n_comp);
fprintf(' HW:Compute budget split    : %.0f%% : %.0f%%\n',lam_opt*100,(1-lam_opt)*100);
fprintf(' Equipment spent            : %.0f wan (budget 2000)\n',spent/1e4);
fprintf(' Avg utilisation HW/Comp    : %.1f%% / %.1f%%\n',avg_util_hw,avg_util_comp);
fprintf(' Cloud top-up (10-yr)       : %.1f wan\n',sum(cloud_cost_yr)/1e4);
fprintf(' Hard:Soft investment       : %.1f%% : %.1f%%\n',ratio_h,ratio_s);
fprintf(' 10-yr total investment     : %.0f wan\n',life_total/1e4);
fprintf('\n 6 figures saved to: %s\n',outdir);
fprintf('============================================================\n');