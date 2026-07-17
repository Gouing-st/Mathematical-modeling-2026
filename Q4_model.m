%% ========================================================================
%  Q4  10-Year Input-Output & Economic Feasibility Analysis
%  Inputs : Q1 site (Econ Dev Zone), Q2 capacity & equipment,
%           Q3 space allocation, appendix cost parameters
%  Outputs: revenue/cost model, cash flow, NPV/IRR/payback,
%           pricing-subsidy optimisation, sensitivity, 6 journal figures
%  MATLAB R2025b
%  ========================================================================
clear; clc; close all;
rng(0);

outdir = fullfile(pwd,'Q4_figs');
if ~exist(outdir,'dir'); mkdir(outdir); end

%% ---------- journal style ----------
set(0,'DefaultAxesFontName','Arial','DefaultTextFontName','Arial');
set(0,'DefaultAxesFontSize',11,'DefaultAxesLineWidth',1.0);
set(0,'DefaultLineLineWidth',1.8);
col.blue   = [0.00 0.45 0.74];
col.orange = [0.85 0.33 0.10];
col.green  = [0.20 0.63 0.17];
col.purple = [0.49 0.18 0.56];
col.grey   = [0.50 0.50 0.50];
col.red    = [0.80 0.14 0.14];
col.teal   = [0.00 0.60 0.56];

%% ========================================================================
%  1.  INPUTS (from Q1-Q3 final results + appendix)
%  ========================================================================
% --- Q2 growth ---
K=1000; N0=100; r_log=0.50; A_log=(K-N0)/N0;
Tspan = 0:10;
N = K./(1+A_log.*exp(-r_log.*Tspan));

% --- Q2 equipment (one-shot optimal) ---
n_hw=341; n_comp=488;
a_d=0.40; b_d=0.65;
D_hw = a_d*N; D_comp = b_d*N;
c_hw=3.0e4; c_comp=2.0e4;            % unit equipment cost CNY

% --- Q3 space ---
S_total=10000; office_area=5500; public_area=1500;

% --- appendix cost parameters ---
reno   = 800*S_total;                % one-off renovation (NOT depreciated)
equip  = 1999e4;                     % Q2 equipment spend
ops_annual = 25*12*S_total;          % O&M 300 wan/yr
soft_pp = 1200;                      % soft support per person-yr
resid = 0.05;                        % equipment residual rate

% --- appendix Econ-Dev-Zone stylised parameters (NOT Q1 field data) ---
rent_ceiling = 40;                   % CNY/m^2/month (market ceiling)
subsidy_rent = 0.60;                 % C41 office-rent subsidy share

% --- cloud top-up unit price (from Q2) ---
p_cloud_hw=0.30e4; p_cloud_comp=0.50e4;
gap_hw   = max(D_hw - n_hw ,0);
gap_comp = max(D_comp - n_comp,0);
cloud_raw = gap_hw*p_cloud_hw + gap_comp*p_cloud_comp;   % CNY

% --- discount rate ---
disc = 0.08;

fprintf('============================================================\n');
fprintf(' Q4  10-Year Economic Feasibility Analysis\n');
fprintf('============================================================\n');
fprintf(' CAPEX = %.0f wan (reno %.0f + equip %.0f)\n',...
        (reno+equip)/1e4,reno/1e4,equip/1e4);
fprintf(' Discount rate = %.1f%%\n',disc*100);

%% ========================================================================
%  2.  REVENUE MODEL (4 streams)
%  ========================================================================
office_occ = (N/K)*office_area;      % occupied office area m^2

% split of rent: gov pays 60%, tenant pays 40% (sum = market ceiling)
rent_gov    = rent_ceiling*subsidy_rent;      % 24 CNY/m^2/mo
rent_tenant = rent_ceiling*(1-subsidy_rent);  % 16 CNY/m^2/mo

R1 = office_occ .* rent_tenant * 12 / 1e4;    % tenant-paid rent
R3 = office_occ .* rent_gov    * 12 / 1e4;    % gov rent subsidy

% usage fee priced from depreciation x markup
dep_hw_u   = c_hw*(1-resid)/10;   markup_hw=2.0;
dep_comp_u = c_comp*(1-resid)/10; markup_comp=4.5;
fee_hw   = dep_hw_u*markup_hw;      % ~5700 CNY/set/yr
fee_comp = dep_comp_u*markup_comp;  % ~8550 CNY/node/yr
useH = min(D_hw,n_hw); useC = min(D_comp,n_comp);
R2 = (useH*fee_hw + useC*fee_comp)/1e4;

% cloud cost pass-through (no markup)
R4 = cloud_raw/1e4;

Revenue = R1 + R2 + R3 + R4;

fprintf('\n--- Revenue (wan) ---\n');
fprintf(' %-4s %8s %8s %8s %8s %8s\n','Year','R1rent','R2fee','R3subs','R4cloud','Total');
for t=2:11
    fprintf(' %-4d %8.1f %8.1f %8.1f %8.2f %8.1f\n',...
            Tspan(t),R1(t),R2(t),R3(t),R4(t),Revenue(t));
end

%% ========================================================================
%  3.  COST MODEL
%  ========================================================================
soft_cost = soft_pp*N/1e4;
gov_ops_sub = ops_annual/1e4 * (public_area/S_total);   % 45 wan/yr baseline
cloud_cost  = cloud_raw/1e4;                            % offsets R4

Cost = ops_annual/1e4 - gov_ops_sub + soft_cost + cloud_cost;

% accounting depreciation (equipment only; renovation one-off per appendix)
dep_equip = equip*(1-resid)/10/1e4;

fprintf('\n--- Cost (wan) ---\n');
fprintf(' %-4s %8s %8s %8s %8s\n','Year','O&M_net','Soft','Cloud','Total');
for t=2:11
    fprintf(' %-4d %8.1f %8.1f %8.2f %8.1f\n',...
            Tspan(t),ops_annual/1e4-gov_ops_sub,soft_cost(t),cloud_cost(t),Cost(t));
end
fprintf(' Equipment depreciation (accounting only): %.1f wan/yr\n',dep_equip);

%% ========================================================================
%  4.  CASH FLOW & ECONOMIC INDICATORS
%  ========================================================================
CF = zeros(1,11);
CF(1) = -(reno+equip)/1e4;             % t=0 capital outlay
CF(2:11) = Revenue(2:11) - Cost(2:11);

cumCF = cumsum(CF);

% static payback (linear interp)
payback_s = NaN;
for t=2:11
    if cumCF(t)>=0
        payback_s = (t-2) + (-cumCF(t-1))/(cumCF(t)-cumCF(t-1));
        break;
    end
end

% dynamic
CF_disc = CF ./ (1+disc).^(0:10);
cumCF_disc = cumsum(CF_disc);
NPV = cumCF_disc(end);
IRR = irr_bisect(CF);
payback_d = NaN;
for t=2:11
    if cumCF_disc(t)>=0
        payback_d = (t-2) + (-cumCF_disc(t-1))/(cumCF_disc(t)-cumCF_disc(t-1));
        break;
    end
end

BC = sum(Revenue(2:11)) / ((reno+equip)/1e4 + sum(Cost(2:11)));

fprintf('\n--- Cash flow (wan) ---\n');
fprintf(' %-4s %8s %8s %8s %10s\n','Year','Rev','Cost','CF','CumCF');
for t=1:11
    fprintf(' %-4d %8.1f %8.1f %8.1f %10.1f\n',...
            Tspan(t),Revenue(t),Cost(t),CF(t),cumCF(t));
end
fprintf('\n Static payback : %s\n',ternary(~isnan(payback_s),sprintf('%.2f yr',payback_s),'not within 10 yr'));
fprintf(' NPV(%.0f%%)      : %.1f wan\n',disc*100,NPV);
fprintf(' IRR            : %s\n',ternary(~isnan(IRR),sprintf('%.2f%%',IRR*100),'no real root'));
fprintf(' Dynamic payback: %s\n',ternary(~isnan(payback_d),sprintf('%.2f yr',payback_d),'not within 10 yr'));
fprintf(' 10-yr B/C ratio: %.3f\n',BC);

%% ========================================================================
%  5.  DISCOUNT-RATE SENSITIVITY
%  ========================================================================
drates = 0.06:0.01:0.10;
NPV_dr = arrayfun(@(d) sum(CF./(1+d).^(0:10)), drates);
fprintf('\n--- Discount-rate sensitivity ---\n');
for k=1:numel(drates)
    fprintf('  %.0f%%: NPV = %.1f wan\n',drates(k)*100,NPV_dr(k));
end

%% ========================================================================
%  6.  PRICING-SUBSIDY OPTIMISATION (2-D grid over rent & fee scaling)
%  ========================================================================
rent_scan = linspace(16,40,25);          % tenant rent CNY/m^2/mo (16=baseline .. 40=full)
feeScale  = linspace(0.8,1.6,25);         % usage-fee multiplier
NPVgrid = zeros(numel(feeScale),numel(rent_scan));
for i=1:numel(feeScale)
    for j=1:numel(rent_scan)
        R1p = office_occ.*rent_scan(j)*12/1e4;
        R2p = (useH*fee_hw+useC*fee_comp)*feeScale(i)/1e4;
        R3p = office_occ.*(rent_ceiling*subsidy_rent)*12/1e4;  % gov subsidy fixed
        Revp = R1p+R2p+R3p+R4;
        CFp = zeros(1,11); CFp(1)=CF(1); CFp(2:11)=Revp(2:11)-Cost(2:11);
        NPVgrid(i,j) = sum(CFp./(1+disc).^(0:10));
    end
end
[bestNPV,idx] = max(NPVgrid(:));
[bi,bj] = ind2sub(size(NPVgrid),idx);
opt_rent = rent_scan(bj); opt_feeScale = feeScale(bi);
fprintf('\n--- Pricing optimisation ---\n');
fprintf('  optimal tenant rent = %.1f CNY/m^2/mo\n',opt_rent);
fprintf('  optimal fee scale   = %.2f (hw %.0f, comp %.0f CNY/yr)\n',...
        opt_feeScale,fee_hw*opt_feeScale,fee_comp*opt_feeScale);
fprintf('  max NPV = %.1f wan\n',bestNPV);

% staged-pricing scenario (yr1-3 discounted, yr4+ full)
rent_stage = rent_tenant*ones(1,11);
rent_stage(Tspan>=4) = rent_ceiling;      % full price from yr4
R1s = office_occ.*rent_stage*12/1e4;
R3s = office_occ.*max(rent_ceiling-rent_stage,0)*12*subsidy_rent/1e4;
Revs = R1s + R2 + R3s + R4;
CFs = zeros(1,11); CFs(1)=CF(1); CFs(2:11)=Revs(2:11)-Cost(2:11);
NPVs = sum(CFs./(1+disc).^(0:10));
cumCFs = cumsum(CFs);
fprintf('  staged-pricing NPV = %.1f wan (10-yr end cumCF %.1f)\n',NPVs,cumCFs(end));

%% ========================================================================
%  7.  FIGURES
%  ========================================================================

% ---- FIG 1: cumulative cash flow (break-even chart) ----
f1=figure('Color','w','Position',[60 60 760 480]);
ax=axes(f1); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
patch(ax,[0 10 10 0],[0 0 -3200 -3200],col.red,'FaceAlpha',0.05,'EdgeColor','none');
patch(ax,[0 10 10 0],[0 0 800 800],col.green,'FaceAlpha',0.06,'EdgeColor','none');
plot(ax,Tspan,cumCF,'-o','Color',col.blue,'MarkerFaceColor',col.blue,...
     'MarkerSize',6,'MarkerEdgeColor','w');
yline(ax,0,'--k','LineWidth',1.2,'Label','Break-even','FontSize',9);
[mn,mi]=min(cumCF);
plot(ax,Tspan(mi),mn,'v','MarkerSize',10,'MarkerFaceColor',col.red,'MarkerEdgeColor','k');
text(ax,Tspan(mi)+0.2,mn-120,sprintf('Trough %.0f wan\n(yr %d)',mn,Tspan(mi)),'FontSize',9,'Color',col.red);
text(ax,7.5,cumCF(11)+180,sprintf('yr10: %.0f wan',cumCF(11)),'FontSize',9,'Color',col.blue);
xlabel(ax,'Year'); ylabel(ax,'Cumulative net cash flow (\times10^4 CNY)');
title(ax,'Static Cumulative Cash Flow','FontWeight','bold');
xlim(ax,[0 10]);
exportgraphics(f1,fullfile(outdir,'Fig1_cumCF.png'),'Resolution',300);

% ---- FIG 2: annual revenue composition (stacked area) ----
f2=figure('Color','w','Position',[60 60 780 480]);
ax=axes(f2); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
Rstack=[R1;R2;R3;R4];
ha=area(ax,Tspan,Rstack','LineStyle','none');
cc={col.blue,col.green,col.orange,col.purple};
for i=1:4; ha(i).FaceColor=cc{i}; ha(i).FaceAlpha=0.85; end
xlabel(ax,'Year'); ylabel(ax,'Revenue (\times10^4 CNY)');
title(ax,'Annual Revenue Composition','FontWeight','bold');
legend(ax,{'Tenant rent (R1)','Usage fee (R2)','Gov rent subsidy (R3)','Cloud pass-through (R4)'},...
       'Location','northwest','Box','off','FontSize',9);
xlim(ax,[0 10]);
exportgraphics(f2,fullfile(outdir,'Fig2_revenue.png'),'Resolution',300);

% ---- FIG 3: annual revenue vs cost & net CF ----
f3=figure('Color','w','Position',[60 60 780 480]);
ax=axes(f3); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
bw=0.35;
bar(ax,Tspan(2:11)-bw/2,Revenue(2:11),bw,'FaceColor',col.green,'EdgeColor','none');
bar(ax,Tspan(2:11)+bw/2,Cost(2:11),bw,'FaceColor',col.orange,'EdgeColor','none');
plot(ax,Tspan(2:11),CF(2:11),'-o','Color',col.blue,'MarkerFaceColor',col.blue,...
     'MarkerSize',5,'MarkerEdgeColor','w','LineWidth',2);
yline(ax,0,'-k','LineWidth',0.8);
xlabel(ax,'Year'); ylabel(ax,'Amount (\times10^4 CNY)');
title(ax,'Annual Revenue, Cost & Net Cash Flow','FontWeight','bold');
legend(ax,{'Revenue','Cost','Net CF'},'Location','northwest','Box','off','FontSize',9);
xlim(ax,[1 10.5]);
exportgraphics(f3,fullfile(outdir,'Fig3_rev_cost.png'),'Resolution',300);

% ---- FIG 4: discount-rate sensitivity ----
f4=figure('Color','w','Position',[60 60 700 460]);
ax=axes(f4); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
bb=bar(ax,drates*100,NPV_dr,0.6,'FaceColor',col.teal,'EdgeColor','none');
% highlight baseline 8%
hold on; bar(ax,8,NPV_dr(drates==0.08),0.6,'FaceColor',col.red,'EdgeColor','none');
yline(ax,0,'-k','LineWidth',0.8);
for k=1:numel(drates)
    text(ax,drates(k)*100,NPV_dr(k)-70,sprintf('%.0f',NPV_dr(k)),...
         'HorizontalAlignment','center','FontSize',8);
end
xlabel(ax,'Discount rate (%)'); ylabel(ax,'NPV (\times10^4 CNY)');
title(ax,'NPV Sensitivity to Discount Rate','FontWeight','bold');
exportgraphics(f4,fullfile(outdir,'Fig4_npv_sensitivity.png'),'Resolution',300);

% ---- FIG 5: pricing-optimisation NPV heatmap ----
f5=figure('Color','w','Position',[60 60 780 500]);
ax=axes(f5);
imagesc(ax,rent_scan,feeScale,NPVgrid);
set(ax,'YDir','normal'); colormap(ax,parula); cb=colorbar(ax);
cb.Label.String='NPV (\times10^4 CNY)'; cb.Label.FontSize=11;
hold(ax,'on');
plot(ax,opt_rent,opt_feeScale,'p','MarkerSize',18,...
     'MarkerFaceColor',col.red,'MarkerEdgeColor','k');
text(ax,opt_rent,opt_feeScale+0.05,sprintf(' optimum NPV=%.0f',bestNPV),...
     'Color','k','FontSize',9,'FontWeight','bold');
xlabel(ax,'Tenant rent (CNY/m^2/month)');
ylabel(ax,'Usage-fee multiplier');
title(ax,'Pricing Optimisation: NPV Landscape','FontWeight','bold');
exportgraphics(f5,fullfile(outdir,'Fig5_pricing_heatmap.png'),'Resolution',300);

% ---- FIG 6: baseline vs staged-pricing cumulative CF ----
f6=figure('Color','w','Position',[60 60 760 480]);
ax=axes(f6); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
plot(ax,Tspan,cumCF,'-o','Color',col.blue,'MarkerFaceColor',col.blue,...
     'MarkerSize',5,'MarkerEdgeColor','w');
plot(ax,Tspan,cumCFs,'-s','Color',col.orange,'MarkerFaceColor',col.orange,...
     'MarkerSize',5,'MarkerEdgeColor','w');
yline(ax,0,'--k','LineWidth',1.2,'Label','Break-even','FontSize',9);
xlabel(ax,'Year'); ylabel(ax,'Cumulative net cash flow (\times10^4 CNY)');
title(ax,'Baseline vs Staged-Pricing Scenario','FontWeight','bold');
legend(ax,{sprintf('Baseline (NPV %.0f)',NPV),...
           sprintf('Staged pricing (NPV %.0f)',NPVs)},...
       'Location','southeast','Box','off','FontSize',9);
xlim(ax,[0 10]);
exportgraphics(f6,fullfile(outdir,'Fig6_scenario.png'),'Resolution',300);

%% ========================================================================
%  8.  EXPORT TABLE
%  ========================================================================
T = table(Tspan(:),round(Revenue(:),1),round(Cost(:),1),round(CF(:),1),...
          round(cumCF(:),1),round(CF_disc(:),1),round(cumCF_disc(:),1),...
          'VariableNames',{'Year','Revenue','Cost','NetCF','CumCF',...
          'DiscCF','CumDiscCF'});
writetable(T,fullfile(outdir,'Q4_results.csv'));
disp(' '); disp('--- Q4 cash flow table ---'); disp(T);

%% ========================================================================
%  9.  SUMMARY
%  ========================================================================
fprintf('\n============================================================\n');
fprintf(' Q4 KEY OUTPUTS\n');
fprintf('============================================================\n');
fprintf(' CAPEX                  : %.0f wan\n',(reno+equip)/1e4);
fprintf(' NPV (%.0f%%)             : %.1f wan\n',disc*100,NPV);
fprintf(' IRR                    : %s\n',ternary(~isnan(IRR),sprintf('%.2f%%',IRR*100),'n/a'));
fprintf(' 10-yr B/C ratio        : %.3f\n',BC);
fprintf(' Static cumCF @yr10     : %.1f wan\n',cumCF(11));
fprintf(' First CF>0 year        : yr%d\n',find(CF(2:11)>0,1));
fprintf(' Optimal rent / feeScale: %.1f CNY / %.2f  -> NPV %.0f wan\n',...
        opt_rent,opt_feeScale,bestNPV);
fprintf(' 6 figures saved to: %s\n',outdir);
fprintf('============================================================\n');

%% ========================================================================
%  helper functions
%  ========================================================================
function s=ternary(c,a,b); if c; s=a; else; s=b; end; end

function r=irr_bisect(cf)
% robust IRR via bisection on NPV(rate); returns NaN if no sign change
    f=@(x) sum(cf./(1+x).^(0:numel(cf)-1));
    lo=-0.99; hi=1.0;
    flo=f(lo); fhi=f(hi);
    if flo*fhi>0; r=NaN; return; end
    for k=1:200
        mid=(lo+hi)/2; fm=f(mid);
        if abs(fm)<1e-6; r=mid; return; end
        if flo*fm<0; hi=mid; else; lo=mid; flo=fm; end
    end
    r=(lo+hi)/2;
end